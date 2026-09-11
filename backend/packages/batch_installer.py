# backend/packages/batch_installer.py
"""
Batch Auto-Install Queue Manager for Software Packages.
Manages a sequential queue of silent package installations running in a background thread.
Each package is installed silently, verified via registry, and progress is tracked in real-time.
"""

import logging
import copy
import threading
import time
from typing import Dict, Any, List, Optional

from packages.manager import scan_packages, silent_install_package, _is_windows_update_blocker

logger = logging.getLogger(__name__)

# Global batch install state
_batch_lock = threading.Lock()
_batch_state: Dict[str, Any] = {
    "is_running": False,
    "cancelled": False,
    "total": 0,
    "completed": 0,
    "failed": 0,
    "skipped": 0,
    "reboot_required": False,
    "current_item_name": None,
    "current_item_index": 0,
    "progress_percent": 0.0,
    "items": [],
    "start_time": None,
    "end_time": None,
    "summary_message": "",
}
_batch_thread: Optional[threading.Thread] = None


def _reset_state():
    """Reset batch state to initial values."""
    global _batch_state
    _batch_state = {
        "is_running": False,
        "cancelled": False,
        "total": 0,
        "completed": 0,
        "failed": 0,
        "skipped": 0,
        "reboot_required": False,
        "current_item_name": None,
        "current_item_index": 0,
        "progress_percent": 0.0,
        "items": [],
        "start_time": None,
        "end_time": None,
        "summary_message": "",
    }


def _run_batch_install(package_ids: List[str], custom_dir: Optional[str] = None):
    """Background thread worker: installs packages one by one silently."""
    global _batch_state

    logger.info(f"[BatchInstall] Starting batch install of {len(package_ids)} packages")

    with _batch_lock:
        _batch_state["start_time"] = time.time()

    for idx, pkg_id in enumerate(package_ids):
        # Check if cancelled
        with _batch_lock:
            if _batch_state["cancelled"]:
                for j in range(idx, len(_batch_state["items"])):
                    if _batch_state["items"][j]["status"] == "queued":
                        _batch_state["items"][j]["status"] = "skipped"
                        _batch_state["items"][j]["message"] = "لغو شده توسط کاربر"
                        _batch_state["skipped"] += 1
                break

            _batch_state["current_item_index"] = idx
            _batch_state["current_item_name"] = _batch_state["items"][idx].get("name", pkg_id)
            _batch_state["items"][idx]["status"] = "installing"
            _batch_state["progress_percent"] = round((idx / _batch_state["total"]) * 100, 1)

        logger.info(f"[BatchInstall] Installing {idx + 1}/{len(package_ids)}: {pkg_id}")

        is_office = (
            pkg_id.lower().startswith("office")
            or "office" in pkg_id.lower()
            or _batch_state["items"][idx].get("installer_type") == "office_cmd"
        )
        timeout = 900 if is_office else 300

        try:
            result = silent_install_package(pkg_id, custom_dir=custom_dir, timeout_seconds=timeout)
        except Exception as e:
            result = {
                "success": False,
                "message": f"خطای غیرمنتظره: {str(e)}",
                "verified_installed": False,
                "skipped": False,
            }

        with _batch_lock:
            item = _batch_state["items"][idx]
            item["message"] = result.get("message", "")
            item["installed_version"] = result.get("installed_version", "")
            item["exit_code"] = result.get("exit_code", -1)
            _batch_state["reboot_required"] = (
                _batch_state["reboot_required"] or bool(result.get("reboot_required")))

            if result.get("skipped"):
                item["status"] = "skipped"
                _batch_state["skipped"] += 1
            elif result.get("success"):
                item["status"] = "completed"
                _batch_state["completed"] += 1
            else:
                item["status"] = "failed"
                _batch_state["failed"] += 1

            _batch_state["progress_percent"] = round(((idx + 1) / _batch_state["total"]) * 100, 1)

        if result.get("exit_code") == -2:
            with _batch_lock:
                _batch_state["cancelled"] = True
                for pending in _batch_state["items"][idx + 1:]:
                    pending["status"] = "skipped"
                    pending["message"] = "نصاب قبلی هنوز ممکن است فعال باشد؛ صف برای بررسی دستی متوقف شد."
                    _batch_state["skipped"] += 1
            break
        time.sleep(0.5)

    # Finalize
    with _batch_lock:
        _batch_state["is_running"] = False
        _batch_state["current_item_name"] = None
        _batch_state["end_time"] = time.time()
        _batch_state["progress_percent"] = 100.0

        elapsed = round(_batch_state["end_time"] - _batch_state["start_time"], 1)
        completed = _batch_state["completed"]
        failed = _batch_state["failed"]
        skipped = _batch_state["skipped"]
        total = _batch_state["total"]

        if _batch_state["cancelled"]:
            _batch_state["summary_message"] = f"نصب خودکار لغو شد. {completed} از {total} نرم‌افزار نصب شد."
        elif failed == 0:
            _batch_state["summary_message"] = f"✓ تمام {completed} نرم‌افزار با موفقیت نصب شد! (در {elapsed} ثانیه)"
        else:
            _batch_state["summary_message"] = f"نصب خودکار تکمیل شد: {completed} موفق، {failed} ناموفق، {skipped} رد شده (در {elapsed} ثانیه)"
        if completed > 0 or _batch_state["reboot_required"]:
            _batch_state["summary_message"] += " — یادتان نرود پس از پایان همهٔ کارها، سیستم را دستی ری‌استارت کنید."

    logger.info(f"[BatchInstall] Batch complete: {_batch_state['summary_message']}")


