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
import copy
import os
import subprocess
import tempfile
import threading
import time
from typing import Dict, Any, List, Optional, Tuple

from utils.powershell import run_powershell_json, get_hidden_subprocess_kwargs
from packages.manager import _run_elevated_and_wait
from .history import record_driver_installation

logger = logging.getLogger(__name__)

def _resolve_driver_log_file(local_app_data: Optional[str] = None) -> str:
    """Return a writable diagnostic path in installed and development builds."""
    app_data = local_app_data if local_app_data is not None else os.environ.get("LOCALAPPDATA")
    if app_data:
        return os.path.abspath(
            os.path.join(app_data, "MarkaziSystemChecker", "logs", "driver_manager.log")
        )
    return os.path.abspath(
        os.path.join(os.path.dirname(__file__), "..", "..", "data", "logs", "driver_manager.log")
    )


LOG_FILE = _resolve_driver_log_file()

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
    "last_update_time": None,
    "worker_alive": False,
    "fatal_error": "",
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
        "Select-Object -ExpandProperty DeviceID | ConvertTo-Json -Compress"
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
    """Installs INF package using Windows PnPUtil with automatic elevation fallback."""
    is_dir = os.path.isdir(inf_path)
    if is_dir:
        pattern = os.path.join(inf_path, "*.inf")
        cmd = ["pnputil.exe", "/add-driver", pattern, "/subdirs", "/install"]
    else:
        cmd = ["pnputil.exe", "/add-driver", inf_path, "/install"]

    code = -1
    out = ""
    try:
        res = subprocess.run(
            cmd,
            timeout=timeout,
            capture_output=True,
            text=True,
            **get_hidden_subprocess_kwargs(),
        )
        out = (res.stdout or res.stderr or "").strip()
        code = res.returncode
        if code in (0, 3010) or "successfully added" in out.lower():
            return (3010 if code == 3010 else 0), out
    except Exception as e:
        code = -1
        out = str(e)

    # If non-elevated call failed (e.g. Access Denied code 1 or 5), try elevated PowerShell
    try:
        from utils.powershell import run_elevated_powershell
        arg_str = f'/add-driver "{pattern}" /subdirs /install' if is_dir else f'/add-driver "{inf_path}" /install'
        ps_script = f"& pnputil.exe {arg_str}"
        ps_res = run_elevated_powershell(ps_script, timeout=timeout)
        ps_out = (ps_res.stdout or ps_res.stderr or "").strip()
        return ps_res.returncode, ps_out
    except Exception:
        pass

    return code, out


