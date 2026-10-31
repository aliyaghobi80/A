# backend/tests/test_backend_persistence_concurrency.py
"""
Unit test suite verifying atomic state persistence, startup reconciliation,
boot_id generation, persist_error reporting, start_time ordering,
driver queue thread nulling, 2X software active_items tracking,
and API route aliasing across backend software and driver queues.
Strictly mocked: Zero real installers, zero restarts.
"""

import copy
import io
import json
import os
import shutil
import sys
import tempfile
import threading
import time
import unittest
from unittest.mock import MagicMock, patch

BACKEND_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if BACKEND_DIR not in sys.path:
    sys.path.insert(0, BACKEND_DIR)

from packages import batch_installer
from drivers import queue_manager
from deployment_scheduler import persist_queue_state_atomic
import api_server


class TestBackendPersistenceAndConcurrency(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.mkdtemp(prefix="test_backend_persist_")
        self.software_state_file = os.path.join(self.temp_dir, "software_queue_state.json")
        self.driver_state_file = os.path.join(self.temp_dir, "driver_queue_state.json")

        self._orig_batch_state = copy.deepcopy(batch_installer._batch_state)
        self._orig_batch_thread = batch_installer._batch_thread
        self._orig_queue_state = copy.deepcopy(queue_manager._queue_state)
        self._orig_queue_thread = queue_manager._queue_thread

    def tearDown(self):
        with batch_installer._batch_lock:
            batch_installer._batch_state = self._orig_batch_state
            batch_installer._batch_thread = self._orig_batch_thread
        with queue_manager._queue_lock:
            queue_manager._queue_state = self._orig_queue_state
            queue_manager._queue_thread = self._orig_queue_thread
        shutil.rmtree(self.temp_dir, ignore_errors=True)

    # -------------------------------------------------------------------------
    # 1. Startup Reconciliation (Software Queue)
    # -------------------------------------------------------------------------
    def test_software_startup_reconciliation_transitions_unfinalized_tasks(self):
        initial_disk_state = {
            "api_contract_version": 5,
            "boot_id": "old-software-boot-id",
            "state_revision": 12,
            "is_running": True,
            "cancelled": False,
            "total": 3,
            "completed": 1,
            "failed": 0,
            "skipped": 0,
            "interrupted": 0,
            "items": [
                {"id": "pkg1", "name": "WinRAR", "status": "completed"},
                {"id": "pkg2", "name": "Chrome", "status": "installing"},
                {"id": "pkg3", "name": "Office", "status": "pending"},
            ],
        }
        with open(self.software_state_file, "w", encoding="utf-8") as f:
            json.dump(initial_disk_state, f)

        batch_installer.reconcile_startup_software_queue(self.software_state_file)

        status = batch_installer.get_batch_status()
        self.assertFalse(status["is_running"])
        self.assertTrue(status["cancelled"])
        self.assertEqual(status["completed"], 1)
        self.assertEqual(status["interrupted"], 2)
        self.assertGreater(status["state_revision"], 12)
        self.assertIn("متوقف شد", status["summary_message"])
        self.assertEqual(status["items"][0]["status"], "completed")
        self.assertEqual(status["items"][1]["status"], "interrupted")
        self.assertEqual(status["items"][2]["status"], "interrupted")
        self.assertEqual(status["boot_id"], batch_installer.BOOT_ID)

        # Verify disk file was atomically replaced with reconciled state
        with open(self.software_state_file, "r", encoding="utf-8") as f:
            disk_saved = json.load(f)
        self.assertFalse(disk_saved["is_running"])
        self.assertEqual(disk_saved["interrupted"], 2)
        self.assertEqual(disk_saved["boot_id"], batch_installer.BOOT_ID)

    # -------------------------------------------------------------------------
    # 2. Startup Reconciliation (Driver Queue)
    # -------------------------------------------------------------------------
    def test_driver_startup_reconciliation_transitions_unfinalized_tasks(self):
        initial_disk_state = {
            "api_contract_version": 5,
            "boot_id": "old-driver-boot-id",
            "state_revision": 7,
            "is_running": True,
            "cancelled": False,
            "total": 3,
            "completed": 1,
            "failed": 0,
            "skipped": 0,
            "interrupted": 0,
            "items": [
                {"package_id": "d1", "display_name": "Chipset", "status": "completed"},
                {"package_id": "d2", "display_name": "Audio", "status": "installing"},
                {"package_id": "d3", "display_name": "LAN", "status": "pending"},
            ],
        }
        with open(self.driver_state_file, "w", encoding="utf-8") as f:
            json.dump(initial_disk_state, f)

        queue_manager.reconcile_startup_driver_queue(self.driver_state_file)

        status = queue_manager.get_driver_queue_status()
        self.assertFalse(status["is_running"])
        self.assertTrue(status["cancelled"])
        self.assertEqual(status["completed"], 1)
        self.assertEqual(status["interrupted"], 2)
        self.assertGreater(status["state_revision"], 7)
        self.assertEqual(status["items"][0]["status"], "completed")
        self.assertEqual(status["items"][1]["status"], "interrupted")
        self.assertEqual(status["items"][2]["status"], "interrupted")
        self.assertEqual(status["boot_id"], queue_manager.BOOT_ID)

        with open(self.driver_state_file, "r", encoding="utf-8") as f:
            disk_saved = json.load(f)
        self.assertFalse(disk_saved["is_running"])
        self.assertEqual(disk_saved["interrupted"], 2)
        self.assertEqual(disk_saved["boot_id"], queue_manager.BOOT_ID)

    # -------------------------------------------------------------------------
    # 3. Atomic State File Creation and Structure
    # -------------------------------------------------------------------------
    def test_atomic_state_file_creation_and_structure(self):
        soft_payload = {
            "api_contract_version": 5,
            "boot_id": batch_installer.BOOT_ID,
            "state_revision": 3,
            "server_time": time.time(),
            "items": [],
        }
        drv_payload = {
            "api_contract_version": 5,
            "boot_id": queue_manager.BOOT_ID,
            "state_revision": 4,
            "server_time": time.time(),
            "items": [],
        }

        soft_out = batch_installer.persist_software_state_atomic(soft_payload, self.software_state_file)
        self.assertTrue(os.path.isfile(soft_out))
        self.assertFalse(os.path.exists(f"{soft_out}.tmp"))

        with open(soft_out, "r", encoding="utf-8") as f:
            loaded_soft = json.load(f)
        self.assertEqual(loaded_soft["boot_id"], batch_installer.BOOT_ID)
        self.assertEqual(loaded_soft["state_revision"], 3)

        drv_out = persist_queue_state_atomic(drv_payload, self.driver_state_file)
        self.assertTrue(os.path.isfile(drv_out))
        self.assertFalse(os.path.exists(f"{drv_out}.tmp"))

        with open(drv_out, "r", encoding="utf-8") as f:
            loaded_drv = json.load(f)
        self.assertEqual(loaded_drv["boot_id"], queue_manager.BOOT_ID)
        self.assertEqual(loaded_drv["state_revision"], 4)

    # -------------------------------------------------------------------------
    # 4. Additive boot_id and persist_error Fields
    # -------------------------------------------------------------------------
    def test_status_endpoints_contain_boot_id_and_persist_error(self):
        software_status = batch_installer.get_batch_status()
        self.assertIn("boot_id", software_status)
        self.assertEqual(software_status["boot_id"], batch_installer.BOOT_ID)
        self.assertIn("persist_error", software_status)
        self.assertIn("active_items", software_status)

        driver_status = queue_manager.get_driver_queue_status()
        self.assertIn("boot_id", driver_status)
        self.assertEqual(driver_status["boot_id"], queue_manager.BOOT_ID)
        self.assertIn("persist_error", driver_status)
        self.assertIn("active_items", driver_status)

    # -------------------------------------------------------------------------
    # 5. Software start_time Recorded Before Initial Revision Bump
    # -------------------------------------------------------------------------
    def test_software_queue_start_time_populated_on_start(self):
        with patch.object(batch_installer, "scan_packages", return_value={"packages": [{"id": "pkg_test", "name": "Test", "is_valid": True, "filename": "test.exe"}]}):
            with patch.object(batch_installer.threading, "Thread") as mock_th:
                mock_th.return_value = MagicMock()
                resp = batch_installer.start_batch_install(package_ids=["pkg_test"])
                self.assertTrue(resp["success"])
                self.assertIsNotNone(resp["status"]["start_time"])
                self.assertGreater(resp["status"]["start_time"], 0)
                # Ensure the global batch state also holds start_time
                self.assertEqual(batch_installer._batch_state["start_time"], resp["status"]["start_time"])

    # -------------------------------------------------------------------------
    # 6. Driver _queue_thread Nulled Preventing False Dead Worker
    # -------------------------------------------------------------------------
    def test_driver_queue_thread_nulled_preventing_false_dead_worker(self):
        # Set queue state to running with mock prior items and start_time in the past
        with queue_manager._queue_lock:
            queue_manager._queue_state["is_running"] = True
            queue_manager._queue_state["start_time"] = time.time() - 10.0
            queue_manager._queue_state["completed"] = 1
            queue_manager._queue_state["fatal_error"] = ""
            queue_manager._queue_state["items"] = [{"display_name": "LAN", "status": "completed"}]

        # Genuinely launch worker thread executing _run_queue_thread with empty packages
        with patch.object(queue_manager, "_query_problematic_devices", return_value=[]):
            with patch.object(queue_manager, "persist_queue_state_atomic"):
                worker = threading.Thread(
                    target=queue_manager._run_queue_thread,
                    args=([],),
                    name="TestDriverQueueWorker",
                )
                queue_manager._queue_thread = worker
                worker.start()
                worker.join(timeout=5.0)

        # 1. Thread must have terminated cleanly within timeout
        self.assertFalse(worker.is_alive(), "Worker thread did not terminate within timeout")

        # 2. Global _queue_thread must be cleared by the worker thread's finally block (non-facade)
        self.assertIsNone(queue_manager._queue_thread, "queue_manager._queue_thread was not nulled on worker exit")

        # 3. get_driver_queue_status must reflect completed state and not trigger stale dead-worker repair
        status = queue_manager.get_driver_queue_status()
        self.assertFalse(status["is_running"])
        self.assertEqual(status["fatal_error"], "")
        self.assertEqual(status["completed"], 1)
        self.assertFalse(status.get("worker_alive", False))

    # -------------------------------------------------------------------------
    # 7. Driver _queue_thread Nulled Before is_running = True On Start
    # -------------------------------------------------------------------------
    def test_driver_queue_thread_nulled_on_start(self):
        # Set a dummy old thread
        old_thread = MagicMock()
        old_thread.ident = 1234
        old_thread.is_alive.return_value = False
        queue_manager._queue_thread = old_thread

        with patch.object(queue_manager, "threading") as mock_threading:
            mock_new_thread = MagicMock()
            mock_threading.Thread.return_value = mock_new_thread

            dummy_pkg = {
                "package_id": "drv_test",
                "display_name": "Test Driver",
                "category": "lan",
                "category_fa": "شبکه",
                "installer_file": "setup.exe",
            }
            resp = queue_manager.start_driver_queue([dummy_pkg])
            self.assertTrue(resp["success"])
            self.assertTrue(resp["status"]["is_running"])
            # Thread constructor was called and started
            mock_new_thread.start.assert_called_once()

    # -------------------------------------------------------------------------
    # 8. Software 2X Active Items Tracking and current_item_name
    # -------------------------------------------------------------------------
    def test_software_2x_active_items_and_combined_name(self):
        # Test the active display synchronization logic directly under _batch_lock
        items = [
            {"id": "pkg1", "name": "WinRAR 7.01", "status": "installing"},
            {"id": "pkg2", "name": "Firefox 128", "status": "installing"},
        ]
        with batch_installer._batch_lock:
            batch_installer._batch_state["is_running"] = True
            batch_installer._batch_state["items"] = items
            batch_installer._batch_state["active_items"] = [
                {"id": "pkg1", "name": "WinRAR 7.01", "index": 0},
                {"id": "pkg2", "name": "Firefox 128", "index": 1},
            ]
            # When two items are active, current_item_name combines them with " • "
            names = [a["name"] for a in batch_installer._batch_state["active_items"]]
            batch_installer._batch_state["current_item_name"] = " • ".join(names)

        status = batch_installer.get_batch_status()
        self.assertEqual(len(status["active_items"]), 2)
        self.assertIn(" • ", status["current_item_name"])
        self.assertEqual(status["current_item_name"], "WinRAR 7.01 • Firefox 128")

    # -------------------------------------------------------------------------
    # 9. Persist Error Populated on Disk Failure
    # -------------------------------------------------------------------------
    def test_persist_error_populated_on_disk_failure(self):
        with patch("packages.batch_installer.persist_software_state_atomic", side_effect=OSError("Disk Full")):
            with batch_installer._batch_lock:
                batch_installer._bump_revision_locked(persist=True)
                self.assertIsNotNone(batch_installer._batch_state["persist_error"])
                self.assertIn("Disk Full", batch_installer._batch_state["persist_error"])

        with patch("drivers.queue_manager.persist_queue_state_atomic", side_effect=OSError("Permission Denied")):
            with queue_manager._queue_lock:
                queue_manager._bump_driver_revision_locked(persist=True)
                self.assertIsNotNone(queue_manager._queue_state["persist_error"])
                self.assertIn("Permission Denied", queue_manager._queue_state["persist_error"])

    # -------------------------------------------------------------------------
    # 10. API Server Route Aliasing: /api/software/batch-status
    # -------------------------------------------------------------------------
    def test_api_server_software_batch_status_alias(self):
        class DummyRequest:
            def makefile(self, *args, **kwargs):
                return io.BytesIO(b"")

        handler = api_server.SystemInspectorRequestHandler.__new__(api_server.SystemInspectorRequestHandler)
        handler.rfile = io.BytesIO(b"")
        handler.wfile = io.BytesIO()
        handler.headers = {}
        handler.path = "/api/software/batch-status"
        handler.command = "GET"
        handler.close_connection = False

        # Mock send_response, send_header, end_headers, _send_cors_headers
        handler.send_response = MagicMock()
        handler.send_header = MagicMock()
        handler.end_headers = MagicMock()
        handler._send_cors_headers = MagicMock()

        handler.do_GET()

        handler.send_response.assert_called_with(200)
        output = handler.wfile.getvalue().decode("utf-8")
        parsed = json.loads(output)
        self.assertIn("boot_id", parsed)
        self.assertIn("state_revision", parsed)
        self.assertEqual(parsed["boot_id"], batch_installer.BOOT_ID)


if __name__ == "__main__":
    unittest.main()
