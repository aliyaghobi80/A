import hashlib
import json
from pathlib import Path
import sys
import tempfile
import threading
import time
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import deployment_scheduler as scheduler


class DeploymentSchedulerTests(unittest.TestCase):
    def test_two_reviewed_disjoint_jobs_overlap_but_barrier_waits(self):
        barrier = threading.Barrier(2, timeout=3)
        completed = []
        def run(index, item):
            if index < 2:
                barrier.wait()
            else:
                self.assertEqual(set(completed), {0, 1})
            completed.append(index)
        scheduler.run_deployment([0, 1, 2], run, double_speed=True,
                                 resources_for=lambda i: frozenset({str(i)}) if i < 2 else None)
        self.assertEqual(completed[-1], 2)
        self.assertEqual(scheduler._active, [])

    def test_sequential_mode_and_conflicts_preserve_order(self):
        for double_speed, resource in ((False, lambda i: frozenset({str(i)})),
                                       (True, lambda i: frozenset({"shared"})),
                                       (True, lambda i: None)):
            seen = []
            scheduler.run_deployment([0, 1, 2], lambda i, item: seen.append(i),
                                     double_speed=double_speed, resources_for=resource)
            self.assertEqual(seen, [0, 1, 2])

    def test_exception_joins_other_lane_before_releasing_queue(self):
        barrier = threading.Barrier(2, timeout=3)
        finished = threading.Event()
        def run(index, item):
            barrier.wait()
            if index == 0:
                raise RuntimeError("fixture")
            time.sleep(0.03)
            finished.set()
        with self.assertRaises(RuntimeError):
            scheduler.run_deployment([0, 1], run, double_speed=True,
                                     resources_for=lambda i: frozenset({str(i)}))
        self.assertTrue(finished.is_set())
        self.assertEqual(scheduler._active, [])

    def test_profiles_require_exact_hash_and_never_parallelize_gpu_or_msi(self):
        with tempfile.TemporaryDirectory() as directory:
            exe = Path(directory) / "driver.exe"
            exe.write_bytes(b"test fixture, never executed")
            policy = Path(directory) / "profiles.json"
            digest = hashlib.sha256(exe.read_bytes()).hexdigest()
            policy.write_text(json.dumps({digest: {"kind": "driver", "reviewed": True,
                                                   "resources": ["camera"]}}))
            item = {"installer_file": str(exe), "category": "camera", "install_method": "setup_exe"}
            with patch.object(scheduler, "POLICY_FILE", policy):
                self.assertEqual(scheduler.approved_resources(item, driver=True), frozenset({"camera"}))
                self.assertIsNone(scheduler.approved_resources(dict(item, category="gpu"), driver=True))
                self.assertIsNone(scheduler.approved_resources(dict(item, install_method="msiexec"), driver=True))
                exe.write_bytes(b"changed version")
                self.assertIsNone(scheduler.approved_resources(item, driver=True))

    def test_missing_profile_fails_closed(self):
        with patch.object(scheduler, "POLICY_FILE", Path("nonexistent-profile-fixture.json")):
            self.assertIsNone(scheduler.approved_resources({"filename": "app.exe"}))

    def test_external_windows_installer_is_waited_for_without_process_control(self):
        notices = []
        with (
            patch.object(scheduler, "windows_installer_busy", side_effect=[True, True, False]),
            patch.object(scheduler.time, "sleep") as sleep,
        ):
            result = scheduler.wait_for_windows_installer_idle(
                timeout_seconds=30,
                poll_seconds=0.1,
                on_wait=lambda: notices.append("waiting"),
            )
        self.assertTrue(result)
        self.assertEqual(notices, ["waiting"])
        self.assertEqual(sleep.call_count, 2)

    def test_external_installer_timeout_stops_before_launch(self):
        launched = []
        with patch.object(
            scheduler,
            "wait_for_windows_installer_idle",
            return_value=False,
        ):
            with self.assertRaises(scheduler.ExternalInstallerBusyError):
                scheduler.run_deployment(
                    ["package"],
                    lambda index, item: launched.append(item),
                    on_external_wait=lambda index, item: None,
                )
        self.assertEqual(launched, [])


if __name__ == "__main__":
    unittest.main()
