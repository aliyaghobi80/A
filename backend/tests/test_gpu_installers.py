# backend/tests/test_gpu_installers.py
"""
Comprehensive Unit Test Suite for GPU Vendor Installation Subsystem.
Tests:
- Dedicated vendor classes (NvidiaGpuInstaller, AmdGpuInstaller, IntelGpuInstaller)
- can_handle matching on HWIDs and filenames
- Priority ordering (iGPU before dGPU; AMD -> Intel -> NVIDIA)
- Display settle delay post-installation
- Unified Adrenalin APU+dGPU package deduplication
- Unattended installation execution, silent switches, and exit code normalization
"""

import os
import shutil
import sys
import tempfile
import unittest
from unittest.mock import MagicMock, patch

BACKEND_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if BACKEND_DIR not in sys.path:
    sys.path.insert(0, BACKEND_DIR)

from drivers.gpu_installers import (
    GpuVendorInstaller,
    NvidiaGpuInstaller,
    AmdGpuInstaller,
    IntelGpuInstaller,
    get_gpu_installer,
    execute_gpu_settle_delay,
    is_igpu_package,
    gpu_priority_key,
    deduplicate_gpu_packages,
    DEFAULT_DISPLAY_SETTLE_SECONDS,
)


class TestGpuInstallers(unittest.TestCase):

    def setUp(self):
        self.test_dir = tempfile.mkdtemp(prefix="test_gpu_")

    def tearDown(self):
        shutil.rmtree(self.test_dir, ignore_errors=True)

    # -------------------------------------------------------------------------
    # 1. Vendor Classes & Matching
    # -------------------------------------------------------------------------
    def test_vendor_classes_inheritance_and_naming(self):
        nv = NvidiaGpuInstaller()
        amd = AmdGpuInstaller()
        intel = IntelGpuInstaller()

        self.assertIsInstance(nv, GpuVendorInstaller)
        self.assertIsInstance(amd, GpuVendorInstaller)
        self.assertIsInstance(intel, GpuVendorInstaller)

        self.assertEqual(nv.get_vendor_name(), "NVIDIA")
        self.assertEqual(amd.get_vendor_name(), "AMD")
        self.assertEqual(intel.get_vendor_name(), "Intel")

    def test_nvidia_can_handle(self):
        nv = NvidiaGpuInstaller()

        # Match by HWID
        pkg_hwid = {"hardware_ids": ["PCI\\VEN_10DE&DEV_28E0&SUBSYS_1234"]}
        self.assertTrue(nv.can_handle(pkg_hwid))

        # Match by filename
        pkg_name = {"installer_file": "551.86-desktop-win10-win11-64bit-international-dch-whql.exe"}
        self.assertTrue(nv.can_handle(pkg_name))

        # Negative test (AMD package)
        pkg_amd = {"hardware_ids": ["PCI\\VEN_1002&DEV_1638"], "installer_file": "radeon.exe"}
        self.assertFalse(nv.can_handle(pkg_amd))

    def test_amd_can_handle(self):
        amd = AmdGpuInstaller()

        # Match by HWID
        pkg_hwid = {"hardware_ids": ["PCI\\VEN_1002&DEV_73DF"]}
        self.assertTrue(amd.can_handle(pkg_hwid))

        # Match by filename / provider
        pkg_name = {"installer_file": "amd-software-adrenalin-edition.exe", "display_name": "AMD Software"}
        self.assertTrue(amd.can_handle(pkg_name))

        # Negative test (NVIDIA package)
        pkg_nv = {"hardware_ids": ["PCI\\VEN_10DE&DEV_1234"]}
        self.assertFalse(amd.can_handle(pkg_nv))

    def test_intel_can_handle(self):
        intel = IntelGpuInstaller()

        # Match by Intel display HWID
        pkg_hwid = {"hardware_ids": ["PCI\\VEN_8086&DEV_9A49"], "category": "gpu"}
        self.assertTrue(intel.can_handle(pkg_hwid))

        # Match by Intel graphics installer file
        pkg_name = {"installer_file": "gfx_win_101.5382.exe", "category": "gpu"}
        self.assertTrue(intel.can_handle(pkg_name))

        # Negative test
        pkg_other = {"hardware_ids": ["PCI\\VEN_10EC&DEV_8168"], "category": "lan"}
        self.assertFalse(intel.can_handle(pkg_other))

    def test_get_gpu_installer_factory(self):
        pkg_nv = {"hardware_ids": ["PCI\\VEN_10DE&DEV_2504"]}
        pkg_amd = {"hardware_ids": ["PCI\\VEN_1002&DEV_67DF"]}
        pkg_intel = {"hardware_ids": ["PCI\\VEN_8086&DEV_5690"], "category": "gpu"}
        pkg_unknown = {"hardware_ids": ["PCI\\VEN_9999&DEV_0000"]}

        self.assertIsInstance(get_gpu_installer(pkg_nv), NvidiaGpuInstaller)
        self.assertIsInstance(get_gpu_installer(pkg_amd), AmdGpuInstaller)
        self.assertIsInstance(get_gpu_installer(pkg_intel), IntelGpuInstaller)
        self.assertIsNone(get_gpu_installer(pkg_unknown))

    # -------------------------------------------------------------------------
    # 2. Priority Ordering (iGPU before dGPU; AMD -> Intel -> NVIDIA)
    # -------------------------------------------------------------------------
    def test_is_igpu_package_detection(self):
        # iGPU packages
        self.assertTrue(is_igpu_package({"display_name": "Intel Iris Xe Graphics"}))
        self.assertTrue(is_igpu_package({"display_name": "Intel UHD Graphics 630"}))
        self.assertTrue(is_igpu_package({"display_name": "AMD Radeon(TM) Graphics APU"}))
        self.assertTrue(is_igpu_package({"gpu_type": "igpu"}))
        self.assertTrue(is_igpu_package({"is_igpu": True}))

        # dGPU packages
        self.assertFalse(is_igpu_package({"display_name": "NVIDIA GeForce RTX 4070"}))
        self.assertFalse(is_igpu_package({"hardware_ids": ["PCI\\VEN_10DE&DEV_28E0"]}))
        self.assertFalse(is_igpu_package({"display_name": "Intel Arc A770M"}))

    def test_gpu_priority_key_sorting(self):
        pkg_nv_dgpu = {"display_name": "NVIDIA GeForce RTX 3060", "hardware_ids": ["PCI\\VEN_10DE&DEV_2504"]}
        pkg_intel_dgpu = {"display_name": "Intel Arc A770", "hardware_ids": ["PCI\\VEN_8086&DEV_5690"]}
        pkg_intel_igpu = {"display_name": "Intel UHD Graphics", "is_igpu": True, "hardware_ids": ["PCI\\VEN_8086&DEV_9A49"]}
        pkg_amd_apu = {"display_name": "AMD Radeon Vega APU", "is_igpu": True, "hardware_ids": ["PCI\\VEN_1002&DEV_1638"]}

        # Sorting key structure: (is_dgpu: 0 or 1, vendor_order: 0=AMD, 1=Intel, 2=NVIDIA, name)
        key_amd_apu = gpu_priority_key(pkg_amd_apu)
        key_intel_igpu = gpu_priority_key(pkg_intel_igpu)
        key_intel_dgpu = gpu_priority_key(pkg_intel_dgpu)
        key_nv_dgpu = gpu_priority_key(pkg_nv_dgpu)

        # 1. iGPU before dGPU:
        self.assertEqual(key_amd_apu[0], 0)
        self.assertEqual(key_intel_igpu[0], 0)
        self.assertEqual(key_intel_dgpu[0], 1)
        self.assertEqual(key_nv_dgpu[0], 1)

        # 2. Vendor order: AMD (0) -> Intel (1) -> NVIDIA (2):
        self.assertLess(key_amd_apu, key_intel_igpu)
        self.assertLess(key_intel_igpu, key_intel_dgpu)
        self.assertLess(key_intel_dgpu, key_nv_dgpu)

    # -------------------------------------------------------------------------
    # 3. Display Settle Delay
    # -------------------------------------------------------------------------
    def test_display_settle_delay_default_and_custom(self):
        self.assertEqual(DEFAULT_DISPLAY_SETTLE_SECONDS, 8.0)

        with patch("time.sleep") as mock_sleep:
            execute_gpu_settle_delay()
            mock_sleep.assert_called_with(8.0)

        with patch("time.sleep") as mock_sleep:
            execute_gpu_settle_delay(5.0)
            mock_sleep.assert_called_with(5.0)

    # -------------------------------------------------------------------------
    # 4. Unified Adrenalin APU + dGPU Package Deduplication
    # -------------------------------------------------------------------------
    def test_deduplicate_gpu_packages_identical_paths(self):
        pkg_apu = {
            "package_id": "pkg_apu",
            "category": "gpu",
            "display_name": "AMD Radeon Graphics (APU)",
            "installer_path": r"C:\Drivers\AMD_Adrenalin\Setup.exe",
            "hardware_ids": ["PCI\\VEN_1002&DEV_1638"],
        }
        pkg_dgpu = {
            "package_id": "pkg_dgpu",
            "category": "gpu",
            "display_name": "AMD Radeon RX 6600M (dGPU)",
            "installer_path": r"C:\Drivers\AMD_Adrenalin\Setup.exe",
            "hardware_ids": ["PCI\\VEN_1002&DEV_73DF"],
        }
        pkg_audio = {
            "package_id": "pkg_audio",
            "category": "audio",
            "display_name": "Realtek Audio",
            "installer_path": r"C:\Drivers\Realtek\Setup.exe",
        }

        # APU and dGPU share identical unified installer path
        deduped = deduplicate_gpu_packages([pkg_apu, pkg_dgpu, pkg_audio])

        # Exactly one GPU package should remain, and non-GPU packages preserved
        gpu_pkgs = [p for p in deduped if p["category"] == "gpu"]
        self.assertEqual(len(gpu_pkgs), 1)
        self.assertEqual(gpu_pkgs[0]["package_id"], "pkg_apu")
        self.assertIn(pkg_audio, deduped)

    def test_deduplicate_gpu_packages_identical_hwids(self):
        pkg1 = {
            "package_id": "pkg1",
            "category": "gpu",
            "display_name": "NVIDIA Driver 1",
            "installer_path": r"C:\Drivers\NV1\setup.exe",
            "hardware_ids": ["PCI\\VEN_10DE&DEV_2504"],
        }
        pkg2 = {
            "package_id": "pkg2",
            "category": "gpu",
            "display_name": "NVIDIA Driver 2",
            "installer_path": r"C:\Drivers\NV2\setup.exe",
            "hardware_ids": ["PCI\\VEN_10DE&DEV_2504"],
        }
        deduped = deduplicate_gpu_packages([pkg1, pkg2])
        self.assertEqual(len(deduped), 1)

    # -------------------------------------------------------------------------
    # 5. Unattended GPU Execution & Exit Codes
    # -------------------------------------------------------------------------
    def test_nvidia_install_execution_exit_codes(self):
        nv = NvidiaGpuInstaller()
        setup_exe = os.path.join(self.test_dir, "setup.exe")
        with open(setup_exe, "wb") as f:
            f.write(b"MZ" + b"\x00" * 100)

        pkg = {
            "installer_path": setup_exe,
            "silent_args": ["-s", "-noreboot"],
        }

        # Success (Exit 0)
        with patch("packages.manager._run_elevated_and_wait", return_value=0):
            res = nv.install(pkg)
            self.assertTrue(res["success"])
            self.assertEqual(res["exit_code"], 0)
            self.assertFalse(res["reboot"])

        # Reboot required (Exit 3010)
        with patch("packages.manager._run_elevated_and_wait", return_value=3010):
            res = nv.install(pkg)
            self.assertTrue(res["success"])
            self.assertEqual(res["exit_code"], 3010)
            self.assertTrue(res["reboot_required"])

        # Timeout (Exit -2)
        with patch("packages.manager._run_elevated_and_wait", return_value=-2):
            res = nv.install(pkg)
            self.assertFalse(res["success"])
            self.assertEqual(res["exit_code"], -2)
            self.assertIn("تایم‌اوت", res["message"])

    def test_amd_install_execution(self):
        amd = AmdGpuInstaller()
        setup_exe = os.path.join(self.test_dir, "amd_setup.exe")
        with open(setup_exe, "wb") as f:
            f.write(b"MZ" + b"\x00" * 100)

        pkg = {
            "installer_path": setup_exe,
            "silent_args": ["-INSTALL", "-OUTPUT", "screen", "-NORESTART"],
        }

        with patch("packages.manager._run_elevated_and_wait", return_value=0):
            res = amd.install(pkg)
            self.assertTrue(res["success"])
            self.assertEqual(res["exit_code"], 0)

    def test_intel_install_execution_modern_switches(self):
        intel = IntelGpuInstaller()
        setup_exe = os.path.join(self.test_dir, "Installer.exe")
        with open(setup_exe, "wb") as f:
            f.write(b"MZ" + b"\x00" * 100)

        pkg = {
            "installer_path": setup_exe,
            # No explicit silent args: should pick modern Arc switch ["--overwrite", "-s"]
        }

        with patch("packages.manager._run_elevated_and_wait", return_value=0) as mock_run:
            res = intel.install(pkg)
            self.assertTrue(res["success"])
            # Verify modern silent switches were passed
            cmd_called = mock_run.call_args[0][0]
            self.assertIn("--overwrite", cmd_called)
            self.assertIn("-s", cmd_called)

    def test_install_missing_file_fails_gracefully(self):
        nv = NvidiaGpuInstaller()
        pkg = {"installer_path": r"C:\Ghost\nonexistent_setup.exe"}
        res = nv.install(pkg)
        self.assertFalse(res["success"])
        self.assertEqual(res["exit_code"], -1)
        self.assertIn("یافت نشد", res["message"])


if __name__ == "__main__":
    unittest.main()