def _format_driver_failure_reason(exit_code: int, method: str, out: str, match: Dict[str, Any]) -> str:
    """Provides human-readable, actionable Persian failure reasons."""
    if method in ("pnputil", "inf_pnputil"):
        out_l = out.lower()
        if any(k in out_l for k in ("no more data", "match", "not found", "no device", "absent")):
            return "سخت‌افزار متناظر با این درایور (INF) روی مادربورد یا سیستم شما متصل نیست."

    if exit_code == 1603:
        return "عدم سازگاری: این درایور با مدل سخت‌افزار یا نسخه ویندوز فعلی سازگار نیست (Error 1603)."
    elif exit_code == 1633:
        return "عدم همخوانی معماری: نسخه درایور با پردازنده یا نسخه ۶۴ بیتی ویندوز سازگار نیست (Error 1633)."
    elif exit_code == 1602:
        return "عملیات نصب توسط کاربر یا سیستم متوقف گردید (کد 1602)."
    elif exit_code == 1618:
        return "یک فرآیند نصب دیگر در پس‌زمینه ویندوز فعال است؛ لطفاً پس از پایان آن مجدداً تلاش کنید."
    elif exit_code in (5, -1073741790):
        return "عدم دسترسی کافی؛ نیازمند مجوز کامل مدیر سیستم (Administrator)."
    elif exit_code in (2, 3):
        return "فایل اجرایی یا مسیر درایور در پوشه یافت نشد یا ناقص است."
    elif exit_code == -2:
        return "زمان مجاز برای پاسخ‌دهی نصاب به پایان رسید (تایم‌اوت)."

    confidence = match.get("confidence", "UNKNOWN")
    is_matched = match.get("is_matched", True)

    if not is_matched or confidence == "NOT_APPLICABLE":
        return "این درایور برای قطعه سخت‌افزاری دیگری است و با مشخصات سیستم شما سازگار نیست."

    if confidence == "LOW":
        return "شناسه سخت‌افزاری دقیقاً با قطعات سیستم مطابقت ندارد و ممکن است درایور نامناسب باشد."

    if method in ("pnputil", "inf_pnputil") and out:
        return f"عدم سازگاری سخت‌افزار یا خطای امضای دیجیتال (PnPUtil: {out[:100]})."

    return f"نصب درایور ناموفق بود (کد خروج: {exit_code} - عدم سازگاری یا خطای نصاب)."


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
        out = ""
        if method in ("pnputil", "inf_pnputil"):
            # Official Windows best practice: if source_path is a directory containing INFs,
            # run PnPUtil once on the whole tree with /subdirs /install. This installs base,
            # extension, and companion component INFs atomically with correct dependency resolution.
            source_dir = pkg.get("source_path")
            if source_dir and os.path.isdir(source_dir) and pkg.get("inf_files"):
                code, output = _install_inf_package(source_dir, timeout=timeout)
                success = code in (0, 3010)
                reboot = (code == 3010)
                exit_code = code
                out = output
            else:
                inf_paths = list(dict.fromkeys(pkg.get("inf_files") or [installer_path]))
                results = []
                for inf_path in inf_paths:
                    try:
                        code, output = _install_inf_package(inf_path, timeout=timeout)
                    except Exception as exc:
                        code, output = -1, str(exc)
                    results.append((code, f"{os.path.basename(inf_path)}: {output}"))
                failed_codes = [code for code, _ in results if code not in (0, 3010)]
                success = not failed_codes
                reboot = any(code == 3010 for code, _ in results)
                exit_code = failed_codes[0] if failed_codes else (3010 if reboot else 0)
                out = "\n".join(output for _, output in results)
            msg = "نصب INF با PnPUtil با موفقیت انجام شد." if success else _format_driver_failure_reason(exit_code, method, out, pkg.get("match", {}))
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
            msg = "بسته MSI با موفقیت نصب شد." if success else _format_driver_failure_reason(exit_code, method, "", pkg.get("match", {}))

        elif method == "script":
            work_dir = os.path.dirname(installer_path)
            try:
                with open(installer_path, "r", encoding="utf-8", errors="ignore") as script_file:
                    script_text = script_file.read().lower()
                reboot_commands = ("shutdown /r", "shutdown.exe /r", "restart-computer", "exitwindowsex")
                if any(command in script_text for command in reboot_commands):
                    return {
                        "success": False,
                        "exit_code": -4,
                        "reboot_required": True,
                        "message": "اسکریپت شامل فرمان ری‌استارت خودکار است و برای ایمنی اجرا نشد؛ نصب دستی را بررسی کنید.",
                    }
            except OSError as exc:
                return {"success": False, "exit_code": -1, "reboot_required": False, "message": str(exc)}
            cmd = ["cmd.exe", "/c", installer_path]
            exit_code = _run_elevated_and_wait(cmd, work_dir, timeout)
            success = exit_code in (0, 3010)
            reboot = (exit_code == 3010)
            msg = "اسکریپت درایور با موفقیت اجرا شد." if success else _format_driver_failure_reason(exit_code, method, "", pkg.get("match", {}))

        else:  # asus_setup or setup_exe
            work_dir = os.path.dirname(installer_path)
            cmd = [installer_path] + list(silent_args)
            exit_code = _run_elevated_and_wait(cmd, work_dir, timeout)
            success = exit_code in (0, 3010, 1638)
            reboot = (exit_code == 3010)
            msg = "نصاب درایور با موفقیت اجرا و نصب شد." if success else _format_driver_failure_reason(exit_code, method, "", pkg.get("match", {}))

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
    """Worker thread that executes the sorted driver queue.

    The outer ``finally`` is intentional: a vendor installer, history writer,
    hardware query, or unexpected Python error must never leave the UI seeing
    an immortal ``is_running`` state.
    """
    global _queue_state
    total = len(packages)
    with _queue_lock:
        any_reboot = bool(_queue_state.get("reboot_required", False))
    fatal_error = ""
    current_index: Optional[int] = None
    current_previous_status = "pending"

    with _queue_lock:
        _queue_state["worker_alive"] = True
        _queue_state["last_update_time"] = time.time()

    try:
        problems_before = set(_query_problematic_devices())

        for idx, pkg in enumerate(packages):
            previous_status = "pending"
            with _queue_lock:
                if _queue_state["cancelled"]:
                    _log_driver_event("Installation queue was cancelled by user.")
                    break
                if (
                    idx < len(_queue_state["items"])
                    and _queue_state["items"][idx].get("status") == "completed"
                ):
                    continue

                current_index = idx
                _queue_state["current_index"] = idx
                _queue_state["current_package"] = pkg.get("display_name")
                _queue_state["progress_percent"] = round((idx / max(total, 1)) * 100.0, 1)
                _queue_state["last_update_time"] = time.time()
                if idx < len(_queue_state["items"]):
                    previous_status = _queue_state["items"][idx].get("status", "pending")
                    current_previous_status = previous_status
                    _queue_state["items"][idx]["status"] = "installing"
                    _queue_state["items"][idx]["message"] = "در حال نصب..."

            res = _install_single_package(pkg)
            any_reboot = any_reboot or bool(res.get("reboot_required"))

            with _queue_lock:
                if idx < len(_queue_state["items"]):
                    item = _queue_state["items"][idx]
                    # Resume retries replace the earlier result instead of
                    # double-counting it.
                    if previous_status == "failed":
                        _queue_state["failed"] = max(0, _queue_state["failed"] - 1)

                    item["exit_code"] = res.get("exit_code")
                    if res.get("success"):
                        item["status"] = "completed"
                        item["message"] = res.get("message", "نصب شد.")
                        item.pop("failure_reason", None)
                        _queue_state["completed"] += 1
                    else:
                        failure_message = res.get("message", "خطا در نصب.")
                        item["status"] = "failed"
                        item["message"] = failure_message
                        item["failure_reason"] = failure_message
                        _queue_state["failed"] += 1

                _queue_state["reboot_required"] = any_reboot
                _queue_state["progress_percent"] = round(
                    ((idx + 1) / max(total, 1)) * 100.0, 1
                )
                _queue_state["last_update_time"] = time.time()

            if res.get("exit_code") == -2:
                _log_driver_event(
                    f"Driver package {pkg.get('display_name')} timed out (-2); "
                    "continuing with remaining queue items."
                )
            time.sleep(1.0)

        try:
            problems_after = set(_query_problematic_devices())
            resolved = len(problems_before - problems_after)
        except Exception as exc:
            logger.warning("Post-install device verification failed: %s", exc)
            resolved = 0
    except Exception as exc:
        fatal_error = f"{type(exc).__name__}: {exc}"
        logger.exception("Unexpected failure in the driver installation queue")
        _log_driver_event(f"Fatal queue error: {fatal_error}")
        resolved = 0
        with _queue_lock:
            if current_index is not None and current_index < len(_queue_state["items"]):
                item = _queue_state["items"][current_index]
                if item.get("status") == "installing":
                    message = "صف نصب به‌علت خطای داخلی متوقف شد؛ این بسته را دوباره اجرا کنید."
                    if current_previous_status == "failed":
                        _queue_state["failed"] = max(0, _queue_state["failed"] - 1)
                    item["status"] = "failed"
                    item["message"] = message
                    item["failure_reason"] = message
                    item["exit_code"] = -5
                    _queue_state["failed"] += 1
    finally:
        with _queue_lock:
            _queue_state["is_running"] = False
            _queue_state["worker_alive"] = False
            _queue_state["current_package"] = None
            _queue_state["end_time"] = time.time()
            _queue_state["last_update_time"] = time.time()
            _queue_state["resolved_devices_count"] = resolved
            _queue_state["fatal_error"] = fatal_error

            completed = _queue_state["completed"]
            failed = _queue_state["failed"]
            processed = completed + failed + _queue_state.get("skipped", 0)
            if not fatal_error and not _queue_state["cancelled"]:
                _queue_state["progress_percent"] = 100.0
            else:
                _queue_state["progress_percent"] = round(
                    (processed / max(total, 1)) * 100.0, 1
                )

            if fatal_error:
                _queue_state["summary_message"] = (
                    f"صف نصب غیرمنتظره متوقف شد ({completed} موفق، {failed} ناموفق). "
                    "برای بسته‌های باقی‌مانده «ادامه نصب» را بزنید."
                )
            elif _queue_state["cancelled"]:
                _queue_state["summary_message"] = (
                    f"عملیات نصب لغو شد ({completed} موفق، {failed} ناموفق)."
                )
            elif failed == 0:
                _queue_state["summary_message"] = (
                    f"✓ تمامی {completed} بسته درایور با موفقیت نصب شدند."
                )
            else:
                _queue_state["summary_message"] = (
                    f"پایان نصب: {completed} درایور موفق، {failed} درایور با خطا مواجه شدند."
                )

            if resolved > 0:
                _queue_state["summary_message"] += (
                    f" ({resolved} خطای سخت‌افزاری برطرف گردید)"
                )
            if completed > 0 or any_reboot:
                _queue_state["summary_message"] += (
                    " — یادتان نرود پس از پایان همهٔ کارها، سیستم را دستی ری‌استارت کنید."
                )
            summary = _queue_state["summary_message"]

        _log_driver_event(f"Queue finished: {summary}")


