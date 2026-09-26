import copy
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch


sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from activation import activation_tools
from packages import batch_installer, manager, orchestrator


HOME = {
    "is_home": True,
    "label": "Windows 11 Home",
    "generation": "Windows 11",
    "edition_id": "Core",
}
PRO = {
    "is_home": False,
    "label": "Windows 11 Pro",
    "generation": "Windows 11",
    "edition_id": "Professional",
}


def office_package() -> dict:
    return {
        "id": "office_2024_pro_plus",
        "name": "Microsoft Office 2024 (Pro Plus)",
        "filename": "Setup_Office 2024.cmd",
        "relative_path": "Office/Setup_Office 2024.cmd",
        "full_path": r"C:\PROGRAM\Office\Setup_Office 2024.cmd",
        "installer_type": "office_cmd",
        "is_valid": True,
        "manual_install_supported": True,
        "auto_install_supported": True,
        "is_installed": False,
    }


def regular_package() -> dict:
    return {
        "id": "chrome",
        "name": "Google Chrome",
        "filename": "Chrome.msi",
        "relative_path": "Chrome/Chrome.msi",
        "full_path": r"C:\PROGRAM\Chrome\Chrome.msi",
        "installer_type": "msiexec",
        "is_valid": True,
        "manual_install_supported": True,
        "auto_install_supported": True,
        "is_installed": False,
    }


