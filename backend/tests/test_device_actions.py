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
            with patch.object(manager, "get_windows_identity", return_value={"is_home": False, "label": "Windows 11 Pro"}), patch.object(manager, "_run_elevated_and_wait", return_value=0) as runner, patch.object(manager, "_windows_update_service_status", return_value={"disabled": True}), patch.object(manager, "_open_windows_update_blocker", return_value=True) as opener:
                result = manager._disable_windows_update_with_wub(self._wub_package(str(exe)), automatic=True)
            self.assertTrue(result["success"])
            self.assertTrue(result["opened_for_pin"])
            opener.assert_called_once_with(str(exe))
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
        with patch.object(device_settings, "_run", return_value=completed) as runner, patch.object(device_settings.os, "name", "nt"), patch('windows.power_settings.get_timeout_status', return_value={'all_never': True}):
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

    def test_disable_startup_apps_uses_elevated_toggle_and_opens_settings(self):
        completed = MagicMock(returncode=0, stdout='{"success":true,"registry_changed":3,"packaged_changed":2}', stderr="")
        with patch.object(device_settings.os, "name", "nt"), patch.object(device_settings, "_run_elevated_powershell", return_value=completed) as runner, patch.object(device_settings, "_open_settings", return_value=True) as opener, patch('windows.startup_status.get_startup_status', return_value={'all_disabled': True}):
            result = device_settings.disable_all_startup_apps()
        self.assertTrue(result["success"])
        script = runner.call_args.args[0]
        self.assertIn("StartupApproved", script)
        self.assertIn("StartupFolder", script)
        self.assertIn("SystemAppData", script)
        self.assertIn("$state -eq 2", script)
        self.assertIn("$bytes[0] = 3", script)
        self.assertIn("return ,$bytes", script)
        self.assertIn("[byte[]]$disabledValue", script)
        self.assertNotIn("RunOnce", script)
        self.assertEqual(result["changed_count"], 5)
        opener.assert_called_once_with("ms-settings:startupapps")

    def test_background_apps_action_is_blocked_on_windows_11(self):
        with patch.object(device_settings, "get_windows_identity", return_value={"generation": "Windows 11", "label": "Windows 11 Pro"}), patch.object(device_settings, "_open_settings") as opener:
            result = device_settings.disable_windows10_background_apps()
        self.assertFalse(result["success"])
        self.assertTrue(result["unsupported"])
        opener.assert_not_called()

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
        with patch.object(batch_installer, "scan_packages", return_value={"directory_exists": True, "packages": [app, wub]}), patch.object(batch_installer, "get_windows_identity", return_value={"is_home": False, "generation": "Windows 11", "label": "Windows 11 Pro"}), patch.object(batch_installer.threading, "Thread"):
            result = batch_installer.start_batch_install(package_ids=["app"])
        self.assertTrue(result["success"])
        self.assertEqual([item["id"] for item in result["items"]], ["app", "wub"])

    def test_full_deployment_finishes_settings_then_opens_windows_security(self):
        app = {
            "id": "app", "relative_path": "App/setup.exe", "filename": "setup.exe",
            "name": "App", "is_valid": True, "auto_install_supported": True,
            "install_allowed": True, "is_installed": False, "installer_type": "inno",
        }
        wub = {
            "id": "wub", "relative_path": "Tools/Wub_x64.exe", "filename": "Wub_x64.exe",
            "name": "Windows Update Blocker", "is_valid": True,
            "auto_install_supported": False, "install_allowed": False,
            "is_installed": True, "installer_type": "portable_tool",
        }
        batch_installer._reset_state()
        self.addCleanup(batch_installer._reset_state)
        with patch.object(batch_installer, "scan_packages", return_value={"directory_exists": True, "packages": [app, wub]}), patch.object(batch_installer, "get_windows_identity", return_value={"is_home": False, "generation": "Windows 11", "label": "Windows 11 Pro"}), patch.object(batch_installer, "has_battery", return_value=False), patch.object(batch_installer.threading, "Thread"):
            result = batch_installer.start_batch_install(
                package_ids=["app"],
                include_system_setup=True,
            )

        actions = [item.get("orchestrator_action") for item in result["items"]]
        self.assertEqual(actions[-1], "windows_security")
        self.assertLess(actions.index("sleep_never"), actions.index("windows_security"))
        self.assertLess(actions.index("startup_apps"), actions.index("windows_security"))


if __name__ == "__main__":
    unittest.main()
