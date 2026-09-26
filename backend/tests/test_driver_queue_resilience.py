import copy
import os
import sys
import threading
import time
import unittest
from unittest.mock import patch


sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from drivers import queue_manager
import session_watchdog


class DriverQueueResilienceTests(unittest.TestCase):
    def setUp(self):
        with queue_manager._queue_lock:
            self.original_state = copy.deepcopy(queue_manager._queue_state)
            self.original_thread = queue_manager._queue_thread
            self.original_packages = queue_manager._last_packages

    def tearDown(self):
        with queue_manager._queue_lock:
            queue_manager._queue_state = self.original_state
            queue_manager._queue_thread = self.original_thread
            queue_manager._last_packages = self.original_packages

    @staticmethod
    def _running_state():
        return {
            "is_running": True,
            "cancelled": False,
            "total": 1,
            "completed": 0,
            "failed": 0,
            "skipped": 0,
            "current_index": 0,
            "current_package": None,
            "progress_percent": 0.0,
            "start_time": time.time(),
            "end_time": None,
            "reboot_required": False,
            "summary_message": "",
            "resolved_devices_count": 0,
            "last_update_time": time.time(),
            "worker_alive": False,
            "fatal_error": "",
            "items": [
                {
                    "package_id": "gpu-1",
                    "display_name": "GPU Driver",
                    "category": "gpu",
                    "installer_file": "setup.exe",
                    "status": "pending",
                    "message": "",
                }
            ],
        }

    def test_unexpected_worker_error_always_unlocks_queue(self):
        with queue_manager._queue_lock:
            queue_manager._queue_state = self._running_state()

        package = {
            "package_id": "gpu-1",
            "display_name": "GPU Driver",
            "category": "gpu",
            "installer_file": "setup.exe",
        }
        with (
            patch("drivers.queue_manager._query_problematic_devices", return_value=[]),
            patch("drivers.queue_manager._install_single_package", side_effect=RuntimeError("fixture crash")),
            patch("drivers.queue_manager._log_driver_event"),
            patch("drivers.queue_manager.logger.exception"),
            patch("drivers.queue_manager.time.sleep"),
        ):
            queue_manager._run_queue_thread([package])

        status = queue_manager.get_driver_queue_status()
        self.assertFalse(status["is_running"])
        self.assertFalse(status["worker_alive"])
        self.assertEqual(status["failed"], 1)
        self.assertEqual(status["items"][0]["status"], "failed")
        self.assertIn("RuntimeError", status["fatal_error"])
        self.assertIn("ادامه نصب", status["summary_message"])

    def test_status_repairs_dead_worker_instead_of_locking_ui_forever(self):
        stopped_thread = threading.Thread(target=lambda: None)
        stopped_thread.start()
        stopped_thread.join()
        state = self._running_state()
        state["start_time"] = time.time() - 10
        state["items"][0]["status"] = "installing"
        with queue_manager._queue_lock:
            queue_manager._queue_state = state
            queue_manager._queue_thread = stopped_thread

        with patch("drivers.queue_manager._log_driver_event"):
            status = queue_manager.get_driver_queue_status()

        self.assertFalse(status["is_running"])
        self.assertEqual(status["items"][0]["status"], "failed")
        self.assertEqual(status["fatal_error"], "worker_thread_stopped")

    def test_driver_log_uses_local_app_data_when_available(self):
        path = queue_manager._resolve_driver_log_file(r"C:\Users\Tech\AppData\Local")
        self.assertEqual(
            os.path.normcase(path),
            os.path.normcase(
                r"C:\Users\Tech\AppData\Local\MarkaziSystemChecker\logs\driver_manager.log"
            ),
        )


class SessionWatchdogTests(unittest.TestCase):
    def test_replacement_frontend_can_adopt_running_backend(self):
        old_parent, old_generation = session_watchdog.get_parent_session()
        old_parents = set(session_watchdog.get_parent_processes())
        try:
            with patch("session_watchdog._is_process_alive", return_value=True):
                self.assertTrue(session_watchdog.adopt_parent_process(43210))
                self.assertTrue(session_watchdog.adopt_parent_process(43211))
                parent, generation = session_watchdog.get_parent_session()
                parents = session_watchdog.get_parent_processes()
            self.assertEqual(parent, 43211)
            self.assertIn(43210, parents)
            self.assertIn(43211, parents)
            self.assertGreater(generation, old_generation)
        finally:
            with session_watchdog._state_lock:
                session_watchdog._parent_pid = old_parent
                session_watchdog._parent_pids = old_parents
                session_watchdog._parent_generation = old_generation


if __name__ == "__main__":
    unittest.main()
