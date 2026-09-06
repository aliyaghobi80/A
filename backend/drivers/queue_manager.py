# backend/drivers/queue_manager.py
"""
Intelligent Driver Installation Queue & Execution Manager.
Organizes selected driver packages into a strict 9-tier priority queue:
  1. Chipset / Platform
  2. Management Engine / Serial IO / System Interfaces
  3. Storage Controller (SATA / AHCI / RAID / NVMe)
  4. Wired LAN / Ethernet
  5. Wireless Wi-Fi
  6. Bluetooth
  7. Audio / Sound
  8. Dedicated & Integrated GPU
  9. Other peripheral devices

Executes packages sequentially:
- PnPUtil for INF packages (/add-driver ... /install)
- Standard & Vendor EXEs with verified silent switches
- MsiExec for MSI packages
- Post-install PnP device verification
- Real-time status reporting and reboot requirement tracking
- File logging to data/logs/driver_manager.log
"""

import logging
import os
import subprocess
import tempfile
import threading
import time
from typing import Dict, Any, List, Optional

from utils.powershell import run_powershell_json, get_hidden_subprocess_kwargs
from packages.manager import _run_elevated_and_wait
from .history import record_driver_installation

logger = logging.getLogger(__name__)

LOG_FILE = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "..", "..", "data", "logs", "driver_manager.log")
)

PRIORITY_ORDER = {
    "chipset": 1,
    "system_mei": 2,
    "storage": 3,
    "lan": 4,
    "wifi": 5,
    "bluetooth": 6,
    "audio": 7,
    "gpu": 8,
    "touchpad": 9,
    "camera": 10,
    "card_reader": 11,
    "usb": 12,
    "other": 99,
}

_queue_lock = threading.Lock()
_queue_state: Dict[str, Any] = {
    "is_running": False,
    "cancelled": False,
    "total": 0,
    "completed": 0,
    "failed": 0,
    "skipped": 0,
    "current_index": 0,
    "current_package": None,
    "progress_percent": 0.0,
    "start_time": None,
    "end_time": None,
    "reboot_required": False,
    "summary_message": "",
    "resolved_devices_count": 0,
    "items": [],
}
_queue_thread: Optional[threading.Thread] = None


def _log_driver_event(msg: str) -> None:
    """Writes timestamped event to data/logs/driver_manager.log."""
    try:
        os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)
        t_str = time.strftime("%Y-%m-%d %H:%M:%S")
        with open(LOG_FILE, "a", encoding="utf-8") as f:
            f.write(f"[{t_str}] {msg}\n")
    except Exception:
        pass


