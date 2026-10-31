# backend/tests/test_challenger_backend_harden.py
"""
Empirical Challenger Adversarial Hardening Suite.

Rigorous stress-testing of backend concurrency, mutex invariants,
Error 1618 retry caps, 2X active_items synchronization, corrupted JSON,
read-only permission crashes, startup reconciliation, and thread lifecycle.

Strictly mocked: Zero real installers, zero restarts, isolated temp directories.
"""

import copy
import io
import json
import logging
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
from deployment_scheduler import (
    DeploymentWorkerPool,
    windows_installer_busy,
    wait_for_windows_installer_idle,
    persist_queue_state_atomic,
)
import api_server


class TestAdversarialConcurrencyAndMutex(unittest.TestCase):
    """Stress-test Global\\_MSIExecute mutex simulation and Error 1618 retry limits."""

    def test_windows_installer_idle_wait_and_timeout(self):
        """Verify wait_for_windows_installer_idle respects timeout and on_wait callback."""
        # 1. Mutex busy then clears
        call_count = [0]
        def fake_busy():
            call_count[0] += 1
            return call_count[0] <= 3

        waited = [False]
        def on_wait():
            waited[0] = True

        with patch("deployment_scheduler.windows_installer_busy", side_effect=fake_busy):
            res = wait_for_windows_installer_idle(timeout_seconds=5.0, poll_seconds=0.01, on_wait=on_wait)
            self.assertTrue(res)
            self.assertTrue(waited[0])
            self.assertGreaterEqual(call_count[0], 3)

        # 2. Mutex stays busy until timeout
        with patch("deployment_scheduler.windows_installer_busy", return_value=True):
            t0 = time.monotonic()
            res = wait_for_windows_installer_idle(timeout_seconds=0.1, poll_seconds=0.02)
            t1 = time.monotonic()
            self.assertFalse(res)
            self.assertGreaterEqual(t1 - t0, 0.08)

    def test_scheduler_pool_1618_retry_capped_at_2(self):
        """Verify handle_1618_retry caps at 2 retries (total 3 attempts) and falls back to serial barrier."""
        items = [
            {"package_id": "pkg1", "display_name": "Audio", "status": "installing", "category": "audio"}
        ]
        pool = DeploymentWorkerPool(items, run_one=lambda idx, item: None, double_speed=True)

        with patch("deployment_scheduler.time.sleep", return_value=None), \
             patch("deployment_scheduler.wait_for_windows_installer_idle", return_value=True):

            # Attempt 1 -> 1618 encounters first failure -> retry 1
            retry_1 = pool.handle_1618_retry(0, items[0])
            self.assertTrue(retry_1)
            self.assertEqual(pool.retry_counts[0], 1)
            self.assertEqual(items[0]["retry_count"], 1)
            self.assertEqual(items[0]["status"], "pending")
            self.assertTrue(items[0]["is_barrier"])
            self.assertFalse(items[0]["is_parallel_safe"])
            self.assertIn("تلاش مجدد 1 از ۲", items[0]["message"])
            self.assertNotIn(0, pool.claimed_indices)

            # Attempt 2 -> 1618 encounters second failure -> retry 2
            retry_2 = pool.handle_1618_retry(0, items[0])
            self.assertTrue(retry_2)
            self.assertEqual(pool.retry_counts[0], 2)
            self.assertEqual(items[0]["retry_count"], 2)
            self.assertEqual(items[0]["status"], "pending")
            self.assertTrue(items[0]["is_barrier"])
            self.assertIn("تلاش مجدد 2 از ۲", items[0]["message"])

            # Attempt 3 -> 1618 encounters third failure -> EXHAUSTED (max 2 retries reached)
            retry_3 = pool.handle_1618_retry(0, items[0])
            self.assertFalse(retry_3)
            self.assertEqual(items[0]["status"], "failed")
            self.assertEqual(items[0]["exit_code"], 1618)
            self.assertIn("بیش از ۲ بار تلاش", items[0]["failure_reason"])
            self.assertIn(0, pool.failed_indices)
            self.assertNotIn(0, pool.completed_indices)

            # Attempt 4 -> calling again still returns False
            retry_4 = pool.handle_1618_retry(0, items[0])
            self.assertFalse(retry_4)
            self.assertIn(0, pool.failed_indices)

    def test_software_batch_1618_exhaustion_terminates_after_3_attempts(self):
        """Verify software queue retry loop executes exactly 3 attempts on 1618 before failing."""
        orig_state = copy.deepcopy(batch_installer._batch_state)
        attempts = [0]

        def fake_silent_install(pkg, custom_dir=None, timeout_seconds=None):
            attempts[0] += 1
            return {"success": False, "exit_code": 1618, "message": "Installer busy"}

        try:
            with patch("packages.batch_installer.silent_install_package", side_effect=fake_silent_install), \
                 patch("packages.batch_installer.wait_for_windows_installer_idle", return_value=True), \
                 patch("deployment_scheduler.wait_for_windows_installer_idle", return_value=True), \
                 patch("packages.batch_installer.time.sleep", return_value=None), \
                 patch("packages.batch_installer.persist_software_state_atomic", return_value="dummy"):

                items_to_run = [{"id": "pkg_busy", "name": "BusyApp", "filename": "setup.exe"}]
                with batch_installer._batch_lock:
                    batch_installer._batch_state["is_running"] = True
                    batch_installer._batch_state["cancelled"] = False
                    batch_installer._batch_state["total"] = 1
                    batch_installer._batch_state["completed"] = 0
                    batch_installer._batch_state["failed"] = 0
                    batch_installer._batch_state["skipped"] = 0
                    batch_installer._batch_state["items"] = [{"id": "pkg_busy", "name": "BusyApp", "status": "pending"}]

                batch_installer._run_batch_install_impl(items_to_run, None)

                # Exactly 3 attempts: initial attempt + 2 retries
                self.assertEqual(attempts[0], 3)
                status = batch_installer.get_batch_status()
                self.assertEqual(status["failed"], 1)
                self.assertEqual(status["completed"], 0)
                self.assertEqual(status["items"][0]["status"], "failed")
                self.assertEqual(status["items"][0]["exit_code"], 1618)
                self.assertIn("بیش از ۲ بار تلاش", status["items"][0]["message"])
        finally:
            with batch_installer._batch_lock:
                batch_installer._batch_state = orig_state

    def test_software_batch_1618_success_on_second_retry(self):
        """Verify software queue recovers when 1618 resolves on attempt 2."""
        orig_state = copy.deepcopy(batch_installer._batch_state)
        attempts = [0]

        def fake_silent_install(pkg, custom_dir=None, timeout_seconds=None):
            attempts[0] += 1
            if attempts[0] == 1:
                return {"success": False, "exit_code": 1618, "message": "Installer busy"}
            return {"success": True, "exit_code": 0, "message": "Installed successfully"}

        try:
            with patch("packages.batch_installer.silent_install_package", side_effect=fake_silent_install), \
                 patch("packages.batch_installer.wait_for_windows_installer_idle", return_value=True), \
                 patch("deployment_scheduler.wait_for_windows_installer_idle", return_value=True), \
                 patch("packages.batch_installer.time.sleep", return_value=None), \
                 patch("packages.batch_installer.persist_software_state_atomic", return_value="dummy"):

                items_to_run = [{"id": "pkg_busy2", "name": "RecoverApp", "filename": "setup.exe"}]
                with batch_installer._batch_lock:
                    batch_installer._batch_state["is_running"] = True
                    batch_installer._batch_state["cancelled"] = False
                    batch_installer._batch_state["total"] = 1
                    batch_installer._batch_state["completed"] = 0
                    batch_installer._batch_state["failed"] = 0
                    batch_installer._batch_state["skipped"] = 0
                    batch_installer._batch_state["items"] = [{"id": "pkg_busy2", "name": "RecoverApp", "status": "pending"}]

                batch_installer._run_batch_install_impl(items_to_run, None)

                self.assertEqual(attempts[0], 2)
                status = batch_installer.get_batch_status()
                self.assertEqual(status["completed"], 1)
                self.assertEqual(status["failed"], 0)
                self.assertEqual(status["items"][0]["status"], "completed")
                self.assertEqual(status["items"][0]["exit_code"], 0)
        finally:
            with batch_installer._batch_lock:
                batch_installer._batch_state = orig_state


