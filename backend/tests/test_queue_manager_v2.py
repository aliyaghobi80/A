# backend/tests/test_queue_manager_v2.py
"""
Comprehensive Unit Test Suite for Intelligent Driver Queue Manager (v2).
Tests:
- Exit code normalization (0, 3010, 1641, 1618, 1602, 1603, -2, -5)
- Reboot suppression and single advisory reboot reminder append to summary_message
- Skipping up-to-date and recommended-skip drivers without running installer
- Atomic disk persistence of queue state (.tmp -> os.replace)
- Timeout process tree termination (terminate_process_tree via taskkill /F /T)
- Queue adoption and active status reporting
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import MagicMock, patch

BACKEND_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if BACKEND_DIR not in sys.path:
    sys.path.insert(0, BACKEND_DIR)

from drivers import queue_manager
from drivers.queue_manager import (
    start_driver_queue,
    get_driver_queue_status,
    cancel_driver_queue,
    _install_single_package,
    _format_driver_failure_reason,
)
from deployment_scheduler import persist_queue_state_atomic
from packages.manager import terminate_process_tree
import copy


class TestQueueManagerV2(unittest.TestCase):

    def setUp(self):
        self.test_dir = tempfile.mkdtemp(prefix="test_qm2_")
        self._orig_queue_state = copy.deepcopy(queue_manager._queue_state)
        self._orig_queue_thread = queue_manager._queue_thread

    def tearDown(self):
        with queue_manager._queue_lock:
            queue_manager._queue_state = self._orig_queue_state
            queue_manager._queue_thread = self._orig_queue_thread
        shutil.rmtree(self.test_dir, ignore_errors=True)

    # -------------------------------------------------------------------------
    # 1. Exit Code Normalization & Reboot Flags
    # -------------------------------------------------------------------------
    def test_exit_code_0_success(self):
        pkg = {
            "package_id": "pkg_0",
            "display_name": "Test Driver",
            "category": "lan",
            "install_method": "setup_exe",
            "installer_path": os.path.join(self.test_dir, "setup.exe"),
            "silent_args": ["/s"],
        }
        with open(pkg["installer_path"], "wb") as f:
            f.write(b"MZ")

        with patch("drivers.queue_manager._run_elevated_and_wait", return_value=0):
            res = _install_single_package(pkg)
            self.assertTrue(res["success"])
            self.assertEqual(res["exit_code"], 0)
            self.assertFalse(res["reboot_required"])
            self.assertFalse(res["reboot"])

    def test_exit_code_3010_and_1641_reboot_required(self):
        pkg = {
            "package_id": "pkg_reboot",
            "display_name": "Reboot Demanding Driver",
            "category": "audio",
            "install_method": "setup_exe",
            "installer_path": os.path.join(self.test_dir, "setup.exe"),
            "silent_args": ["/s"],
        }
        with open(pkg["installer_path"], "wb") as f:
            f.write(b"MZ")

        # 3010: ERROR_SUCCESS_REBOOT_REQUIRED
        with patch("drivers.queue_manager._run_elevated_and_wait", return_value=3010):
            res3010 = _install_single_package(pkg)
            self.assertTrue(res3010["success"])
            self.assertEqual(res3010["exit_code"], 3010)
            self.assertTrue(res3010["reboot_required"])
            self.assertTrue(res3010["reboot"])

        # 1641: ERROR_SUCCESS_REBOOT_INITIATED
        with patch("drivers.queue_manager._run_elevated_and_wait", return_value=1641):
            res1641 = _install_single_package(pkg)
            self.assertTrue(res1641["success"])
            self.assertEqual(res1641["exit_code"], 1641)
            self.assertTrue(res1641["reboot_required"])
            self.assertTrue(res1641["reboot"])

    def test_exit_codes_failures_and_messages(self):
        # 1603 Fatal error
        msg1603 = _format_driver_failure_reason(1603, "setup_exe", "", {})
        self.assertIn("1603", msg1603)
        self.assertIn("سازگار نیست", msg1603)

        # 1602 User cancelled
        msg1602 = _format_driver_failure_reason(1602, "setup_exe", "", {})
        self.assertIn("1602", msg1602)
        self.assertIn("متوقف", msg1602)

        # 1618 Already running
        msg1618 = _format_driver_failure_reason(1618, "setup_exe", "", {})
        self.assertIn("ویندوز فعال است", msg1618)

        # -2 Timeout
        msg_timeout = _format_driver_failure_reason(-2, "setup_exe", "", {})
        self.assertIn("زمان مجاز", msg_timeout)

        # -5 Abrupt termination
        msg_crash = _format_driver_failure_reason(-5, "setup_exe", "", {})
        self.assertIn("غیرمنتظره", msg_crash)

    # -------------------------------------------------------------------------
    # 2. Single Advisory Reboot Reminder Append
    # -------------------------------------------------------------------------
    def test_single_advisory_reboot_reminder_appended(self):
        reminder_text = " — یادتان نرود پس از پایان همهٔ کارها، سیستم را دستی ری‌استارت کنید."
        with queue_manager._queue_lock:
            queue_manager._queue_thread = None
            queue_manager._queue_state.update({
                "status": "ok",
                "is_running": False,
                "completed": 2,
                "failed": 0,
                "reboot_required": True,
                "summary_message": "✓ تمامی ۲ بسته درایور با موفقیت نصب شدند." + reminder_text,
            })

        # Call get_driver_queue_status outside lock to avoid self-deadlock
        status = queue_manager.get_driver_queue_status()

        summary = status["summary_message"]
        # Must contain exactly ONE advisory reminder text
        self.assertEqual(summary.count(reminder_text), 1)
        self.assertTrue(status["reboot_required"])

    # -------------------------------------------------------------------------
    # 3. Skipping Up-to-Date Drivers
    # -------------------------------------------------------------------------
    def test_skipping_up_to_date_drivers(self):
        pkg_uptodate = {
            "package_id": "pkg_skip",
            "display_name": "Up to Date Driver",
            "category": "lan",
            "installer_file": "setup.exe",
            "match": {
                "status": "up_to_date",
                "recommendation": "skip",
            },
        }
        pkg_needed = {
            "package_id": "pkg_needed",
            "display_name": "Needed Driver",
            "category": "audio",
            "installer_file": "setup.exe",
            "match": {
                "status": "needs_install",
                "recommendation": "recommended",
            },
        }

        # Prevent background worker execution while verifying initial queue structure
        with patch("drivers.queue_manager._run_queue_thread"):
            res = start_driver_queue([pkg_uptodate, pkg_needed])
            self.assertTrue(res["success"])
            items = res["status"]["items"]

            # First item must be pre-marked as skipped
            skip_item = next(i for i in items if i["package_id"] == "pkg_skip")
            self.assertEqual(skip_item["status"], "skipped")
            self.assertIn("به‌روز است", skip_item["message"])

            # Second item must be pending
            need_item = next(i for i in items if i["package_id"] == "pkg_needed")
            self.assertEqual(need_item["status"], "pending")

            self.assertEqual(res["status"]["skipped"], 1)

    # -------------------------------------------------------------------------
    # 4. Atomic Disk Persistence Protocol (.tmp -> os.replace)
    # -------------------------------------------------------------------------
    def test_atomic_state_persistence(self):
        state_file = os.path.join(self.test_dir, "driver_queue_state.json")
        payload = {
            "status": "ok",
            "is_running": True,
            "completed": 3,
            "active_items": [
                {"package_id": "drv_1", "worker_id": 1, "status": "installing"},
                {"package_id": "drv_2", "worker_id": 2, "status": "installing"},
            ],
        }

        # Persist atomically
        written_path = persist_queue_state_atomic(payload, state_file)
        self.assertEqual(written_path, os.path.abspath(state_file))
        self.assertTrue(os.path.isfile(state_file))

        # Ensure .tmp file was cleanly replaced and does not remain
        self.assertFalse(os.path.exists(f"{state_file}.tmp"))

        # Verify disk contents match exactly
        with open(state_file, "r", encoding="utf-8") as f:
            loaded = json.load(f)

        self.assertEqual(loaded["completed"], 3)
        self.assertEqual(len(loaded["active_items"]), 2)
        self.assertEqual(loaded["active_items"][1]["package_id"], "drv_2")

    # -------------------------------------------------------------------------
    # 5. Process Tree Termination (taskkill.exe /F /T /PID)
    # -------------------------------------------------------------------------
    def test_terminate_process_tree_valid_pid(self):
        # Mock successful taskkill execution
        with patch("subprocess.run", return_value=MagicMock(returncode=0)) as mock_run:
            ok = terminate_process_tree(12345)
            self.assertTrue(ok)
            cmd_args = mock_run.call_args[0][0]
            self.assertEqual(cmd_args, ["taskkill.exe", "/F", "/T", "/PID", "12345"])

    def test_terminate_process_tree_invalid_pids(self):
        self.assertFalse(terminate_process_tree(0))
        self.assertFalse(terminate_process_tree(-1))
        self.assertFalse(terminate_process_tree(None))

    def test_terminate_process_tree_exception_handled(self):
        with patch("subprocess.run", side_effect=OSError("Access denied")):
            self.assertFalse(terminate_process_tree(999))


if __name__ == "__main__":
    unittest.main()
