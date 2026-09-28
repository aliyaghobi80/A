import unittest
import os
import sys
from unittest.mock import patch

backend_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if backend_dir not in sys.path:
    sys.path.insert(0, backend_dir)

from hardware.storage import (
    get_connected_usb_drives,
    get_storage_info,
    is_removable_or_usb_physical_disk,
    safe_eject_drive,
)

class TestStorageUsb(unittest.TestCase):

    def test_get_connected_usb_drives_returns_list(self):
        drives = get_connected_usb_drives()
        self.assertIsInstance(drives, list)
        for d in drives:
            self.assertIn('drive_letter', d)
            self.assertIn('volume_name', d)
            self.assertIn('total_gb', d)
            self.assertIn('free_gb', d)
            self.assertIn('percent_used', d)
            self.assertTrue(d.get('is_removable', False))
            self.assertTrue(d['drive_letter'].endswith(':'))

    def test_safe_eject_drive_rejects_invalid_letters(self):
        res = safe_eject_drive('INVALID_DRIVE')
        self.assertFalse(res['success'])
        self.assertIn('نامعتبر', res['message'])

    def test_safe_eject_drive_protects_system_drive(self):
        sys_drive = (os.environ.get('SystemDrive') or 'C:').upper().rstrip('\\')
        res = safe_eject_drive(sys_drive)
        self.assertFalse(res['success'])
        self.assertIn('سیستمی', res['message'])

    def test_internal_emmc_is_not_classified_as_removable(self):
        self.assertFalse(
            is_removable_or_usb_physical_disk(
                {
                    "BusType": "MMC",
                    "MediaType": "SSD",
                    "Model": "Hynix HCG8a4 eMMC",
                    "Size": 128000000000,
                }
            )
        )

    @patch("hardware.storage.check_physical_drive_is_removable_or_usb", return_value=False)
    @patch("hardware.storage._get_volume_usage_by_disk", return_value={})
    @patch("hardware.storage.query_physical_drive_health")
    @patch("hardware.storage.run_powershell_json")
    def test_physical_disk_fallback_runs_when_wmi_only_contains_usb(
        self,
        run_json,
        health_query,
        _usage,
        _ioctl,
    ):
        run_json.side_effect = [
            {
                "Index": 1,
                "Model": "SanDisk Cruzer Blade USB Device",
                "BusType": "USB",
                "Size": 32000000000,
            },
            {
                "DeviceId": 0,
                "FriendlyName": "Micron 2400 NVMe 512GB",
                "Model": "Micron 2400 NVMe 512GB",
                "MediaType": "SSD",
                "BusType": "NVMe",
                "Size": 512000000000,
                "SerialNumber": "NVME123",
                "HealthStatus": "Healthy",
            },
        ]
        health_query.return_value = {
            "health_grade_fa": "سالم",
            "health_percent": None,
            "health_type": "UNKNOWN",
            "health_grade": "Healthy",
            "health_source": "Windows",
            "source": "Windows",
            "wear_percent": None,
            "temperature_c": None,
            "power_on_hours": None,
            "power_cycles": None,
            "unsafe_shutdowns": None,
            "media_errors": None,
            "available_spare_percent": None,
            "reallocated_sectors": None,
            "pending_sectors": None,
            "smart_status": "PASSED",
            "diagnostic_error": "",
        }

        result = get_storage_info()
        self.assertEqual(len(result), 1)
        self.assertIn("Micron", result[0]["model"])

    @patch('hardware.storage.get_connected_usb_drives', return_value=[])
    def test_safe_eject_rejects_non_removable_target(self, _mock_drives):
        res = safe_eject_drive('Z:')
        self.assertFalse(res['success'])
        self.assertIn('USB', res['message'])

if __name__ == '__main__':
    unittest.main()
