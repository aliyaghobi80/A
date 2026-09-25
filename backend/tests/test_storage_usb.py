import unittest
import os
import sys
from unittest.mock import patch

backend_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if backend_dir not in sys.path:
    sys.path.insert(0, backend_dir)

from hardware.storage import get_connected_usb_drives, safe_eject_drive

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

    @patch('hardware.storage.get_connected_usb_drives', return_value=[])
    def test_safe_eject_rejects_non_removable_target(self, _mock_drives):
        res = safe_eject_drive('Z:')
        self.assertFalse(res['success'])
        self.assertIn('USB', res['message'])

if __name__ == '__main__':
    unittest.main()
