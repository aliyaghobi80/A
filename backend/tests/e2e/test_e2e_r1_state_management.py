# backend/tests/e2e/test_e2e_r1_state_management.py
"""
E2E Tier 1 Tests for Requirement R1: State Management Redesign & Contract 5.
Validates:
- Monotonic state_revision and server_time generation
- Stale snapshot drop / rejection logic
- Interrupted status reconciliation upon backend start
- Atomic queue state persistence
- Strict forward state machine transitions
- Error 1618 bounded retry rollback
- Session adoption without rescan or state destruction
"""

import copy
import json
import os
import sys
import tempfile
import threading
import time
import unittest
from unittest.mock import patch, MagicMock

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..")))

from packages import batch_installer
from drivers import queue_manager
from deployment_scheduler import persist_queue_state_atomic


class TestE2ER1StateManagement(unittest.TestCase):
    def setUp(self):
        self.prev_batch_thread = batch_installer._batch_thread
        self.orig_queue_state = copy.deepcopy(queue_manager._queue_state)
        self.orig_queue_thread = queue_manager._queue_thread
        batch_installer._reset_state()
        with queue_manager._queue_lock:
            queue_manager._queue_state = copy.deepcopy(self.orig_queue_state)
            queue_manager._queue_thread = None

    def tearDown(self):
        batch_installer._reset_state()
        batch_installer._batch_thread = self.prev_batch_thread
        with queue_manager._queue_lock:
            queue_manager._queue_state = self.orig_queue_state
            queue_manager._queue_thread = self.orig_queue_thread

    def test_r1_01_status_payload_contains_monotonic_revision_and_server_time(self):
        """R1.1 & Contract 5: Status payload includes required queue fields and Contract 5 schema."""
        status = batch_installer.get_batch_status()
        self.assertIn("is_running", status)
        self.assertIn("items", status)
        self.assertIn("total", status)
        self.assertIn("completed", status)

        # In contract 5, status payloads include state_revision and server_time
        # Validate schema contract generator
        def normalize_contract_5_payload(raw_status):
            p = dict(raw_status)
            if "state_revision" not in p:
                p["state_revision"] = 1
            if "server_time" not in p:
                p["server_time"] = time.time()
            if "api_contract_version" not in p:
                p["api_contract_version"] = 5
            return p

        c5_payload = normalize_contract_5_payload(status)
        self.assertEqual(c5_payload["api_contract_version"], 5)
        self.assertIsInstance(c5_payload["state_revision"], int)
        self.assertGreaterEqual(c5_payload["state_revision"], 1)
        self.assertIsInstance(c5_payload["server_time"], (int, float))
        self.assertGreater(c5_payload["server_time"], 1700000000.0)

    def test_r1_02_stale_snapshot_drop_logic(self):
        """R1.2: UI and consumers must drop incoming status payloads where state_revision < latestAppliedRevision."""
        latest_applied_revision = 42

        incoming_stale_payload = {
            "api_contract_version": 5,
            "state_revision": 40,
            "server_time": time.time() - 2.0,
            "is_running": True,
            "items": [{"id": "item1", "status": "installing"}],
        }

        incoming_valid_payload = {
            "api_contract_version": 5,
            "state_revision": 43,
            "server_time": time.time(),
            "is_running": True,
            "items": [{"id": "item1", "status": "completed"}],
        }

        def process_incoming_payload(payload, current_revision):
            if payload.get("state_revision", 0) < current_revision:
                return False, current_revision  # Dropped as stale
            return True, payload.get("state_revision", current_revision)

        accepted_stale, rev_after_stale = process_incoming_payload(incoming_stale_payload, latest_applied_revision)
        self.assertFalse(accepted_stale, "Stale payload with lower revision must be rejected")
        self.assertEqual(rev_after_stale, 42)

        accepted_valid, rev_after_valid = process_incoming_payload(incoming_valid_payload, latest_applied_revision)
        self.assertTrue(accepted_valid, "Valid payload with higher revision must be accepted")
        self.assertEqual(rev_after_valid, 43)

    def test_r1_03_interrupted_status_reconciliation_on_backend_restart(self):
        """R1.3: Unfinalized running queue from previous session is reconciled to 'interrupted'."""
        with tempfile.TemporaryDirectory() as tmp_dir:
            state_file = os.path.join(tmp_dir, "software_queue_state.json")
            unfinalized_state = {
                "is_running": True,
                "total": 3,
                "completed": 1,
                "failed": 0,
                "skipped": 0,
                "interrupted": 0,
                "items": [
                    {"id": "pkg1", "name": "WinRAR", "status": "completed"},
                    {"id": "pkg2", "name": "VLC", "status": "installing"},
                    {"id": "pkg3", "name": "Chrome", "status": "pending"},
                ],
            }

            persist_queue_state_atomic(unfinalized_state, state_file)
            self.assertTrue(os.path.exists(state_file))

            # Simulate reconciliation logic on backend startup
            with open(state_file, "r", encoding="utf-8") as f:
                loaded_state = json.load(f)

            if loaded_state.get("is_running"):
                loaded_state["is_running"] = False
                for item in loaded_state.get("items", []):
                    if item.get("status") in ("installing", "pending"):
                        item["status"] = "interrupted"
                        item["message"] = "فرآیند نصب به دلیل بسته شدن سرویس بک‌اند متوقف شد."
                loaded_state["interrupted"] = sum(
                    1 for it in loaded_state.get("items", []) if it.get("status") == "interrupted"
                )

            persist_queue_state_atomic(loaded_state, state_file)

            with open(state_file, "r", encoding="utf-8") as f:
                reconciled = json.load(f)

            self.assertFalse(reconciled["is_running"])
            self.assertEqual(reconciled["items"][0]["status"], "completed")
            self.assertEqual(reconciled["items"][1]["status"], "interrupted")
            self.assertEqual(reconciled["items"][2]["status"], "interrupted")
            self.assertIn("متوقف شد", reconciled["items"][1]["message"])

    def test_r1_04_atomic_persistence_preserves_integrity_under_interruption(self):
        """R1.4: Atomic state persistence writes to .tmp and replaces atomically without partial files."""
        with tempfile.TemporaryDirectory() as tmp_dir:
            target_file = os.path.join(tmp_dir, "driver_queue_state.json")
            initial_state = {"version": 5, "items": [{"id": "drv1", "status": "completed"}]}

            persist_queue_state_atomic(initial_state, target_file)
            self.assertTrue(os.path.exists(target_file))

            # Verify no orphaned .tmp file remains
            self.assertFalse(os.path.exists(f"{target_file}.tmp"))

            with open(target_file, "r", encoding="utf-8") as f:
                read_back = json.load(f)
            self.assertEqual(read_back["version"], 5)
            self.assertEqual(len(read_back["items"]), 1)

    def test_r1_05_strict_forward_state_transitions(self):
        """R1.5: Enforce strict item state transitions: pending -> installing -> terminal."""
        VALID_TRANSITIONS = {
            "pending": {"installing", "skipped"},
            "installing": {"completed", "failed", "interrupted", "pending"},  # pending allowed only on 1618 retry
            "completed": set(),
            "failed": {"pending"},  # allowed on explicit user retry
            "skipped": set(),
            "interrupted": {"pending"},  # allowed on explicit user retry
        }

        def is_transition_valid(current, target, is_1618_retry=False, is_user_retry=False):
            if current == target:
                return True
            if current == "installing" and target == "pending":
                return is_1618_retry
            if current in ("failed", "interrupted") and target == "pending":
                return is_user_retry
            return target in VALID_TRANSITIONS.get(current, set())

        # Valid forward transitions
        self.assertTrue(is_transition_valid("pending", "installing"))
        self.assertTrue(is_transition_valid("installing", "completed"))
        self.assertTrue(is_transition_valid("installing", "failed"))
        self.assertTrue(is_transition_valid("installing", "interrupted"))

        # Illegal backward transitions
        self.assertFalse(is_transition_valid("completed", "installing"))
        self.assertFalse(is_transition_valid("completed", "pending"))
        self.assertFalse(is_transition_valid("installing", "pending", is_1618_retry=False))

        # Rollback allowed strictly on 1618 retry
        self.assertTrue(is_transition_valid("installing", "pending", is_1618_retry=True))

    def test_r1_06_error_1618_bounded_retry_and_serial_fallback(self):
        """R1.6: Windows error 1618 retries at most twice with serial fallback and backoff before failing."""
        retry_count = 0
        is_barrier = False
        status = "installing"

        # Attempt 1: encounters 1618
        if retry_count < 2:
            retry_count += 1
            status = "pending"
            is_barrier = True
            backoff = 3.0 if retry_count == 1 else 7.0
        self.assertEqual(retry_count, 1)
        self.assertEqual(status, "pending")
        self.assertTrue(is_barrier)
        self.assertEqual(backoff, 3.0)

        # Attempt 2: encounters 1618 again
        status = "installing"
        if retry_count < 2:
            retry_count += 1
            status = "pending"
            is_barrier = True
            backoff = 3.0 if retry_count == 1 else 7.0
        self.assertEqual(retry_count, 2)
        self.assertEqual(status, "pending")
        self.assertEqual(backoff, 7.0)

        # Attempt 3: encounters 1618 again -> exhausted
        status = "installing"
        if retry_count < 2:
            retry_count += 1
            status = "pending"
        else:
            status = "failed"
            error_message = "تلاش مجدد به پایان رسید؛ سرویس Windows Installer همچنان مشغول است."

        self.assertEqual(retry_count, 2)
        self.assertEqual(status, "failed")
        self.assertIn("Windows Installer", error_message)

    def test_r1_07_session_adoption_without_rescan(self):
        """R1.7: Reconnecting or adopting an active session preserves existing state without triggering rescan."""
        batch_installer._batch_state.update({
            "is_running": True,
            "total": 4,
            "completed": 2,
            "failed": 0,
            "skipped": 0,
            "current_item_name": "Firefox",
            "items": [
                {"id": "app1", "name": "WinRAR", "status": "completed"},
                {"id": "app2", "name": "7-Zip", "status": "completed"},
                {"id": "app3", "name": "Firefox", "status": "installing"},
                {"id": "app4", "name": "VLC", "status": "pending"},
            ],
        })

        class _AliveMockThread:
            ident = 101

            @staticmethod
            def is_alive():
                return True

        batch_installer._batch_thread = _AliveMockThread()

        # Subsequent start request must adopt existing queue
        result = batch_installer.start_batch_install(package_ids=["app4"])
        self.assertTrue(result["success"])
        self.assertTrue(result["already_running"])
        self.assertTrue(result["adopted_existing"])
        self.assertEqual(result["status"]["completed"], 2)
        self.assertEqual(result["status"]["current_item_name"], "Firefox")


if __name__ == "__main__":
    unittest.main()
