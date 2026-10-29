"""Bounded deployment lanes with conservative, cross-queue resource exclusion.

2X is a maximum, never a promise that arbitrary OEM installers can overlap.
Only locally reviewed, hash-pinned profiles may opt into parallel execution.
Unknown packages, orchestrator stages, and core driver changes are exclusive.
"""
from concurrent.futures import ThreadPoolExecutor
from contextlib import contextmanager
import hashlib
import json
import logging
import os
from pathlib import Path
import sys
import threading
import time
from typing import Any, Callable, Dict, List, Optional, Set, Tuple

logger = logging.getLogger(__name__)

POLICY_FILE = ((Path(sys.executable).resolve().parent.parent if getattr(sys, "frozen", False)
                else Path(__file__).resolve().parent.parent) / "config" / "parallel_installers.json")
_condition = threading.Condition()
_active = []


class ExternalInstallerBusyError(RuntimeError):
    pass


def windows_installer_busy() -> bool:
    """Return True only when Windows Installer's documented execute mutex is held."""
    if os.name != "nt":
        return False
    import ctypes
    from ctypes import wintypes
    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel.OpenMutexW.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.LPCWSTR]
    kernel.OpenMutexW.restype = wintypes.HANDLE
    kernel.WaitForSingleObject.argtypes = [wintypes.HANDLE, wintypes.DWORD]
    kernel.WaitForSingleObject.restype = wintypes.DWORD
    kernel.ReleaseMutex.argtypes = [wintypes.HANDLE]
    kernel.CloseHandle.argtypes = [wintypes.HANDLE]
    synchronize = 0x00100000
    modify_state = 0x0001
    handle = kernel.OpenMutexW(synchronize | modify_state, False, "Global\\_MSIExecute")
    if not handle:
        return False
    try:
        result = kernel.WaitForSingleObject(handle, 0)
        if result in (0x00000000, 0x00000080):
            kernel.ReleaseMutex(handle)
            return False
        return result == 0x00000102
    finally:
        kernel.CloseHandle(handle)


def wait_for_windows_installer_idle(timeout_seconds: float = 900, poll_seconds: float = 1.0, on_wait: Optional[Callable[[], None]] = None) -> bool:
    """Wait for an external MSI transaction without touching its process/UI."""
    deadline = time.monotonic() + max(0.0, float(timeout_seconds))
    announced = False
    while windows_installer_busy():
        if not announced and on_wait:
            on_wait()
            announced = True
        if time.monotonic() >= deadline:
            return False
        time.sleep(max(0.05, float(poll_seconds)))
    return True


def approved_resources(item: Any, *, driver: bool = False, root: Optional[str] = None) -> Optional[frozenset]:
    """Inspects package profile and returns approved resource tag set, or None if exclusive."""
    if not isinstance(item, dict):
        return None
    if item.get("orchestrator_action"):
        return None
    if driver and (item.get("category") in {"gpu", "chipset", "storage", "system_mei"}
                   or item.get("install_method") in {"msiexec", "pnputil", "inf_pnputil", "script"}):
        return None
    path = (item.get("installer_path") or item.get("installer_file") or
            item.get("relative_path") or item.get("filename"))
    if not path:
        return None
    path = Path(path)
    if not path.is_absolute() and root:
        path = Path(root) / path
    if path.suffix.lower() != ".exe":
        return None
    try:
        if not POLICY_FILE.exists():
            return None
        profiles = json.loads(POLICY_FILE.read_text(encoding="utf-8"))
        if not profiles:
            return None
        digest = hashlib.sha256()
        with path.open("rb") as stream:
            for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                digest.update(chunk)
        profile = profiles.get(digest.hexdigest(), {})
        resources = profile.get("resources")
        if (profile.get("kind") != ("driver" if driver else "software") or
                profile.get("reviewed") is not True or not isinstance(resources, list) or
                not resources or not all(isinstance(x, str) and x.strip() for x in resources)):
            return None
        return frozenset(resources)
    except (OSError, ValueError, TypeError, AttributeError):
        return None


