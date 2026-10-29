# backend/tests/test_scheduler_worker_pool.py
"""
Comprehensive Unit Test Suite for DeploymentWorkerPool & 2X Concurrency Scheduler.
Tests:
- 2X mode concurrent execution of two parallel-safe EXEs
- MSI executing as a strict serial barrier with pre-barrier drain
- Mixed execution: parallel EXEs -> serial MSI barrier -> parallel EXEs
- GPU executing as exclusive barrier with post-install settle delay
- Topological priority ordering (Chipset before GPU; iGPU before dGPU; AMD -> Intel -> NVIDIA)
- Error 1618 retry policy capped at 2 retries with backoff and serial fallback without infinite loops
- Single worker failure isolation
- Cancel and pause
- Dynamic 2X to 1X mode switching without terminating active workers mid-flight
- Dead worker detection and queue state repair
- Empty and single-item queues
"""

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

from deployment_scheduler import (
    DeploymentWorkerPool,
    run_deployment,
    persist_queue_state_atomic,
    windows_installer_busy,
    wait_for_windows_installer_idle,
)
from drivers.gpu_installers import (
    gpu_priority_key,
    execute_gpu_settle_delay,
)
from drivers import queue_manager
from drivers.queue_manager import (
    sort_driver_queue,
    get_driver_queue_status,
)
import copy


