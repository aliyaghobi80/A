"""Create idempotent desktop shortcuts for the core Microsoft Office apps."""

from __future__ import annotations

import base64
import ctypes
import os
import subprocess
from pathlib import Path
from typing import Any, Dict, Optional


OFFICE_APPS = {
    "Word": "WINWORD.EXE",
    "Excel": "EXCEL.EXE",
    "PowerPoint": "POWERPNT.EXE",
}


def _desktop_path() -> Path:
    if os.name == "nt":
        try:
            buffer = ctypes.create_unicode_buffer(32768)
            # CSIDL_DESKTOPDIRECTORY resolves redirected/OneDrive desktops too.
            if ctypes.windll.shell32.SHGetFolderPathW(None, 0x10, None, 0, buffer) == 0:
                return Path(buffer.value)
        except Exception:
            pass
    return Path.home() / "Desktop"


def _find_app_path(executable: str) -> Optional[Path]:
    if os.name == "nt":
        try:
            import winreg

            subkey = rf"SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\{executable}"
            for hive in (winreg.HKEY_LOCAL_MACHINE, winreg.HKEY_CURRENT_USER):
                for view in (getattr(winreg, "KEY_WOW64_64KEY", 0), getattr(winreg, "KEY_WOW64_32KEY", 0)):
                    try:
                        with winreg.OpenKey(hive, subkey, 0, winreg.KEY_READ | view) as key:
                            candidate = Path(str(winreg.QueryValueEx(key, None)[0]).strip('"'))
                            if candidate.is_file():
                                return candidate
                    except OSError:
                        continue
        except Exception:
            pass

    roots = [os.environ.get("ProgramFiles"), os.environ.get("ProgramFiles(x86)")]
    for root in filter(None, roots):
        for office_dir in ("Office16", "Office15", "Office14"):
            candidate = Path(root) / "Microsoft Office" / "root" / office_dir / executable
            if candidate.is_file():
                return candidate
            legacy = Path(root) / "Microsoft Office" / office_dir / executable
            if legacy.is_file():
                return legacy
    return None


def _create_shortcut(shortcut: Path, executable: Path) -> None:
    literal = lambda value: "'" + str(value).replace("'", "''") + "'"
    script = (
        "$ErrorActionPreference='Stop';"
        f"$p={literal(shortcut)};$t={literal(executable)};"
        "$w=New-Object -ComObject WScript.Shell;$s=$w.CreateShortcut($p);"
        "$s.TargetPath=$t;$s.WorkingDirectory=[IO.Path]::GetDirectoryName($t);"
        "$s.IconLocation=\"$t,0\";$s.Save()"
    )
    encoded = base64.b64encode(script.encode("utf-16le")).decode("ascii")
    result = subprocess.run(
        ["powershell.exe", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "RemoteSigned", "-EncodedCommand", encoded],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=30,
        creationflags=0x08000000 if os.name == "nt" else 0,
    )
    if result.returncode != 0 or not shortcut.is_file():
        raise RuntimeError((result.stderr or result.stdout).strip() or "Shortcut creation failed")


def ensure_office_desktop_shortcuts() -> Dict[str, Any]:
    desktop = _desktop_path()
    desktop.mkdir(parents=True, exist_ok=True)
    created: list[str] = []
    missing: list[str] = []
    errors: list[str] = []
    for display_name, executable_name in OFFICE_APPS.items():
        executable = _find_app_path(executable_name)
        if executable is None:
            missing.append(display_name)
            continue
        try:
            _create_shortcut(desktop / f"{display_name}.lnk", executable)
            created.append(display_name)
        except Exception as exc:
            errors.append(f"{display_name}: {exc}")

    success = len(created) == len(OFFICE_APPS)
    if success:
        message = "میانبرهای Word، Excel و PowerPoint روی Desktop ساخته شدند."
    elif created:
        message = f"میانبرهای {', '.join(created)} ساخته شدند؛ موارد پیدا نشده: {', '.join(missing)}."
    else:
        message = "فایل اجرایی Word، Excel و PowerPoint پیدا نشد؛ میانبری ساخته نشد."
    return {"success": success, "created": created, "missing": missing, "errors": errors, "message": message}
