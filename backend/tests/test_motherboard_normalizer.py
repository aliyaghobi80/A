import unittest
from hardware.normalizer import normalize_motherboard_info

class TestMotherboardNormalizer(unittest.TestCase):
    def test_gigabyte_normalization(self):
        res = normalize_motherboard_info('Gigabyte Technology Co., Ltd.', 'H610M K DDR4')
        self.assertEqual(res['brand'], 'GIGABYTE')
        self.assertEqual(res['brand_fa'], 'گیگابایت')
        self.assertEqual(res['chipset'], 'Intel H610')
        self.assertEqual(res['form_factor'], 'Micro-ATX')
        self.assertEqual(res['display_name'], 'GIGABYTE H610M K DDR4')

    def test_asus_normalization(self):
        res = normalize_motherboard_info('ASUSTeK COMPUTER INC.', 'ROG STRIX B650-A GAMING WIFI')
        self.assertEqual(res['brand'], 'ASUS')
        self.assertEqual(res['brand_fa'], 'ایسوس')
        self.assertEqual(res['chipset'], 'AMD B650')
        self.assertEqual(res['display_name'], 'ASUS ROG STRIX B650-A GAMING WIFI')

    def test_msi_normalization(self):
        res = normalize_motherboard_info('Micro-Star International Co., Ltd.', 'MAG B760 TOMAHAWK WIFI DDR4')
        self.assertEqual(res['brand'], 'MSI')
        self.assertEqual(res['brand_fa'], 'ام‌اس‌آی')
        self.assertEqual(res['chipset'], 'Intel B760')
        self.assertEqual(res['display_name'], 'MSI MAG B760 TOMAHAWK WIFI DDR4')

    def test_asrock_normalization(self):
        res = normalize_motherboard_info('ASRock', 'B550M Pro4')
        self.assertEqual(res['brand'], 'ASRock')
        self.assertEqual(res['brand_fa'], 'ازراک')
        self.assertEqual(res['chipset'], 'AMD B550')
        self.assertEqual(res['form_factor'], 'Micro-ATX')
        self.assertEqual(res['display_name'], 'ASRock B550M Pro4')

    def test_mini_itx_detection(self):
        res = normalize_motherboard_info('ASUS', 'ROG STRIX B760-I GAMING WIFI')
        self.assertEqual(res['form_factor'], 'Mini-ITX')

    def test_intel_next_gen_chipset(self):
        res = normalize_motherboard_info('Gigabyte Technology Co., Ltd.', 'Z890 AORUS MASTER')
        self.assertEqual(res['brand'], 'GIGABYTE')
        self.assertEqual(res['chipset'], 'Intel Z890')

    def test_amd_x670_chipset(self):
        res = normalize_motherboard_info('Micro-Star International Co., Ltd.', 'MPG X670E CARBON WIFI')
        self.assertEqual(res['chipset'], 'AMD X670E')

if __name__ == '__main__':
    unittest.main()