class TestConcurrentActiveWorkersStress(unittest.TestCase):
    """Stress-test 2X active_items dictionary synchronization under heavy thread contention."""

    def test_concurrent_active_items_no_key_error_or_race(self):
        """Simulate high concurrency with multiple worker threads updating active_items simultaneously."""
        orig_state = copy.deepcopy(batch_installer._batch_state)
        stop_event = threading.Event()
        errors = []

        try:
            with batch_installer._batch_lock:
                batch_installer._batch_state["is_running"] = True
                batch_installer._batch_state["active_items"] = []
                batch_installer._batch_state["items"] = [
                    {"id": f"pkg_{i}", "name": f"App_{i}", "status": "pending"}
                    for i in range(10)
                ]

            def worker_simulation(worker_id: int):
                for loop in range(50):
                    if stop_event.is_set():
                        break
                    # Add item
                    with batch_installer._batch_lock:
                        try:
                            current = list(batch_installer._batch_state.get("active_items") or [])
                            current = [item for item in current if item.get("id") != f"pkg_{worker_id}"]
                            current.append({
                                "id": f"pkg_{worker_id}",
                                "name": f"App_{worker_id}",
                                "index": worker_id,
                                "status": "installing",
                                "start_time": time.time(),
                            })
                            batch_installer._batch_state["active_items"] = current
                            if len(current) == 1:
                                batch_installer._batch_state["current_item_name"] = current[0]["name"]
                            elif len(current) >= 2:
                                names = [str(a["name"]) for a in current[:2]]
                                batch_installer._batch_state["current_item_name"] = " • ".join(names)
                        except Exception as exc:
                            errors.append(f"Worker {worker_id} add error: {exc}")

                    time.sleep(0.001)

                    # Remove item
                    with batch_installer._batch_lock:
                        try:
                            current = list(batch_installer._batch_state.get("active_items") or [])
                            current = [item for item in current if item.get("id") != f"pkg_{worker_id}"]
                            batch_installer._batch_state["active_items"] = current
                            if not current:
                                if not batch_installer._batch_state.get("is_running"):
                                    batch_installer._batch_state["current_item_name"] = None
                            elif len(current) == 1:
                                batch_installer._batch_state["current_item_name"] = current[0]["name"]
                            else:
                                names = [str(a["name"]) for a in current[:2]]
                                batch_installer._batch_state["current_item_name"] = " • ".join(names)
                        except Exception as exc:
                            errors.append(f"Worker {worker_id} remove error: {exc}")

                    time.sleep(0.001)

            def status_reader_simulation():
                while not stop_event.is_set():
                    try:
                        st = batch_installer.get_batch_status()
                        self.assertIsInstance(st["active_items"], list)
                        if len(st["active_items"]) >= 2:
                            self.assertIn(" • ", st["current_item_name"])
                        elif len(st["active_items"]) == 1:
                            self.assertNotIn(" • ", st["current_item_name"])
                    except Exception as exc:
                        errors.append(f"Reader error: {exc}")
                    time.sleep(0.0005)

            # Launch 6 concurrent workers and 4 concurrent status readers
            threads = []
            for w in range(6):
                t = threading.Thread(target=worker_simulation, args=(w,), daemon=True)
                threads.append(t)
            for r in range(4):
                t = threading.Thread(target=status_reader_simulation, daemon=True)
                threads.append(t)

            for t in threads:
                t.start()

            time.sleep(0.3)
            stop_event.set()

            for t in threads:
                t.join(timeout=2.0)

            self.assertEqual(errors, [], f"Encountered concurrency errors: {errors}")
        finally:
            with batch_installer._batch_lock:
                batch_installer._batch_state = orig_state