class TestSchedulerWorkerPool(unittest.TestCase):

    def setUp(self):
        self.test_dir = tempfile.mkdtemp(prefix="test_pool_")
        self._orig_queue_state = copy.deepcopy(queue_manager._queue_state)
        self._orig_queue_thread = queue_manager._queue_thread

    def tearDown(self):
        with queue_manager._queue_lock:
            queue_manager._queue_state = self._orig_queue_state
            queue_manager._queue_thread = self._orig_queue_thread
        shutil.rmtree(self.test_dir, ignore_errors=True)

    # -------------------------------------------------------------------------
    # 1. 2X Concurrent Execution of Two Parallel-Safe EXEs
    # -------------------------------------------------------------------------
    def test_2x_concurrent_execution_of_two_parallel_safe_exes(self):
        item_audio = {
            "package_id": "pkg_audio",
            "display_name": "Realtek Audio",
            "category": "audio",
            "install_method": "setup_exe",
            "is_barrier": False,
            "is_parallel_safe": True,
            "resource_tag": "audio",
            "silent_args": ["/s"],
        }
        item_wifi = {
            "package_id": "pkg_wifi",
            "display_name": "Intel Wi-Fi",
            "category": "wifi",
            "install_method": "setup_exe",
            "is_barrier": False,
            "is_parallel_safe": True,
            "resource_tag": "wifi",
            "silent_args": ["/s"],
        }

        concurrent_barrier = threading.Barrier(2, timeout=5)
        both_active = threading.Event()
        executed_workers = []
        lock = threading.Lock()

        def run_one(idx, pkg):
            wid = 1 if pkg["package_id"] == "pkg_audio" else 2
            with lock:
                executed_workers.append(pkg["package_id"])
            # Both workers wait here simultaneously, proving true concurrency
            concurrent_barrier.wait()
            both_active.set()
            time.sleep(0.05)

        pool = DeploymentWorkerPool(
            [item_audio, item_wifi],
            run_one,
            double_speed=True,
        )
        pool.run()

        self.assertTrue(both_active.is_set(), "Two parallel-safe EXEs did not execute concurrently!")
        self.assertEqual(len(executed_workers), 2)
        self.assertEqual(pool.failed_indices, set())
        self.assertEqual(pool.completed_indices, {0, 1})

    # -------------------------------------------------------------------------
    # 2. MSI Strict Serial Barrier with Pre-Barrier Drain
    # -------------------------------------------------------------------------
    def test_msi_strict_serial_barrier_with_pre_barrier_drain(self):
        item_parallel1 = {
            "package_id": "pkg_lan",
            "display_name": "Realtek LAN",
            "category": "lan",
            "install_method": "setup_exe",
            "is_barrier": False,
            "is_parallel_safe": True,
            "resource_tag": "lan",
            "silent_args": ["/s"],
        }
        item_parallel2 = {
            "package_id": "pkg_audio",
            "display_name": "Realtek Audio",
            "category": "audio",
            "install_method": "setup_exe",
            "is_barrier": False,
            "is_parallel_safe": True,
            "resource_tag": "audio",
            "silent_args": ["/s"],
        }
        item_msi = {
            "package_id": "pkg_msi",
            "display_name": "Vendor Software MSI",
            "category": "other",
            "install_method": "msiexec",
            "is_barrier": True,
            "is_parallel_safe": False,
            "silent_args": ["/qn"],
        }

        timeline = []
        timeline_lock = threading.Lock()

        def run_one(idx, pkg):
            with timeline_lock:
                timeline.append((pkg["package_id"], "start", pool.get_active_items()))
            if pkg["package_id"] in ("pkg_lan", "pkg_audio"):
                time.sleep(0.08)
            elif pkg["package_id"] == "pkg_msi":
                # When MSI executes, Worker 2 MUST have drained!
                with timeline_lock:
                    active_now = pool.get_active_items()
                    self.assertEqual(
                        len(active_now),
                        1,
                        f"MSI executed while other workers were active: {active_now}",
                    )
                    self.assertEqual(active_now[0]["worker_id"], 1)
                time.sleep(0.04)
            with timeline_lock:
                timeline.append((pkg["package_id"], "end", None))

        pool = DeploymentWorkerPool(
            [item_parallel1, item_parallel2, item_msi],
            run_one,
            double_speed=True,
        )
        pool.run()

        self.assertEqual(pool.completed_indices, {0, 1, 2})

    # -------------------------------------------------------------------------
    # 3. Combination of Parallel EXEs -> MSI Barrier -> Parallel EXEs
    # -------------------------------------------------------------------------
    def test_mixed_parallel_exes_and_msi_barrier(self):
        items = [
            {"package_id": "exe1", "category": "lan", "install_method": "setup_exe", "is_barrier": False, "is_parallel_safe": True, "silent_args": ["/s"], "resource_tag": "lan"},
            {"package_id": "exe2", "category": "wifi", "install_method": "setup_exe", "is_barrier": False, "is_parallel_safe": True, "silent_args": ["/s"], "resource_tag": "wifi"},
            {"package_id": "msi1", "category": "other", "install_method": "msiexec", "is_barrier": True, "is_parallel_safe": False, "silent_args": ["/qn"]},
            {"package_id": "exe3", "category": "audio", "install_method": "setup_exe", "is_barrier": False, "is_parallel_safe": True, "silent_args": ["/s"], "resource_tag": "audio"},
            {"package_id": "exe4", "category": "touchpad", "install_method": "setup_exe", "is_barrier": False, "is_parallel_safe": True, "silent_args": ["/s"], "resource_tag": "touchpad"},
        ]

        running_concurrently = set()
        running_lock = threading.Lock()
        max_msi_concurrency = 0

        def run_one(idx, pkg):
            nonlocal max_msi_concurrency
            with running_lock:
                running_concurrently.add(pkg["package_id"])
                if pkg["package_id"] == "msi1":
                    max_msi_concurrency = max(max_msi_concurrency, len(running_concurrently))
            time.sleep(0.04)
            with running_lock:
                running_concurrently.remove(pkg["package_id"])

        pool = DeploymentWorkerPool(items, run_one, double_speed=True)
        pool.run()

        self.assertEqual(pool.completed_indices, {0, 1, 2, 3, 4})
        # During msi1 execution, concurrency MUST be strictly 1 (no other installer running!)
        self.assertEqual(max_msi_concurrency, 1)

    # -------------------------------------------------------------------------
    # 4. GPU Exclusive Barrier with Display Settle Delay
    # -------------------------------------------------------------------------
    def test_gpu_exclusive_barrier_classification_and_settle(self):
        gpu_pkg = {
            "package_id": "pkg_gpu",
            "display_name": "NVIDIA GeForce Driver",
            "category": "gpu",
            "install_method": "setup_exe",
            "silent_args": ["-s", "-noreboot"],
        }
        pool = DeploymentWorkerPool([gpu_pkg], lambda i, p: None, double_speed=True)

        # Must be strictly classified as a Barrier
        self.assertTrue(pool.is_barrier(gpu_pkg))
        self.assertFalse(pool.is_parallel_safe(gpu_pkg))

        # Test display settle delay executes without error
        with patch("time.sleep") as mock_sleep:
            execute_gpu_settle_delay(seconds=8.0)
            mock_sleep.assert_called_once_with(8.0)

    # -------------------------------------------------------------------------
    # 5. Priority Ordering Contract (Chipset -> iGPU -> dGPU; AMD -> Intel -> NVIDIA)
    # -------------------------------------------------------------------------
    def test_priority_ordering_chipset_before_gpu_and_gpu_ordering(self):
        pkg_nvidia_dgpu = {
            "package_id": "p_nv",
            "display_name": "NVIDIA RTX 4060",
            "category": "gpu",
            "category_order": 8,
            "hardware_ids": ["PCI\\VEN_10DE&DEV_28E0"],
        }
        pkg_intel_igpu = {
            "package_id": "p_intel",
            "display_name": "Intel Iris Xe Graphics",
            "category": "gpu",
            "category_order": 8,
            "hardware_ids": ["PCI\\VEN_8086&DEV_9A49"],
            "is_igpu": True,
        }
        pkg_amd_apu = {
            "package_id": "p_amd",
            "display_name": "AMD Radeon Graphics APU",
            "category": "gpu",
            "category_order": 8,
            "hardware_ids": ["PCI\\VEN_1002&DEV_1638"],
            "is_igpu": True,
        }
        pkg_chipset = {
            "package_id": "p_chipset",
            "display_name": "Intel Chipset Device Software",
            "category": "chipset",
            "category_order": 1,
        }
        pkg_audio = {
            "package_id": "p_audio",
            "display_name": "Realtek Audio",
            "category": "audio",
            "category_order": 7,
        }

        unordered = [pkg_nvidia_dgpu, pkg_audio, pkg_intel_igpu, pkg_chipset, pkg_amd_apu]
        sorted_pkgs = sort_driver_queue(unordered)

        # Priority 1: Chipset must be first
        self.assertEqual(sorted_pkgs[0]["package_id"], "p_chipset")
        # Priority 2: Audio before GPU (category_order 7 vs 8)
        self.assertEqual(sorted_pkgs[1]["package_id"], "p_audio")

        # GPU ordering within category 8:
        # iGPU before dGPU; AMD APU (0) -> Intel iGPU (1) -> NVIDIA dGPU (2)
        gpu_sublist = [p["package_id"] for p in sorted_pkgs[2:]]
        self.assertEqual(gpu_sublist, ["p_amd", "p_intel", "p_nv"])

    # -------------------------------------------------------------------------
    # 6. Error 1618 Bounded Retry Policy
    # -------------------------------------------------------------------------
    def test_error_1618_bounded_retry_capped_at_2_retries_with_serial_fallback(self):
        item = {
            "package_id": "pkg_busy",
            "display_name": "Realtek Audio Installer",
            "status": "installing",
            "category": "audio",
            "is_barrier": False,
            "is_parallel_safe": True,
        }
        pool = DeploymentWorkerPool([item], lambda i, p: None, double_speed=True)

        with (
            patch("deployment_scheduler.wait_for_windows_installer_idle", return_value=True),
            patch("time.sleep"),
        ):
            # Attempt 1 -> Exit 1618 -> First retry
            retry1 = pool.handle_1618_retry(0, item)
            self.assertTrue(retry1)
            self.assertEqual(item["retry_count"], 1)
            self.assertEqual(item["status"], "pending")
            # Must enforce serial fallback
            self.assertTrue(item["is_barrier"])
            self.assertFalse(item["is_parallel_safe"])
            self.assertIn("تلاش مجدد", item["message"])
            self.assertIn("1 از ۲", item["message"])

            # Attempt 2 -> Exit 1618 -> Second retry
            retry2 = pool.handle_1618_retry(0, item)
            self.assertTrue(retry2)
            self.assertEqual(item["retry_count"], 2)
            self.assertIn("2 از ۲", item["message"])

            # Attempt 3 -> Exit 1618 -> Retries exhausted!
            retry3 = pool.handle_1618_retry(0, item)
            self.assertFalse(retry3)
            self.assertEqual(item["status"], "failed")
            self.assertEqual(item["exit_code"], 1618)
            self.assertIn("بیش از ۲ بار تلاش", item["failure_reason"])
            self.assertIn(0, pool.failed_indices)

    # -------------------------------------------------------------------------
    # 7. Single Worker Failure Isolation
    # -------------------------------------------------------------------------
    def test_single_worker_failure_isolation(self):
        pool = DeploymentWorkerPool(
            [{"package_id": "item1"}, {"package_id": "item2"}],
            lambda idx, item: None,
            double_speed=True,
        )
        pool.claimed_indices.add(0)
        pool.claimed_indices.add(1)

        # Worker 2 reports non-zero failure without fatal exception
        pool.release_item(2, 1, success=False, exit_code=1603)
        self.assertIn(1, pool.failed_indices)
        self.assertIsNone(pool.fatal_error)

        # Worker 1 reports separate fatal exception
        err = RuntimeError("Fatal crash")
        pool.release_item(1, 0, success=False, error=err)
        self.assertEqual(pool.fatal_error, err)

    # -------------------------------------------------------------------------
    # 8. Cancel and Pause
    # -------------------------------------------------------------------------
    def test_cancel_stops_subsequent_claims(self):
        items = [{"package_id": f"item_{i}"} for i in range(5)]
        claimed_count = 0

        def run_one(idx, item):
            nonlocal claimed_count
            claimed_count += 1
            if idx == 0:
                pool.cancel()

        pool = DeploymentWorkerPool(items, run_one, double_speed=False)
        pool.run()

        self.assertTrue(pool.cancelled)
        self.assertLess(claimed_count, 5)

    # -------------------------------------------------------------------------
    # 9. Dynamic 2X to 1X Switching Without Killing Active Worker
    # -------------------------------------------------------------------------
    def test_dynamic_2x_to_1x_mode_switch(self):
        item1 = {"package_id": "p1", "category": "lan", "install_method": "setup_exe", "is_barrier": False, "is_parallel_safe": True, "resource_tag": "lan"}
        item2 = {"package_id": "p2", "category": "wifi", "install_method": "setup_exe", "is_barrier": False, "is_parallel_safe": True, "resource_tag": "wifi"}
        item3 = {"package_id": "p3", "category": "audio", "install_method": "setup_exe", "is_barrier": False, "is_parallel_safe": True, "resource_tag": "audio"}

        barrier = threading.Barrier(2, timeout=5)
        completed = []

        def run_one(idx, pkg):
            if idx < 2:
                barrier.wait()
                # Dynamically switch mode from 2X to 1X mid-flight!
                pool.set_double_speed(False)
            completed.append(pkg["package_id"])
            time.sleep(0.04)

        pool = DeploymentWorkerPool([item1, item2, item3], run_one, double_speed=True)
        pool.run()

        self.assertEqual(len(completed), 3)
        self.assertEqual(pool.completed_indices, {0, 1, 2})
        self.assertFalse(pool.double_speed)

    # -------------------------------------------------------------------------
    # 10. Dead Worker Watchdog State Repair
    # -------------------------------------------------------------------------
    def test_dead_worker_watchdog_state_repair(self):
        stopped_thread = threading.Thread(target=lambda: None)
        stopped_thread.start()
        stopped_thread.join()

        with queue_manager._queue_lock:
            queue_manager._queue_state.update({
                "status": "ok",
                "is_running": True,
                "start_time": time.time() - 10.0,
                "items": [
                    {
                        "package_id": "stale_pkg",
                        "display_name": "Stale Package",
                        "status": "installing",
                        "message": "در حال نصب...",
                    }
                ],
                "failed": 0,
            })
            queue_manager._queue_thread = stopped_thread

        with patch("drivers.queue_manager._log_driver_event"):
            status = queue_manager.get_driver_queue_status()

        self.assertFalse(status["is_running"])
        self.assertEqual(status["failed"], 1)
        item = status["items"][0]
        self.assertEqual(item["status"], "failed")
        self.assertEqual(item["exit_code"], -5)
        self.assertIn("پردازش نصب غیرمنتظره متوقف شد", item["message"])

    # -------------------------------------------------------------------------
    # 11. Empty and Single-Item Queues
    # -------------------------------------------------------------------------
    def test_empty_queue(self):
        executed = []
        pool = DeploymentWorkerPool([], lambda i, p: executed.append(i), double_speed=True)
        pool.run()
        self.assertEqual(executed, [])
        self.assertFalse(pool.is_running)

    def test_single_item_queue(self):
        executed = []
        item = {"package_id": "solo", "category": "lan", "install_method": "setup_exe", "is_barrier": False, "is_parallel_safe": True}
        pool = DeploymentWorkerPool([item], lambda i, p: executed.append(p["package_id"]), double_speed=True)
        pool.run()
        self.assertEqual(executed, ["solo"])
        self.assertEqual(pool.completed_indices, {0})


if __name__ == "__main__":
    unittest.main()