@contextmanager
def deployment_slot(resources: Optional[frozenset]):
    """An exclusive job blocks both software and driver lanes in this backend."""
    token = object()
    with _condition:
        _condition.wait_for(lambda: not _active or (
            resources is not None and len(_active) < 2 and
            all(existing is not None and not (existing & resources)
                for _, existing in _active)))
        _active.append((token, resources))
    try:
        yield
    finally:
        with _condition:
            _active[:] = [(key, value) for key, value in _active if key is not token]
            _condition.notify_all()


def persist_queue_state_atomic(state_dict: dict, file_path: Optional[str] = None) -> str:
    """
    Atomically persists queue state dictionary to disk (CONTRACT.md § 9).
    Uses temporary file write with flush and fsync, followed by os.replace.
    """
    if not file_path:
        base = os.environ.get("LOCALAPPDATA") or os.environ.get("APPDATA")
        if base:
            file_path = os.path.join(base, "MarkaziSystemChecker", "driver_queue_state.json")
        else:
            file_path = os.path.join(os.path.dirname(__file__), "..", "data", "driver_queue_state.json")

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


class DeploymentWorkerPool:
    """
    Dynamic 2-lane deployment scheduler pool for sequential drivers and software installations.

    Guarantees:
    - In 1X mode: 1 worker running serially.
    - In 2X mode: 2 workers (Worker 1 + Worker 2).
    - Worker 1 handles Barriers and parallel-safe items.
    - Worker 2 handles parallel-safe items only.
    - Pre-barrier drain: Worker 1 waits until Worker 2 finishes before executing a Barrier.
    - Lookahead brake: Worker 2 yields if the next pending item in queue is a Barrier.
    - Global_MSIExecute mutex synchronization.
    - Error 1618 retry policy: bounded max 2 retries (total 3 attempts), exponential backoff (3s, 7s),
      forced serial fallback (is_barrier = True).
    - Dynamic 2X -> 1X switching without killing Worker 2 mid-flight.
    """

    def __init__(
        self,
        items: List[Any],
        run_one: Callable[[int, Any], Any],
        *,
        double_speed: bool = False,
        resources_for: Optional[Callable[[Any], Optional[frozenset]]] = None,
        on_external_wait: Optional[Callable[[int, Any], None]] = None,
        on_status_change: Optional[Callable[[], None]] = None,
        state_file: Optional[str] = None,
    ):
        self.items = list(items)
        self.run_one = run_one
        self.double_speed = bool(double_speed)
        self.resources_for = resources_for
        self.on_external_wait = on_external_wait
        self.on_status_change = on_status_change
        self.state_file = state_file

        self.state_lock = threading.Lock()
        self.drain_condition = threading.Condition(self.state_lock)

        self.claimed_indices: Set[int] = set()
        self.completed_indices: Set[int] = set()
        self.failed_indices: Set[int] = set()
        self.active_items: Dict[int, Dict[str, Any]] = {}  # worker_id -> info
        self.retry_counts: Dict[int, int] = {}

        self.cancelled = False
        self.is_running = False
        self.fatal_error: Optional[Exception] = None
        self.worker_threads: List[threading.Thread] = []

    def set_double_speed(self, double_speed: bool) -> None:
        """Dynamically toggle 2X mode without killing active workers."""
        with self.state_lock:
            self.double_speed = bool(double_speed)
            self.drain_condition.notify_all()

    def set_mode(self, mode: str) -> None:
        """Sets mode to '1X' or '2X'."""
        self.set_double_speed(mode == "2X")

    def _get_resources(self, item: Any) -> Optional[frozenset]:
        if not self.double_speed:
            return None
        if self.resources_for:
            try:
                return self.resources_for(item)
            except Exception:
                return None
        if isinstance(item, dict):
            tag = item.get("resource_tag") or item.get("category")
            if tag:
                return frozenset({str(tag)})
        return None

    def is_barrier(self, item: Any) -> bool:
        """Classifies if item is a strict Barrier requiring exclusive Worker 1 execution."""
        if isinstance(item, dict):
            if item.get("is_barrier") is True:
                return True
            cat = str(item.get("category") or "").lower()
            if cat in ("chipset", "system_mei", "storage", "gpu"):
                return True
            method = str(item.get("install_method") or "").lower()
            if method in ("msiexec", "pnputil", "inf_pnputil", "script"):
                return True
            if item.get("installer_type") in ("msi", "orchestrator"):
                return True
            fn = str(item.get("filename") or item.get("installer_file") or item.get("installer_path") or "").lower()
            if fn.endswith(".msi"):
                return True
            if item.get("orchestrator_action"):
                return True
            # Unknown or unswitched packages are barriers
            silent_args = item.get("silent_args")
            if silent_args == [] and method not in ("pnputil", "inf_pnputil"):
                return True
            if self.resources_for:
                res = self._get_resources(item)
                if res is None and item.get("is_parallel_safe") is not True:
                    return True
            return False
        # Generic objects or numbers: if resources_for returned None, it's a barrier
        if self.resources_for:
            return self._get_resources(item) is None
        return True

    def is_parallel_safe(self, item: Any) -> bool:
        """Classifies if item is eligible for concurrent execution on Worker 2."""
        if self.is_barrier(item):
            return False
        if isinstance(item, dict):
            if item.get("is_parallel_safe") is False:
                return False
            if item.get("is_parallel_safe") is True:
                return True
            cat = str(item.get("category") or "").lower()
            if cat in ("audio", "lan", "wifi", "bluetooth", "touchpad", "card_reader", "camera", "usb", "other"):
                return True
            return False
        if self.resources_for:
            return self._get_resources(item) is not None
        return True

    def claim_next_item(self, worker_id: int) -> Optional[Tuple[int, Any, Optional[frozenset]]]:
        """
        Atomically claims next executable item for worker_id.
        Enforces pre-barrier drain and lookahead brake invariants.
        """
        with self.state_lock:
            while not self.cancelled and self.fatal_error is None:
                # Check if all items are processed or claimed
                if len(self.claimed_indices) >= len(self.items):
                    return None

                # Find next pending item index
                next_pending_idx: Optional[int] = None
                for i in range(len(self.items)):
                    if i not in self.claimed_indices:
                        next_pending_idx = i
                        break

                if next_pending_idx is None:
                    return None

                # WORKER 2 RULES (2X Lane):
                if worker_id == 2:
                    if not self.double_speed:
                        # 2X mode disabled; Worker 2 stops claiming tasks and drains
                        return None

                    # Barrier Execution Lock (CONTRACT.md § 3.1):
                    # Worker 2 must yield if Worker 1 is running a Barrier!
                    if 1 in self.active_items:
                        w1_item = self.active_items[1].get("item")
                        if self.is_barrier(w1_item):
                            return None

                    # Lookahead Barrier Brake (CONTRACT.md § 3.3):
                    # If the next pending item in queue is a Barrier, Worker 2 must not claim any item!
                    if self.is_barrier(self.items[next_pending_idx]):
                        # Yield slot immediately so Worker 1 can execute the Barrier
                        return None

                    # Find first unclaimed parallel-safe item without resource conflict
                    candidate_idx: Optional[int] = None
                    candidate_res: Optional[frozenset] = None

                    for idx in range(next_pending_idx, len(self.items)):
                        if idx in self.claimed_indices:
                            continue
                        candidate_item = self.items[idx]
                        if self.is_barrier(candidate_item):
                            # Reached a barrier in lookahead; brake further inspection
                            break
                        if not self.is_parallel_safe(candidate_item):
                            continue

                        res = self._get_resources(candidate_item)
                        # Check collision with active items on other workers
                        collision = False
                        for other_wid, info in self.active_items.items():
                            if other_wid != worker_id:
                                other_res = info.get("resources")
                                if res is not None and other_res is not None and (res & other_res):
                                    collision = True
                                    break
                        if not collision:
                            candidate_idx = idx
                            candidate_res = res
                            break

                    if candidate_idx is not None:
                        # Successfully claimed by Worker 2
                        item = self.items[candidate_idx]
                        self.claimed_indices.add(candidate_idx)
                        now = time.time()
                        self.active_items[worker_id] = {
                            "index": candidate_idx,
                            "item": item,
                            "package_id": item.get("package_id") if isinstance(item, dict) else str(candidate_idx),
                            "display_name": item.get("display_name") if isinstance(item, dict) else str(item),
                            "category": item.get("category") if isinstance(item, dict) else "",
                            "worker_id": worker_id,
                            "status": "installing",
                            "start_time": now,
                            "retry_count": self.retry_counts.get(candidate_idx, 0),
                            "resources": candidate_res,
                        }
                        self.drain_condition.notify_all()
                        return (candidate_idx, item, candidate_res)

                    # No eligible parallel item available right now
                    return None

                # WORKER 1 RULES (Primary Lane):
                else:
                    item = self.items[next_pending_idx]
                    res = self._get_resources(item)

                    if self.is_barrier(item):
                        # Pre-Barrier Drain Rule (CONTRACT.md § 3.3):
                        # If Worker 2 is currently active, Worker 1 must wait until Worker 2 completes!
                        while any(wid != 1 for wid in self.active_items):
                            if self.cancelled or self.fatal_error is not None:
                                return None
                            self.drain_condition.wait()

                        # Worker 2 is drained! Worker 1 claims barrier item exclusively
                        self.claimed_indices.add(next_pending_idx)
                        now = time.time()
                        self.active_items[1] = {
                            "index": next_pending_idx,
                            "item": item,
                            "package_id": item.get("package_id") if isinstance(item, dict) else str(next_pending_idx),
                            "display_name": item.get("display_name") if isinstance(item, dict) else str(item),
                            "category": item.get("category") if isinstance(item, dict) else "",
                            "worker_id": 1,
                            "status": "installing",
                            "start_time": now,
                            "retry_count": self.retry_counts.get(next_pending_idx, 0),
                            "resources": None,
                        }
                        self.drain_condition.notify_all()
                        return (next_pending_idx, item, None)

                    # Non-barrier item on Worker 1:
                    # Check resource collision with Worker 2
                    collision = False
                    for other_wid, info in self.active_items.items():
                        if other_wid != 1:
                            other_res = info.get("resources")
                            if res is not None and other_res is not None and (res & other_res):
                                collision = True
                                break
                    if collision:
                        # Wait for Worker 2 to release conflicting resource
                        self.drain_condition.wait()
                        continue

                    self.claimed_indices.add(next_pending_idx)
                    now = time.time()
                    self.active_items[1] = {
                        "index": next_pending_idx,
                        "item": item,
                        "package_id": item.get("package_id") if isinstance(item, dict) else str(next_pending_idx),
                        "display_name": item.get("display_name") if isinstance(item, dict) else str(item),
                        "category": item.get("category") if isinstance(item, dict) else "",
                        "worker_id": 1,
                        "status": "installing",
                        "start_time": now,
                        "retry_count": self.retry_counts.get(next_pending_idx, 0),
                        "resources": res,
                    }
                    self.drain_condition.notify_all()
                    return (next_pending_idx, item, res)

            return None

    def release_item(
        self,
        worker_id: int,
        index: int,
        *,
        success: bool = True,
        exit_code: int = 0,
        error: Optional[Exception] = None,
    ) -> None:
        """Releases worker slot and marks completion/failure status."""
        with self.state_lock:
            self.active_items.pop(worker_id, None)
            if error is not None and self.fatal_error is None:
                self.fatal_error = error
            elif index in self.failed_indices:
                self.completed_indices.discard(index)
            elif index not in self.claimed_indices:
                # The item was retried (unclaimed in handle_1618_retry), not completed
                self.completed_indices.discard(index)
            elif success and not (index < len(self.items) and isinstance(self.items[index], dict) and self.items[index].get("status") == "failed"):
                self.completed_indices.add(index)
            else:
                self.failed_indices.add(index)
                self.completed_indices.discard(index)
            self.drain_condition.notify_all()

    def handle_1618_retry(self, index: int, item: Any) -> bool:
        """
        Error 1618 bounded retry policy (CONTRACT.md § 5.2):
        Caps at 2 retries (total 3 attempts), with exponential backoff (3s, 7s)
        and forced serial fallback (is_barrier = True).
        Returns True if item was re-queued for retry, False if retries exhausted.
        """
        with self.state_lock:
            retries = self.retry_counts.get(index, 0)
            if retries >= 2:
                if isinstance(item, dict):
                    item["status"] = "failed"
                    item["failure_reason"] = "نصب‌کننده Windows Installer همچنان مشغول است؛ بیش از ۲ بار تلاش انجام شد و نصب متوقف گردید."
                    item["exit_code"] = 1618
                self.failed_indices.add(index)
                self.completed_indices.discard(index)
                return False

            new_retry = retries + 1
            self.retry_counts[index] = new_retry
            if isinstance(item, dict):
                item["retry_count"] = new_retry
                item["status"] = "pending"
                item["is_barrier"] = True
                item["is_parallel_safe"] = False
                item["message"] = f"Windows Installer در حال استفاده است؛ تلاش مجدد {new_retry} از ۲..."
            backoff = 3.0 if new_retry == 1 else 7.0

        # Perform backoff and wait synchronously within worker before unclaiming
        time.sleep(backoff)
        wait_for_windows_installer_idle(timeout_seconds=900)

        with self.state_lock:
            # Release claim so Worker 1 can re-claim it after drain
            self.claimed_indices.discard(index)
            self.completed_indices.discard(index)
            self.drain_condition.notify_all()
        return True

    def get_active_items(self) -> List[Dict[str, Any]]:
        """Returns snapshot of currently executing active items."""
        with self.state_lock:
            result = []
            now = time.time()
            for wid in sorted(self.active_items.keys()):
                info = self.active_items[wid]
                start_t = info.get("start_time", now)
                result.append({
                    "package_id": info.get("package_id"),
                    "display_name": info.get("display_name"),
                    "category": info.get("category"),
                    "worker_id": wid,
                    "status": "installing",
                    "start_time": start_t,
                    "elapsed_seconds": round(max(0.0, now - start_t), 1),
                    "retry_count": info.get("retry_count", 0),
                })
            return result

    def cancel(self) -> None:
        """Signals cancellation to all workers."""
        with self.state_lock:
            self.cancelled = True
            self.drain_condition.notify_all()

    def _worker_loop(self, worker_id: int) -> None:
        """Worker thread main execution loop."""
        while not self.cancelled and self.fatal_error is None:
            claimed = self.claim_next_item(worker_id)
            if claimed is None:
                # No more items or lookahead brake / mode change
                if worker_id == 2 and not self.double_speed:
                    break
                with self.state_lock:
                    if len(self.claimed_indices) >= len(self.items) and not self.active_items:
                        break
                    # Wait briefly for condition change
                    self.drain_condition.wait(timeout=0.25)
                continue

            index, item, resources = claimed

            # Check Windows Installer idle
            if not wait_for_windows_installer_idle(
                on_wait=(lambda: self.on_external_wait(index, item)) if self.on_external_wait else None
            ):
                err = ExternalInstallerBusyError("Windows Installer remained busy for 15 minutes; queue stopped safely.")
                self.release_item(worker_id, index, success=False, error=err)
                break

            worker_err: Optional[Exception] = None
            try:
                with deployment_slot(resources):
                    self.run_one(index, item)
            except Exception as exc:
                worker_err = exc

            self.release_item(
                worker_id,
                index,
                success=(worker_err is None),
                error=worker_err,
            )

            if worker_err is not None:
                break

    def run(self) -> None:
        """Runs the worker pool synchronously and waits for all lanes to join."""
        self.is_running = True
        num_workers = 2 if self.double_speed else 1

        with ThreadPoolExecutor(max_workers=2, thread_name_prefix="DeploymentWorker") as pool:
            futures = [pool.submit(self._worker_loop, wid) for wid in range(1, num_workers + 1)]
            for future in futures:
                try:
                    future.result()
                except Exception as exc:
                    if self.fatal_error is None:
                        self.fatal_error = exc

        self.is_running = False
        if self.fatal_error is not None:
            raise self.fatal_error


def run_deployment(items: List[Any], run_one: Callable[[int, Any], Any], *,
                   double_speed: bool = False,
                   resources_for: Callable[[Any], Optional[frozenset]] = lambda item: None,
                   on_external_wait: Optional[Callable[[int, Any], None]] = None) -> None:
    """
    Executes items preserving barriers and sequential priorities.
    Uses DeploymentWorkerPool to enforce 2X bounded concurrency.
    """
    pool = DeploymentWorkerPool(
        items,
        run_one,
        double_speed=double_speed,
        resources_for=resources_for,
        on_external_wait=on_external_wait,
    )
    pool.run()
