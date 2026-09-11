"""Safe, explicit Windows device settings used by the technician UI.

Nothing in this module runs at import time.  Every mutating operation is invoked
only from a dedicated API action and returns a structured result for the UI.
"""

from __future__ import annotations

import base64
import ctypes
import os
import platform
import subprocess
from ctypes import wintypes
from pathlib import Path
from typing import Any, Dict, Optional


CREATE_NO_WINDOW = 0x08000000
SW_HIDE = 0


class SYSTEM_POWER_STATUS(ctypes.Structure):
    _fields_ = [
        ("ACLineStatus", wintypes.BYTE),
        ("BatteryFlag", wintypes.BYTE),
        ("BatteryLifePercent", wintypes.BYTE),
        ("SystemStatusFlag", wintypes.BYTE),
        ("BatteryLifeTime", wintypes.DWORD),
        ("BatteryFullLifeTime", wintypes.DWORD),
    ]


def _run(command: list[str], timeout: int = 30) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=timeout,
        creationflags=CREATE_NO_WINDOW if os.name == "nt" else 0,
    )


def _powershell_encoded(script: str, timeout: int = 30) -> subprocess.CompletedProcess[str]:
    encoded = base64.b64encode(script.encode("utf-16le")).decode("ascii")
    return _run(
        [
            "powershell.exe",
            "-NoProfile",
            "-NonInteractive",
            "-ExecutionPolicy",
            "RemoteSigned",
            "-EncodedCommand",
            encoded,
        ],
        timeout=timeout,
    )


def _run_elevated_powershell(script: str, timeout: int = 120) -> subprocess.CompletedProcess[str]:
    """Run one encoded PowerShell payload elevated and wait for completion."""
    inner = base64.b64encode(script.encode("utf-16le")).decode("ascii")
    outer = (
        "$ErrorActionPreference='Stop';"
        f"$a=@('-NoProfile','-NonInteractive','-ExecutionPolicy','RemoteSigned','-EncodedCommand','{inner}');"
        "try{$p=Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $a -PassThru -Wait;exit $p.ExitCode}"
        "catch{if($_.Exception.NativeErrorCode -eq 1223){exit 1223};exit 1}"
    )
    return _powershell_encoded(outer, timeout=timeout)


def _open_settings(uri: str) -> bool:
    if os.name != "nt":
        return False
    try:
        os.startfile(uri)
        return True
    except Exception:
        try:
            subprocess.Popen(
                ["explorer.exe", uri],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                creationflags=CREATE_NO_WINDOW,
            )
            return True
        except Exception:
            return False


def _startup_disable_script() -> str:
    """Return an idempotent script matching Settings/Task Manager Startup toggles."""
    return r"""
$ErrorActionPreference = 'Stop'
$approvedRoot = 'Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved'
$runRoot = 'Software\Microsoft\Windows\CurrentVersion\Run'
$run32Root = 'Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'

function New-DisabledValue {
    $bytes = New-Object byte[] 12
    $bytes[0] = 3
    [BitConverter]::GetBytes([DateTime]::UtcNow.ToFileTimeUtc()).CopyTo($bytes, 4)
    return $bytes
}

function Disable-ApprovedEntries($hive, [string]$approvedName, [string]$sourcePath) {
    $names = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    $source = $hive.OpenSubKey($sourcePath, $false)
    if ($source) {
        foreach ($name in $source.GetValueNames()) { [void]$names.Add($name) }
        $source.Close()
    }
    $approvedPath = "$approvedRoot\$approvedName"
    $existing = $hive.OpenSubKey($approvedPath, $false)
    if ($existing) {
        foreach ($name in $existing.GetValueNames()) { [void]$names.Add($name) }
        $existing.Close()
    }
    if ($names.Count -gt 0) {
        $target = $hive.CreateSubKey($approvedPath, $true)
        foreach ($name in $names) {
            $target.SetValue($name, (New-DisabledValue), [Microsoft.Win32.RegistryValueKind]::Binary)
        }
        $target.Close()
    }
}

function Disable-StartupFolder($hive, [string]$folderPath) {
    $names = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    if (Test-Path -LiteralPath $folderPath) {
        Get-ChildItem -LiteralPath $folderPath -File -ErrorAction SilentlyContinue | ForEach-Object { [void]$names.Add($_.Name) }
    }
    $approvedPath = "$approvedRoot\StartupFolder"
    $existing = $hive.OpenSubKey($approvedPath, $false)
    if ($existing) {
        foreach ($name in $existing.GetValueNames()) { [void]$names.Add($name) }
        $existing.Close()
    }
    if ($names.Count -gt 0) {
        $target = $hive.CreateSubKey($approvedPath, $true)
        foreach ($name in $names) {
            $target.SetValue($name, (New-DisabledValue), [Microsoft.Win32.RegistryValueKind]::Binary)
        }
        $target.Close()
    }
}

$cu = [Microsoft.Win32.Registry]::CurrentUser
$lm = [Microsoft.Win32.Registry]::LocalMachine
Disable-ApprovedEntries $cu 'Run' $runRoot
Disable-ApprovedEntries $cu 'Run32' $run32Root
Disable-ApprovedEntries $lm 'Run' $runRoot
Disable-ApprovedEntries $lm 'Run32' $run32Root
Disable-StartupFolder $cu ([Environment]::GetFolderPath('Startup'))
Disable-StartupFolder $lm ([Environment]::GetFolderPath('CommonStartup'))
"""


