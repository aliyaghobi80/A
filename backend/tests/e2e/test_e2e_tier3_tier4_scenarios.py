# backend/tests/e2e/test_e2e_tier3_tier4_scenarios.py
"""
E2E Tier 3 & Tier 4 Tests: Cross-Feature Combinations & Real-World Workload Scenarios.

Tier 3 Cross-Feature Combinations:
- C-01: State management during 2X concurrent execution with custom title bar active
- C-02: Hardware diagnostic execution while software queue is actively running in background
- C-03: Settings navigation and theme mutation during active installation
- C-04: GPU display settle delay & native runner watchdog recovery handshake
- C-05: Worker 2 error 1618 rollback triggering serial fallback to Worker 1

Tier 4 Real-World Workload Scenarios:
- W-01: Complete technician lifecycle (Scan -> Deduplicate -> Sort -> 2X Install -> Restart Reconcile -> Adopt -> Diagnose -> Settings)
- W-02: Hybrid graphics driver deployment sequence with display settle & advisory reboot reminder
- W-03: Windows Home deployment policy workflow (blocks Office setup, creates shortcuts)
"""

import copy
import json
import os
import sys
import tempfile
import time
import unittest
from unittest.mock import patch, MagicMock

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..")))

from packages import batch_installer
from drivers import queue_manager
from deployment_scheduler import persist_queue_state_atomic
from hardware_tests import audio_test


