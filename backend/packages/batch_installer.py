# backend/packages/batch_installer.py
"""
Batch Auto-Install Queue Manager for Software Packages & System Setup Orchestration.
Manages a sequential queue of silent package installations and essential Windows optimizations
running in a background thread.
Each item is executed, verified, and progress is tracked in real-time.
"""

import logging
import copy
import os
import threading
import time
from typing import Dict, Any, List, Optional

from packages.manager import (
    scan_packages,
    silent_install_package,
    _is_microsoft_office_package,
    _is_windows_update_blocker,
    get_packages_directory,
)
from windows.device_settings import get_windows_identity, has_battery
from deployment_scheduler import (
    approved_resources,
    run_deployment,
    wait_for_windows_installer_idle,
)

logger = logging.getLogger(__name__)


def _is_winrar_package(package: Dict[str, Any]) -> bool:
    combined = " ".join(
        str(package.get(field) or "")
        for field in ("id", "name", "filename", "relative_path", "publisher")
    ).lower()
    return "winrar" in "".join(char for char in combined if char.isalnum())

# Global batch install state
_batch_lock = threading.Lock()
_batch_state: Dict[str, Any] = {
    "api_contract_version": 5,
    "state_revision": 1,
    "server_time": time.time(),
    "is_running": False,
    "cancelled": False,
    "total": 0,
    "completed": 0,
    "failed": 0,
    "skipped": 0,
    "interrupted": 0,
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

_VALID_TRANSITIONS = {
    "pending": {"installing", "skipped", "interrupted", "queued"},
    "queued": {"installing", "skipped", "interrupted", "pending"},
    "installing": {"completed", "failed", "interrupted", "pending", "skipped"},
    "completed": set(),
    "failed": {"pending", "queued"},
    "skipped": set(),
    "interrupted": {"pending", "queued"},
}


def _can_transition(current_status: str, new_status: str, is_1618_retry: bool = False) -> bool:
    """Validate item state machine transitions according to CONTRACT.md § 2.5."""
    if current_status == new_status:
        return True
    if current_status == "installing" and new_status in ("pending", "queued"):
        return is_1618_retry
    allowed = _VALID_TRANSITIONS.get(current_status, set())
    return new_status in allowed


def _get_software_state_filepath(local_app_data: Optional[str] = None) -> str:
    app_data = local_app_data if local_app_data is not None else (os.environ.get("LOCALAPPDATA") or os.environ.get("APPDATA"))
    if app_data:
        return os.path.abspath(os.path.join(app_data, "MarkaziSystemChecker", "software_queue_state.json"))
    return os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "data", "software_queue_state.json"))


def persist_software_state_atomic(state_dict: dict, file_path: Optional[str] = None) -> str:
    """Atomically persist software queue state to disk using tmp file and os.replace."""
    if not file_path:
        file_path = _get_software_state_filepath()
    file_path = os.path.abspath(file_path)
    os.makedirs(os.path.dirname(file_path), exist_ok=True)
    temp_path = f"{file_path}.tmp"
    with open(temp_path, "w", encoding="utf-8") as f:
        json.dump(state_dict, f, ensure_ascii=False, indent=2)
        f.flush()
        try:
            os.fsync(f.fileno())
        except OSError:
            pass
    os.replace(temp_path, file_path)
    return file_path


def _bump_revision_locked(persist: bool = True) -> int:
    """Increment monotonic state_revision and update server_time."""
    current = _batch_state.get("state_revision", 0)
    _batch_state["state_revision"] = max(1, current + 1)
    _batch_state["server_time"] = time.time()
    _batch_state["api_contract_version"] = 5
    if persist:
        try:
            persist_software_state_atomic(_batch_state)
        except Exception as exc:
            logger.debug(f"[BatchInstall] Failed to persist state: {exc}")
    return _batch_state["state_revision"]


