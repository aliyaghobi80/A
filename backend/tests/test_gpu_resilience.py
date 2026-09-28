import os
import sys
import unittest
from unittest.mock import patch


sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from hardware import gpu


class GpuResilienceTests(unittest.TestCase):
    def test_controller_survives_pnp_query_failure(self):
        controller = {
            "Name": "Intel(R) Graphics",
            "AdapterRAM": 0,
            "DriverVersion": "32.0.101.6737",
            "VideoProcessor": "Intel(R) Graphics",
            "PNPDeviceID": r"PCI\VEN_8086&DEV_7D55",
        }
        with (
            patch.object(gpu, "run_powershell_json", side_effect=[[controller], None]),
            patch.object(gpu, "_get_registry_gpu_memory", return_value={}),
        ):
            result = gpu.get_gpu_info()

        self.assertEqual(len(result), 1)
        self.assertEqual(result[0]["name"], "Intel(R) Graphics")
        self.assertTrue(result[0]["is_integrated"])
        self.assertFalse(result[0]["needs_driver"])

    def test_registry_fallback_restores_intel_gpu(self):
        registry_device = {
            "Name": "Intel(R) Graphics",
            "Manufacturer": "Intel Corporation",
            "PNPDeviceID": r"PCI\VEN_8086&DEV_7D55",
            "DriverVersion": "32.0.101.6737",
            "ConfigManagerErrorCode": 0,
        }
        with (
            patch.object(gpu, "run_powershell_json", return_value=None),
            patch.object(gpu, "_get_registry_gpu_devices", return_value=[registry_device]),
            patch.object(gpu, "_get_registry_gpu_memory", return_value={}),
        ):
            result = gpu.get_gpu_info()

        self.assertEqual([item["name"] for item in result], ["Intel(R) Graphics"])

    def test_hybrid_graphics_preserves_both_adapters(self):
        controllers = [
            {
                "Name": "Intel(R) Graphics",
                "PNPDeviceID": r"PCI\VEN_8086&DEV_7D55",
                "DriverVersion": "1",
            },
            {
                "Name": "NVIDIA GeForce RTX 4050 Laptop GPU",
                "PNPDeviceID": r"PCI\VEN_10DE&DEV_28A1",
                "DriverVersion": "2",
            },
        ]
        displays = [
            {
                "Name": item["Name"],
                "PNPDeviceID": item["PNPDeviceID"],
                "ConfigManagerErrorCode": 0,
            }
            for item in controllers
        ]
        result = gpu.merge_gpu_records(controllers, displays)
        self.assertEqual(len(result), 2)
        self.assertTrue(result[0]["is_discrete"])
        self.assertTrue(result[1]["is_integrated"])


if __name__ == "__main__":
    unittest.main()