class TestPersistenceAndReconciliationHardening(unittest.TestCase):
    """Stress-test corrupt JSON, read-only permissions, and crash state files."""

    def setUp(self):
        self.temp_dir = tempfile.mkdtemp(prefix="test_challenger_persist_")
        self.software_file = os.path.join(self.temp_dir, "software_state.json")
        self.driver_file = os.path.join(self.temp_dir, "driver_state.json")
        self._orig_batch_state = copy.deepcopy(batch_installer._batch_state)
        self._orig_queue_state = copy.deepcopy(queue_manager._queue_state)

    def tearDown(self):
        with batch_installer._batch_lock:
            batch_installer._batch_state = self._orig_batch_state
        with queue_manager._queue_lock:
            queue_manager._queue_state = self._orig_queue_state
        shutil.rmtree(self.temp_dir, ignore_errors=True)

    def test_corrupted_json_software_reconciliation(self):
        """Verify startup reconciliation survives corrupted/malformed JSON without crashing."""
        corrupted_payloads = [
            "",                                # Empty file
            "{",                               # Incomplete JSON
            '{"is_running": true, "items": [', # Truncated array
            "\x00\xff\xfe\xca\xfe",            # Binary garbage
        ]

        for payload in corrupted_payloads:
            with open(self.software_file, "w", encoding="utf-8", errors="ignore") as f:
                f.write(payload)

            with self.assertLogs("packages.batch_installer", level="WARNING") as cm:
                batch_installer.reconcile_startup_software_queue(self.software_file)

            # Must log warning and record persist_error without crashing
            status = batch_installer.get_batch_status()
            self.assertIsNotNone(status["boot_id"])
            self.assertEqual(status["boot_id"], batch_installer.BOOT_ID)
            self.assertIsNotNone(status["persist_error"])
            self.assertIn("Reconciliation failed", status["persist_error"])

        # Non-dict JSON ([1, 2, 3]) returns gracefully
        with open(self.software_file, "w", encoding="utf-8") as f:
            f.write("[1, 2, 3]")
        batch_installer.reconcile_startup_software_queue(self.software_file)
        status = batch_installer.get_batch_status()
        self.assertEqual(status["boot_id"], batch_installer.BOOT_ID)

    def test_corrupted_json_driver_reconciliation(self):
        """Verify driver startup reconciliation survives corrupted/malformed JSON without crashing."""
        corrupted_payloads = [
            "",
            "{malformed json",
            '{"is_running": true, "items": [{"status": "installing"',
            "\x00\x01\x02\x03\x04",
        ]

        for payload in corrupted_payloads:
            with open(self.driver_file, "w", encoding="utf-8", errors="ignore") as f:
                f.write(payload)

            with self.assertLogs("drivers.queue_manager", level="WARNING") as cm:
                queue_manager.reconcile_startup_driver_queue(self.driver_file)

            status = queue_manager.get_driver_queue_status()
            self.assertIsNotNone(status["boot_id"])
            self.assertEqual(status["boot_id"], queue_manager.BOOT_ID)
            self.assertIsNotNone(status["persist_error"])
            self.assertIn("Reconciliation failed", status["persist_error"])

        # Non-dict JSON returns gracefully
        with open(self.driver_file, "w", encoding="utf-8") as f:
            f.write("null")
        queue_manager.reconcile_startup_driver_queue(self.driver_file)
        status = queue_manager.get_driver_queue_status()
        self.assertEqual(status["boot_id"], queue_manager.BOOT_ID)

    def test_read_only_disk_write_failure_captured_in_status(self):
        """Verify read-only or permission failures log warnings and report persist_error."""
        # Software queue disk failure
        with patch("packages.batch_installer.persist_software_state_atomic", side_effect=PermissionError("Access Denied")):
            with self.assertLogs("packages.batch_installer", level="WARNING") as cm:
                with batch_installer._batch_lock:
                    batch_installer._bump_revision_locked(persist=True)

            status = batch_installer.get_batch_status()
            self.assertIn("Access Denied", str(status.get("persist_error")))
            self.assertIn("Failed to persist state", cm.output[0])

        # Driver queue disk failure
        with patch("drivers.queue_manager.persist_queue_state_atomic", side_effect=PermissionError("Write Protected")):
            with self.assertLogs("drivers.queue_manager", level="WARNING") as cm:
                with queue_manager._queue_lock:
                    queue_manager._bump_driver_revision_locked(persist=True)

            status = queue_manager.get_driver_queue_status()
            self.assertIn("Write Protected", str(status.get("persist_error")))
            self.assertIn("Failed to persist driver queue state", cm.output[0])

    def test_sudden_crash_reconciliation_transitions_unfinalized_strictly_to_interrupted(self):
        """Verify unfinalized items in installing, queued, and pending transition strictly to interrupted."""
        crash_data = {
            "api_contract_version": 5,
            "boot_id": "crashed-boot-uuid",
            "state_revision": 20,
            "is_running": True,
            "cancelled": False,
            "total": 6,
            "completed": 2,
            "failed": 1,
            "skipped": 0,
            "interrupted": 0,
            "items": [
                {"id": "p1", "name": "Finished1", "status": "completed"},
                {"id": "p2", "name": "Finished2", "status": "completed"},
                {"id": "p3", "name": "Broken", "status": "failed"},
                {"id": "p4", "name": "Active", "status": "installing"},
                {"id": "p5", "name": "InQueue", "status": "queued"},
                {"id": "p6", "name": "Waiting", "status": "pending"},
            ],
        }

        with open(self.software_file, "w", encoding="utf-8") as f:
            json.dump(crash_data, f)

        batch_installer.reconcile_startup_software_queue(self.software_file)

        status = batch_installer.get_batch_status()
        self.assertFalse(status["is_running"])
        self.assertTrue(status["cancelled"])
        self.assertEqual(status["completed"], 2)
        self.assertEqual(status["failed"], 1)
        self.assertEqual(status["interrupted"], 3)  # p4, p5, p6
        self.assertEqual(status["items"][0]["status"], "completed")
        self.assertEqual(status["items"][1]["status"], "completed")
        self.assertEqual(status["items"][2]["status"], "failed")
        self.assertEqual(status["items"][3]["status"], "interrupted")
        self.assertEqual(status["items"][4]["status"], "interrupted")
        self.assertEqual(status["items"][5]["status"], "interrupted")
        self.assertEqual(status["boot_id"], batch_installer.BOOT_ID)
        self.assertNotEqual(status["boot_id"], "crashed-boot-uuid")