def reconcile_startup_software_queue(file_path: Optional[str] = None) -> None:
    """Load persisted queue state upon startup and reconcile unfinalized installing items."""
    global _batch_state
    path = file_path or _get_software_state_filepath()
    if not os.path.isfile(path):
        return
    try:
        with open(path, "r", encoding="utf-8") as f:
            saved = json.load(f)
        if not isinstance(saved, dict):
            return

        with _batch_lock:
            if saved.get("is_running"):
                logger.warning("[BatchInstall] Startup reconciliation: unfinalized queue detected; reconciling to interrupted.")
                items = saved.get("items", [])
                interrupted_count = 0
                for item in items:
                    status = item.get("status")
                    if status in ("installing", "queued", "pending"):
                        item["status"] = "interrupted"
                        item["message"] = "فرآیند نصب به دلیل بسته شدن یا راه‌اندازی مجدد سرویس متوقف شد."
                        interrupted_count += 1
                saved["is_running"] = False
                saved["cancelled"] = True
                saved["interrupted"] = interrupted_count
                saved["summary_message"] = "فرآیند قبلی به دلیل بسته شدن ناگهانی سرویس متوقف شد."
                saved["state_revision"] = max(1, saved.get("state_revision", 0) + 1)
                saved["server_time"] = time.time()
                saved["api_contract_version"] = 5
                persist_software_state_atomic(saved, path)

            _batch_state.update(saved)
            _batch_state["state_revision"] = max(1, _batch_state.get("state_revision", 1))
            _batch_state["server_time"] = time.time()
            _batch_state["api_contract_version"] = 5
    except Exception as exc:
        logger.debug(f"[BatchInstall] Startup reconciliation skipped: {exc}")


try:
    reconcile_startup_software_queue()
except Exception:
    pass


def _active_batch_response_locked() -> Dict[str, Any]:
    """Return an idempotent start response for the queue already in flight.

    The desktop UI can be recreated independently of the backend (for example
    after navigation/theme rebuilds or graphics recovery).  Treating a second
    start request as a hard error leaves that replacement UI looking idle even
    though this worker is still installing packages.  Returning the live
    snapshot lets the client adopt the existing session immediately.
    """
    status = copy.deepcopy(_batch_state)
    status["state_revision"] = max(1, status.get("state_revision", 1))
    status["server_time"] = time.time()
    status["api_contract_version"] = 5
    return {
        "success": True,
        "already_running": True,
        "adopted_existing": True,
        "message": "صف نصب فعال بازیابی شد؛ وضعیت زنده نمایش داده می‌شود.",
        "status": status,
        "total": status.get("total", 0),
        "items": status.get("items", []),
    }


def _mark_batch_worker_failed_locked(reason: str) -> None:
    """Unlock a queue whose worker exited before normal finalization."""
    now = time.time()
    for item in _batch_state.get("items", []):
        status = item.get("status")
        if status == "installing":
            item["status"] = "failed"
            item["message"] = reason
        elif status in ("queued", "pending"):
            item["status"] = "skipped"
            item["message"] = "به علت توقف غیرمنتظره صف اجرا نشد."

    items = _batch_state.get("items", [])
    _batch_state["completed"] = sum(1 for item in items if item.get("status") == "completed")
    _batch_state["failed"] = sum(1 for item in items if item.get("status") == "failed")
    _batch_state["skipped"] = sum(1 for item in items if item.get("status") == "skipped")
    _batch_state["interrupted"] = sum(1 for item in items if item.get("status") == "interrupted")
    _batch_state["is_running"] = False
    _batch_state["current_item_name"] = None
    _batch_state["end_time"] = now
    _batch_state["progress_percent"] = 100.0 if _batch_state.get("total", 0) else 0.0
    _batch_state["summary_message"] = (
        "صف نصب به‌طور غیرمنتظره متوقف شد؛ کنترل‌ها آزاد شدند. "
        "جزئیات مرحله ناموفق را بررسی و دوباره تلاش کنید."
    )
    _bump_revision_locked()


def _repair_dead_worker_locked() -> None:
    """Repair stale running state after an unhandled worker termination."""
    thread = _batch_thread
    if not _batch_state.get("is_running") or thread is None:
        return
    # ``ident is None`` is the tiny valid interval between constructing and
    # starting a thread, so it must not be mistaken for a crashed worker.
    if thread.ident is not None and not thread.is_alive():
        logger.error("[BatchInstall] Dead worker detected; repairing queue state")
        _mark_batch_worker_failed_locked("پردازش نصب به‌طور غیرمنتظره متوقف شد.")


