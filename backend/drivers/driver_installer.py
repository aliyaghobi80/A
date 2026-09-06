# backend/drivers/driver_installer.py
"""
Automatic Driver Folder Installer.
Scans a selected folder for driver installers (.exe, .msi, .inf),
installs them silently one by one with /NORESTART switches,
and verifies driver detection after each install.
"""

import logging
import os
import subprocess
import tempfile
import threading
import time
import zipfile
from typing import Dict, Any, List, Optional

from utils.powershell import run_powershell_json, get_hidden_subprocess_kwargs
from packages.manager import (
    _extract_exe_metadata,
    _guess_installer_type,
    _run_elevated_and_wait,
    _validate_installer,
)

logger = logging.getLogger(__name__)

# Global driver install state
_driver_lock = threading.Lock()
_driver_state: Dict[str, Any] = {
    "is_running": False,
    "cancelled": False,
    "total": 0,
    "completed": 0,
    "failed": 0,
    "skipped": 0,
    "current_file": None,
    "current_index": 0,
    "progress_percent": 0.0,
    "folder_path": "",
    "start_time": None,
    "end_time": None,
    "summary_message": "",
    "reboot_required": False,
    "items": [],
}
_driver_thread: Optional[threading.Thread] = None


def _driver_exe_silent_args(file_path: str, installer_type: Optional[str] = None) -> Optional[List[str]]:
    """Returns robust vendor/installer-specific silent switches for driver executables."""
    kind = installer_type or _guess_installer_type(file_path)
    filename = os.path.basename(file_path).lower()

    if kind == "innosetup":
        return ["/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART", "/SP-"]
    if kind in {"nsis", "7zip", "vlc"}:
        return ["/S", "/NORESTART"]
    if kind == "wix":
        return ["/quiet", "/norestart"]

    # DPInst (Driver Package Installer)
    if "dpinst" in filename:
        return ["/q", "/se", "/sa", "/sw"]

    # Vendor switches
    if "nvidia" in filename:
        return ["-s", "-noreboot"]
    if any(token in filename for token in ("amd", "radeon", "ati")):
        return ["-INSTALL", "-OUTPUT", "screen", "-NORESTART"]
    if "intel" in filename:
        return ["-s", "-norestart"]
    if any(token in filename for token in ("realtek", "lenovo", "audio", "lan", "wlan", "wifi", "bluetooth", "touchpad", "chipset")):
        return ["/s", "/norestart"]

    # Generic fallback
    return ["/s", "/S", "/VERYSILENT", "/quiet", "/norestart"]


