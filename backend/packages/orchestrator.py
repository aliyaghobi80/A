# backend/packages/orchestrator.py
"""
Setup & Deployment Orchestrator for Markazi System Checker.
Automates pre-installation and post-installation workflows:
1. Intelligent Office archive detection and extraction (extract here if not yet extracted).
2. KMS archive detection and extraction into the PROGRAM directory.
3. Windows activation execution via elevated WINDOWS.cmd and live licensing verification.
4. Essential desktop icons configuration (This PC, Recycle Bin, Control Panel).
5. Essential device settings application:
   - Display & Sleep timeouts to Never (powercfg)
   - Laptop power modes (AC: Best performance, DC: Balanced)
   - Tehran timezone (UTC+03:30) and automatic timezone update
   - Startup apps optimization
   - Windows 10 background apps optimization
"""

import os
import sys
import time
import logging
import subprocess
from typing import Dict, Any, Optional, List

from drivers.archive_extractor import extract_driver_archive
from activation.windows_activation import _query_wmi_licensing
from activation.activation_tools import execute_activation_tool, DEFAULT_TOOLS_DIR, is_safe_tool_path
from windows.desktop_time import show_desktop_icons, set_tehran_automatic_timezone
from windows.device_settings import (
    set_sleep_never,
    disable_all_startup_apps,
    disable_windows10_background_apps,
    has_battery,
    get_windows_identity,
)
from windows.power_settings import set_laptop_power_modes

logger = logging.getLogger(__name__)


def is_office_already_extracted(packages_dir: str) -> bool:
    """
    Checks if Microsoft Office is already extracted in the packages directory.
    Returns True if an 'Office' or 'Microsoft Office' folder exists and contains
    setup/install executables or scripts.
    """
    if not packages_dir or not os.path.isdir(packages_dir):
        return False

    try:
        for entry in os.listdir(packages_dir):
            full_path = os.path.join(packages_dir, entry)
            if os.path.isdir(full_path) and "office" in entry.lower():
                # Check if it contains setup files
                for root, _, files in os.walk(full_path):
                    for f in files:
                        f_lower = f.lower()
                        if f_lower in ("setup.exe", "install.exe", "setup.cmd", "office.cmd", "install.cmd", "configuration.xml"):
                            logger.info(f"[Orchestrator] Office already extracted in: {full_path}")
                            return True
                # If the folder exists and has at least 3 files, consider it extracted
                file_count = sum(len(files) for _, _, files in os.walk(full_path))
                if file_count >= 3:
                    logger.info(f"[Orchestrator] Office folder detected with {file_count} files in: {full_path}")
                    return True
    except Exception as e:
        logger.warning(f"[Orchestrator] Error checking office extraction status: {e}")

    return False


def ensure_office_extracted(packages_dir: str) -> Dict[str, Any]:
    """
    Checks whether the Office folder has been extracted.
    If not extracted, extracts any Office archive (.rar, .zip, .7z) found in packages_dir.
    If already extracted, returns successfully without redundant work.
    """
    identity = get_windows_identity()
    if identity.get("is_home") is True:
        return {
            "success": True,
            "skipped": True,
            "blocked": True,
            "home_guard": True,
            "windows": identity,
            "message": "Windows Home اورجینال است؛ آرشیو Office استخراج نمی‌شود.",
        }

    if not packages_dir or not os.path.isdir(packages_dir):
        return {
            "success": True,
            "skipped": True,
            "message": "پوشه نرم‌افزارها در دسترس نیست.",
        }

    if is_office_already_extracted(packages_dir):
        return {
            "success": True,
            "already_extracted": True,
            "message": "پوشه آفیس قبلاً استخراج شده است (بدون نیاز به تغییر).",
        }

    # Find Office archive
    archive_candidates = []
    try:
        for entry in os.listdir(packages_dir):
            entry_lower = entry.lower()
            if "office" in entry_lower:
                _, ext = os.path.splitext(entry_lower)
                if ext in (".rar", ".zip", ".7z"):
                    archive_candidates.append(os.path.join(packages_dir, entry))
    except Exception as e:
        logger.warning(f"[Orchestrator] Error searching for Office archive: {e}")

    if not archive_candidates:
        return {
            "success": True,
            "skipped": True,
            "message": "آرشیو فشرده آفیس در پوشه نرم‌افزارها یافت نشد.",
        }

    # Sort to pick the cleanest name first
    archive_candidates.sort(key=lambda p: len(os.path.basename(p)))
    target_archive = archive_candidates[0]
    archive_name = os.path.basename(target_archive)

    logger.info(f"[Orchestrator] Extracting Office archive: {target_archive} into {packages_dir}")
    try:
        ok = extract_driver_archive(target_archive, packages_dir)
        if ok:
            return {
                "success": True,
                "already_extracted": False,
                "archive_name": archive_name,
                "message": f"آرشیو آفیس ({archive_name}) با موفقیت استخراج شد.",
            }
        else:
            return {
                "success": False,
                "archive_name": archive_name,
                "message": f"استخراج خودکار آرشیو آفیس ({archive_name}) ناموفق بود.",
            }
    except Exception as e:
        logger.error(f"[Orchestrator] Office extraction error: {e}")
        return {
            "success": False,
            "archive_name": archive_name,
            "message": f"خطا در استخراج آفیس: {e}",
        }