def _home_office_shortcuts_result() -> Dict[str, Any]:
    """Create Office shortcuts without installing or activating anything."""
    from packages.office_shortcuts import ensure_office_desktop_shortcuts

    identity = get_windows_identity()
    shortcuts = ensure_office_desktop_shortcuts()
    label = str(identity.get("label") or "Windows Home")
    created = list(shortcuts.get("created") or [])
    return {
        "success": bool(shortcuts.get("success")),
        "skipped": not bool(shortcuts.get("success")),
        "home_guard": True,
        "desktop_shortcuts": shortcuts,
        "exit_code": 0,
        "message": (
            f"{label} اورجینال شناسایی شد؛ KMS و نصب Office اجرا نشد. "
            f"{shortcuts.get('message', '')}"
            + (f" ({len(created)} میانبر)" if created else "")
        ).strip(),
    }


def _reset_state():
    """Reset batch state to initial values while preserving monotonic revision."""
    global _batch_state
    rev = max(1, _batch_state.get("state_revision", 0) + 1)
    _batch_state = {
        "api_contract_version": 5,
        "state_revision": rev,
        "server_time": time.time(),
        "is_running": False,
        "cancelled": False,
        "total": 0,
        "completed": 0,
        "failed": 0,
        "skipped": 0,
        "interrupted": 0,
        "reboot_required": False,
        "current_item_name": None,
        "current_item_index": 0,
        "progress_percent": 0.0,
        "items": [],
        "start_time": None,
        "end_time": None,
        "summary_message": "",
    }