def scan_driver_folder(folder_path: str) -> Dict[str, Any]:
    """
    Recursively scans the given folder for driver files:
    - .inf (Setup Information) -> PnPUtil
    - .msi (Windows Installer) -> MsiExec /qn /norestart
    - .exe (Executable Driver Setup) -> one verified silent strategy
    - .zip/.cab (Driver archive) -> safe extraction followed by PnPUtil
    
    Returns list of discovered driver files with size, type, relative path.
    """
    if not folder_path or not os.path.isdir(folder_path):
        return {
            "success": False,
            "message": f"پوشه انتخاب‌شده معتبر نیست: {folder_path}",
            "folder_path": folder_path,
            "total": 0,
            "files": [],
        }

    abs_folder = os.path.abspath(folder_path)
    discovered: List[Dict[str, Any]] = []

    try:
        ignored_dirs = {"backend", "_internal", "build", "dist", "node_modules", ".git", "temp", "tmp", "logs", "__pycache__"}
        for root, dirs, files in os.walk(abs_folder):
            dirs[:] = [d for d in dirs if d.lower() not in ignored_dirs and not d.startswith(".")]
            for file in files:
                f_lower = file.lower()
                if "backend_server" in f_lower or "markazisystemchecker" in f_lower:
                    continue
                ext = os.path.splitext(file)[1].lower()
                if ext in (".inf", ".msi", ".exe", ".zip", ".cab"):
                    full_path = os.path.join(root, file)
                    rel_path = os.path.relpath(full_path, abs_folder)
                    size = os.path.getsize(full_path) if os.path.isfile(full_path) else 0

                    type_label = ext.replace(".", "").upper()
                    entrypoint_desc = ""
                    if ext in (".zip", ".cab"):
                        install_method = "archive_installer"
                        is_valid = True
                        validation_error = None
                        auto_supported = True
                        if ext == ".zip":
                            try:
                                with zipfile.ZipFile(full_path, "r") as zf:
                                    names = [n.replace("\\", "/").lower() for n in zf.namelist()]
                                    if any(n.endswith("asussetup.exe") for n in names):
                                        entrypoint_desc = "AsusSetup.exe (نصاب رسمی ایسوس)"
                                    elif any(n.endswith(s) for n in names for s in ("silentinstall.cmd", "silentinstall.bat", "install.cmd", "install.bat")):
                                        entrypoint_desc = "اسکریپت نصب خودکار (Vendor Script)"
                                    elif any(n.endswith(s) for n in names for s in ("setup.exe", "installer.exe", "setuprst.exe", "igxpin.exe")):
                                        entrypoint_desc = "برنامه ستاپ درایور (Setup Executable)"
                                    elif any(n.endswith(".inf") for n in names):
                                        entrypoint_desc = "بسته راه‌انداز INF (PnPUtil)"
                                    elif any(n.endswith(".exe") for n in names):
                                        entrypoint_desc = "فایل اجرایی درایور"
                            except Exception:
                                pass
                    elif ext == ".inf":
                        install_method = "pnputil"
                        is_valid = True
                        validation_error = None
                        auto_supported = True
                        entrypoint_desc = "درایور سخت‌افزار INF"
                    elif ext == ".msi":
                        install_method = "msiexec"
                        is_valid = True
                        validation_error = None
                        auto_supported = True
                        entrypoint_desc = "بسته نصبی MSI"
                    else:
                        install_method = "executable"
                        installer_type = _guess_installer_type(full_path)
                        validation = _validate_installer(full_path, _extract_exe_metadata(full_path), installer_type, {})
                        is_valid = bool(validation["is_valid"])
                        validation_error = validation.get("validation_error")
                        auto_supported = bool(is_valid and _driver_exe_silent_args(full_path, installer_type) is not None)
                        entrypoint_desc = f"برنامه نصبی {installer_type.upper()}"

                    installer_type = _guess_installer_type(full_path) if ext == ".exe" else ext.lstrip(".")

                    discovered.append({
                        "filename": file,
                        "relative_path": rel_path,
                        "full_path": full_path,
                        "type": ext.replace(".", ""),
                        "type_label": type_label,
                        "install_method": install_method,
                        "installer_type": installer_type,
                        "entrypoint_description": entrypoint_desc,
                        "auto_install_supported": auto_supported,
                        "is_valid": is_valid,
                        "validation_error": validation_error,
                        "file_size": size,
                        "file_size_display": _format_size(size),
                    })

    except Exception as e:
        logger.error(f"Error scanning driver folder {folder_path}: {e}")
        return {
            "success": False,
            "message": f"خطا در اسکن پوشه: {str(e)}",
            "folder_path": abs_folder,
            "total": 0,
            "files": [],
        }

    def _type_priority(item):
        t = item["type"]
        if t == "inf":
            return 0
        elif t == "msi":
            return 1
        return 2

    discovered.sort(key=lambda x: (_type_priority(x), x["filename"].lower()))

    return {
        "success": True,
        "folder_path": abs_folder,
        "total": len(discovered),
        "files": discovered,
        "summary": {
            "total_files": len(discovered),
            "inf_count": sum(1 for d in discovered if d["type"] == "inf"),
            "msi_count": sum(1 for d in discovered if d["type"] == "msi"),
            "exe_count": sum(1 for d in discovered if d["type"] == "exe"),
            "archive_count": sum(1 for d in discovered if d["type"] in ("zip", "cab")),
            "manual_only_count": sum(1 for d in discovered if not d["auto_install_supported"]),
            "blocked_count": sum(1 for d in discovered if not d["is_valid"]),
        },
    }