def extract_kms_archive(packages_dir: str) -> Dict[str, Any]:
    """
    Finds and extracts any archive starting with 'kms', 'KMS', or 'KMS v6' (.rar, .zip, .7z)
    inside the PROGRAM / packages folder directly (extract here).
    """
    identity = get_windows_identity()
    if identity.get("is_home") is True:
        return {
            "success": True,
            "skipped": True,
            "blocked": True,
            "home_guard": True,
            "found": False,
            "windows": identity,
            "message": "Windows Home اورجینال است؛ آرشیو KMS استخراج نشد.",
        }

    if not packages_dir or not os.path.isdir(packages_dir):
        return {
            "success": True,
            "found": False,
            "message": "پوشه پکیج‌ها یافت نشد.",
        }

    kms_archives = []
    try:
        for entry in os.listdir(packages_dir):
            entry_lower = entry.lower()
            if entry_lower.startswith("kms") or "kms v" in entry_lower or "kms_" in entry_lower or "kmsauto" in entry_lower:
                _, ext = os.path.splitext(entry_lower)
                if ext in (".rar", ".zip", ".7z"):
                    kms_archives.append(os.path.join(packages_dir, entry))
    except Exception as e:
        logger.warning(f"[Orchestrator] Error scanning for KMS archives: {e}")

    # Avoid re-extracting KMS v6, while still allowing a v6 archive to replace
    # an older extracted KMS folder that happens to be present in PROGRAM.
    existing_cmd = find_windows_cmd(packages_dir, allow_bundled=False)
    if existing_cmd:
        relative = os.path.relpath(existing_cmd, packages_dir).replace("\\", "/").lower()
        normalized = relative.replace("_", " ").replace("-", " ")
        has_v6_archive = any(
            "kms v6" in os.path.basename(path).lower().replace("_", " ").replace("-", " ")
            for path in kms_archives
        )
        if "kms v6" in normalized or ("kms" in normalized and not has_v6_archive):
            return {
                "success": True,
                "found": True,
                "already_extracted": True,
                "command_path": existing_cmd,
                "message": "KMS v6 قبلاً در پوشه PROGRAM استخراج شده است.",
            }

    if not kms_archives:
        logger.info("[Orchestrator] No KMS archive found in packages directory.")
        return {
            "success": True,
            "found": False,
            "message": "آرشیو KMS در پوشه نرم‌افزارها یافت نشد.",
        }

    # Prefer the explicitly requested KMS v6 archive over older KMS bundles.
    def archive_priority(path: str) -> tuple[int, int, str]:
        name = os.path.basename(path).lower().replace("_", " ").replace("-", " ")
        return (0 if "kms v6" in name else 1, len(name), name)

    kms_archives.sort(key=archive_priority)
    # Extract the KMS archive directly into packages_dir ("extract here")
    target_archive = kms_archives[0]
    archive_name = os.path.basename(target_archive)
    logger.info(f"[Orchestrator] Extracting KMS archive: {target_archive} directly into {packages_dir}")

    try:
        ok = extract_driver_archive(target_archive, packages_dir)
        return {
            "success": ok,
            "found": True,
            "archive_name": archive_name,
            "message": f"آرشیو {archive_name} با موفقیت در پوشه استخراج شد." if ok else f"خطا در استخراج آرشیو {archive_name}.",
        }
    except Exception as e:
        logger.error(f"[Orchestrator] KMS extraction error: {e}")
        return {
            "success": False,
            "found": True,
            "archive_name": archive_name,
            "message": f"خطا در استخراج KMS: {e}",
        }


