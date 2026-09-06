# backend/tests/test_driver_manager.py
"""
Comprehensive Unit Test Suite for Intelligent Driver Manager (Phase 5).
Tests all core scenarios:
- Test A: Simple EXE driver (Audio/setup.exe)
- Test B: ASUS-style multi-file package (ASUSSetup.exe prioritized)
- Test C: Lenovo-style random EXE (identified from folder & metadata)
- Test D: ZIP package (safe extraction & inspection)
- Test E: INF driver (Hardware IDs extracted, PnPUtil method)
- Test F: Duplicate prevention & deduplication
- Test G: Already installed driver (version comparison, up-to-date skip)
- Test H: Wrong driver / Not Applicable (NVIDIA on non-matching system)
- Test I: Driver problem device (Code 28 priority matching)
- Test J: Multiple selected drivers & 9-tier priority queue ordering
"""

import os
import shutil
import sys
import tempfile
import unittest
import zipfile

# Ensure backend root is in sys.path
BACKEND_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if BACKEND_DIR not in sys.path:
    sys.path.insert(0, BACKEND_DIR)

from drivers.package_inspector import (
    inspect_driver_package,
    classify_driver_category,
    parse_inf_file,
    _safe_extract_zip,
)
from drivers.hardware_matcher import (
    match_package_to_hardware,
    _compare_driver_versions,
)
from drivers.deduplicator import (
    generate_package_fingerprint,
    deduplicate_driver_packages,
)
from drivers.queue_manager import sort_driver_queue, PRIORITY_ORDER


