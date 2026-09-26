"""Lifecycle hand-off between the Flutter UI and the local backend service.

The Windows UI may deliberately restart itself after a graphics-driver reset.
The backend must stay alive long enough for the replacement UI process to
adopt it, otherwise an in-progress driver queue would be lost.
"""

from __future__ import annotations

import logging
import os
import threading
import time
from typing import Callable, Optional, Tuple


logger = logging.getLogger(__name__)

_state_lock = threading.Lock()
_parent_pid: Optional[int] = None
_parent_pids = set()
_parent_generation = 0
_watchdog_started = False


def _is_process_alive(pid: int) -> bool:
    if pid <= 1:
        return False

    if os.name != "nt":
        try:
            os.kill(pid, 0)
            return True
        except OSError:
            return False

    try:
        import ctypes
        from ctypes import wintypes

        kernel = ctypes.WinDLL("kernel32", use_last_error=True)
        kernel.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
        kernel.OpenProcess.restype = wintypes.HANDLE
        kernel.CloseHandle.argtypes = [wintypes.HANDLE]
        kernel.CloseHandle.restype = wintypes.BOOL
        synchronize = 0x00100000
        handle = kernel.OpenProcess(synchronize, False, int(pid))
        if not handle:
            return False
        kernel.CloseHandle(handle)
        return True
    except Exception:
        return False


def adopt_parent_process(parent_pid: int) -> bool:
    """Make ``parent_pid`` the UI process currently owning this backend."""
    global _parent_pid, _parent_generation
    try:
        parsed_pid = int(parent_pid)
    except (TypeError, ValueError):
        return False
    if parsed_pid <= 1 or not _is_process_alive(parsed_pid):
        return False

    with _state_lock:
        _parent_pid = parsed_pid
        _parent_pids.add(parsed_pid)
        _parent_generation += 1
        generation = _parent_generation
    logger.info("Backend adopted by frontend PID %s (generation %s).", parsed_pid, generation)
    return True


def get_parent_session() -> Tuple[Optional[int], int]:
    """Return an immutable snapshot used by diagnostics and tests."""
    with _state_lock:
        return _parent_pid, _parent_generation


def get_parent_processes() -> Tuple[int, ...]:
    """Return all live-or-pending frontend owners known to the backend."""
    with _state_lock:
        return tuple(sorted(_parent_pids))


def _prune_and_check_parents() -> Tuple[bool, int]:
    """Drop exited owners without racing a newly attached UI process."""
    global _parent_pid
    with _state_lock:
        candidates = tuple(_parent_pids)
        generation = _parent_generation

    alive = {pid for pid in candidates if _is_process_alive(pid)}
    with _state_lock:
        if generation != _parent_generation:
            return bool(_parent_pids), _parent_generation
        _parent_pids.intersection_update(alive)
        if _parent_pid not in _parent_pids:
            _parent_pid = next(iter(_parent_pids), None)
        return bool(_parent_pids), _parent_generation


def start_parent_watchdog(
    parent_pid: Optional[int],
    *,
    grace_seconds: float = 30.0,
    poll_seconds: float = 1.0,
    exit_process: Callable[[int], None] = os._exit,
) -> None:
    """Watch the active UI process while allowing a controlled UI hand-off.

    A graphics driver can invalidate Flutter's rendering device.  The native
    runner then starts a replacement UI process.  That process calls the
    session-attach endpoint and increments ``_parent_generation``.  Only when
    no replacement arrives during the grace period is the backend terminated.
    """
    global _watchdog_started
    if parent_pid is None or not adopt_parent_process(parent_pid):
        return

    with _state_lock:
        if _watchdog_started:
            return
        _watchdog_started = True

    def _watch() -> None:
        missing_generation: Optional[int] = None
        missing_since = 0.0
        while True:
            has_live_parent, generation = _prune_and_check_parents()
            current_pid, _ = get_parent_session()
            if has_live_parent:
                missing_generation = None
                missing_since = 0.0
            elif missing_generation != generation:
                missing_generation = generation
                missing_since = time.monotonic()
                logger.warning(
                    "Frontend PID %s exited; waiting %.0f seconds for UI recovery hand-off.",
                    current_pid,
                    grace_seconds,
                )
            elif time.monotonic() - missing_since >= grace_seconds:
                logger.info("No replacement frontend adopted the backend; stopping service.")
                exit_process(0)
                return
            time.sleep(max(0.05, poll_seconds))

    threading.Thread(
        target=_watch,
        daemon=True,
        name="ParentProcessWatchdog",
    ).start()