def start_batch_install(package_ids: Optional[List[str]] = None, custom_dir: Optional[str] = None) -> Dict[str, Any]:
    """
    Starts a batch silent installation of software packages.
    If package_ids is None/empty, installs every validated package with a known
    silent strategy. Unknown/manual-only files are never guessed or auto-clicked.
    """
    global _batch_thread, _batch_state

    with _batch_lock:
        if _batch_state["is_running"]:
            return {
                "success": False,
                "message": "یک عملیات نصب خودکار در حال اجرا است. لطفاً صبر کنید یا آن را لغو کنید.",
            }

    pkg_data = scan_packages(custom_dir)
    if not pkg_data.get("directory_exists"):
        return {"success": False, "message": "فولدر نرم‌افزارها یافت نشد."}

    all_packages = pkg_data.get("packages", [])

    if package_ids:
        target_packages = []
        for pid in package_ids:
            pid_clean = pid.strip().replace("\\", "/").lower()
            for pkg in all_packages:
                if pid_clean in [pkg["id"].lower(), pkg.get("relative_path", "").lower(), pkg.get("filename", "").lower()]:
                    if pkg.get("is_valid") and (
                        pkg.get("auto_install_supported")
                        or pkg.get("installer_type") == "office_cmd"
                        or _is_windows_update_blocker(pkg)
                    ):
                        target_packages.append(pkg)
                    break
    else:
        target_packages = [
            p for p in all_packages
            if (p.get("install_allowed") or _is_windows_update_blocker(p))
            and (p.get("auto_install_supported") or _is_windows_update_blocker(p))
            and p.get("is_valid")
            and (not p.get("is_installed") or _is_windows_update_blocker(p))
        ]

    # WUB is a deployment finishing action, not a conventional installer. If
    # it exists in the source, include it exactly once at the end of every
    # automatic deployment. The package manager enforces the Windows Home guard.
    if target_packages and not any(_is_windows_update_blocker(p) for p in target_packages):
        blocker = next(
            (p for p in all_packages if p.get("is_valid") and _is_windows_update_blocker(p)),
            None,
        )
        if blocker is not None:
            target_packages.append(blocker)

    if not target_packages:
        return {
            "success": False,
            "message": "هیچ نصاب معتبرِ قابل نصب خودکاری یافت نشد؛ موارد ناشناخته را با نصب دستی بررسی کنید.",
        }

    # Queue reordering: regular applications, Office, then the WUB deployment action.
    normal_pkgs = [p for p in target_packages if p.get("installer_type") != "office_cmd" and "office" not in p.get("id", "").lower() and not _is_windows_update_blocker(p)]
    office_pkgs = [p for p in target_packages if p.get("installer_type") == "office_cmd" or "office" in p.get("id", "").lower()]
    update_blockers = [p for p in target_packages if _is_windows_update_blocker(p)]
    if update_blockers:
        # The official archive contains x86 and x64 executables. Run exactly
        # one, preferring x64 on the supported 64-bit Windows target.
        update_blockers.sort(
            key=lambda p: "x64" in str(p.get("filename", "")).lower(),
            reverse=True,
        )
        update_blockers = update_blockers[:1]
    target_packages = normal_pkgs + office_pkgs + update_blockers

    with _batch_lock:
        if _batch_state["is_running"]:
            return {"success": False, "message": "صف نصب نرم‌افزارها در حال اجراست."}
        _reset_state()
        _batch_state["is_running"] = True
        _batch_state["cancelled"] = False
        _batch_state["total"] = len(target_packages)
        _batch_state["items"] = [
            {
                "id": pkg.get("id", ""),
                "name": pkg.get("name", pkg.get("filename", "")),
                "filename": pkg.get("filename", ""),
                "relative_path": pkg.get("relative_path", ""),
                "installer_type": pkg.get("installer_type", ""),
                "status": "queued",
                "message": "",
                "installed_version": "",
                "exit_code": None,
            }
            for pkg in target_packages
        ]

    ids_to_install = [pkg.get("relative_path") or pkg.get("id") or pkg.get("filename") for pkg in target_packages]

    _batch_thread = threading.Thread(
        target=_run_batch_install,
        args=(ids_to_install, custom_dir),
        daemon=True,
    )
    _batch_thread.start()

    return {
        "success": True,
        "message": f"نصب خودکار {len(target_packages)} نرم‌افزار شروع شد...",
        "total": len(target_packages),
        "items": list(_batch_state["items"]),
    }


def get_batch_status() -> Dict[str, Any]:
    """Returns current batch install progress and status."""
    with _batch_lock:
        return copy.deepcopy(_batch_state)


def cancel_batch_install() -> Dict[str, Any]:
    """Cancels the running batch install."""
    with _batch_lock:
        if not _batch_state["is_running"]:
            return {"success": False, "message": "هیچ عملیات نصب خودکاری در حال اجرا نیست."}
        _batch_state["cancelled"] = True
    return {"success": True, "message": "دستور لغو ارسال شد. آیتم‌های باقی‌مانده رد خواهند شد."}