def _format_size(size_bytes: int) -> str:
    if size_bytes < 1024:
        return f"{size_bytes} B"
    elif size_bytes < 1024 * 1024:
        return f"{size_bytes / 1024:.1f} KB"
    elif size_bytes < 1024 * 1024 * 1024:
        return f"{size_bytes / (1024 * 1024):.1f} MB"
    else:
        return f"{size_bytes / (1024 * 1024 * 1024):.2f} GB"


def _get_driver_error_description(exit_code: int, install_type: str, filename: str) -> str:
    """Returns a clear Persian description of why a driver succeeded or failed."""
    if exit_code in (0, 3010):
        if exit_code == 3010:
            return f"✓ {filename} با موفقیت نصب شد (نیازمند ری‌استارت سیستم)."
        return f"✓ {filename} با موفقیت نصب شد."
    elif exit_code == 1602 or exit_code == 1223:
        return f"⚠ نصب {filename} توسط کاربر لغو شد."
    elif exit_code == 1603:
        return f"✗ خطای ۱۶۰۳ در نصب {filename} (نیاز به دسترسی کامل ادمین یا عدم سازگاری بسته با این نسخه ویندوز)."
    elif exit_code == 1618:
        return f"✗ خطای ۱۶۱۸ در نصب {filename} (یک فرایند نصب دیگر در ویندوز در حال اجرا بود)."
    elif exit_code == 1619:
        return f"✗ خطای ۱۶۱۹ در نصب {filename} (بسته نصبی باز نشد یا مسیر فایل نامعتبر است)."
    elif exit_code == 1620:
        return f"✗ خطای ۱۶۲۰ در نصب {filename} (فایل نصبی خراب یا ناقص است)."
    elif exit_code == 1633:
        return f"✗ خطای ۱۶۳۳ در نصب {filename} (عدم تطابق معماری پردازنده یا نسخه سیستم‌عامل)."
    elif exit_code == 1638:
        return f"✓ نسخه دیگری از {filename} قبلاً روی سیستم نصب است."
    elif exit_code == 2:
        return f"✗ خطای ۲ در نصب {filename} (فایل نصبی یا پیش‌نیاز آن یافت نشد)."
    elif exit_code == 5:
        return f"✗ خطای ۵ در نصب {filename} (عدم دسترسی کافی - Access Denied)."
    elif exit_code == 259:
        return f"⚠ {filename}: دستگاه متناظری برای این درایور یافت نشد یا درایور قبلاً نصب است."
    elif exit_code == -1:
        return f"✗ تایم‌اوت یا عدم اجرای خودکار {filename}."
    elif install_type == "inf":
        return f"✗ خطای PnPUtil در نصب {filename} (کد خطای ویندوز: {exit_code})."
    else:
        return f"✗ نصب {filename} ناموفق بود (کد خروج: {exit_code})."


def _verify_driver_changes() -> List[Dict[str, Any]]:
    """Queries PnP devices via PowerShell to inspect driver state."""
    ps_script = """
    Get-CimInstance Win32_PnPEntity | Where-Object { $_.ConfigManagerErrorCode -ne 0 -or $_.Status -ne 'OK' } | Select-Object -Property DeviceID, Name, Description, Status, ConfigManagerErrorCode | ConvertTo-Json -Compress
    """
    try:
        res = run_powershell_json(ps_script)
        if isinstance(res, list):
            return res
        elif isinstance(res, dict):
            return [res]
    except Exception as e:
        logger.debug(f"Driver verification query error: {e}")
    return []


def _install_inf_tree(folder_path: str, timeout: int) -> tuple[int, str]:
    pattern = os.path.join(folder_path, "*.inf")
    result = subprocess.run(
        ["pnputil", "/add-driver", pattern, "/subdirs", "/install"],
        timeout=timeout,
        capture_output=True,
        text=True,
        **get_hidden_subprocess_kwargs(),
    )
    output = "\n".join(part for part in (result.stdout, result.stderr) if part).strip()
    return int(result.returncode), output


