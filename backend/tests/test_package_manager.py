import os
import tempfile
import unittest
from unittest import mock

from packages import manager


class PackageManagerTests(unittest.TestCase):
    def test_adobe_msi_install_command_is_normalized_to_uninstall(self):
        entry = {
            "command": "MsiExec.exe /I{AC76BA86-1033-1033-7760-BC15014EA700}",
            "product_code": "{AC76BA86-1033-1033-7760-BC15014EA700}",
            "windows_installer": True,
        }
        executable, arguments = manager._build_uninstall_invocation(entry)

        self.assertTrue(executable.lower().endswith(r"system32\msiexec.exe"))
        self.assertIn("/x", arguments.lower())
        self.assertNotIn("/i{", arguments.lower())
        self.assertIn(entry["product_code"], arguments)
        self.assertIn("/passive", arguments.lower())
        self.assertIn("/norestart", arguments.lower())
        self.assertIn("REBOOT=ReallySuppress", arguments)

    def test_unquoted_exe_uninstall_path_with_spaces_stays_intact(self):
        executable, arguments = manager._build_uninstall_invocation(
            {
                "command": r"C:\Program Files\Vendor App\uninstall.exe --remove",
                "windows_installer": False,
            }
        )
        self.assertEqual(executable, r"C:\Program Files\Vendor App\uninstall.exe")
        self.assertEqual(arguments, "--remove")

    def test_kmplayer_remove_only_suffix_matches_safely(self):
        candidate = {
            "display_name": "KMPlayer 64X (remove only)",
            "publisher": "PandoraTV",
            "install_location": r"C:\Program Files\KMPlayer 64X",
        }
        score = manager._uninstall_match_score(
            candidate,
            ["KMPlayer 64X", "kmplayer"],
            publisher="PandoraTV",
            install_location=r"C:\Program Files\KMPlayer 64X",
        )
        self.assertGreaterEqual(score, 1000)

    def test_unrelated_partial_name_is_not_accepted_for_uninstall(self):
        candidate = {
            "display_name": "KMPlayer Codec Pack",
            "publisher": "Unknown",
            "install_location": r"C:\Program Files\Other",
        }
        score = manager._uninstall_match_score(candidate, ["KMPlayer 64X"])
        self.assertEqual(score, 0)

    def test_manual_fallback_opens_installed_apps_when_no_safe_match(self):
        package = {
            "id": "sample",
            "relative_path": "Sample/Setup.exe",
            "filename": "Setup.exe",
            "name": "Sample App",
            "is_installed": True,
        }
        with (
            mock.patch.object(manager, "scan_packages", return_value={"packages": [package]}),
            mock.patch.object(manager, "_find_uninstall_entry", return_value=None),
            mock.patch.object(manager, "_open_installed_apps_settings", return_value=True) as opener,
        ):
            result = manager.uninstall_package("Sample/Setup.exe")
        self.assertTrue(result["success"])
        self.assertTrue(result["manual_required"])
        opener.assert_called_once_with()

    def test_blocks_renamed_windows_binary(self):
        result = manager._validate_installer(
            r"C:\Packages\vlc.exe",
            {
                "product_name": "Microsoft Windows Operating System",
                "file_description": "Notepad",
                "publisher": "Microsoft Corporation",
                "original_filename": "NOTEPAD.EXE",
            },
            "vlc",
            {},
        )
        self.assertFalse(result["is_valid"])
        self.assertEqual(result["validation_code"], "identity_mismatch")
        self.assertFalse(result["auto_install_supported"])

    def test_accepts_windows_package_formats(self):
        for extension in (".msi", ".msp", ".msu", ".msix", ".msixbundle", ".appx", ".appxbundle"):
            with self.subTest(extension=extension):
                result = manager._validate_installer(
                    rf"C:\Packages\sample{extension}", {}, extension.lstrip("."), {}
                )
                self.assertTrue(result["is_valid"])
                self.assertTrue(result["auto_install_supported"])

    def test_msu_silent_command_suppresses_restart(self):
        command = manager._silent_install_command(
            {"full_path": r"C:\Packages\windows-update.msu"}
        )
        self.assertTrue(command[0].lower().endswith("wusa.exe"))
        self.assertIn("/quiet", command)
        self.assertIn("/norestart", command)

    def test_vlc_detection_uses_exact_aliases(self):
        apps = [
            {
                "name": "VLC media player",
                "version": "3.0.21",
                "publisher": "VideoLAN",
                "location": r"C:\Program Files\VideoLAN\VLC",
                "icon": r"C:\Program Files\VideoLAN\VLC\vlc.exe",
            },
            {
                "name": "Visual C++ Redistributable",
                "version": "14.0",
                "publisher": "Microsoft",
                "location": "",
                "icon": "",
            },
        ]
        with mock.patch.object(manager, "_resolve_known_executable", return_value=r"C:\Program Files\VideoLAN\VLC\vlc.exe"):
            detection = manager._detect_installed_package(
                apps,
                "VLC Media Player",
                "vlc-3.0.21-win64.exe",
                "VLC media player",
                "VideoLAN",
                "vlc",
            )
        self.assertTrue(detection["is_installed"])
        self.assertEqual(detection["installed_version"], "3.0.21")
        self.assertEqual(detection["matched_app_name"], "VLC media player")

    def test_unknown_executable_has_no_silent_fallback(self):
        package = {
            "full_path": r"C:\Packages\CustomSetup.exe",
            "installer_type": "unknown",
            "silent_arguments": "",
        }
        self.assertEqual(manager._get_silent_args(package), "")
        self.assertEqual(manager._silent_install_command(package), [])

    def test_scan_includes_msi_and_blocks_masquerading_exe(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            msi_path = os.path.join(temp_dir, "Agent.msi")
            fake_path = os.path.join(temp_dir, "vlc.exe")
            open(msi_path, "wb").close()
            open(fake_path, "wb").close()

            fake_meta = {
                "product_name": "Microsoft Windows Operating System",
                "file_description": "Notepad",
                "publisher": "Microsoft Corporation",
                "version": "10.0",
                "original_filename": "NOTEPAD.EXE",
                "display_name": "Notepad",
            }
            with (
                mock.patch.object(manager, "get_packages_directory", return_value=temp_dir),
                mock.patch.object(manager, "get_all_installed_registry_apps", return_value=[]),
                mock.patch.object(manager, "_extract_icons_batch", return_value={}),
                mock.patch.object(manager, "_extract_exe_metadata", return_value=fake_meta),
                mock.patch.object(manager, "_resolve_known_executable", return_value=None),
            ):
                result = manager.scan_packages(temp_dir)

        self.assertEqual(result["summary"]["total_packages"], 2)
        self.assertEqual(result["summary"]["valid_packages"], 1)
        self.assertEqual(result["summary"]["blocked_packages"], 1)
        formats = {item["filename"]: item["package_format"] for item in result["packages"]}
        self.assertEqual(formats["Agent.msi"], "MSI")

    def test_wub_and_portable_tools_classified_as_portable_tool(self):
        for tool_name in ("Wub.exe", "Wub_x64.exe", "dcontrol.exe", "rufus.exe", "AnyDesk.exe"):
            with self.subTest(tool=tool_name):
                result = manager._validate_installer(
                    rf"C:\Packages\{tool_name}",
                    {"product_name": "", "file_description": "", "publisher": ""},
                    "unknown",
                    {},
                )
                self.assertTrue(result["is_valid"])
                self.assertTrue(result["is_portable_tool"])
                self.assertTrue(result["can_open_tool"])
                self.assertFalse(result["auto_install_supported"])
                self.assertFalse(result["manual_install_supported"])
                self.assertEqual(result["validation_code"], "portable_tool")

    def test_scan_packages_marks_wub_with_open_action_and_installed_path(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            wub_path = os.path.join(temp_dir, "Wub_x64.exe")
            with open(wub_path, "wb") as f:
                f.write(b"MZ" + b"\x00" * 100)

            wub_meta = {
                "product_name": "Windows Update Blocker",
                "file_description": "Windows Update Blocker v1.8",
                "publisher": "Sordum.org",
                "version": "1.8",
                "original_filename": "Wub_x64.exe",
                "display_name": "Windows Update Blocker",
            }
            with (
                mock.patch.object(manager, "get_packages_directory", return_value=temp_dir),
                mock.patch.object(manager, "get_all_installed_registry_apps", return_value=[]),
                mock.patch.object(manager, "_extract_icons_batch", return_value={}),
                mock.patch.object(manager, "_extract_exe_metadata", return_value=wub_meta),
                mock.patch.object(manager, "_resolve_known_executable", return_value=None),
            ):
                result = manager.scan_packages(temp_dir)

        self.assertEqual(result["summary"]["total_packages"], 1)
        pkg = result["packages"][0]
        self.assertTrue(pkg["is_portable_tool"])
        self.assertTrue(pkg["can_open_tool"])
        self.assertFalse(pkg["install_allowed"])
        self.assertEqual(pkg["installed_exe_path"], wub_path)
        self.assertEqual(pkg["name"], "Windows Update Blocker")
        self.assertEqual(pkg["status"], "Ready to Run")


if __name__ == "__main__":
    unittest.main()
