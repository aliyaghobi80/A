import unittest
from unittest.mock import patch
from windows.system import build_device_display_name, get_windows_and_system_info


class SystemIdentityTests(unittest.TestCase):
    def test_system_information_sku_takes_priority_over_product_sku(self):
        data = {'System': {'Manufacturer': 'ASUS', 'Model': 'ASUS Vivobook', 'SystemSKUNumber': 'ASUS_Notebook_X1504VAP'},
                'Product': {'SKUNumber': 'Other product code'}}
        with patch('windows.system.run_powershell_json', return_value=data), patch('windows.system._get_registry_windows_version', return_value={}):
            system = get_windows_and_system_info()['system']
        self.assertEqual(system['sku'], 'ASUS_Notebook_X1504VAP')
        self.assertEqual(system['model'], 'ASUS Vivobook')
        self.assertEqual(system['display_name'], 'ASUS Vivobook X1504VAP')
        self.assertEqual(system['model_code'], 'X1504VAP')

    def test_aio_display_name_uses_exact_model_code(self):
        identity = build_device_display_name(
            "ASUSTeK COMPUTER INC.",
            "ASUS All-in-One",
            "ASUS_AIO_P440VA",
        )
        self.assertEqual(identity["display_name"], "ASUS All-in-One P440VA")

    def test_desktop_memory_generation_is_not_used_as_model_code(self):
        identity = build_device_display_name(
            "Gigabyte Technology Co., Ltd.",
            "H610M K DDR4",
            "Not available",
        )
        self.assertEqual(identity["display_name"], "GIGABYTE H610M K DDR4")
        self.assertEqual(identity["model_code"], "H610M")
