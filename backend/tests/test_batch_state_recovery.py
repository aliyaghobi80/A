import os
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from packages import batch_installer


class _AliveThread:
    ident = 101

    @staticmethod
    def is_alive():
        return True


class _DeadThread:
    ident = 202

    @staticmethod
    def is_alive():
        return False


class TestSoftwareBatchStateRecovery(unittest.TestCase):
    def setUp(self):
        self.previous_thread = batch_installer._batch_thread
        batch_installer._reset_state()

    def tearDown(self):
        batch_installer._reset_state()
        batch_installer._batch_thread = self.previous_thread

    def _seed_running_queue(self):
        batch_installer._batch_state.update(
            {
                "is_running": True,
                "total": 2,
                "completed": 0,
                "failed": 0,
                "skipped": 0,
                "current_item_name": "App A",
                "items": [
                    {"id": "app-a", "name": "App A", "status": "installing"},
                    {"id": "app-b", "name": "App B", "status": "queued"},
                ],
            }
        )

    def test_second_start_adopts_existing_queue_instead_of_returning_error(self):
        self._seed_running_queue()
        batch_installer._batch_thread = _AliveThread()

        result = batch_installer.start_batch_install(package_ids=["app-b"])

        self.assertTrue(result["success"])
        self.assertTrue(result["already_running"])
        self.assertTrue(result["adopted_existing"])
        self.assertTrue(result["status"]["is_running"])
        self.assertEqual(result["status"]["current_item_name"], "App A")

    def test_status_endpoint_repairs_a_dead_worker_and_unlocks_controls(self):
        self._seed_running_queue()
        batch_installer._batch_thread = _DeadThread()

        status = batch_installer.get_batch_status()

        self.assertFalse(status["is_running"])
        self.assertEqual(status["failed"], 1)
        self.assertEqual(status["skipped"], 1)
        self.assertEqual(status["items"][0]["status"], "failed")
        self.assertEqual(status["items"][1]["status"], "skipped")
        self.assertIn("کنترل‌ها آزاد شدند", status["summary_message"])

    def test_worker_boundary_clears_running_state_after_unhandled_failure(self):
        self._seed_running_queue()
        batch_installer._batch_thread = None

        with patch.object(
            batch_installer,
            "_run_batch_install_impl",
            side_effect=RuntimeError("synthetic worker failure"),
        ):
            batch_installer._run_batch_install([], None)

        self.assertFalse(batch_installer._batch_state["is_running"])
        self.assertEqual(batch_installer._batch_state["failed"], 1)
        self.assertIn("synthetic worker failure", batch_installer._batch_state["items"][0]["message"])


if __name__ == "__main__":
    unittest.main()