_last_packages = []

def start_driver_queue(packages: List[Dict[str, Any]], resume: bool = False) -> Dict[str, Any]:
    """Starts the sequential installation queue for selected packages, with resume support."""
    global _queue_thread, _queue_state, _last_packages

    with _queue_lock:
        if _queue_state["is_running"]:
            return {"success": False, "message": "صف نصب درایورها هم‌اکنون در حال اجراست."}

    if not packages and not resume:
        return {"success": False, "message": "هیچ بسته درایوری برای نصب انتخاب نشده است."}

    if resume:
        if not _queue_state["items"]:
            return {"success": False, "message": "هیچ صفی برای ادامه دادن یافت نشد."}
        sorted_pkgs = _last_packages
        with _queue_lock:
            _queue_state["is_running"] = True
            _queue_state["cancelled"] = False
            _queue_state["summary_message"] = "در حال از سرگیری صف نصب درایورها..."
            _queue_state["worker_alive"] = False
            _queue_state["fatal_error"] = ""
            _queue_state["start_time"] = time.time()
            _queue_state["last_update_time"] = time.time()
            # Keep completed/failed counts, we will just skip them in the loop
            _queue_state["end_time"] = None
    else:
        sorted_pkgs = sort_driver_queue(packages)
        _last_packages = sorted_pkgs
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
                "last_update_time": time.time(),
                "worker_alive": False,
                "fatal_error": "",
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
    try:
        _queue_thread.start()
    except Exception:
        with _queue_lock:
            _queue_state["is_running"] = False
            _queue_state["worker_alive"] = False
            _queue_state["end_time"] = time.time()
            _queue_state["last_update_time"] = time.time()
            _queue_state["fatal_error"] = "thread_start_failed"
            _queue_state["summary_message"] = "شروع صف نصب ناموفق بود؛ دوباره تلاش کنید."
        logger.exception("Unable to start driver queue")
        return {"success": False, "message": "شروع صف نصب ناموفق بود؛ دوباره تلاش کنید."}

    msg = "ادامه نصب درایورها آغاز شد." if resume else f"صف نصب {len(sorted_pkgs)} بسته درایور با اولویت‌بندی صحیح آغاز شد."
    return {
        "success": True,
        "message": msg,
        "total": len(sorted_pkgs),
    }