def sort_driver_queue(packages: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """Sorts packages according to the 9-tier priority install ordering."""
    def _sort_key(p: Dict[str, Any]):
        cat = p.get("category", "other")
        order = PRIORITY_ORDER.get(cat, 99)
        name = p.get("display_name", "")
        return (order, name)

    return sorted(packages, key=_sort_key)


def _query_problematic_devices() -> List[str]:
    """Returns list of device IDs currently reporting a problem (ConfigManagerErrorCode != 0)."""
    ps = (
        "Get-CimInstance Win32_PnPEntity | "
        "Where-Object { $_.ConfigManagerErrorCode -ne 0 } | "
        "Select-Object -ExpandProperty DeviceID"
    )
    try:
        res = run_powershell_json(ps, timeout=8)
        if isinstance(res, list):
            return [str(x) for x in res if x]
        elif isinstance(res, (str, int)):
            return [str(res)]
    except Exception:
        pass
    return []


def _install_inf_package(inf_path: str, timeout: int = 180) -> Tuple[int, str]:
    """Installs INF package using Windows PnPUtil."""
    is_dir = os.path.isdir(inf_path)
    if is_dir:
        pattern = os.path.join(inf_path, "*.inf")
        cmd = ["pnputil", "/add-driver", pattern, "/subdirs", "/install"]
    else:
        cmd = ["pnputil", "/add-driver", inf_path, "/install"]

    res = subprocess.run(
        cmd,
        timeout=timeout,
        capture_output=True,
        text=True,
        **get_hidden_subprocess_kwargs(),
    )
    out = (res.stdout or res.stderr or "").strip()
    return res.returncode, out


def _install_single_package(pkg: Dict[str, Any], timeout: int = 240) -> Dict[str, Any]:
    """
    Executes installation for a single validated DriverPackage:
    - PnPUtil for INFs
    - ASUSSetup / Vendor Setup EXEs with elevated execution and silent switches
    - MSI packages via msiexec
    """
    method = pkg.get("install_method", "setup_exe")
    installer_path = pkg.get("installer_path") or pkg.get("installer_file") or pkg.get("source_path")
    pkg_name = pkg.get("display_name", "Driver Package")
    silent_args = pkg.get("silent_args", ["/s", "/norestart"])
    category = pkg.get("category", "other")
    fingerprint = pkg.get("fingerprint", "")
    version = pkg.get("driver_version", "")

    if not installer_path or not os.path.exists(installer_path):
        return {
            "success": False,
            "exit_code": -1,
            "reboot_required": False,
            "message": f"فایل نصبی یافت نشد: {installer_path}",
        }

    _log_driver_event(f"Starting installation of [{category.upper()}] {pkg_name} using method '{method}' ({installer_path})")

    try:
        if method == "pnputil":
            exit_code, out = _install_inf_package(installer_path, timeout=timeout)
            success = exit_code in (0, 259, 3010)
            reboot = (exit_code == 3010)
            msg = "نصب INF با PnPUtil با موفقیت انجام شد." if success else f"خطای PnPUtil: {out[:200]}"
            if reboot:
                msg += " (نیازمند راه‌اندازی مجدد)"

        elif method == "msiexec":
            work_dir = os.path.dirname(installer_path)
            sys_root = os.environ.get("SystemRoot", r"C:\Windows")
            cmd = [
                os.path.join(sys_root, "System32", "msiexec.exe"),
                "/i",
                installer_path,
                "/qn",
                "/norestart",
                "REBOOT=ReallySuppress",
            ]
            exit_code = _run_elevated_and_wait(cmd, work_dir, timeout)
            success = exit_code in (0, 3010, 1638)
            reboot = (exit_code == 3010)
            msg = "بسته MSI با موفقیت نصب شد." if success else f"خطای msiexec: کد خروج {exit_code}"

        elif method == "script":
            work_dir = os.path.dirname(installer_path)
            cmd = ["cmd.exe", "/c", installer_path]
            exit_code = _run_elevated_and_wait(cmd, work_dir, timeout)
            success = exit_code in (0, 3010)
            reboot = (exit_code == 3010)
            msg = "اسکریپت درایور با موفقیت اجرا شد." if success else f"خطا در اجرای اسکریپت: کد خروج {exit_code}"

        else:  # asus_setup or setup_exe
            work_dir = os.path.dirname(installer_path)
            cmd = [installer_path] + list(silent_args)
            exit_code = _run_elevated_and_wait(cmd, work_dir, timeout)
            success = exit_code in (0, 3010, 1638)
            reboot = (exit_code == 3010)
            msg = "نصاب درایور با موفقیت اجرا و نصب شد." if success else f"خطا در نصب درایور: کد خروج {exit_code}"

        # Record to persistent installation history
        res_str = "needs_reboot" if reboot else ("success" if success else "failed")
        record_driver_installation(
            fingerprint=fingerprint,
            category=category,
            package_name=pkg_name,
            installer_path=installer_path,
            driver_version=version,
            result=res_str,
            exit_code=exit_code,
            reboot_required=reboot,
            message=msg,
        )

        _log_driver_event(f"Completed [{category.upper()}] {pkg_name} -> Result: {res_str} (Exit: {exit_code})")

        return {
            "success": success,
            "exit_code": exit_code,
            "reboot_required": reboot,
            "message": msg,
        }

    except subprocess.TimeoutExpired:
        _log_driver_event(f"Timeout installing {pkg_name} after {timeout}s")
        return {"success": False, "exit_code": -1, "reboot_required": False, "message": f"تایم‌اوت در نصب {pkg_name}."}
    except Exception as e:
        _log_driver_event(f"Exception installing {pkg_name}: {e}")
        return {"success": False, "exit_code": -1, "reboot_required": False, "message": f"خطا: {str(e)}"}


def _run_queue_thread(packages: List[Dict[str, Any]]) -> None:
    """Worker thread that executes the sorted driver queue."""
    global _queue_state
    total = len(packages)
    any_reboot = False

    # Snapshot problem devices before installation
    problems_before = set(_query_problematic_devices())

    for idx, pkg in enumerate(packages):
        with _queue_lock:
            if _queue_state["cancelled"]:
                _log_driver_event("Installation queue was cancelled by user.")
                break
            _queue_state["current_index"] = idx
            _queue_state["current_package"] = pkg.get("display_name")
            _queue_state["progress_percent"] = round((idx / total) * 100.0, 1)
            if idx < len(_queue_state["items"]):
                _queue_state["items"][idx]["status"] = "installing"

        res = _install_single_package(pkg)

        if res.get("reboot_required"):
            any_reboot = True

        with _queue_lock:
            if idx < len(_queue_state["items"]):
                if res.get("success"):
                    _queue_state["items"][idx]["status"] = "completed"
                    _queue_state["items"][idx]["message"] = res.get("message", "نصب شد.")
                    _queue_state["completed"] += 1
                else:
                    _queue_state["items"][idx]["status"] = "failed"
                    _queue_state["items"][idx]["message"] = res.get("message", "خطا در نصب.")
                    _queue_state["failed"] += 1

            _queue_state["reboot_required"] = any_reboot
            _queue_state["progress_percent"] = round(((idx + 1) / total) * 100.0, 1)

        time.sleep(1.0)

    # Re-evaluate problem devices after installation (Verification)
    problems_after = set(_query_problematic_devices())
    resolved = len(problems_before - problems_after)

    with _queue_lock:
        _queue_state["is_running"] = False
        _queue_state["current_package"] = None
        _queue_state["progress_percent"] = 100.0
        _queue_state["end_time"] = time.time()
        _queue_state["resolved_devices_count"] = resolved

        c = _queue_state["completed"]
        f = _queue_state["failed"]
        if _queue_state["cancelled"]:
            _queue_state["summary_message"] = f"عملیات نصب لغو شد ({c} موفق، {f} ناموفق)."
        elif f == 0:
            _queue_state["summary_message"] = f"✓ تمامی {c} بسته درایور با موفقیت نصب شدند."
        else:
            _queue_state["summary_message"] = f"پایان نصب: {c} درایور موفق، {f} درایور با خطا مواجه شدند."

        if resolved > 0:
            _queue_state["summary_message"] += f" ({resolved} خطای سخت‌افزاری برطرف گردید)"

        if any_reboot:
            _queue_state["summary_message"] += " — نیاز به راه‌اندازی مجدد سیستم دارد."

    _log_driver_event(f"Queue finished: {_queue_state['summary_message']}")


def start_driver_queue(packages: List[Dict[str, Any]]) -> Dict[str, Any]:
    """Starts the sequential installation queue for selected packages."""
    global _queue_thread, _queue_state

    with _queue_lock:
        if _queue_state["is_running"]:
            return {"success": False, "message": "صف نصب درایورها هم‌اکنون در حال اجراست."}

    if not packages:
        return {"success": False, "message": "هیچ بسته درایوری برای نصب انتخاب نشده است."}

    sorted_pkgs = sort_driver_queue(packages)

    with _queue_lock:
        _queue_state = {
            "is_running": True,
            "cancelled": False,
            "total": len(sorted_pkgs),
            "completed": 0,
            "failed": 0,
            "skipped": 0,
            "current_index": 0,
            "current_package": None,
            "progress_percent": 0.0,
            "start_time": time.time(),
            "end_time": None,
            "reboot_required": False,
            "summary_message": "در حال آغاز صف نصب درایورها...",
            "resolved_devices_count": 0,
            "items": [
                {
                    "package_id": p.get("package_id"),
                    "display_name": p.get("display_name"),
                    "category": p.get("category"),
                    "category_fa": p.get("category_fa"),
                    "installer_file": p.get("installer_file"),
                    "status": "pending",
                    "message": "",
                }
                for p in sorted_pkgs
            ],
        }

    _queue_thread = threading.Thread(
        target=_run_queue_thread,
        args=(sorted_pkgs,),
        daemon=True,
        name="IntelligentDriverQueueThread",
    )
    _queue_thread.start()

    return {
        "success": True,
        "message": f"صف نصب {len(sorted_pkgs)} بسته درایور با اولویت‌بندی صحیح آغاز شد.",
        "total": len(sorted_pkgs),
    }


def get_driver_queue_status() -> Dict[str, Any]:
    """Returns current state of the installation queue."""
    with _queue_lock:
        return dict(_queue_state)


def cancel_driver_queue() -> Dict[str, Any]:
    """Cancels active driver installation queue."""
    global _queue_state
    with _queue_lock:
        if not _queue_state["is_running"]:
            return {"success": False, "message": "هیچ صفی در حال اجرا نیست."}
        _queue_state["cancelled"] = True
        _queue_state["summary_message"] = "در حال لغو صف نصب..."

    return {"success": True, "message": "دستور لغو ارسال شد."}