def _run_batch_install_impl(items_to_run: List[Dict[str, Any]], custom_dir: Optional[str] = None):
    """Background thread worker: installs packages and executes orchestrator steps one by one."""
    global _batch_state

    logger.info(f"[BatchInstall] Starting batch execution of {len(items_to_run)} items")

    with _batch_lock:
        _batch_state["start_time"] = time.time()

    resolved_pkg_dir = custom_dir or get_packages_directory()

    def run_one(idx, item_info):
        # Check if cancelled
        with _batch_lock:
            if _batch_state["cancelled"]:
                for j in range(idx, len(_batch_state["items"])):
                    if _batch_state["items"][j]["status"] in ("queued", "pending"):
                        _batch_state["items"][j]["status"] = "skipped"
                        _batch_state["items"][j]["message"] = "لغو شده توسط کاربر"
                        _batch_state["skipped"] += 1
                _bump_revision_locked()
                return

            _batch_state["current_item_index"] = idx
            _batch_state["current_item_name"] = _batch_state["items"][idx].get("name", item_info.get("id"))
            current_st = _batch_state["items"][idx].get("status", "pending")
            if _can_transition(current_st, "installing"):
                _batch_state["items"][idx]["status"] = "installing"
                _bump_revision_locked()
            else:
                logger.warning(f"[BatchInstall] Illegal transition ignored: {current_st} -> installing")

        action = item_info.get("orchestrator_action")
        pkg_id = item_info.get("id", "")

        logger.info(f"[BatchInstall] Processing {idx + 1}/{len(items_to_run)}: {item_info.get('name')} (action={action})")

        result: Dict[str, Any] = {}

        try:
            if action == "office_extract":
                if get_windows_identity().get("is_home") is True:
                    result = {
                        "success": True,
                        "skipped": True,
                        "home_guard": True,
                        "message": "Windows Home شناسایی شد؛ آرشیو Office استخراج نمی‌شود.",
                        "exit_code": 0,
                    }
                else:
                    from packages.orchestrator import ensure_office_extracted
                    res = ensure_office_extracted(resolved_pkg_dir)
                    result = {
                        "success": res.get("success", True),
                        "skipped": res.get("skipped", False),
                        "message": res.get("message", "بررسی استخراج آفیس پایان یافت."),
                        "exit_code": 0 if res.get("success") else 1,
                    }
            elif action == "kms_activate":
                if _batch_state.get("include_activation") is not True:
                    result = {"success": True, "skipped": True, "exit_code": 0,
                              "message": "مرحلهٔ فعال‌سازی انتخاب نشده است؛ اجرا نشد."}
                elif get_windows_identity().get("is_home") is True:
                    result = {
                        "success": True,
                        "skipped": True,
                        "home_guard": True,
                        "message": "Windows Home اورجینال است؛ KMS استخراج یا اجرا نشد.",
                        "exit_code": 0,
                    }
                else:
                    from packages.orchestrator import activate_windows_and_office_from_packages
                    res = activate_windows_and_office_from_packages(
                        resolved_pkg_dir,
                        timeout_seconds=300,
                    )
                    result = {
                        "success": res.get("success", False),
                        "skipped": res.get("skipped", False),
                        "message": res.get(
                            "message",
                            "فعال‌سازی Windows و Office بررسی شد.",
                        ),
                        "exit_code": 0 if res.get("success") else 1,
                    }
            elif action == "office_shortcuts":
                result = _home_office_shortcuts_result()
            elif action == "desktop_icons":
                from packages.orchestrator import apply_desktop_icons
                res = apply_desktop_icons()
                result = {
                    "success": res.get("success", False),
                    "message": res.get("message", "آیکن‌های دسکتاپ تنظیم شدند."),
                    "exit_code": 0 if res.get("success") else 1,
                }
            elif action == "sleep_never":
                from windows.device_settings import set_sleep_never
                res = set_sleep_never()
                result = {
                    "success": res.get("success", False),
                    "message": res.get("message", "زمان‌های Sleep و خاموشی صفحه روی Never تنظیم شدند."),
                    "exit_code": 0 if res.get("success") else 1,
                }
            elif action == "power_modes":
                from windows.power_settings import set_laptop_power_modes
                res = set_laptop_power_modes()
                result = {
                    "success": res.get("success", False),
                    "message": res.get("message", "طرح توان باتری و برق تنظیم شد."),
                    "exit_code": 0 if res.get("success") else 1,
                }
            elif action == "tehran_timezone":
                from windows.desktop_time import set_tehran_automatic_timezone
                res = set_tehran_automatic_timezone()
                result = {
                    "success": res.get("success", False),
                    "message": res.get("message", "منطقه زمانی تهران تنظیم شد."),
                    "exit_code": 0 if res.get("success") else 1,
                }
            elif action == "startup_apps":
                from windows.device_settings import disable_all_startup_apps
                res = disable_all_startup_apps(elevate=False, open_page=False)
                result = {
                    "success": res.get("success", False) or res.get("cancelled", False),
                    "message": res.get("message", "برنامه‌های استارتاپ بهینه‌سازی شدند."),
                    "exit_code": 0,
                }
            elif action == "background_apps":
                from windows.device_settings import disable_windows10_background_apps
                res = disable_windows10_background_apps(open_page=False)
                result = {
                    "success": res.get("success", False) or res.get("unsupported", False),
                    "message": res.get("message", "برنامه‌های پس‌زمینه بهینه‌سازی شدند."),
                    "exit_code": 0,
                }
            elif action == "windows_security":
                from windows.device_settings import pin_windows_security
                res = pin_windows_security()
                result = {
                    "success": res.get("success", False),
                    "message": res.get(
                        "message",
                        "Windows Security برای بررسی و Pin به Taskbar باز شد.",
                    ),
                    "exit_code": 0 if res.get("success") else 1,
                }
            else:
                # Regular Software Package Installer
                is_office = _is_microsoft_office_package(item_info)
                if is_office and get_windows_identity().get("is_home") is True:
                    result = _home_office_shortcuts_result()
                else:
                    timeout = 900 if is_office else 300
                    result = silent_install_package(
                        item_info.get("relative_path") or pkg_id or item_info.get("filename"),
                        custom_dir=custom_dir,
                        timeout_seconds=timeout,
                    )
                    retry_count = 0
                    while result.get("exit_code") == 1618 and retry_count < 2:
                        retry_count += 1
                        backoff = 3.0 if retry_count == 1 else 7.0
                        with _batch_lock:
                            # Rollback to pending exclusively on Error 1618 retry
                            item_dict = _batch_state["items"][idx]
                            item_dict["status"] = "pending"
                            item_dict["is_barrier"] = True
                            item_dict["retry_count"] = retry_count
                            item_dict["message"] = (
                                f"Windows Installer در حال استفاده است؛ تلاش مجدد {retry_count} از ۲..."
                            )
                            _bump_revision_locked()
                        time.sleep(backoff)
                        if wait_for_windows_installer_idle(timeout_seconds=900):
                            with _batch_lock:
                                _batch_state["items"][idx]["status"] = "installing"
                                _bump_revision_locked()
                            result = silent_install_package(
                                item_info.get("relative_path") or pkg_id or item_info.get("filename"),
                                custom_dir=custom_dir,
                                timeout_seconds=timeout,
                            )
                        else:
                            break
                    if result.get("exit_code") == 1618:
                        result["message"] = "نصب‌کننده Windows Installer همچنان مشغول است؛ بیش از ۲ بار تلاش انجام شد و نصب متوقف گردید."
                        result["success"] = False

        except Exception as e:
            logger.error(f"[BatchInstall] Error processing {pkg_id}: {e}")
            result = {
                "success": False,
                "message": f"خطای غیرمنتظره: {str(e)}",
                "verified_installed": False,
                "skipped": False,
            }

        with _batch_lock:
            item = _batch_state["items"][idx]
            current_status = item.get("status", "pending")
            item["message"] = result.get("message", "")
            item["installed_version"] = result.get("installed_version", "")
            item["exit_code"] = result.get("exit_code", -1)
            _batch_state["reboot_required"] = (
                _batch_state["reboot_required"] or bool(result.get("reboot_required"))
            )

            if result.get("skipped"):
                new_status = "skipped"
            elif result.get("success"):
                new_status = "completed"
            else:
                new_status = "failed"

            if _can_transition(current_status, new_status):
                item["status"] = new_status
                if new_status == "completed":
                    _batch_state["completed"] += 1
                elif new_status == "skipped":
                    _batch_state["skipped"] += 1
                else:
                    _batch_state["failed"] += 1
            else:
                logger.warning(f"[BatchInstall] Illegal transition ignored: {current_status} -> {new_status}")

            processed = sum(_batch_state[key] for key in ("completed", "failed", "skipped"))
            _batch_state["progress_percent"] = round((processed / max(1, _batch_state["total"])) * 100, 1)
            _bump_revision_locked()

        if result.get("exit_code") == -2:
            logger.warning(f"[BatchInstall] Item {pkg_id} timed out; continuing with remaining queue items.")
        time.sleep(0.5)

    def mark_external_wait(idx, item):
        with _batch_lock:
            _batch_state["current_item_index"] = idx
            _batch_state["current_item_name"] = item.get("name") or item.get("id")
            _batch_state["items"][idx]["message"] = (
                "در انتظار پایان نصب دستی یا Windows Installer خارجی..."
            )
            _bump_revision_locked()

    run_deployment(
        items_to_run,
        run_one,
        double_speed=_batch_state.get("double_speed", False),
        resources_for=lambda item: approved_resources(item, root=resolved_pkg_dir),
        on_external_wait=mark_external_wait,
    )

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
            _batch_state["summary_message"] = f"نصب خودکار لغو شد. {completed} از {total} عملیات انجام شد."
        elif failed == 0:
            _batch_state["summary_message"] = f"✓ تمام {completed} مرحله با موفقیت انجام شد! (در {elapsed} ثانیه)"
        else:
            _batch_state["summary_message"] = f"عملیات پایان یافت: {completed} موفق، {failed} ناموفق، {skipped} رد شده (در {elapsed} ثانیه)"
        if completed > 0 or _batch_state["reboot_required"]:
            _batch_state["summary_message"] += " — یادتان نرود پس از پایان کارها، سیستم را دستی ری‌استارت کنید."
        _bump_revision_locked()

    logger.info(f"[BatchInstall] Batch complete: {_batch_state['summary_message']}")


