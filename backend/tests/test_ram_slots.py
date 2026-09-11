import unittest

from hardware.ram import normalize_ram_slot


class RamSlotNormalizationTests(unittest.TestCase):
    def test_direct_motherboard_slot_is_preserved(self):
        result = normalize_ram_slot("DIMM_A2", "BANK 1")
        self.assertEqual(result["slot"], "A2")
        self.assertEqual(result["device_locator"], "DIMM_A2")

    def test_channel_dimm_slot_is_normalized(self):
        result = normalize_ram_slot("ChannelB-DIMM1", "BANK 3")
        self.assertEqual(result["slot"], "B2")
        self.assertEqual(result["slot_confidence"], "normalized")

    def test_controller_locator_is_preserved_without_guessing_board_label(self):
        result = normalize_ram_slot("Controller1-ChannelA-DIMM0", "BANK 0")
        self.assertEqual(result["slot"], "Controller 1 / Channel A / DIMM 0")
        self.assertEqual(result["slot_confidence"], "firmware")

    def test_unknown_vendor_locator_is_not_invented(self):
        result = normalize_ram_slot("Bottom - Slot 1 (left)", "BANK 0")
        self.assertEqual(result["slot"], "Bottom - Slot 1 (left)")

    def test_missing_firmware_locator_is_explicit(self):
        result = normalize_ram_slot(None, None)
        self.assertEqual(result["slot"], "نامشخص")
        self.assertEqual(result["slot_confidence"], "unknown")


if __name__ == "__main__":
    unittest.main()