def get_driver_queue_status() -> Dict[str, Any]:
    """Return a snapshot and repair a stale state left by a dead worker."""
    global _queue_state, _queue_thread
    with _queue_lock:
        worker_alive = bool(_queue_thread and _queue_thread.is_alive())
        # A thread has an ident only after start(). The age check avoids
        # misclassifying the tiny window between state initialization and
        # Thread.start() as a crash.
        started_at = _queue_state.get("start_time") or time.time()
        worker_was_started_and_stopped = _queue_thread is None or (
            _queue_thread.ident is not None and not worker_alive
        )
        stale_running_state = (
            _queue_state.get("is_running")
            and worker_was_started_and_stopped
            and time.time() - started_at >= 1.0
        )
        if stale_running_state:
            for item in _queue_state.get("items", []):
                if item.get("status") == "installing":
                    message = "پردازش نصب غیرمنتظره متوقف شد؛ این بسته را دوباره اجرا کنید."
                    item["status"] = "failed"
                    item["message"] = message
                    item["failure_reason"] = message
                    item["exit_code"] = -5
                    _queue_state["failed"] += 1
                    break
            _queue_state["is_running"] = False
            _queue_state["current_package"] = None
            _queue_state["end_time"] = time.time()
            _queue_state["fatal_error"] = "worker_thread_stopped"
            _queue_state["summary_message"] = (
                "پردازش صف درایورها متوقف شد؛ برای بسته‌های باقی‌مانده «ادامه نصب» را بزنید."
            )
            _log_driver_event("Repaired stale queue state after worker thread stopped.")
        _queue_state["worker_alive"] = worker_alive and _queue_state.get("is_running", False)
        return copy.deepcopy(_queue_state)


def cancel_driver_queue() -> Dict[str, Any]:
    """Cancels active driver installation queue."""
    global _queue_state
    with _queue_lock:
        if not _queue_state["is_running"]:
            return {"success": False, "message": "هیچ صفی در حال اجرا نیست."}
        _queue_state["cancelled"] = True
        _queue_state["summary_message"] = "در حال لغو صف نصب..."

    return {"success": True, "message": "دستور لغو ارسال شد."}