class HomeDeploymentPolicyTests(unittest.TestCase):
    def setUp(self):
        batch_installer._reset_state()
        self.addCleanup(batch_installer._reset_state)

    def test_full_home_queue_never_contains_kms_or_office_deployment(self):
        scanned = {
            "directory_exists": True,
            "packages_directory": r"H:\PROGRAM",
            "packages": [regular_package(), office_package()],
        }
        with (
            patch.object(batch_installer, "scan_packages", return_value=scanned),
            patch.object(batch_installer, "get_windows_identity", return_value=HOME),
            patch.object(batch_installer, "has_battery", return_value=False),
            patch.object(batch_installer.threading, "Thread"),
        ):
            result = batch_installer.start_batch_install(
                package_ids=["chrome", "office_2024_pro_plus"],
                custom_dir=r"H:\PROGRAM",
                include_system_setup=True,
            )

        self.assertTrue(result["success"])
        actions = [item.get("orchestrator_action") for item in result["items"]]
        ids = [item.get("id") for item in result["items"]]
        self.assertIn("office_shortcuts", actions)
        self.assertNotIn("kms_activate", actions)
        self.assertNotIn("office_extract", actions)
        self.assertNotIn("office_2024_pro_plus", ids)
        self.assertIn("chrome", ids)

    def test_single_office_request_on_home_becomes_shortcut_only_step(self):
        scanned = {
            "directory_exists": True,
            "packages_directory": r"H:\PROGRAM",
            "packages": [office_package()],
        }
        with (
            patch.object(batch_installer, "scan_packages", return_value=scanned),
            patch.object(batch_installer, "get_windows_identity", return_value=HOME),
            patch.object(batch_installer.threading, "Thread"),
        ):
            result = batch_installer.start_batch_install(
                package_ids=["office_2024_pro_plus"],
                custom_dir=r"H:\PROGRAM",
                include_system_setup=False,
            )

        self.assertTrue(result["success"])
        self.assertEqual(len(result["items"]), 1)
        self.assertEqual(result["items"][0]["orchestrator_action"], "office_shortcuts")

    def test_forged_home_kms_queue_item_is_skipped_without_extraction_or_execution(self):
        item = {
            "id": "step_kms_activate",
            "name": "KMS",
            "filename": "WINDOWS.cmd",
            "relative_path": "",
            "installer_type": "orchestrator",
            "orchestrator_action": "kms_activate",
            "status": "queued",
            "message": "",
            "installed_version": "",
            "exit_code": None,
        }
        batch_installer._batch_state.update(
            {
                "is_running": True,
                "total": 1,
                "items": [copy.deepcopy(item)],
            }
        )
        with (
            patch.object(batch_installer, "get_windows_identity", return_value=HOME),
            patch.object(batch_installer.time, "sleep"),
            patch.object(orchestrator, "activate_windows_from_packages") as activator,
        ):
            batch_installer._run_batch_install([item], custom_dir=r"H:\PROGRAM")

        activator.assert_not_called()
        status = batch_installer.get_batch_status()
        self.assertEqual(status["items"][0]["status"], "skipped")
        self.assertEqual(status["failed"], 0)

    def test_direct_office_install_paths_are_blocked_on_home_and_only_make_shortcuts(self):
        scanned = {
            "directory_exists": True,
            "packages_directory": r"H:\PROGRAM",
            "packages": [office_package()],
        }
        shortcut_result = {
            "success": True,
            "created": ["Word", "Excel", "PowerPoint"],
            "missing": [],
            "errors": [],
            "message": "shortcuts created",
        }
        with (
            patch.object(manager, "scan_packages", return_value=scanned),
            patch.object(manager, "get_windows_identity", return_value=HOME),
            patch.object(manager, "ensure_office_desktop_shortcuts", return_value=shortcut_result) as shortcuts,
            patch.object(manager, "_launch_elevated") as interactive_runner,
            patch.object(manager, "_install_office_automated") as silent_runner,
        ):
            interactive = manager.install_package("office_2024_pro_plus", custom_dir=r"H:\PROGRAM")
            silent = manager.silent_install_package("office_2024_pro_plus", custom_dir=r"H:\PROGRAM")

        self.assertTrue(interactive["home_guard"])
        self.assertTrue(silent["home_guard"])
        self.assertTrue(interactive["skipped"])
        self.assertTrue(silent["skipped"])
        self.assertEqual(shortcuts.call_count, 2)
        interactive_runner.assert_not_called()
        silent_runner.assert_not_called()

    def test_low_level_activation_guards_stop_home_before_tool_lookup(self):
        for target in ("windows", "office"):
            with self.subTest(target=target):
                with (
                    patch("windows.device_settings.get_windows_identity", return_value=HOME),
                    patch.object(activation_tools, "get_tool_status") as tool_status,
                ):
                    result = activation_tools.execute_activation_tool(target)

                self.assertFalse(result["success"])
                self.assertTrue(result["home_guard"])
                self.assertTrue(result["skipped"])
                tool_status.assert_not_called()

    def test_home_shortcut_queue_step_never_calls_an_installer(self):
        item = {
            "id": "step_office_shortcuts",
            "name": "Office shortcuts",
            "filename": "Microsoft Office",
            "relative_path": "",
            "installer_type": "orchestrator",
            "orchestrator_action": "office_shortcuts",
            "status": "queued",
            "message": "",
            "installed_version": "",
            "exit_code": None,
        }
        batch_installer._batch_state.update(
            {"is_running": True, "total": 1, "items": [copy.deepcopy(item)]}
        )
        shortcut_result = {
            "success": True,
            "created": ["Word", "Excel", "PowerPoint"],
            "message": "shortcuts created",
        }
        with (
            patch.object(batch_installer, "get_windows_identity", return_value=HOME),
            patch.object(batch_installer.time, "sleep"),
            patch("packages.office_shortcuts.ensure_office_desktop_shortcuts", return_value=shortcut_result),
            patch.object(batch_installer, "silent_install_package") as installer,
        ):
            batch_installer._run_batch_install([item], custom_dir=r"H:\PROGRAM")

        installer.assert_not_called()
        status = batch_installer.get_batch_status()
        self.assertEqual(status["items"][0]["status"], "completed")
        self.assertIn("KMS و نصب Office اجرا نشد", status["items"][0]["message"])

    def test_orchestrator_guards_stop_home_before_kms_file_or_license_work(self):
        with (
            patch.object(orchestrator, "get_windows_identity", return_value=HOME),
            patch.object(orchestrator, "extract_driver_archive") as archive_runner,
            patch.object(orchestrator, "_query_wmi_licensing") as license_query,
        ):
            office_extraction = orchestrator.ensure_office_extracted(r"H:\PROGRAM")
            extraction = orchestrator.extract_kms_archive(r"H:\PROGRAM")
            activation = orchestrator.run_windows_cmd_activation(r"H:\PROGRAM")

        self.assertTrue(office_extraction["home_guard"])
        self.assertTrue(extraction["home_guard"])
        self.assertTrue(activation["home_guard"])
        archive_runner.assert_not_called()
        license_query.assert_not_called()

    def test_non_home_extraction_prefers_kms_v6_archive(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            old_archive = Path(temp_dir) / "KMS old.zip"
            v6_archive = Path(temp_dir) / "KMS v6.rar"
            old_archive.write_bytes(b"old")
            v6_archive.write_bytes(b"v6")
            with (
                patch.object(orchestrator, "get_windows_identity", return_value=PRO),
                patch.object(orchestrator, "extract_driver_archive", return_value=True) as extractor,
            ):
                result = orchestrator.extract_kms_archive(temp_dir)

        self.assertTrue(result["success"])
        self.assertEqual(result["archive_name"], "KMS v6.rar")
        self.assertEqual(extractor.call_args.args[0], str(v6_archive))

    def test_non_home_package_activation_extracts_then_runs_selected_program_folder(self):
        extraction = {"success": True, "archive_name": "KMS v6.rar"}
        activation = {"success": True, "activated": True, "message": "activated"}
        with (
            patch.object(orchestrator, "get_windows_identity", return_value=PRO),
            patch.object(orchestrator, "extract_kms_archive", return_value=extraction) as extractor,
            patch.object(orchestrator, "run_windows_cmd_activation", return_value=activation) as runner,
        ):
            result = orchestrator.activate_windows_from_packages(
                r"H:\PROGRAM", timeout_seconds=90
            )

        self.assertTrue(result["success"])
        self.assertEqual(result["extraction"], extraction)
        extractor.assert_called_once_with(r"H:\PROGRAM")
        runner.assert_called_once_with(r"H:\PROGRAM", timeout_seconds=90)


if __name__ == "__main__":
    unittest.main()