def _safe_extract_zip(archive_path: str, destination: str) -> None:
    destination_abs = os.path.abspath(destination)
    with zipfile.ZipFile(archive_path) as archive:
        for member in archive.infolist():
            target = os.path.abspath(os.path.join(destination_abs, member.filename))
            if os.path.commonpath([destination_abs, target]) != destination_abs:
                raise ValueError(f"Unsafe ZIP entry: {member.filename}")
        archive.extractall(destination_abs)


def _find_best_installer_in_extracted_tree(temp_dir: str) -> tuple[str, str, str]:
    """
    Finds the best installer entrypoint inside an extracted driver archive:
    Returns (kind, target_path, friendly_description)
    kind is one of: 'asus_setup', 'script', 'setup_exe', 'exe', 'msi', 'inf', 'unknown'
    """
    all_files: List[str] = []
    for root, _, files in os.walk(temp_dir):
        for f in files:
            all_files.append(os.path.join(root, f))

    # Priority 1: AsusSetup.exe (Unified ASUS motherboard driver installer)
    for full_p in all_files:
        if os.path.basename(full_p).lower() == "asussetup.exe":
            return "asus_setup", full_p, "AsusSetup.exe (نصاب رسمی ایسوس)"

    # Priority 2: Vendor Silent Scripts (SilentInstall.cmd / Install.cmd / Install.bat / run.bat)
    script_candidates = ("silentinstall.cmd", "silentinstall.bat", "install.cmd", "install.bat", "setup.cmd", "setup.bat", "run.bat")
    for full_p in all_files:
        if os.path.basename(full_p).lower() in script_candidates:
            return "script", full_p, f"{os.path.basename(full_p)} (اسکریپت خودکار)"

    # Priority 3: Setup.exe / Installer.exe / SetupRST.exe / igxpin.exe
    known_setups = (
        "setup.exe",
        "installer.exe",
        "setuprst.exe",
        "setupchipset.exe",
        "igxpin.exe",
        "platformperformancepackageinstaller.exe",
        "armourycrateinstaller.exe",
    )
    for full_p in all_files:
        if os.path.basename(full_p).lower() in known_setups:
            return "setup_exe", full_p, f"{os.path.basename(full_p)} (برنامه ستاپ)"

    # Priority 4: Any root or near-root .exe (depth <= 2 from temp_dir)
    for full_p in all_files:
        if full_p.lower().endswith(".exe"):
            rel = os.path.relpath(full_p, temp_dir)
            depth = len(rel.replace("\\", "/").split("/"))
            if depth <= 2:
                return "exe", full_p, f"{os.path.basename(full_p)} (فایل اجرایی)"

    # Priority 5: MSI Installer
    for full_p in all_files:
        if full_p.lower().endswith(".msi"):
            return "msi", full_p, f"{os.path.basename(full_p)} (نصاب MSI)"

    # Priority 6: INF Driver Tree
    has_inf = any(full_p.lower().endswith(".inf") for full_p in all_files)
    if has_inf:
        return "inf", temp_dir, "بسته‌های راه‌انداز INF (PnPUtil)"

    return "unknown", "", "فایل نصبی شناخته‌شده‌ای یافت نشد"