class TestDriverThreadLifecycleHardening(unittest.TestCase):
    """Stress-test driver queue thread nulling under lock to prevent false dead-worker repairs."""

    def setUp(self):
        self._orig_queue_state = copy.deepcopy(queue_manager._queue_state)
        self._orig_queue_thread = queue_manager._queue_thread

    def tearDown(self):
        with queue_manager._queue_lock:
            queue_manager._queue_state = self._orig_queue_state
            queue_manager._queue_thread = self._orig_queue_thread

    def test_null_thread_after_completion_prevents_false_dead_worker_repair(self):
        """Ensure that when a previous queue completed, get_driver_queue_status never falsely repairs it."""
        with queue_manager._queue_lock:
            queue_manager._queue_thread = None
            queue_manager._queue_state["is_running"] = False
            queue_manager._queue_state["start_time"] = time.time() - 3600.0  # 1 hour ago
            queue_manager._queue_state["fatal_error"] = ""
            queue_manager._queue_state["completed"] = 3
            queue_manager._queue_state["items"] = [{"display_name": f"D_{i}", "status": "completed"} for i in range(3)]

        for _ in range(50):
            st = queue_manager.get_driver_queue_status()
            self.assertFalse(st["is_running"])
            self.assertEqual(st["fatal_error"], "")
            self.assertEqual(st["completed"], 3)

    def test_rapid_status_polling_during_queue_start_no_dead_worker_remediation(self):
        """Simulate rapid status polling at high frequency while start_driver_queue initializes."""
        dummy_pkg = {
            "package_id": "drv_rapid",
            "display_name": "Rapid Driver",
            "category": "lan",
            "category_fa": "شبکه",
            "installer_file": "setup.exe",
        }

        # Mock thread to start cleanly
        with patch.object(queue_manager, "_run_queue_thread", return_value=None):
            with queue_manager._queue_lock:
                queue_manager._queue_thread = None
                queue_manager._queue_state["is_running"] = False
                queue_manager._queue_state["start_time"] = time.time() - 500.0

            res = queue_manager.start_driver_queue([dummy_pkg])
            self.assertTrue(res["success"])

            # Immediately poll 50 times in rapid loop
            for _ in range(50):
                st = queue_manager.get_driver_queue_status()
                # Must NEVER be falsely marked as stopped or fatal
                self.assertNotEqual(st["fatal_error"], "worker_thread_stopped")

    def test_genuine_dead_worker_is_detected_and_repaired(self):
        """Ensure that an actual dead worker (ident not None, is_alive=False, > 1.0s elapsed) is repaired."""
        dead_thread = MagicMock()
        dead_thread.ident = 99999
        dead_thread.is_alive.return_value = False

        with queue_manager._queue_lock:
            queue_manager._queue_thread = dead_thread
            queue_manager._queue_state["is_running"] = True
            queue_manager._queue_state["start_time"] = time.time() - 2.0  # 2 seconds ago (> 1.0s)
            queue_manager._queue_state["items"] = [
                {"package_id": "drv_dead", "display_name": "Dead Driver", "status": "installing"}
            ]

        st = queue_manager.get_driver_queue_status()
        self.assertFalse(st["is_running"])
        self.assertEqual(st["fatal_error"], "worker_thread_stopped")
        self.assertEqual(st["items"][0]["status"], "failed")
        self.assertEqual(st["items"][0]["exit_code"], -5)
        self.assertIn("پردازش صف درایورها متوقف شد", st["summary_message"])


if __name__ == "__main__":
    unittest.main()