class TestIntelligentDriverManager(unittest.TestCase):

    def setUp(self):
        self.test_dir = tempfile.mkdtemp(prefix="test_drivers_")

    def tearDown(self):
        shutil.rmtree(self.test_dir, ignore_errors=True)

    # -------------------------------------------------------------------------
    # Test A: Simple EXE driver
    # -------------------------------------------------------------------------
    def test_a_simple_exe_driver(self):
        audio_dir = os.path.join(self.test_dir, "Realtek_Audio")
        os.makedirs(audio_dir, exist_ok=True)
        setup_exe = os.path.join(audio_dir, "setup.exe")
        with open(setup_exe, "wb") as f:
            f.write(b"MZ" + b"\x00" * 2000)

        pkg = inspect_driver_package(audio_dir, self.test_dir)
        self.assertIsNotNone(pkg)
        self.assertEqual(pkg.category, "audio")
        self.assertIn("setup.exe", pkg.installer_file.lower())
        self.assertEqual(pkg.install_method, "setup_exe")
        self.assertIn("/s", pkg.silent_args)

    # -------------------------------------------------------------------------
    # Test B: ASUS-style multi-file package
    # -------------------------------------------------------------------------
    def test_b_asus_style_multifile_package(self):
        asus_dir = os.path.join(self.test_dir, "ASUS_LAN")
        os.makedirs(asus_dir, exist_ok=True)
        for name in ("setup.exe", "install.exe", "ASUSSetup.exe", "silentinstall.exe"):
            with open(os.path.join(asus_dir, name), "wb") as f:
                f.write(b"MZ" + b"\x00" * 1000)

        pkg = inspect_driver_package(asus_dir, self.test_dir)
        self.assertIsNotNone(pkg)
        # ASUSSetup.exe must be the primary candidate, not setup.exe or install.exe
        self.assertEqual(os.path.basename(pkg.installer_file).lower(), "asussetup.exe")
        self.assertEqual(pkg.install_method, "asus_setup")
        # Other files should be listed in alternative_installers
        alts = [os.path.basename(a).lower() for a in pkg.alternative_installers]
        self.assertIn("setup.exe", alts)
        self.assertIn("install.exe", alts)

    # -------------------------------------------------------------------------
    # Test C: Lenovo-style random EXE
    # -------------------------------------------------------------------------
    def test_c_lenovo_random_exe(self):
        lenovo_dir = os.path.join(self.test_dir, "Lenovo_Bluetooth_Driver")
        os.makedirs(lenovo_dir, exist_ok=True)
        random_exe = os.path.join(lenovo_dir, "alsdlkasdjflasjdfsd.exe")
        with open(random_exe, "wb") as f:
            f.write(b"MZ" + b"\x00" * 1500)

        pkg = inspect_driver_package(lenovo_dir, self.test_dir)
        self.assertIsNotNone(pkg)
        self.assertEqual(pkg.category, "bluetooth")
        # Display name should reflect Bluetooth Driver, not the gibberish exe name
        self.assertIn("Bluetooth", pkg.display_name)
        self.assertEqual(os.path.basename(pkg.installer_file).lower(), "alsdlkasdjflasjdfsd.exe")

    # -------------------------------------------------------------------------
    # Test D: ZIP package
    # -------------------------------------------------------------------------
    def test_d_zip_package(self):
        zip_path = os.path.join(self.test_dir, "Intel_WiFi.zip")
        with zipfile.ZipFile(zip_path, "w") as zf:
            zf.writestr("drivers/netwtw08.inf", "[Version]\nSignature=\"$Windows NT$\"\nClass=Net\nProvider=Intel\nDriverVer=05/12/2023,22.180.0.4\n")
            zf.writestr("Setup.exe", b"MZ" + b"\x00" * 500)

        pkg = inspect_driver_package(zip_path, self.test_dir)
        self.assertIsNotNone(pkg)
        self.assertEqual(pkg.package_type, "zip")
        self.assertEqual(pkg.category, "wifi")
        self.assertIn("22.180.0.4", pkg.driver_version)
        # Cleanup temporary extraction directory
        if pkg.extraction_dir and os.path.isdir(pkg.extraction_dir):
            shutil.rmtree(pkg.extraction_dir, ignore_errors=True)

    # -------------------------------------------------------------------------
    # Test E: INF driver package
    # -------------------------------------------------------------------------
    def test_e_inf_driver_package(self):
        lan_dir = os.path.join(self.test_dir, "Realtek_LAN")
        os.makedirs(lan_dir, exist_ok=True)
        inf_content = """
[Version]
Signature="$Windows NT$"
Class=Net
ClassGUID={4d36e972-e325-11ce-bfc1-08002be10318}
Provider=%Realtek%
DriverVer=03/15/2024,11.18.0.0

[Manufacturer]
%Realtek%=Realtek,NTamd64

[Realtek.NTamd64]
%RTL8168.DeviceDesc%=RTL8168.ndi, PCI\\VEN_10EC&DEV_8168&SUBSYS_123410EC

[Strings]
Realtek="Realtek Semiconductor Corp."
RTL8168.DeviceDesc="Realtek PCIe GbE Family Controller"
"""
        inf_file = os.path.join(lan_dir, "rt640x64.inf")
        with open(inf_file, "w", encoding="utf-8") as f:
            f.write(inf_content)

        pkg = inspect_driver_package(lan_dir, self.test_dir)
        self.assertIsNotNone(pkg)
        self.assertEqual(pkg.category, "lan")
        self.assertEqual(pkg.driver_version, "11.18.0.0")
        self.assertIn("PCI\\VEN_10EC&DEV_8168", pkg.hardware_ids[0])
        self.assertEqual(pkg.install_method, "pnputil")

    # -------------------------------------------------------------------------
    # Test F: Duplicate prevention & deduplication
    # -------------------------------------------------------------------------
    def test_f_duplicate_prevention(self):
        pkg1 = {
            "package_id": "pkg_lan_v10",
            "display_name": "Realtek LAN Driver",
            "category": "lan",
            "driver_version": "10.50.0.0",
            "package_type": "folder",
            "hardware_ids": ["PCI\\VEN_10EC&DEV_8168&SUBSYS_1234"],
        }
        pkg2 = {
            "package_id": "pkg_lan_v11",
            "display_name": "Realtek LAN Driver (Newer)",
            "category": "lan",
            "driver_version": "11.20.0.0",
            "package_type": "folder",
            "hardware_ids": ["PCI\\VEN_10EC&DEV_8168&SUBSYS_5678"],
        }
        unique, dups = deduplicate_driver_packages([pkg1, pkg2])
        self.assertEqual(len(unique), 1)
        self.assertEqual(len(dups), 1)
        # Higher version (v11) must be preserved as active
        self.assertEqual(unique[0]["package_id"], "pkg_lan_v11")
        self.assertEqual(dups[0]["package_id"], "pkg_lan_v10")

    # -------------------------------------------------------------------------
    # Test G: Already installed (Up to date skip)
    # -------------------------------------------------------------------------
    def test_g_already_installed_skip(self):
        mock_hardware = [{
            "DeviceID": "PCI\\VEN_10EC&DEV_8168&SUBSYS_1234",
            "Name": "Realtek PCIe GbE Family Controller",
            "HardwareIDs": ["PCI\\VEN_10EC&DEV_8168&SUBSYS_1234"],
            "PNPClass": "Net",
            "ProblemCode": 0,
            "DriverVersion": "11.18.0.0",
        }]

        package_same = {
            "category": "lan",
            "display_name": "Realtek LAN Driver",
            "driver_version": "11.18.0.0",
            "hardware_ids": ["PCI\\VEN_10EC&DEV_8168"],
        }

        match = match_package_to_hardware(package_same, mock_hardware)
        self.assertTrue(match["is_matched"])
        self.assertEqual(match["status"], "up_to_date")
        self.assertEqual(match["recommendation"], "skip")
        self.assertEqual(match["confidence"], "HIGH")

    # -------------------------------------------------------------------------
    # Test H: Wrong driver / Not Applicable
    # -------------------------------------------------------------------------
    def test_h_wrong_driver_not_applicable(self):
        mock_hardware = [{
            "DeviceID": "PCI\\VEN_8086&DEV_9BC4",
            "Name": "Intel(R) UHD Graphics 630",
            "HardwareIDs": ["PCI\\VEN_8086&DEV_9BC4"],
            "PNPClass": "Display",
            "ProblemCode": 0,
            "DriverVersion": "31.0.101.2111",
        }]

        nvidia_pkg = {
            "category": "gpu",
            "display_name": "NVIDIA GeForce Game Ready Driver",
            "driver_version": "551.86",
            "hardware_ids": ["PCI\\VEN_10DE&DEV_2484"],  # RTX 3070
        }

        match = match_package_to_hardware(nvidia_pkg, mock_hardware)
        self.assertFalse(match["is_matched"])
        self.assertEqual(match["confidence"], "NOT_APPLICABLE")
        self.assertEqual(match["status"], "not_applicable")
        self.assertEqual(match["recommendation"], "skip")

    # -------------------------------------------------------------------------
    # Test I: Driver failure / Problem Code 28
    # -------------------------------------------------------------------------
    def test_i_driver_problem_prioritization(self):
        mock_hardware = [{
            "DeviceID": "PCI\\VEN_10EC&DEV_8168&SUBSYS_1234",
            "Name": "Ethernet Controller",
            "HardwareIDs": ["PCI\\VEN_10EC&DEV_8168"],
            "PNPClass": "Net",
            "ProblemCode": 28,  # Missing driver
            "DriverVersion": "",
        }]

        lan_pkg = {
            "category": "lan",
            "display_name": "Realtek LAN Driver",
            "driver_version": "11.18.0.0",
            "hardware_ids": ["PCI\\VEN_10EC&DEV_8168"],
        }

        match = match_package_to_hardware(lan_pkg, mock_hardware)
        self.assertTrue(match["is_matched"])
        self.assertEqual(match["status"], "needs_install")
        self.assertEqual(match["recommendation"], "recommended")
        self.assertEqual(match["confidence"], "HIGH")

    # -------------------------------------------------------------------------
    # Test J: Multiple selected drivers & 9-tier priority ordering
    # -------------------------------------------------------------------------
    def test_j_install_queue_priority_ordering(self):
        packages = [
            {"package_id": "pkg_audio", "category": "audio", "display_name": "Audio Driver"},
            {"package_id": "pkg_gpu", "category": "gpu", "display_name": "Graphics Driver"},
            {"package_id": "pkg_chipset", "category": "chipset", "display_name": "Intel Chipset Driver"},
            {"package_id": "pkg_lan", "category": "lan", "display_name": "Ethernet Driver"},
            {"package_id": "pkg_storage", "category": "storage", "display_name": "RST Storage Driver"},
            {"package_id": "pkg_wifi", "category": "wifi", "display_name": "Wi-Fi Driver"},
        ]

        sorted_queue = sort_driver_queue(packages)
        expected_order = ["chipset", "storage", "lan", "wifi", "audio", "gpu"]
        actual_order = [p["category"] for p in sorted_queue]
        self.assertEqual(actual_order, expected_order)


if __name__ == "__main__":
    unittest.main()