def _install_driver_archive(full_path: str, install_type: str, timeout: int) -> tuple[int, str]:
    archive_name = os.path.basename(full_path)
    with tempfile.TemporaryDirectory(prefix="markazi_driver_") as temp_dir:
        if install_type == "zip":
            try:
                _safe_extract_zip(full_path, temp_dir)
            except Exception as e:
                return -1, f"خطا در استخراج فایل زیپ: {str(e)}"
        else:
            expand_exe = os.path.join(os.environ.get("SystemRoot", r"C:\Windows"), "System32", "expand.exe")
            expanded = subprocess.run(
                [expand_exe, full_path, "-F:*", temp_dir],
                timeout=timeout,
                capture_output=True,
                text=True,
                **get_hidden_subprocess_kwargs(),
            )
            if expanded.returncode != 0:
                return int(expanded.returncode), (expanded.stderr or expanded.stdout or "CAB extraction failed").strip()

        kind, target_path, desc = _find_best_installer_in_extracted_tree(temp_dir)
        logger.info(f"[DriverBatch] Archive {archive_name} -> Resolved entrypoint: {desc} ({target_path})")

        if kind in ("asus_setup", "setup_exe", "exe"):
            work_dir = os.path.dirname(target_path)
            exe_name = os.path.basename(target_path).lower()
            if kind == "asus_setup" or "asus" in exe_name:
                cmd = [target_path, "-s", "-norestart"]
            else:
                silent_args = _driver_exe_silent_args(target_path) or ["/s", "/norestart"]
                cmd = [target_path] + silent_args

            exit_code = _run_elevated_and_wait(
                cmd,
                work_dir,
                timeout,
                keywords=[archive_name, os.path.basename(target_path), "driver", "setup", "asus", "installer"],
            )
            return exit_code, f"اجرای {desc}"

        elif kind == "script":
            work_dir = os.path.dirname(target_path)
            cmd = ["cmd.exe", "/c", target_path]
            exit_code = _run_elevated_and_wait(
                cmd,
                work_dir,
                timeout,
                keywords=[archive_name, os.path.basename(target_path), "driver", "setup", "install"],
            )
            return exit_code, f"اجرای اسکریپت {desc}"

        elif kind == "msi":
            work_dir = os.path.dirname(target_path)
            system_root = os.environ.get("SystemRoot", r"C:\Windows")
            cmd = [
                os.path.join(system_root, "System32", "msiexec.exe"),
                "/i",
                target_path,
                "/qn",
                "/norestart",
                "REBOOT=ReallySuppress",
            ]
            exit_code = _run_elevated_and_wait(cmd, work_dir, timeout)
            return exit_code, f"نصب بسته MSI {desc}"

        elif kind == "inf":
            return _install_inf_tree(temp_dir, timeout)

        else:
            return -5, "هیچ فایل نصبی یا درایور معتبری در فایل زیپ یافت نشد."


def _install_single_driver(driver_file: Dict[str, Any], timeout: int = 180) -> Dict[str, Any]:
    """
    Installs a single driver file silently:
    - .inf: pnputil /add-driver "<path>" /install
    - .msi: msiexec /i "<path>" /qn /norestart REBOOT=ReallySuppress
    - .exe: Try /S /NORESTART, /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-, etc.
    """
    full_path = driver_file["full_path"]
    filename = driver_file["filename"]
    install_type = driver_file["type"]

    if not os.path.isfile(full_path):
        return {
            "success": False,
            "exit_code": -1,
            "reboot_required": False,
            "message": f"فایل درایور یافت نشد: {filename}",
        }

    if not driver_file.get("is_valid", True):
        return {
            "success": False,
            "blocked": True,
            "exit_code": -2,
            "reboot_required": False,
            "message": driver_file.get("validation_error") or f"فایل مشکوک {filename} مسدود شد.",
        }

    logger.info(f"[DriverBatch] Installing {install_type.upper()}: {filename} ({full_path})")

    try:
        if install_type == "inf":
            cmd = ["pnputil", "/add-driver", full_path, "/install"]
            result = subprocess.run(
                cmd,
                timeout=timeout,
                capture_output=True,
                text=True,
                **get_hidden_subprocess_kwargs(),
            )
            exit_code = result.returncode
            success = exit_code in (0, 259, 3010)
            reboot_req = exit_code == 3010
            msg = _get_driver_error_description(exit_code, "inf", filename)
            return {
                "success": success,
                "exit_code": exit_code,
                "reboot_required": reboot_req,
                "message": msg,
            }

        elif install_type == "msi":
            working_dir = os.path.dirname(full_path)
            system_root = os.environ.get("SystemRoot", r"C:\Windows")
            cmd = [
                os.path.join(system_root, "System32", "msiexec.exe"),
                "/i",
                full_path,
                "/qn",
                "/norestart",
                "REBOOT=ReallySuppress",
            ]
            exit_code = _run_elevated_and_wait(cmd, working_dir, timeout)
            success = exit_code in (0, 3010, 1638)
            reboot_req = exit_code == 3010
            return {
                "success": success,
                "exit_code": exit_code,
                "reboot_required": reboot_req,
                "message": _get_driver_error_description(exit_code, "msi", filename),
            }

        elif install_type in ("zip", "cab"):
            exit_code, output = _install_driver_archive(full_path, install_type, timeout)
            success = exit_code in (0, 259, 3010)
            reboot_req = exit_code == 3010
            message = _get_driver_error_description(exit_code, "inf", filename)
            if not success and output:
                message = f"{message} {output[:300]}"
            return {
                "success": success,
                "exit_code": exit_code,
                "reboot_required": reboot_req,
                "message": message,
            }

        else:  # .exe
            working_dir = os.path.dirname(full_path)
            installer_type = driver_file.get("installer_type") or _guess_installer_type(full_path)
            silent_args = _driver_exe_silent_args(full_path, installer_type)
            if not silent_args:
                return {
                    "success": False,
                    "manual_required": True,
                    "exit_code": -4,
                    "reboot_required": False,
                    "message": f"⚠ نوع نصب خودکار {filename} شناخته‌شده نیست و برای ایمنی اجرا نشد.",
                }
            exit_code = _run_elevated_and_wait([full_path, *silent_args], working_dir, timeout)
            success = exit_code in (0, 3010, 1638)
            return {
                "success": success,
                "exit_code": exit_code,
                "reboot_required": exit_code == 3010,
                "message": _get_driver_error_description(exit_code, "exe", filename),
            }

    except subprocess.TimeoutExpired:
        return {
            "success": False,
            "exit_code": -1,
            "reboot_required": False,
            "message": f"تایم‌اوت در نصب {filename} پس از {timeout} ثانیه.",
        }
    except Exception as e:
        return {
            "success": False,
            "exit_code": -1,
            "reboot_required": False,
            "message": f"خطا در نصب {filename}: {str(e)}",
        }