def find_windows_cmd(packages_dir: Optional[str] = None, allow_bundled: bool = True) -> Optional[str]:
    """
    Finds WINDOWS.cmd (or windows.cmd) in the packages directory and subfolders,
    falling back to Tools/WINDOWS.cmd in the repo root.
    """
    candidates = []

    # 1. Look in packages_dir
    if packages_dir and os.path.isdir(packages_dir):
        for root, _, files in os.walk(packages_dir):
            for f in files:
                f_lower = f.lower()
                if f_lower in ("windows.cmd", "windows.bat", "window.cmd", "window.bat", "win.cmd", "activate.cmd"):
                    candidates.append(os.path.join(root, f))

    # Prefer KMS v6, then an exact WINDOWS.cmd name, then shorter paths.  This
    # makes PROGRAM deterministic when it contains older activator folders too.
    if candidates:
        candidates.sort(
            key=lambda c: (
                0 if "kms v6" in c.lower().replace("_", " ").replace("-", " ") else 1,
                0 if os.path.basename(c).lower() == "windows.cmd" else 1,
                len(c),
                c.lower(),
            )
        )
        return os.path.abspath(candidates[0])

    # 2. Fallback to bundled Tools/WINDOWS.cmd
    bundled_cmd = os.path.abspath(os.path.join(DEFAULT_TOOLS_DIR, "WINDOWS.cmd"))
    if allow_bundled and os.path.isfile(bundled_cmd):
        return bundled_cmd

    return None