def disable_all_startup_apps() -> Dict[str, Any]:
    """Disable entries surfaced by Windows Startup Apps, then open that page."""
    if os.name != "nt":
        return {"success": False, "message": "این قابلیت فقط در ویندوز در دسترس است."}
    result = _run_elevated_powershell(_startup_disable_script())
    if result.returncode == 1223:
        return {"success": False, "cancelled": True, "message": "درخواست دسترسی مدیر لغو شد؛ تغییری اعمال نشد."}
    if result.returncode != 0:
        details = (result.stderr or result.stdout).strip()
        return {"success": False, "message": details or "خاموش‌کردن Startup Apps انجام نشد."}
    opened = _open_settings("ms-settings:startupapps")
    return {
        "success": True,
        "settings_opened": opened,
        "message": "برنامه‌های Startup خاموش شدند و صفحهٔ بررسی Startup Apps باز شد؛ نیازی به ری‌استارت فوری نیست.",
    }


def disable_windows10_background_apps() -> Dict[str, Any]:
    """Disable the Windows 10 global Store/UWP background-app toggle."""
    identity = get_windows_identity()
    if identity.get("generation") != "Windows 10":
        return {
            "success": False,
            "unsupported": True,
            "windows": identity,
            "message": "این گزینه فقط برای Windows 10 است؛ در Windows 11 تنظیم سراسری Background Apps وجود ندارد.",
        }
    if os.name != "nt":
        return {"success": False, "message": "این قابلیت فقط در ویندوز در دسترس است."}
    try:
        import winreg

        with winreg.CreateKeyEx(
            winreg.HKEY_CURRENT_USER,
            r"Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications",
            0,
            winreg.KEY_SET_VALUE,
        ) as key:
            winreg.SetValueEx(key, "GlobalUserDisabled", 0, winreg.REG_DWORD, 1)
        with winreg.CreateKeyEx(
            winreg.HKEY_CURRENT_USER,
            r"Software\Microsoft\Windows\CurrentVersion\Search",
            0,
            winreg.KEY_SET_VALUE,
        ) as key:
            winreg.SetValueEx(key, "BackgroundAppGlobalToggle", 0, winreg.REG_DWORD, 0)
        opened = _open_settings("ms-settings:privacy-backgroundapps")
        return {
            "success": True,
            "settings_opened": opened,
            "windows": identity,
            "message": "اجرای پس‌زمینهٔ برنامه‌های Store در Windows 10 خاموش شد و صفحهٔ Background Apps باز شد.",
        }
    except Exception as exc:
        return {"success": False, "windows": identity, "message": f"خاموش‌کردن Background Apps انجام نشد: {exc}"}


def get_windows_identity() -> Dict[str, Any]:
    """Return a stable Windows 10/11 label plus Home-edition classification."""
    product_name = "Windows"
    edition_id = ""
    build = ""
    if os.name == "nt":
        try:
            import winreg

            key_path = r"SOFTWARE\Microsoft\Windows NT\CurrentVersion"
            with winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, key_path) as key:
                for value_name, fallback in (("ProductName", "Windows"), ("EditionID", ""), ("CurrentBuild", "")):
                    try:
                        value = str(winreg.QueryValueEx(key, value_name)[0]).strip()
                    except OSError:
                        value = fallback
                    if value_name == "ProductName":
                        product_name = value or fallback
                    elif value_name == "EditionID":
                        edition_id = value
                    else:
                        build = value
        except Exception:
            build = platform.version()

    try:
        build_number = int(build.split(".")[-1])
    except (TypeError, ValueError):
        build_number = 0

    # Some Windows 11 installations still expose "Windows 10" in ProductName.
    generation = "Windows 11" if build_number >= 22000 else "Windows 10"
    lower = f"{product_name} {edition_id}".lower().replace(" ", "")
    is_home = any(token in lower for token in ("home", "core", "coresinglelanguage"))

    suffix = "Home" if is_home else ""
    for candidate in ("Pro", "Enterprise", "Education"):
        if candidate.lower() in lower:
            suffix = candidate
            break
    label = f"{generation} {suffix}".strip()
    return {
        "product_name": product_name,
        "edition_id": edition_id,
        "build": build,
        "generation": generation,
        "label": label,
        "is_home": is_home,
    }


def has_battery() -> bool:
    if os.name != "nt":
        return False
    try:
        status = SYSTEM_POWER_STATUS()
        if not ctypes.windll.kernel32.GetSystemPowerStatus(ctypes.byref(status)):
            return False
        return status.BatteryFlag != 128
    except Exception:
        return False