def _run_batch_install(items_to_run: List[Dict[str, Any]], custom_dir: Optional[str] = None):
    """Failure-safe worker wrapper that can never leave UI controls locked."""
    try:
        _run_batch_install_impl(items_to_run, custom_dir)
    except BaseException as exc:  # pragma: no branch - final safety boundary
        logger.exception("[BatchInstall] Worker terminated unexpectedly: %s", exc)
        with _batch_lock:
            if _batch_state.get("is_running"):
                _mark_batch_worker_failed_locked(
                    f"خطای غیرمنتظره در پردازش صف: {exc}"
                )


def start_batch_install(
    package_ids: Optional[List[str]] = None,
    custom_dir: Optional[str] = None,
    include_system_setup: Optional[bool] = None,
    include_activation: bool = False,
    double_speed: bool = False,
) -> Dict[str, Any]:
    """
    Starts a batch silent installation of software packages and automated system setup.
    If include_system_setup is None:
      - Automatically True when package_ids is None or len(package_ids) > 1 (full automated deployment).
      - False when package_ids contains exactly 1 package (isolated single package install).
    """
    global _batch_thread, _batch_state

    with _batch_lock:
        _repair_dead_worker_locked()
        if _batch_state["is_running"]:
            return _active_batch_response_locked()

    pkg_data = scan_packages(custom_dir)
    pkg_dir = custom_dir or (pkg_data.get("packages_directory") if isinstance(pkg_data, dict) else None)

    all_packages = pkg_data.get("packages", []) if isinstance(pkg_data, dict) else []

    target_packages = []
    if package_ids:
        for pid in package_ids:
            pid_clean = pid.strip().replace("\\", "/").lower()
            for pkg in all_packages:
                if pid_clean in [pkg["id"].lower(), pkg.get("relative_path", "").lower(), pkg.get("filename", "").lower()]:
                    if pkg.get("is_valid", True):
                        target_packages.append(pkg)
                    break
    else:
        target_packages = [
            p for p in all_packages
            if p.get("is_valid", True)
            and (not p.get("is_installed") or _is_windows_update_blocker(p))
            and not p.get("is_portable_tool", False)
        ]

    # Decide whether to include pre-install & post-install system setup steps
    if include_system_setup is None:
        include_system_setup = (package_ids is None or len(package_ids) > 1)

    windows_identity = get_windows_identity()
    is_home = windows_identity.get("is_home") is True

    # Windows Update Blocker is a portable action rather than an installer, so
    # it is normally excluded from selected package IDs.  Append the matching
    # architecture automatically on non-Home editions as required by the
    # deployment workflow; Home editions intentionally keep Windows Update on.
    if target_packages and not any(_is_windows_update_blocker(p) for p in target_packages):
        try:
            if not is_home:
                blockers = [p for p in all_packages if _is_windows_update_blocker(p)]
                blockers.sort(
                    key=lambda p: "x64" in str(p.get("filename", "")).lower(),
                    reverse=True,
                )
                if blockers:
                    target_packages.append(blockers[0])
        except Exception:
            logger.debug("Could not determine Windows edition for WUB queue", exc_info=True)

    # Reorder software packages. WinRAR must complete before archive-driven
    # provisioning (Office/KMS), otherwise a fresh Windows installation has no
    # reliable RAR extractor yet.
    normal_pkgs = [p for p in target_packages if not _is_microsoft_office_package(p) and not _is_windows_update_blocker(p)]
    office_pkgs = [p for p in target_packages if _is_microsoft_office_package(p)]
    update_blockers = [p for p in target_packages if _is_windows_update_blocker(p)]
    if update_blockers:
        update_blockers.sort(key=lambda p: "x64" in str(p.get("filename", "")).lower(), reverse=True)
        update_blockers = update_blockers[:1]

    archive_prerequisites = (
        [package for package in normal_pkgs if _is_winrar_package(package)]
        if include_system_setup and not is_home
        else []
    )
    if archive_prerequisites:
        normal_pkgs = [
            package
            for package in normal_pkgs
            if not _is_winrar_package(package)
        ]

    # Home systems use the preinstalled Office only. Never place its setup
    # script in the queue; a dedicated shortcut-only step is used instead.
    ordered_software = normal_pkgs + ([] if is_home else office_pkgs) + update_blockers

    # Construct complete queue items list
    queue_items: List[Dict[str, Any]] = []

    if is_home and (include_system_setup or bool(office_pkgs)):
        queue_items.append({
            "id": "step_office_shortcuts",
            "name": "ساخت میانبرهای Word، Excel و PowerPoint (بدون نصب)",
            "filename": "Microsoft Office",
            "relative_path": "",
            "installer_type": "orchestrator",
            "orchestrator_action": "office_shortcuts",
            "status": "queued",
            "message": "Windows Home: فقط میانبرهای Office ساخته می‌شوند.",
            "installed_version": "",
            "exit_code": None,
        })

    for package in archive_prerequisites:
        queue_items.append({
            "id": package.get("id", ""),
            "name": f"{package.get('name', 'WinRAR')} (پیش‌نیاز استخراج)",
            "filename": package.get("filename", ""),
            "relative_path": package.get("relative_path", ""),
            "installer_type": package.get("installer_type", ""),
            "orchestrator_action": None,
            "status": "queued",
            "message": "WinRAR پیش از استخراج Office/KMS نصب می‌شود.",
            "installed_version": "",
            "exit_code": None,
        })

    if include_system_setup and not is_home:
        # 1. Office extraction check
        from packages.orchestrator import is_office_already_extracted
        has_office_archive = False
        if pkg_dir and os.path.isdir(pkg_dir):
            try:
                for entry in os.listdir(pkg_dir):
                    if "office" in entry.lower() and entry.lower().endswith((".rar", ".zip", ".7z")):
                        has_office_archive = True
                        break
            except Exception:
                pass

        if has_office_archive and not is_office_already_extracted(pkg_dir):
            queue_items.append({
                "id": "step_office_extract",
                "name": "بررسی و استخراج آفیس",
                "filename": "Office Archive",
                "relative_path": "",
                "installer_type": "orchestrator",
                "orchestrator_action": "office_extract",
                "status": "queued",
                "message": "",
                "installed_version": "",
                "exit_code": None,
            })

    # Install software (including Office) before product activation. This
    # guarantees OFFICE.cmd never runs against an Office package that is still
    # waiting later in the same queue.
    for pkg in ordered_software:
        queue_items.append({
            "id": pkg.get("id", ""),
            "name": pkg.get("name", pkg.get("filename", "")),
            "filename": pkg.get("filename", ""),
            "relative_path": pkg.get("relative_path", ""),
            "installer_type": pkg.get("installer_type", ""),
            "orchestrator_action": None,
            "status": "queued",
            "message": "",
            "installed_version": "",
            "exit_code": None,
        })

    if include_system_setup and not is_home and include_activation is True:
        queue_items.append({
            "id": "step_kms_activate",
            "name": "استخراج KMS v6 و فعال‌سازی Windows و Office",
            "filename": "WINDOWS.cmd + OFFICE.cmd",
            "relative_path": "",
            "installer_type": "orchestrator",
            "orchestrator_action": "kms_activate",
            "status": "queued",
            "message": "پس از نصب Office، وضعیت هر دو لایسنس بررسی می‌شود.",
            "installed_version": "",
            "exit_code": None,
        })

    if include_system_setup:
        # Desktop icons are attempted after activation; the action itself also
        # verifies consolidated Windows activation before changing the desktop.
        queue_items.append({
            "id": "step_desktop_icons",
            "name": "تنظیم ۳ آیکن اصلی دسکتاپ (This PC، کنترل پنل، سطل آشغال)",
            "filename": "Desktop Icons",
            "relative_path": "",
            "installer_type": "orchestrator",
            "orchestrator_action": "desktop_icons",
            "status": "queued",
            "message": "",
            "installed_version": "",
            "exit_code": None,
        })

    if include_system_setup:
        # Device settings
        queue_items.append({
            "id": "step_sleep_never",
            "name": "تنظیم Sleep و خاموشی صفحه روی Never",
            "filename": "powercfg",
            "relative_path": "",
            "installer_type": "orchestrator",
            "orchestrator_action": "sleep_never",
            "status": "queued",
            "message": "",
            "installed_version": "",
            "exit_code": None,
        })

        if has_battery():
            queue_items.append({
                "id": "step_power_modes",
                "name": "طرح توان لپ‌تاپ (برق Best Performance / باتری Balanced)",
                "filename": "Power Modes",
                "relative_path": "",
                "installer_type": "orchestrator",
                "orchestrator_action": "power_modes",
                "status": "queued",
                "message": "",
                "installed_version": "",
                "exit_code": None,
            })

        queue_items.append({
            "id": "step_tehran_timezone",
            "name": "تنظیم منطقه زمانی تهران و ساعت خودکار",
            "filename": "tzutil",
            "relative_path": "",
            "installer_type": "orchestrator",
            "orchestrator_action": "tehran_timezone",
            "status": "queued",
            "message": "",
            "installed_version": "",
            "exit_code": None,
        })

        queue_items.append({
            "id": "step_startup_apps",
            "name": "بهینه‌سازی برنامه‌های استارتاپ",
            "filename": "Startup Apps",
            "relative_path": "",
            "installer_type": "orchestrator",
            "orchestrator_action": "startup_apps",
            "status": "queued",
            "message": "",
            "installed_version": "",
            "exit_code": None,
        })

        if get_windows_identity().get("generation") == "Windows 10":
            queue_items.append({
                "id": "step_background_apps",
                "name": "غیرفعال‌سازی Background Apps ویندوز 10",
                "filename": "Background Apps",
                "relative_path": "",
                "installer_type": "orchestrator",
                "orchestrator_action": "background_apps",
                "status": "queued",
                "message": "",
                "installed_version": "",
                "exit_code": None,
            })

        # Keep this as the final setup barrier. It opens Defender only after
        # every installation and machine setting has finished, so the
        # technician can inspect it and pin it without interrupting the queue.
        queue_items.append({
            "id": "step_windows_security",
            "name": "باز کردن Windows Security برای بررسی و Pin",
            "filename": "Windows Security",
            "relative_path": "",
            "installer_type": "orchestrator",
            "orchestrator_action": "windows_security",
            "status": "queued",
            "message": "",
            "installed_version": "",
            "exit_code": None,
        })

    if not queue_items:
        return {
            "success": False,
            "message": "هیچ موردی برای نصب یا اجرا یافت نشد.",
        }

    with _batch_lock:
        _repair_dead_worker_locked()
        if _batch_state["is_running"]:
            return _active_batch_response_locked()
        _reset_state()
        _batch_state["is_running"] = True
        _batch_state["double_speed"] = double_speed is True
        _batch_state["include_activation"] = include_activation is True and not is_home
        _batch_state["cancelled"] = False
        _batch_state["total"] = len(queue_items)
        _batch_state["items"] = copy.deepcopy(queue_items)
        _bump_revision_locked()
        # Clear the previous completed worker before publishing the new
        # running state. The status endpoint treats a non-alive published
        # worker as crashed; keeping the old thread here would create a small
        # false-positive window before the replacement thread is assigned.
        _batch_thread = None

    _batch_thread = threading.Thread(
        target=_run_batch_install,
        args=(queue_items, custom_dir),
        daemon=True,
    )
    try:
        _batch_thread.start()
    except Exception as exc:
        logger.exception("[BatchInstall] Could not start worker thread: %s", exc)
        with _batch_lock:
            _mark_batch_worker_failed_locked(
                f"پردازش صف نصب شروع نشد: {exc}"
            )
            status = copy.deepcopy(_batch_state)
        return {
            "success": False,
            "message": status["summary_message"],
            "status": status,
        }

    with _batch_lock:
        status = copy.deepcopy(_batch_state)

    return {
        "success": True,
        "message": f"فرآیند نصب خودکار و تنظیمات سیستم ({len(queue_items)} مرحله) آغاز شد...",
        "total": len(queue_items),
        "items": status["items"],
        "status": status,
    }


def get_batch_status() -> Dict[str, Any]:
    """Returns current batch install progress and status."""
    with _batch_lock:
        _repair_dead_worker_locked()
        snapshot = copy.deepcopy(_batch_state)
        snapshot["state_revision"] = max(1, snapshot.get("state_revision", 1))
        snapshot["server_time"] = time.time()
        snapshot["api_contract_version"] = 5
        return snapshot


def cancel_batch_install() -> Dict[str, Any]:
    """Cancels the running batch install."""
    with _batch_lock:
        if not _batch_state["is_running"]:
            return {"success": False, "message": "هیچ عملیات نصب خودکاری در حال اجرا نیست."}
        _batch_state["cancelled"] = True
        _bump_revision_locked()
    return {"success": True, "message": "دستور لغو ارسال شد. آیتم‌های باقی‌مانده رد خواهند شد."}