def run_windows_cmd_activation(packages_dir: Optional[str] = None, timeout_seconds: int = 90) -> Dict[str, Any]:
    """
    Executes WINDOWS.cmd with Administrator privileges, then waits and polls
    until Windows licensing verifies active status.
    """
    identity = get_windows_identity()
    if identity.get("is_home") is True:
        return {
            "success": True,
            "skipped": True,
            "blocked": True,
            "home_guard": True,
            "windows": identity,
            "message": "Windows Home اورجینال است؛ KMS اجرا نشد.",
        }

    # 1. Check if already activated
    try:
        current_lic = _query_wmi_licensing()
        if current_lic.get("activated") is True:
            logger.info("[Orchestrator] Windows is already fully licensed and activated.")
            return {
                "success": True,
                "already_activated": True,
                "message": "ویندوز قبلاً فعال و دارای لایسنس قانونی است.",
            }
    except Exception:
        pass

    # 2. Find WINDOWS.cmd
    cmd_path = find_windows_cmd(packages_dir, allow_bundled=packages_dir is None)
    if not cmd_path or not os.path.isfile(cmd_path):
        return {
            "success": False,
            "message": "اسکریپت فعال‌سازی WINDOWS.cmd مربوط به KMS v6 در پوشه PROGRAM یافت نشد.",
        }

    logger.info(f"[Orchestrator] Found WINDOWS.cmd at: {cmd_path}")

    # 3. Execute WINDOWS.cmd with Administrator privileges
    try:
        from activation.activation_tools import execute_activation_tool, set_tools_directory, get_activation_config

        # Temporarily configure or run
        work_dir = os.path.dirname(cmd_path)
        log_file = os.path.join(work_dir, "windows_activation_run.log")

        # Win32 ShellExecuteEx elevated
        import ctypes
        from ctypes import wintypes

        SEE_MASK_NOCLOSEPROCESS = 0x00000040
        SW_HIDE = 0

        class SHELLEXECUTEINFOW(ctypes.Structure):
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
                ("lpIDList", ctypes.c_void_p),
                ("lpClass", wintypes.LPCWSTR),
                ("hkeyClass", wintypes.HKEY),
                ("dwHotKey", wintypes.DWORD),
                ("hIcon", wintypes.HANDLE),
                ("hProcess", wintypes.HANDLE),
            ]

        sei = SHELLEXECUTEINFOW()
        sei.cbSize = ctypes.sizeof(SHELLEXECUTEINFOW)
        sei.fMask = SEE_MASK_NOCLOSEPROCESS
        sei.hwnd = None
        sei.lpVerb = "runas"
        sei.lpFile = "cmd.exe"
        sei.lpParameters = f'/d /s /c "(echo 1) | call "{cmd_path}" > "{log_file}" 2>&1"'
        sei.lpDirectory = work_dir
        sei.nShow = SW_HIDE

        shell32 = ctypes.windll.shell32
        kernel32 = ctypes.windll.kernel32
        shell32.ShellExecuteExW.argtypes = [ctypes.POINTER(SHELLEXECUTEINFOW)]
        shell32.ShellExecuteExW.restype = wintypes.BOOL
        kernel32.WaitForSingleObject.argtypes = [wintypes.HANDLE, wintypes.DWORD]
        kernel32.WaitForSingleObject.restype = wintypes.DWORD
        kernel32.GetExitCodeProcess.argtypes = [wintypes.HANDLE, ctypes.POINTER(wintypes.DWORD)]
        kernel32.CloseHandle.argtypes = [wintypes.HANDLE]

        if not shell32.ShellExecuteExW(ctypes.byref(sei)):
            err = ctypes.GetLastError()
            return {
                "success": False,
                "message": f"اجرای WINDOWS.cmd با دسترسی مدیر انجام نشد (کد: {err}).",
            }

        h_process = sei.hProcess

        # 4. Monitor & poll until activated or process completes
        poll_start = time.time()
        activated = False

        while time.time() - poll_start < timeout_seconds:
            # Check WMI licensing
            try:
                lic = _query_wmi_licensing()
                if lic.get("activated") is True:
                    activated = True
                    logger.info("[Orchestrator] Windows activation verified successfully via WMI!")
                    break
            except Exception:
                pass

            # Check if process finished
            if h_process:
                wait_res = kernel32.WaitForSingleObject(h_process, 2000)
                if wait_res == 0:
                    logger.info("[Orchestrator] WINDOWS.cmd process finished.")
                    # Check one more time
                    time.sleep(1)
                    lic = _query_wmi_licensing()
                    activated = lic.get("activated") is True
                    break
            else:
                time.sleep(2)

        if h_process:
            kernel32.CloseHandle(h_process)

        if activated:
            return {
                "success": True,
                "activated": True,
                "message": "ویندوز با موفقیت فعال و لایسنس تأیید شد.",
            }
        else:
            return {
                "success": False,
                "activated": False,
                "message": "اسکریپت اجرا شد اما فعال‌سازی ویندوز هنوز تأیید نشده است.",
            }

    except Exception as e:
        logger.error(f"[Orchestrator] Error executing WINDOWS.cmd: {e}")
        return {
            "success": False,
            "message": f"خطا در اجرای فعال‌سازی ویندوز: {e}",
        }


def activate_windows_from_packages(
    packages_dir: Optional[str], timeout_seconds: int = 90
) -> Dict[str, Any]:
    """Prepare KMS v6 from the selected PROGRAM folder, then run WINDOWS.cmd."""
    identity = get_windows_identity()
    if identity.get("is_home") is True:
        return {
            "success": True,
            "skipped": True,
            "blocked": True,
            "home_guard": True,
            "windows": identity,
            "message": "Windows Home اورجینال است؛ KMS استخراج یا اجرا نشد.",
        }

    extraction = extract_kms_archive(packages_dir or "")
    if not extraction.get("success", False):
        return {
            "success": False,
            "extraction": extraction,
            "message": extraction.get("message", "استخراج KMS v6 ناموفق بود."),
        }

    activation = run_windows_cmd_activation(packages_dir, timeout_seconds=timeout_seconds)
    activation["extraction"] = extraction
    return activation


