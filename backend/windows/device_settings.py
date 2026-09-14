"""Safe, explicit Windows device settings used by the technician UI.

Nothing in this module runs at import time.  Every mutating operation is invoked
only from a dedicated API action and returns a structured result for the UI.
"""

from __future__ import annotations

import base64
import ctypes
import json
import os
import platform
import subprocess
import tempfile
from ctypes import wintypes
from pathlib import Path
from typing import Any, Dict, Optional


CREATE_NO_WINDOW = 0x08000000
SW_HIDE = 0
SEE_MASK_NOCLOSEPROCESS = 0x00000040
ERROR_CANCELLED = 1223


class _SHELLEXECUTEINFOW(ctypes.Structure):
    _fields_ = [
        ("cbSize", wintypes.DWORD),
        ("fMask", wintypes.ULONG),
        ("hwnd", wintypes.HWND),
        ("lpVerb", wintypes.LPCWSTR),
        ("lpFile", wintypes.LPCWSTR),
        ("lpParameters", wintypes.LPCWSTR),
        ("lpDirectory", wintypes.LPCWSTR),
        ("nShow", ctypes.c_int),
        ("hInstApp", wintypes.HINSTANCE),
        ("lpIDList", wintypes.LPVOID),
        ("lpClass", wintypes.LPCWSTR),
        ("hkeyClass", wintypes.HKEY),
        ("dwHotKey", wintypes.DWORD),
        ("hIconOrMonitor", wintypes.HANDLE),
        ("hProcess", wintypes.HANDLE),
    ]


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


def _wrap_elevated_payload(script: str, result_path: str) -> str:
    literal_path = "'" + result_path.replace("'", "''") + "'"
    return (
        "$ErrorActionPreference='Stop';"
        f"$resultPath={literal_path};"
        "try{& {"
        + script
        + "};"
        "$payload=[ordered]@{success=$true;registry_changed=[int]$script:RegistryChanged;packaged_changed=[int]$script:PackagedChanged};"
        "$payload|ConvertTo-Json -Compress|Set-Content -LiteralPath $resultPath -Encoding UTF8;exit 0}"
        "catch{$payload=[ordered]@{success=$false;error=$_.Exception.Message};"
        "$payload|ConvertTo-Json -Compress|Set-Content -LiteralPath $resultPath -Encoding UTF8;exit 1}"
    )


def _run_elevated_powershell(script: str, timeout: int = 120) -> subprocess.CompletedProcess[str]:
    """Run an encoded payload directly through ShellExecuteEx and capture a clean result."""
    fd, result_path = tempfile.mkstemp(prefix="msc-startup-", suffix=".json")
    os.close(fd)
    try:
        wrapped = _wrap_elevated_payload(script, result_path)
        encoded = base64.b64encode(wrapped.encode("utf-16le")).decode("ascii")
        command = [
            "powershell.exe",
            "-NoProfile",
            "-NonInteractive",
            "-ExecutionPolicy",
            "RemoteSigned",
            "-EncodedCommand",
            encoded,
        ]
        info = _SHELLEXECUTEINFOW()
        info.cbSize = ctypes.sizeof(_SHELLEXECUTEINFOW)
        info.fMask = SEE_MASK_NOCLOSEPROCESS
        info.lpVerb = "runas"
        info.lpFile = command[0]
        info.lpParameters = subprocess.list2cmdline(command[1:])
        info.lpDirectory = str(Path.cwd())
        info.nShow = SW_HIDE

        shell = ctypes.windll.shell32
        shell.ShellExecuteExW.argtypes = [ctypes.POINTER(_SHELLEXECUTEINFOW)]
        shell.ShellExecuteExW.restype = wintypes.BOOL
        kernel = ctypes.windll.kernel32
        kernel.WaitForSingleObject.argtypes = [wintypes.HANDLE, wintypes.DWORD]
        kernel.WaitForSingleObject.restype = wintypes.DWORD
        kernel.GetExitCodeProcess.argtypes = [wintypes.HANDLE, ctypes.POINTER(wintypes.DWORD)]
        kernel.GetExitCodeProcess.restype = wintypes.BOOL
        kernel.CloseHandle.argtypes = [wintypes.HANDLE]
        kernel.CloseHandle.restype = wintypes.BOOL
        ctypes.set_last_error(0)
        if not shell.ShellExecuteExW(ctypes.byref(info)):
            error = ctypes.get_last_error() or ctypes.windll.kernel32.GetLastError()
            return subprocess.CompletedProcess(command, ERROR_CANCELLED if error == ERROR_CANCELLED else -int(error or 1), "", "")
        if not info.hProcess:
            return subprocess.CompletedProcess(command, -4, "", "پردازش مدیریتی ایجاد نشد.")

        try:
            wait_result = kernel.WaitForSingleObject(info.hProcess, timeout * 1000)
            if wait_result != 0:
                return subprocess.CompletedProcess(command, -2, "", "عملیات در زمان تعیین‌شده کامل نشد.")
            exit_code = wintypes.DWORD()
            if not kernel.GetExitCodeProcess(info.hProcess, ctypes.byref(exit_code)):
                return subprocess.CompletedProcess(command, -3, "", "وضعیت پایان عملیات خوانده نشد.")
            output = ""
            try:
                with open(result_path, "r", encoding="utf-8-sig") as stream:
                    output = stream.read().strip()
            except OSError:
                pass
            return subprocess.CompletedProcess(command, int(exit_code.value), output, "")
        finally:
            kernel.CloseHandle(info.hProcess)
    finally:
        try:
            os.remove(result_path)
        except OSError:
            pass


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
$script:RegistryChanged = 0
$script:PackagedChanged = 0

