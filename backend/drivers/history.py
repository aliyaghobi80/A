# backend/drivers/history.py
"""
Lightweight Local Driver Installation History Manager.
Persists records of executed driver installations in data/driver_install_history.json:
- Package Fingerprint & Canonical Path
- Driver Category & Version
- Execution Timestamp
- Result, Exit Code, and Reboot Requirement Flag
Safe: stores no credentials or sensitive tokens.
"""

import json
import logging
import os
import time
import threading
from functools import wraps
from typing import Dict, Any, List

logger = logging.getLogger(__name__)
_history_lock = threading.RLock()


def _serialized(function):
    @wraps(function)
    def wrapped(*args, **kwargs):
        with _history_lock:
            return function(*args, **kwargs)
    return wrapped

HISTORY_FILE = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "..", "..", "data", "driver_install_history.json")
)


def _ensure_history_file() -> None:
    os.makedirs(os.path.dirname(HISTORY_FILE), exist_ok=True)
    if not os.path.isfile(HISTORY_FILE):
        try:
            with open(HISTORY_FILE, "w", encoding="utf-8") as f:
                f.write("[]")
        except Exception as e:
            logger.error(f"Error creating driver history file: {e}")


@_serialized
def load_driver_history() -> List[Dict[str, Any]]:
    """Loads all historical installation records."""
    _ensure_history_file()
    try:
        with open(HISTORY_FILE, "r", encoding="utf-8") as f:
            data = json.load(f)
            if isinstance(data, list):
                return data
    except Exception as e:
        logger.error(f"Error reading driver history file: {e}")
    return []


@_serialized
def record_driver_installation(
    fingerprint: str,
    category: str,
    package_name: str,
    installer_path: str,
    driver_version: str,
    result: str,  # 'success', 'failed', 'skipped', 'needs_reboot'
    exit_code: int,
    reboot_required: bool,
    message: str = "",
) -> None:
    """Appends a new installation event to the history JSON."""
    _ensure_history_file()
    history = load_driver_history()

    record = {
        "fingerprint": fingerprint,
        "category": category,
        "package_name": package_name,
        "installer_path": installer_path,
        "driver_version": driver_version,
        "timestamp": time.time(),
        "date_str": time.strftime("%Y-%m-%d %H:%M:%S"),
        "result": result,
        "exit_code": exit_code,
        "reboot_required": reboot_required,
        "message": message,
    }

    history.append(record)

    # Keep latest 200 records
    if len(history) > 200:
        history = history[-200:]

    try:
        temporary = HISTORY_FILE + ".tmp"
        with open(temporary, "w", encoding="utf-8") as f:
            json.dump(history, f, indent=2, ensure_ascii=False)
        os.replace(temporary, HISTORY_FILE)
        logger.info(f"[DriverHistory] Recorded {result} for {package_name} ({fingerprint})")
    except Exception as e:
        logger.error(f"Error writing driver history file: {e}")


def has_recently_installed(fingerprint: str, max_age_seconds: int = 86400) -> bool:
    """Checks if a package was successfully installed recently."""
    history = load_driver_history()
    now = time.time()
    for rec in reversed(history):
        if rec.get("fingerprint") == fingerprint and rec.get("result") in ("success", "needs_reboot"):
            if now - float(rec.get("timestamp", 0)) < max_age_seconds:
                return True
    return False
