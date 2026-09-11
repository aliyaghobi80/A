import unittest
import os
from unittest.mock import patch
import sys
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
import tempfile
import shutil
from packages.manager import scan_packages
from packages.batch_installer import start_batch_install, cancel_batch_install, get_batch_status


class TestOfficeAutomation(unittest.TestCase):
    def setUp(self):
        thread_patch = patch("packages.batch_installer.threading.Thread")
        thread_patch.start()
        self.addCleanup(thread_patch.stop)
        from packages.batch_installer import _reset_state
        _reset_state()
        self.addCleanup(_reset_state)
        self.temp_dir = tempfile.mkdtemp()
        self.office_dir = os.path.join(self.temp_dir, "Microsoft Office 2019-2024 Pro Plus 2509")
        os.makedirs(self.office_dir, exist_ok=True)
        self.office_cmd = os.path.join(self.office_dir, "Setup_Office 2024.cmd")
        with open(self.office_cmd, "w", encoding="utf-8") as f:
            f.write("@echo off\r\necho Menu Office 2024\r\n")

        self.app_dir = os.path.join(self.temp_dir, "Google Chrome")
        os.makedirs(self.app_dir, exist_ok=True)
        self.app_msi = os.path.join(self.app_dir, "Setup.msi")
        with open(self.app_msi, "w", encoding="utf-8") as f:
            f.write("dummy-msi")

    def tearDown(self):
        cancel_batch_install()
        shutil.rmtree(self.temp_dir, ignore_errors=True)

    def test_office_detection(self):
        result = scan_packages(self.temp_dir)
        pkgs = result.get("packages", [])
        office_pkg = next((p for p in pkgs if p.get("installer_type") == "office_cmd"), None)
        self.assertIsNotNone(office_pkg)
        self.assertIn("Microsoft Office 2024", office_pkg["name"])
        self.assertTrue(office_pkg["auto_install_supported"])
        self.assertTrue(office_pkg["install_allowed"])

    def test_office_reordered_to_end_of_queue(self):
        result = start_batch_install(
            package_ids=["office_2024_pro_plus", "Google Chrome/Setup.msi"],
            custom_dir=self.temp_dir,
        )
        self.assertTrue(result.get("success"))
        items = result.get("items", [])
        self.assertGreaterEqual(len(items), 2)
        # Office must be the last item in the queue
        self.assertEqual(items[-1]["installer_type"], "office_cmd")
        self.assertNotEqual(items[0]["installer_type"], "office_cmd")


if __name__ == "__main__":
    unittest.main()
