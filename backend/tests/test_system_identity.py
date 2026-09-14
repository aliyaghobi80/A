import unittest
from unittest.mock import patch
from windows.system import get_windows_and_system_info


class SystemIdentityTests(unittest.TestCase):
    def test_system_information_sku_takes_priority_over_product_sku(self):
        data = {'System': {'Manufacturer': 'ASUS', 'Model': 'ASUS Vivobook', 'SystemSKUNumber': 'ASUS_Notebook_X1504VAP'},
                'Product': {'SKUNumber': 'Other product code'}}
        with patch('windows.system.run_powershell_json', return_value=data), patch('windows.system._get_registry_windows_version', return_value={}):
            system = get_windows_and_system_info()['system']
        self.assertEqual(system['sku'], 'ASUS_Notebook_X1504VAP')
        self.assertEqual(system['model'], 'ASUS Vivobook')