def _run_driver_batch_thread(files: List[Dict[str, Any]], folder_path: str):
    """Sequential driver installation background worker."""
    global _driver_state
    total = len(files)
    any_reboot_required = False
    problems_before = {
        str(item.get("DeviceID") or item.get("Name") or "")
        for item in _verify_driver_changes()
        if item.get("DeviceID") or item.get("Name")
    }

    logger.info(f"[DriverBatch] Starting batch installation of {total} driver files from {folder_path}")

    for idx, f in enumerate(files):
        with _driver_lock:
            if _driver_state["cancelled"]:
                logger.info("[DriverBatch] Batch installation cancelled by user.")
                break

            _driver_state["current_file"] = f["filename"]
            _driver_state["current_index"] = idx
            _driver_state["progress_percent"] = round((idx / total) * 100.0, 1)
            if idx < len(_driver_state["items"]):
                _driver_state["items"][idx]["status"] = "installing"

        res = _install_single_driver(f)

        if res.get("reboot_required"):
            any_reboot_required = True

        with _driver_lock:
            if idx < len(_driver_state["items"]):
                if res.get("blocked"):
                    _driver_state["items"][idx]["status"] = "blocked"
                    _driver_state["items"][idx]["message"] = res.get("message", "فایل مشکوک مسدود شد")
                    _driver_state["skipped"] += 1
                elif res.get("manual_required"):
                    _driver_state["items"][idx]["status"] = "manual_required"
                    _driver_state["items"][idx]["message"] = res.get("message", "نیازمند نصب دستی")
                    _driver_state["skipped"] += 1
                elif res.get("success"):
                    _driver_state["items"][idx]["status"] = "completed"
                    _driver_state["items"][idx]["message"] = res.get("message", "نصب شد.")
                    _driver_state["completed"] += 1
                else:
                    _driver_state["items"][idx]["status"] = "failed"
                    _driver_state["items"][idx]["message"] = res.get("message", "خطا در نصب.")
                    _driver_state["failed"] += 1

            _driver_state["reboot_required"] = any_reboot_required
            _driver_state["progress_percent"] = round(((idx + 1) / total) * 100.0, 1)

        time.sleep(1.0)

    problems_after = {
        str(item.get("DeviceID") or item.get("Name") or "")
        for item in _verify_driver_changes()
        if item.get("DeviceID") or item.get("Name")
    }
    resolved_count = len(problems_before - problems_after)

    with _driver_lock:
        _driver_state["is_running"] = False
        _driver_state["current_file"] = None
        _driver_state["progress_percent"] = 100.0
        _driver_state["end_time"] = time.time()

        comp = _driver_state["completed"]
        failed = _driver_state["failed"]
        skipped = _driver_state["skipped"]
        _driver_state["problems_before"] = len(problems_before)
        _driver_state["problems_after"] = len(problems_after)
        _driver_state["resolved_problems"] = resolved_count

        if _driver_state["cancelled"]:
            _driver_state["summary_message"] = f"عملیات لغو شد. ({comp} نصب‌شده، {failed} ناموفق)"
        elif failed == 0 and skipped == 0:
            _driver_state["summary_message"] = f"✓ تمام {comp} فایل درایور با موفقیت نصب شدند."
        else:
            _driver_state["summary_message"] = f"پایان نصب: {comp} موفق، {failed} ناموفق و {skipped} نیازمند بررسی دستی از مجموع {total} فایل."

        if resolved_count:
            _driver_state["summary_message"] += f" ({resolved_count} خطای دستگاه برطرف شد)"

        if any_reboot_required:
            _driver_state["summary_message"] += " (جهت اعمال کامل، ری‌استارت سیستم پیشنهاد می‌شود)"

    logger.info(f"[DriverBatch] Batch finished: {_driver_state['summary_message']}")


