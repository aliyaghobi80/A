import os
import tempfile
import unittest
from unittest import mock

from packages import manager


class PackageManagerTests(unittest.TestCase):
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


if __name__ == "__main__":
    unittest.main()
