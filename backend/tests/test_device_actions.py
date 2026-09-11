import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from packages import manager
from packages import office_shortcuts
from packages import batch_installer
from windows import device_settings


class DeviceActionSafetyTests(unittest.TestCase):
    def _wub_package(self, path):
        return {
            "id": "windows-update-blocker",
            "name": "Windows Update Blocker",
            "filename": "Wub_x64.exe",
            "full_path": path,
        }

    def test_home_automatic_wub_is_skipped_without_execution(self):
        with patch.object(manager, "get_windows_identity", return_value={"is_home": True, "label": "Windows 11 Home"}), patch.object(manager, "_run_elevated_and_wait") as runner:
            result = manager._disable_windows_update_with_wub(self._wub_package("missing.exe"), automatic=True)
        self.assertTrue(result["success"])
        self.assertTrue(result["skipped"])
        self.assertTrue(result["home_guard"])
        runner.assert_not_called()

    def test_home_manual_wub_requires_confirmation_without_execution(self):
        with patch.object(manager, "get_windows_identity", return_value={"is_home": True, "label": "Windows 10 Home"}), patch.object(manager, "_run_elevated_and_wait") as runner:
            result = manager._disable_windows_update_with_wub(self._wub_package("missing.exe"), automatic=False)
        self.assertTrue(result["requires_confirmation"])
        self.assertFalse(result["success"])
        runner.assert_not_called()

    def test_non_home_wub_uses_disable_and_protect_switches_only(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            exe = Path(temp_dir) / "Wub_x64.exe"
            exe.write_bytes(b"MZ")
            with patch.object(manager, "get_windows_identity", return_value={"is_home": False, "label": "Windows 11 Pro"}), patch.object(manager, "_run_elevated_and_wait", return_value=0) as runner, patch.object(manager, "_windows_update_service_status", return_value={"disabled": True}):
                result = manager._disable_windows_update_with_wub(self._wub_package(str(exe)), automatic=True)
            self.assertTrue(result["success"])
            command = runner.call_args.args[0]
            self.assertEqual(command[1:], ["/D", "/P"])
            self.assertNotIn("restart", " ".join(command).lower())

    def test_wub_enable_uses_enable_switch_only_and_never_restarts(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            exe = Path(temp_dir) / "Wub_x64.exe"
            exe.write_bytes(b"MZ")
            with patch.object(manager, "_run_elevated_and_wait", return_value=0) as runner, patch.object(manager, "_windows_update_service_status", return_value={"start": 3, "running": False, "disabled": False}):
                result = manager._enable_windows_update_with_wub(self._wub_package(str(exe)))
            self.assertTrue(result["success"])
            self.assertFalse(result["windows_update_blocked"])
            command = runner.call_args.args[0]
            self.assertEqual(command[1:], ["/E"])
            self.assertNotIn("restart", " ".join(command).lower())

    def test_power_never_sets_display_sleep_and_hibernate_for_ac_dc(self):
        completed = MagicMock(returncode=0, stdout="", stderr="")
        with patch.object(device_settings, "_run", return_value=completed) as runner, patch.object(device_settings.os, "name", "nt"):
            result = device_settings.set_sleep_never()
        self.assertTrue(result["success"])
        commands = [call.args[0] for call in runner.call_args_list]
        self.assertEqual(commands, [
            ["powercfg.exe", "/change", "monitor-timeout-ac", "0"],
            ["powercfg.exe", "/change", "standby-timeout-ac", "0"],
            ["powercfg.exe", "/change", "hibernate-timeout-ac", "0"],
            ["powercfg.exe", "/change", "monitor-timeout-dc", "0"],
            ["powercfg.exe", "/change", "standby-timeout-dc", "0"],
            ["powercfg.exe", "/change", "hibernate-timeout-dc", "0"],
        ])

    def test_office_shortcuts_are_created_for_all_three_apps(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            desktop = Path(temp_dir) / "Desktop"
            executables = {}
            for display, exe_name in office_shortcuts.OFFICE_APPS.items():
                path = Path(temp_dir) / exe_name
                path.write_bytes(b"MZ")
                executables[exe_name] = path

            def fake_create(shortcut, executable):
                shortcut.write_text(str(executable), encoding="utf-8")

            with patch.object(office_shortcuts, "_desktop_path", return_value=desktop), patch.object(office_shortcuts, "_find_app_path", side_effect=lambda name: executables[name]), patch.object(office_shortcuts, "_create_shortcut", side_effect=fake_create):
                result = office_shortcuts.ensure_office_desktop_shortcuts()
            self.assertTrue(result["success"])
            self.assertEqual(set(result["created"]), {"Word", "Excel", "PowerPoint"})
            self.assertTrue((desktop / "Word.lnk").is_file())

    def test_wub_is_appended_to_automatic_deployment(self):
        app = {
            "id": "app", "relative_path": "App/setup.msi", "filename": "setup.msi",
            "name": "App", "is_valid": True, "auto_install_supported": True,
            "install_allowed": True, "is_installed": False, "installer_type": "msiexec",
        }
        wub = {
            "id": "wub", "relative_path": "Tools/Wub_x64.exe", "filename": "Wub_x64.exe",
            "name": "Windows Update Blocker", "is_valid": True,
            "auto_install_supported": False, "install_allowed": False,
            "is_installed": True, "installer_type": "portable_tool",
        }
        batch_installer._reset_state()
        self.addCleanup(batch_installer._reset_state)
        with patch.object(batch_installer, "scan_packages", return_value={"directory_exists": True, "packages": [app, wub]}), patch.object(batch_installer.threading, "Thread"):
            result = batch_installer.start_batch_install(package_ids=["app"])
        self.assertTrue(result["success"])
        self.assertEqual([item["id"] for item in result["items"]], ["app", "wub"])


if __name__ == "__main__":
    unittest.main()