function New-DisabledValue {
    $bytes = New-Object byte[] 12
    $bytes[0] = 3
    [BitConverter]::GetBytes([DateTime]::UtcNow.ToFileTimeUtc()).CopyTo($bytes, 4)
    # PowerShell enumerates arrays written to the pipeline. The leading comma
    # preserves byte[] so RegistryKey.SetValue receives REG_BINARY, not Object[].
    return ,$bytes
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
            [byte[]]$disabledValue = New-DisabledValue
            $target.SetValue([string]$name, $disabledValue, [Microsoft.Win32.RegistryValueKind]::Binary)
            $script:RegistryChanged++
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
            [byte[]]$disabledValue = New-DisabledValue
            $target.SetValue([string]$name, $disabledValue, [Microsoft.Win32.RegistryValueKind]::Binary)
            $script:RegistryChanged++
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

# Packaged applications (MSIX/UWP/Desktop Bridge) keep StartupTask state in
# SystemAppData rather than Explorer\StartupApproved. State 2 means Enabled;
# State 1 is DisabledByUser and remains reversible in Windows Settings.
$appModelRoot = 'Registry::HKEY_CURRENT_USER\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData'
if (Test-Path -LiteralPath $appModelRoot) {
    foreach ($packageKey in Get-ChildItem -LiteralPath $appModelRoot -ErrorAction SilentlyContinue) {
        foreach ($taskKey in Get-ChildItem -LiteralPath $packageKey.PSPath -ErrorAction SilentlyContinue) {
            $state = $taskKey.GetValue('State', $null)
            if ($state -eq 2) {
                Set-ItemProperty -LiteralPath $taskKey.PSPath -Name 'State' -Value 1
                Set-ItemProperty -LiteralPath $taskKey.PSPath -Name 'UserEnabledStartupOnce' -Value 0 -ErrorAction SilentlyContinue
                $script:PackagedChanged++
            }
        }
    }
}
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
        try:
            parsed = json.loads(result.stdout)
            details = str(parsed.get("error") or details)
        except Exception:
            pass
        return {"success": False, "message": details or "خاموش‌کردن Startup Apps انجام نشد."}
    registry_changed = 0
    packaged_changed = 0
    try:
        parsed = json.loads(result.stdout)
        registry_changed = int(parsed.get("registry_changed") or 0)
        packaged_changed = int(parsed.get("packaged_changed") or 0)
    except Exception:
        pass
    opened = _open_settings("ms-settings:startupapps")
    from windows.startup_status import get_startup_status
    state = get_startup_status()
    return {
        "success": state['all_disabled'] is True,
        "startup": state,
        "settings_opened": opened,
        "registry_changed": registry_changed,
        "packaged_changed": packaged_changed,
        "changed_count": registry_changed + packaged_changed,
        "message": (f"همهٔ Startup Apps خاموش هستند؛ {registry_changed + packaged_changed} ورودی پردازش شد." if state['all_disabled'] is True
                    else 'بعضی Startup Apps هنوز فعال یا غیرقابل‌بررسی هستند؛ صفحهٔ Startup را بررسی کنید.'),
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
        from windows.startup_status import get_background_status
        state = get_background_status(True)
        return {
            "success": state['all_disabled'] is True,
            "background_apps": state,
            "settings_opened": opened,
            "windows": identity,
            "message": ('Background Apps خاموش است؛ تنظیم سراسری تأیید شد.' if state['all_disabled'] is True
                        else 'خاموش‌شدن Background Apps تأیید نشد؛ ممکن است سیاست دستگاه مانع تغییر باشد.'),
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
        return status.BatteryFlag not in (128, 255)
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
        from windows.power_settings import get_timeout_status
        state = get_timeout_status()
        return {
            "success": state['all_never'] is True,
            "timeouts": state,
            "message": ('Screen، Sleep و Hibernate برای برق و باتری روی Never هستند؛ تأیید شد.' if state['all_never'] is True
                        else 'همهٔ زمان‌ها پس از تغییر تأیید نشدند؛ وضعیت طرح برق را بررسی کنید.'),
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
    from windows.power_settings import get_timeout_status, get_power_mode_status
    from windows.startup_status import get_startup_status, get_background_status
    identity = get_windows_identity()
    return {
        "success": True,
        "timeouts": get_timeout_status(),
        "power_modes": get_power_mode_status(),
        "startup": get_startup_status(),
        "background_apps": get_background_status(identity.get('generation') == 'Windows 10'),
        "has_battery": has_battery(),
        "windows": identity,
        "is_windows_10": identity.get("generation") == "Windows 10",
        "background_apps_supported": identity.get("generation") == "Windows 10",
        "taskbar_pin_requires_confirmation": identity.get("generation") == "Windows 11",
    }