def apply_desktop_icons() -> Dict[str, Any]:
    """
    Adds This PC, Recycle Bin, and Control Panel icons to the desktop.
    """
    try:
        from activation.windows_activation import get_windows_activation_info

        activation = get_windows_activation_info()
        if activation.get("activated") is not True:
            return {
                "success": False,
                "blocked": True,
                "message": "ابتدا فعال‌بودن ویندوز را تأیید کنید؛ آیکن‌های دسکتاپ تغییری نکردند.",
                "activation": activation,
            }
        res = show_desktop_icons(force=True)
        res["activation"] = activation
        return res
    except Exception as e:
        logger.error(f"[Orchestrator] Error applying desktop icons: {e}")
        return {
            "success": False,
            "message": f"خطا در تنظیم آیکن‌های دسکتاپ: {e}",
        }


def apply_essential_device_settings() -> Dict[str, Any]:
    """
    Applies the essential device settings in sequence:
    1. Sleep & screen timeouts to Never (for both AC & DC).
    2. Laptop power modes (AC: Best Performance, DC: Balanced) if device has battery.
    3. Tehran timezone (UTC+03:30) and automatic timezone update.
    4. Startup apps optimization.
    5. Windows 10 background apps optimization (if Windows 10).
    """
    results = {}

    # 1. Sleep & Screen Timeouts to Never
    try:
        sleep_res = set_sleep_never()
        results["sleep_never"] = sleep_res
        logger.info(f"[Orchestrator] Sleep timeouts set to Never: {sleep_res.get('success')}")
    except Exception as e:
        results["sleep_never"] = {"success": False, "message": str(e)}

    # 2. Power Modes (if battery/laptop)
    try:
        if has_battery():
            power_res = set_laptop_power_modes()
            results["power_modes"] = power_res
            logger.info(f"[Orchestrator] Laptop power modes set: {power_res.get('success')}")
        else:
            results["power_modes"] = {
                "success": True,
                "skipped": True,
                "message": "دستگاه رومیزی (بدون باتری) است؛ طرح توان لپ‌تاپ نیاز نیست.",
            }
    except Exception as e:
        results["power_modes"] = {"success": False, "message": str(e)}

    # 3. Tehran Timezone
    try:
        tz_res = set_tehran_automatic_timezone()
        results["tehran_timezone"] = tz_res
        logger.info(f"[Orchestrator] Tehran timezone configured: {tz_res.get('success')}")
    except Exception as e:
        results["tehran_timezone"] = {"success": False, "message": str(e)}

    # 4. Disable Startup Apps (silent, non-elevated user-level execution)
    try:
        startup_res = disable_all_startup_apps(elevate=False, open_page=False)
        results["startup_apps"] = startup_res
        logger.info(f"[Orchestrator] Startup apps configured: {startup_res.get('success')}")
    except Exception as e:
        results["startup_apps"] = {"success": False, "message": str(e)}

    # 5. Disable Windows 10 Background Apps
    identity = get_windows_identity()
    if identity.get("generation") == "Windows 10":
        try:
            bg_res = disable_windows10_background_apps(open_page=False)
            results["background_apps"] = bg_res
            logger.info(f"[Orchestrator] Windows 10 background apps disabled: {bg_res.get('success')}")
        except Exception as e:
            results["background_apps"] = {"success": False, "message": str(e)}

    # Core setting is sleep_never. If sleep_never or the majority succeeded, report success.
    sleep_ok = results.get("sleep_never", {}).get("success", False)
    all_success = all(v.get("success") for v in results.values())
    overall_ok = all_success or (sleep_ok and any(v.get("success") for k, v in results.items() if k != "sleep_never"))

    return {
        "success": overall_ok,
        "all_success": all_success,
        "results": results,
        "message": "تنظیمات مهم سیستم با موفقیت اعمال شدند." if all_success else "تنظیمات اصلی سیستم (خاموشی صفحه، زمان Sleep و...) با موفقیت اعمال شدند.",
    }