def set_sleep_never() -> Dict[str, Any]:
    """Set display, standby, and hibernate timeouts to Never for AC/DC."""
    if os.name != "nt":
        return {"success": False, "message": "این قابلیت فقط در ویندوز در دسترس است."}

    results = []
    for mode in ("ac", "dc"):
        for timeout_name in ("monitor", "standby", "hibernate"):
            result = _run(
                [
                    "powercfg.exe",
                    "/change",
                    f"{timeout_name}-timeout-{mode}",
                    "0",
                ]
            )
            results.append(result)
    if all(item.returncode == 0 for item in results):
        return {
            "success": True,
            "message": "خاموش‌شدن نمایشگر، Sleep و Hibernate برای برق و باتری روی Never تنظیم شد؛ نیازی به ری‌استارت نیست.",
            "monitor_ac_minutes": 0,
            "monitor_dc_minutes": 0,
            "sleep_ac_minutes": 0,
            "sleep_dc_minutes": 0,
            "hibernate_ac_minutes": 0,
            "hibernate_dc_minutes": 0,
        }
    details = " ".join((item.stderr or item.stdout).strip() for item in results if item.returncode != 0)
    return {"success": False, "message": details or "تنظیم Sleep انجام نشد."}


def _start_menu_folder() -> Path:
    appdata = Path(os.environ.get("APPDATA", str(Path.home() / "AppData/Roaming")))
    folder = appdata / "Microsoft" / "Windows" / "Start Menu" / "Programs" / "Markazi System Checker"
    folder.mkdir(parents=True, exist_ok=True)
    return folder


def _create_shortcut(name: str, target: str, arguments: str = "", icon: str = "") -> Path:
    shortcut = _start_menu_folder() / f"{name}.lnk"
    literal = lambda value: "'" + str(value).replace("'", "''") + "'"
    script = (
        "$ErrorActionPreference='Stop';"
        f"$p={literal(shortcut)};$t={literal(target)};$a={literal(arguments)};$i={literal(icon)};"
        "$w=New-Object -ComObject WScript.Shell;$s=$w.CreateShortcut($p);"
        "$s.TargetPath=$t;$s.Arguments=$a;if($i){$s.IconLocation=$i};$s.Save()"
    )
    result = _powershell_encoded(script)
    if result.returncode != 0 or not shortcut.exists():
        raise RuntimeError((result.stderr or result.stdout).strip() or "Shortcut creation failed")
    return shortcut


def _try_legacy_taskbar_pin(shortcut: Path) -> bool:
    """Best effort for Windows 10. Windows 11 intentionally requires user confirmation."""
    identity = get_windows_identity()
    try:
        if int(identity.get("build") or 0) >= 22000:
            return False
    except ValueError:
        return False
    script = (
        f"$p={str(shortcut.parent)!r};$n={shortcut.name!r};"
        "$s=New-Object -ComObject Shell.Application;$i=$s.Namespace($p).ParseName($n);"
        "if(-not $i){exit 2};$i.InvokeVerb('taskbarpin');Start-Sleep -Milliseconds 500"
    )
    return _powershell_encoded(script).returncode == 0


def pin_to_taskbar(
    name: str,
    target: str,
    arguments: str = "",
    icon: str = "",
    launch_target: Optional[str] = None,
) -> Dict[str, Any]:
    """Create an app shortcut and request taskbar pinning without Taskband hacks."""
    if os.name != "nt":
        return {"success": False, "message": "این قابلیت فقط در ویندوز در دسترس است."}
    try:
        shortcut = _create_shortcut(name, target, arguments, icon)
        if _try_legacy_taskbar_pin(shortcut):
            return {"success": True, "message": f"{name} به Taskbar اضافه شد.", "shortcut": str(shortcut)}

        # Windows 11 does not expose a supported silent arbitrary-app pin API.
        try:
            os.startfile(launch_target) if launch_target else subprocess.Popen(
                [target, *([arguments] if arguments else [])], creationflags=CREATE_NO_WINDOW
            )
        except Exception:
            pass
        return {
            "success": True,
            "manual_required": True,
            "message": f"میانبر {name} ساخته و برنامه باز شد. روی آیکن آن در Taskbar راست‌کلیک و «Pin to taskbar» را انتخاب کنید.",
            "shortcut": str(shortcut),
        }
    except Exception as exc:
        return {"success": False, "message": f"ساخت میانبر Taskbar انجام نشد: {exc}"}


def pin_windows_security() -> Dict[str, Any]:
    explorer = os.path.join(os.environ.get("SystemRoot", r"C:\Windows"), "explorer.exe")
    return pin_to_taskbar(
        "Windows Security",
        explorer,
        "windowsdefender:",
        r"%SystemRoot%\System32\SecurityHealthSystray.exe,0",
        launch_target="windowsdefender:",
    )


def get_device_settings_status() -> Dict[str, Any]:
    identity = get_windows_identity()
    return {
        "success": True,
        "has_battery": has_battery(),
        "windows": identity,
        "is_windows_10": identity.get("generation") == "Windows 10",
        "background_apps_supported": identity.get("generation") == "Windows 10",
        "taskbar_pin_requires_confirmation": identity.get("generation") == "Windows 11",
    }
