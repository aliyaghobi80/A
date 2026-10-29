# backend/tests/test_package_inspector.py
"""
Comprehensive Unit Test Suite for Driver Package Inspector & Profiler.
Tests:
- Zero guessed switches fallback (unknown packages return empty list [])
- Metadata parsing (.cva, InstallStep.txt, README)
- Vendor profiles (Samsung, Toshiba/Dynabook, Huawei, Goodix, ASUS, Lenovo, HP, Dell, NVIDIA, AMD, Intel)
- Exclusions of diagnostics, cleanup utilities, firmware/BIOS flashers, uninstallers
- Concurrency classification (is_barrier and is_parallel_safe conforming to CONTRACT.md § 3)
- Normalized DriverPackage dictionary schema compliance (CONTRACT.md § 2)
"""

import os
import shutil
import sys
import tempfile
import unittest

BACKEND_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if BACKEND_DIR not in sys.path:
    sys.path.insert(0, BACKEND_DIR)

from drivers.package_inspector import (
    DriverPackage,
    inspect_driver_package,
    get_driver_exe_silent_args,
    is_excluded_utility,
    classify_concurrency_flags,
    classify_driver_category,
    _parse_helper_metadata,
    parse_inf_file,
    DRIVER_CATEGORIES,
)


class TestPackageInspector(unittest.TestCase):

    def setUp(self):
        self.test_dir = tempfile.mkdtemp(prefix="test_inspector_")

    def tearDown(self):
        shutil.rmtree(self.test_dir, ignore_errors=True)

    # -------------------------------------------------------------------------
    # 1. Zero Guessed Switches Fallback
    # -------------------------------------------------------------------------
    def test_zero_guessed_switches_for_unknown_package(self):
        unknown_files = [
            "custom_installer.exe",
            "my_special_setup.exe",
            "random_oem_tool_v2.exe",
            "unknown_utility.exe",
        ]
        for name in unknown_files:
            switches = get_driver_exe_silent_args(name)
            self.assertEqual(
                switches,
                [],
                f"Unknown package {name} received guessed switches: {switches}",
            )

    # -------------------------------------------------------------------------
    # 2. Vendor Profiles
    # -------------------------------------------------------------------------
    def test_samsung_vendor_profile(self):
        switches = get_driver_exe_silent_args("samsung_wlan_installer.exe")
        self.assertEqual(switches, ["/s", "/norestart"])

        # Also test via path
        switches_path = get_driver_exe_silent_args(r"C:\Drivers\Samsung\setup.exe")
        self.assertEqual(switches_path, ["/s", "/norestart"])

    def test_toshiba_dynabook_vendor_profile(self):
        switches_toshiba = get_driver_exe_silent_args("toshiba_touchpad.exe")
        self.assertEqual(switches_toshiba, ["/s", "/norestart"])

        switches_dynabook = get_driver_exe_silent_args("dynabook_audio.exe")
        self.assertEqual(switches_dynabook, ["/s", "/norestart"])

    def test_huawei_vendor_profile(self):
        switches = get_driver_exe_silent_args("huawei_fingerprint_setup.exe")
        self.assertEqual(switches, ["/s", "/norestart"])

    def test_goodix_component_profile(self):
        switches = get_driver_exe_silent_args("goodix_touch_setup.exe")
        self.assertEqual(switches, ["/s", "/norestart"])

    def test_asus_vendor_profile(self):
        switches = get_driver_exe_silent_args("AsusSetup.exe")
        self.assertEqual(switches, ["-s", "-norestart"])

    def test_lenovo_vendor_profile(self):
        # Lenovo SoftPaq style: e.g. u1lan01us14.exe or containing lenovo
        switches_sp = get_driver_exe_silent_args("u1lan01us14.exe")
        self.assertEqual(switches_sp, ["/VERYSILENT", "/NORESTART", "/SUPPRESSMSGBOXES"])

        switches_named = get_driver_exe_silent_args("lenovo_audio.exe")
        self.assertEqual(switches_named, ["/VERYSILENT", "/NORESTART", "/SUPPRESSMSGBOXES"])

    def test_hp_vendor_profile(self):
        # HP SoftPaq: sp12345.exe
        switches = get_driver_exe_silent_args("sp98765.exe")
        self.assertEqual(switches, ["/s", "-s"])

    def test_dell_vendor_profile(self):
        # Dell DUP: e.g. Dell-Audio-Driver_win64.exe
        switches = get_driver_exe_silent_args("dell_network_driver.exe")
        self.assertEqual(switches, ["/s"])

    def test_gpu_vendor_profiles(self):
        # NVIDIA
        nvidia_switches = get_driver_exe_silent_args("551.86-desktop-win10-win11-64bit-international-dch-whql.exe")
        self.assertEqual(nvidia_switches, ["-s", "-noreboot"])

        # AMD Radeon
        amd_switches = get_driver_exe_silent_args("amd-software-adrenalin-edition.exe")
        self.assertEqual(amd_switches, ["-INSTALL", "-OUTPUT", "screen", "-NORESTART"])

        # Intel Graphics Modern
        intel_arc_switches = get_driver_exe_silent_args(r"C:\Drivers\gfx_win_101.5382\Installer.exe")
        self.assertEqual(intel_arc_switches, ["--overwrite", "-s"])

    # -------------------------------------------------------------------------
    # 3. Metadata Parsing (.cva, InstallStep.txt, README)
    # -------------------------------------------------------------------------
    def test_parse_helper_metadata_cva(self):
        pkg_dir = os.path.join(self.test_dir, "hp_sp_driver")
        os.makedirs(pkg_dir, exist_ok=True)

        setup_exe = os.path.join(pkg_dir, "Setup.exe")
        with open(setup_exe, "wb") as f:
            f.write(b"MZ" + b"\x00" * 100)

        cva_file = os.path.join(pkg_dir, "sp12345.cva")
        with open(cva_file, "w", encoding="utf-8") as f:
            f.write(
                "[Information]\n"
                "Software Title=Realtek High Definition Audio Driver\n"
                "Version=6.0.8924.1\n"
                "[Install]\n"
                "SilentInstall=Setup.exe -s -norestart\n"
            )

        meta = _parse_helper_metadata(pkg_dir)
        self.assertEqual(meta["title"], "Realtek High Definition Audio Driver")
        self.assertEqual(meta["version"], "6.0.8924.1")
        self.assertEqual(meta["entrypoint"], setup_exe)
        self.assertEqual(meta["method"], "setup_exe")
        self.assertEqual(meta["silent_args"], ["-s", "-norestart"])

    def test_parse_helper_metadata_installstep_txt(self):
        pkg_dir = os.path.join(self.test_dir, "asus_installstep")
        os.makedirs(pkg_dir, exist_ok=True)

        asus_setup = os.path.join(pkg_dir, "AsusSetup.exe")
        with open(asus_setup, "wb") as f:
            f.write(b"MZ" + b"\x00" * 100)

        step_file = os.path.join(pkg_dir, "InstallStep.txt")
        with open(step_file, "w", encoding="utf-8") as f:
            f.write("Step 1: Execute AsusSetup.exe -s\n")

        meta = _parse_helper_metadata(pkg_dir)
        self.assertEqual(meta["entrypoint"], asus_setup)
        self.assertEqual(meta["method"], "asus_setup")
        self.assertIn("-s", meta["silent_args"])

    def test_parse_helper_metadata_readme(self):
        pkg_dir = os.path.join(self.test_dir, "readme_driver")
        os.makedirs(pkg_dir, exist_ok=True)

        installer = os.path.join(pkg_dir, "SilentInstall.bat")
        with open(installer, "w", encoding="utf-8") as f:
            f.write("@echo off\r\npnputil /add-driver *.inf /install\r\n")

        readme_file = os.path.join(pkg_dir, "README.txt")
        with open(readme_file, "w", encoding="utf-8") as f:
            f.write("Installation Instructions:\nRun SilentInstall.bat /q\n")

        meta = _parse_helper_metadata(pkg_dir)
        self.assertEqual(meta["entrypoint"], installer)
        self.assertEqual(meta["method"], "script")
        self.assertEqual(meta["silent_args"], ["/q"])

    # -------------------------------------------------------------------------
    # 4. Exclusion Filter (Diagnostics, Cleanup, Firmware/BIOS, Uninstallers)
    # -------------------------------------------------------------------------
    def test_exclusion_filter_diagnostics(self):
        diagnostic_paths = [
            "SupportAssistx64.exe",
            "DellCommandUpdate.exe",
            "LenovoDiagnostics.exe",
            "hwdiagnostic.exe",
            "C:\\Drivers\\pc-doctor\\setup.exe",
            "diags_tool.exe",
        ]
        for p in diagnostic_paths:
            self.assertTrue(is_excluded_utility(p), f"Diagnostic {p} was not excluded!")

    def test_exclusion_filter_cleanup(self):
        cleanup_paths = [
            "DDU.exe",
            "DisplayDriverUninstaller.exe",
            "AMDCleanupUtility.exe",
            "DriverCleanerPro.exe",
            "C:\\Tools\\remover.exe",
        ]
        for p in cleanup_paths:
            self.assertTrue(is_excluded_utility(p), f"Cleanup tool {p} was not excluded!")

    def test_exclusion_filter_firmware_and_bios(self):
        firmware_paths = [
            "flash.bat",
            "flash.exe",
            "fpt.exe",
            "afudos.exe",
            "FWUpdate.exe",
            "MEUpdate.exe",
            "biosflash.exe",
            "InsydeFlash.exe",
            "HPFlash.exe",
            "bios_update.exe",
            "C:\\Drivers\\Firmware\\setup.exe",
        ]
        for p in firmware_paths:
            self.assertTrue(is_excluded_utility(p), f"Firmware/BIOS {p} was not excluded!")

    def test_exclusion_filter_uninstallers(self):
        uninstaller_paths = [
            "uninstall.exe",
            "unins000.exe",
            "unins001.exe",
            "Realtek_Uninstaller.exe",
        ]
        for p in uninstaller_paths:
            self.assertTrue(is_excluded_utility(p), f"Uninstaller {p} was not excluded!")

    def test_inspect_driver_package_ignores_excluded_utilities(self):
        ddu_dir = os.path.join(self.test_dir, "DDU_v18.0")
        os.makedirs(ddu_dir, exist_ok=True)
        exe = os.path.join(ddu_dir, "Display Driver Uninstaller.exe")
        with open(exe, "wb") as f:
            f.write(b"MZ" + b"\x00" * 500)

        pkg = inspect_driver_package(ddu_dir, self.test_dir)
        self.assertIsNone(pkg, "Excluded utility was inspected as a valid driver package!")

    # -------------------------------------------------------------------------
    # 5. Concurrency Classification (CONTRACT.md § 3)
    # -------------------------------------------------------------------------
    def test_concurrency_classification_barriers(self):
        # 1. Chipset, Platform, Storage
        self.assertEqual(classify_concurrency_flags("chipset", "setup_exe", ["-s"]), (True, False))
        self.assertEqual(classify_concurrency_flags("system_mei", "setup_exe", ["-s"]), (True, False))
        self.assertEqual(classify_concurrency_flags("storage", "setup_exe", ["-s"]), (True, False))

        # 2. GPU
        self.assertEqual(classify_concurrency_flags("gpu", "setup_exe", ["-s", "-noreboot"]), (True, False))

        # 3. MSI packages
        self.assertEqual(classify_concurrency_flags("audio", "msiexec", ["/qn"]), (True, False))

        # 4. PnPUtil INF batches
        self.assertEqual(classify_concurrency_flags("lan", "pnputil", []), (True, False))
        self.assertEqual(classify_concurrency_flags("wifi", "inf_pnputil", []), (True, False))

        # 5. Vendor batch scripts
        self.assertEqual(classify_concurrency_flags("touchpad", "script", []), (True, False))

        # 6. Unknown / Unswitched installers (silent_args is empty)
        self.assertEqual(classify_concurrency_flags("audio", "setup_exe", []), (True, False))

    def test_concurrency_classification_parallel_safe(self):
        # Parallel-safe categories with verified silent args
        parallel_categories = ["audio", "lan", "wifi", "bluetooth", "touchpad", "card_reader", "camera", "usb"]
        for cat in parallel_categories:
            barrier, parallel = classify_concurrency_flags(cat, "setup_exe", ["/s", "/norestart"])
            self.assertFalse(barrier, f"Category {cat} should not be a barrier")
            self.assertTrue(parallel, f"Category {cat} should be parallel-safe")

        # AsusSetup method is also parallel-safe
        barrier, parallel = classify_concurrency_flags("wifi", "asus_setup", ["-s", "-norestart"])
        self.assertFalse(barrier)
        self.assertTrue(parallel)

    # -------------------------------------------------------------------------
    # 6. Normalized DriverPackage Schema Compliance (CONTRACT.md § 2)
    # -------------------------------------------------------------------------
    def test_driver_package_schema_contract_compliance(self):
        pkg = DriverPackage(
            package_id="drv_pkg_test12345678",
            display_name="Realtek High Definition Audio Driver",
            category="audio",
            category_fa="کارت صدا و مالتی‌مدیا",
            package_type="folder",
            source_path=r"C:\Drivers\Realtek_Audio",
            relative_path="Realtek_Audio",
            installer_file=r"C:\Drivers\Realtek_Audio\setup.exe",
            install_method="setup_exe",
            silent_args=["-s", "-norestart"],
            size_bytes=104857600,
            fingerprint="sha256_mock_fingerprint",
            hardware_ids=["HDAUDIO\\FUNC_01&VEN_10EC&DEV_0256"],
            driver_version="6.0.9239.1",
            driver_date="2024-03-15",
            provider="Realtek Semiconductor Corp.",
            requires_reboot=False,
        )

        d = pkg.to_dict()

        # Verify all mandatory schema keys from CONTRACT.md § 2.1
        required_keys = [
            "package_id", "display_name", "category", "category_fa", "category_order",
            "package_type", "source_path", "relative_path", "installer_file", "installer_path",
            "install_method", "silent_args", "is_barrier", "is_parallel_safe", "resource_tag",
            "timeout_seconds", "requires_reboot", "hardware_ids", "driver_version",
            "driver_date", "provider",
        ]
        for key in required_keys:
            self.assertIn(key, d, f"Missing required CONTRACT.md field: {key}")

        # Check values
        self.assertEqual(d["package_id"], "drv_pkg_test12345678")
        self.assertEqual(d["is_barrier"], False)
        self.assertEqual(d["is_parallel_safe"], True)
        self.assertEqual(d["resource_tag"], "audio")
        self.assertEqual(d["timeout_seconds"], 300)
        self.assertEqual(d["category_order"], 7)


if __name__ == "__main__":
    unittest.main()