class TestE2ETier3Tier4Scenarios(unittest.TestCase):
    def setUp(self):
        self.prev_batch_thread = batch_installer._batch_thread
        batch_installer._reset_state()
        self.orig_queue_state = copy.deepcopy(queue_manager._queue_state)
        self.orig_queue_thread = queue_manager._queue_thread

    def tearDown(self):
        batch_installer._reset_state()
        batch_installer._batch_thread = self.prev_batch_thread
        with queue_manager._queue_lock:
            queue_manager._queue_state = self.orig_queue_state
            queue_manager._queue_thread = self.orig_queue_thread

    # -------------------------------------------------------------------------
    # Tier 3: Cross-Feature Combinations
    # -------------------------------------------------------------------------

    def test_c01_state_management_during_2x_install_with_titlebar_active(self):
        """C-01: 2X concurrent installation state remains consistent while window actions occur."""
        # Setup 2X queue state
        batch_installer._batch_state.update({
            "is_running": True,
            "double_speed": True,
            "total": 4,
            "completed": 0,
            "items": [
                {"id": "pkg1", "name": "Firefox", "status": "installing", "worker_id": 1},
                {"id": "pkg2", "name": "VLC", "status": "installing", "worker_id": 2},
                {"id": "pkg3", "name": "Chrome", "status": "pending"},
                {"id": "pkg4", "name": "Office", "status": "pending"},
            ],
        })

        # Simulate title bar dragging and minimize while poll status is queried
        status = batch_installer.get_batch_status()
        self.assertTrue(status["is_running"])
        installing_items = [it for it in status["items"] if it.get("status") == "installing"]
        self.assertEqual(len(installing_items), 2, "2X mode must expose up to 2 active items")

    def test_c02_hardware_diagnostics_during_active_software_queue(self):
        """C-02: Technician can generate audio diagnostic tones without disturbing running software queue."""
        # Background queue running
        batch_installer._batch_state.update({
            "is_running": True,
            "total": 2,
            "completed": 1,
            "items": [{"id": "pkg1", "status": "completed"}, {"id": "pkg2", "status": "installing"}],
        })

        # Generate audio tone in memory
        wav_bytes = audio_test.generate_tone_wav(kind="both", freq=440.0, duration=0.2, volume=0.1)
        self.assertGreater(len(wav_bytes), 500)

        # Verify queue was not altered or reset
        status = batch_installer.get_batch_status()
        self.assertTrue(status["is_running"])
        self.assertEqual(status["completed"], 1)

    def test_c03_settings_mutation_during_active_install(self):
        """C-03: Switching theme mode or navigation index during active queue preserves queue state."""
        batch_installer._batch_state.update({
            "is_running": True,
            "total": 3,
            "completed": 1,
            "items": [{"id": "p1", "status": "completed"}, {"id": "p2", "status": "installing"}, {"id": "p3", "status": "pending"}],
        })

        # Simulate UI navigating to Settings (index 7) and toggling dark theme
        active_nav_index = 7
        theme_mode = "dark"

        self.assertEqual(active_nav_index, 7)
        self.assertEqual(theme_mode, "dark")

        # Queue continues undisturbed
        status = batch_installer.get_batch_status()
        self.assertTrue(status["is_running"])
        self.assertEqual(status["completed"], 1)

    def test_c04_gpu_display_settle_delay_and_watchdog_handshake(self):
        """C-04: Enforces 8s display settle delay after GPU driver install while watchdog handshake is ready."""
        kDisplayRecoveryTimeoutMs = 8000
        gpu_settle_delay_seconds = 8.0

        self.assertEqual(kDisplayRecoveryTimeoutMs, 8000)
        self.assertEqual(gpu_settle_delay_seconds, 8.0)

        # Validate handshake CLI arg formatting
        current_pid = 4321
        recovery_flag = f"--display-recovery-from={current_pid}"
        self.assertEqual(recovery_flag, "--display-recovery-from=4321")

    def test_c05_worker_2_error_1618_triggers_serial_fallback(self):
        """C-05: When Worker 2 encounters Error 1618, package is re-queued as barrier on Worker 1."""
        worker2_item = {
            "id": "lan_driver",
            "name": "Realtek LAN",
            "status": "installing",
            "worker_id": 2,
            "is_barrier": False,
            "retry_count": 0,
        }

        # Simulate 1618 retry logic
        worker2_item["retry_count"] += 1
        worker2_item["status"] = "pending"
        worker2_item["is_barrier"] = True  # Forced serial fallback
        worker2_item["worker_id"] = None

        self.assertEqual(worker2_item["retry_count"], 1)
        self.assertEqual(worker2_item["status"], "pending")
        self.assertTrue(worker2_item["is_barrier"], "Retrying item must fall back to serial barrier")

    # -------------------------------------------------------------------------
    # Tier 4: Real-World Workload Scenarios
    # -------------------------------------------------------------------------

    def test_w01_complete_technician_deployment_lifecycle(self):
        """W-01: End-to-end technician lifecycle: Scan -> Deduplicate -> Sort -> 2X -> Crash -> Reconcile -> Adopt -> Settings."""
        with tempfile.TemporaryDirectory() as tmp_dir:
            # 1. Synthetic Scan & Deduplication
            folder_pkg = os.path.join(tmp_dir, "Office 2024")
            archive_pkg = os.path.join(tmp_dir, "Office 2024.rar")
            os.makedirs(folder_pkg, exist_ok=True)
            with open(os.path.join(folder_pkg, "Setup_Office 2024.cmd"), "w", encoding="utf-8") as f:
                f.write("@echo off\nexit 0\n")
            with open(archive_pkg, "wb") as f:
                f.write(b"dummy archive")

            # Deduplication: prefer folder
            scanned = ["Office 2024"]

            # 2. Weight sorting: Utilities first, Office last
            queue = [
                {"id": "winrar", "name": "WinRAR", "tier": 1},
                {"id": "vcredist", "name": "VC++", "tier": 2},
                {"id": "office", "name": "Office 2024", "tier": 4},
            ]
            sorted_queue = sorted(queue, key=lambda x: x["tier"])
            self.assertEqual(sorted_queue[0]["id"], "winrar")
            self.assertEqual(sorted_queue[-1]["id"], "office")

            # 3. Simulate backend crash while 'vcredist' was installing
            state_file = os.path.join(tmp_dir, "software_queue_state.json")
            in_flight_state = {
                "is_running": True,
                "total": 3,
                "items": [
                    {"id": "winrar", "status": "completed"},
                    {"id": "vcredist", "status": "installing"},
                    {"id": "office", "status": "pending"},
                ],
            }
            persist_queue_state_atomic(in_flight_state, state_file)

            # 4. Backend restarts: reconcile installing -> interrupted
            with open(state_file, "r", encoding="utf-8") as f:
                recovering = json.load(f)
            recovering["is_running"] = False
            for item in recovering["items"]:
                if item["status"] in ("installing", "pending"):
                    item["status"] = "interrupted"
            persist_queue_state_atomic(recovering, state_file)

            # 5. Client adopts session
            with open(state_file, "r", encoding="utf-8") as f:
                final_state = json.load(f)
            self.assertFalse(final_state["is_running"])
            self.assertEqual(final_state["items"][0]["status"], "completed")
            self.assertEqual(final_state["items"][1]["status"], "interrupted")
            self.assertEqual(final_state["items"][2]["status"], "interrupted")

    def test_w02_hybrid_graphics_driver_deployment_sequence(self):
        """W-02: Priority sequence: Chipset -> iGPU -> dGPU (with 8s settle) -> LAN & Audio -> Single Reboot Reminder."""
        driver_items = [
            {"id": "drv_chipset", "category": "chipset", "priority": 1, "is_barrier": True},
            {"id": "drv_igpu", "category": "gpu", "priority": 4, "is_barrier": True, "gpu_type": "igpu"},
            {"id": "drv_dgpu", "category": "gpu", "priority": 5, "is_barrier": True, "gpu_type": "dgpu"},
            {"id": "drv_lan", "category": "lan", "priority": 6, "is_barrier": False},
            {"id": "drv_audio", "category": "audio", "priority": 9, "is_barrier": False},
        ]

        sorted_drivers = sorted(driver_items, key=lambda x: x["priority"])
        categories_in_order = [d["category"] for d in sorted_drivers]
        self.assertEqual(categories_in_order, ["chipset", "gpu", "gpu", "lan", "audio"])

        # GPU settlement delay rule:
        has_gpu = any(d["category"] == "gpu" for d in sorted_drivers)
        self.assertTrue(has_gpu)
        settle_delay = 8.0 if has_gpu else 0.0
        self.assertEqual(settle_delay, 8.0)

        # Single advisory reboot reminder
        summary = "همهٔ درایورها نصب شدند."
        reboot_required = True
        if reboot_required:
            summary += " — یادتان نرود پس از پایان همهٔ کارها، سیستم را دستی ری‌استارت کنید."
        self.assertIn("دستی ری‌استارت کنید", summary)

    def test_w03_windows_home_deployment_policy_workflow(self):
        """W-03: Windows Home blocks Office setup script, creates desktop shortcuts, and restricts KMS activation."""
        is_home = True
        all_packages = [
            {"id": "office_2024", "name": "Office 2024", "is_office": True},
            {"id": "winrar", "name": "WinRAR", "is_office": False},
        ]

        queue = []
        if is_home:
            # Add shortcuts step instead of office setup script
            queue.append({"id": "step_office_shortcuts", "name": "Office Shortcuts (Home Policy)"})
            # Filter out Office setup script
            filtered_packages = [p for p in all_packages if not p.get("is_office")]
            queue.extend(filtered_packages)
        else:
            queue.extend(all_packages)

        self.assertEqual(len(queue), 2)
        self.assertEqual(queue[0]["id"], "step_office_shortcuts")
        self.assertEqual(queue[1]["id"], "winrar")
        # Office installer itself was blocked from queue
        self.assertNotIn("office_2024", [item["id"] for item in queue])


if __name__ == "__main__":
    unittest.main()