def start_batch_driver_install(folder_path: str) -> Dict[str, Any]:
    """Scan folder and start sequential silent driver installation."""
    global _driver_thread, _driver_state

    with _driver_lock:
        if _driver_state["is_running"]:
            return {"success": False, "message": "عملیات نصب درایور در حال اجراست. لطفاً صبر کنید یا لغو کنید."}

    scan = scan_driver_folder(folder_path)
    if not scan.get("success") or not scan.get("files"):
        return {"success": False, "message": scan.get("message", "هیچ فایل درایوری یافت نشد.")}

    files = [
        item for item in scan["files"]
        if item.get("is_valid", True) and item.get("auto_install_supported", True)
    ]
    if not files:
        return {
            "success": False,
            "message": "هیچ بسته درایور معتبر با روش نصب خودکار شناخته‌شده یافت نشد.",
        }

    _driver_state = {
        "is_running": True,
        "cancelled": False,
        "total": len(files),
        "completed": 0,
        "failed": 0,
        "skipped": 0,
        "current_file": None,
        "current_index": 0,
        "progress_percent": 0.0,
        "folder_path": folder_path,
        "start_time": time.time(),
        "end_time": None,
        "summary_message": "",
        "reboot_required": False,
        "items": [
            {
                "filename": f["filename"],
                "relative_path": f["relative_path"],
                "type": f["type"],
                "file_size_display": f["file_size_display"],
                "status": "pending",
                "message": "",
            }
            for f in files
        ],
    }

    _driver_thread = threading.Thread(
        target=_run_driver_batch_thread,
        args=(files, folder_path),
        daemon=True,
        name="DriverBatchInstallerThread",
    )
    _driver_thread.start()

    return {
        "success": True,
        "message": f"صف نصب {len(files)} فایل درایور با موفقیت آغاز شد.",
        "total": len(files),
    }


def get_driver_batch_status() -> Dict[str, Any]:
    """Returns a snapshot of the current driver batch installation progress."""
    with _driver_lock:
        return dict(_driver_state)


def cancel_driver_batch_install() -> Dict[str, Any]:
    """Cancels the active driver batch installation."""
    global _driver_state
    with _driver_lock:
        if not _driver_state["is_running"]:
            return {"success": False, "message": "هیچ عملیات نصب درایوری در حال اجرا نیست."}

        _driver_state["cancelled"] = True
        _driver_state["summary_message"] = "در حال لغو عملیات..."
        logger.info("[DriverBatch] Cancel requested by client.")

    return {"success": True, "message": "درخواست لغو عملیات ارسال شد."}
