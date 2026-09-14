import unittest
from unittest.mock import patch
import struct

from hardware.ram import normalize_ram_slot, get_ram_info
from hardware.memory_slots import parse_memory_slots


class RamSlotNormalizationTests(unittest.TestCase):
    def test_direct_motherboard_slot_is_preserved(self):
        result = normalize_ram_slot("DIMM_A2", "BANK 1")
        self.assertEqual(result["slot"], "A2")
        self.assertEqual(result["device_locator"], "DIMM_A2")

    def test_channel_index_does_not_invent_printed_board_label(self):
        result = normalize_ram_slot("ChannelB-DIMM1", "BANK 3")
        self.assertEqual(result["slot"], "ChannelB-DIMM1")
        self.assertEqual(result["slot_confidence"], "firmware")

    def test_two_and_four_slot_boards_preserve_empty_slot_positions(self):
        for labels in [('A1', 'B1'), ('A1', 'A2', 'B1', 'B2')]:
            with self.subTest(labels=labels):
                array = bytearray(15)
                struct.pack_into('<BBH', array, 0, 16, 15, 42)
                array[5] = 3
                raw = bytes(array) + b'\0\0'
                for index, label in enumerate(labels):
                    record = bytearray(21)
                    struct.pack_into('<BBH', record, 0, 17, 21, index + 100)
                    struct.pack_into('<H', record, 4, 42)
                    struct.pack_into('<H', record, 12, 8192 if index == 1 else 0)
                    record[16] = 1
                    raw += bytes(record) + label.encode() + b'\0\0'
                devices = parse_memory_slots(raw)
                self.assertEqual(len(devices), len(labels))
                self.assertEqual([d['occupied'] for d in devices], [i == 1 for i in range(len(labels))])
                module = {'Capacity': 8 * 1024**3, 'DeviceLocator': labels[1], 'PartNumber': 'CL40-40-40', 'SMBIOSMemoryType': 34}
                with patch('hardware.ram.run_powershell_json', return_value={'Modules': [module], 'TotalSlots': len(labels)}), patch('hardware.ram.read_memory_slots', return_value=devices):
                    result = get_ram_info()
                self.assertEqual([s['slot'] for s in result['slots']], list(labels))
                self.assertEqual(result['slots'][1]['module_index'], 0)
                self.assertIsNone(result['slots'][0]['module_index'])
                self.assertEqual(result['modules'][0]['type'], 'DDR5')
                self.assertEqual(result['modules'][0]['rated_cl'], 40)
                self.assertIsNone(result['modules'][0]['active_cl'])

    def test_lpddr4_and_missing_cl_are_not_invented(self):
        module = {'Capacity': 4 * 1024**3, 'SMBIOSMemoryType': 30, 'PartNumber': 'UNKNOWN123'}
        with patch('hardware.ram.run_powershell_json', return_value={'Modules': [module], 'TotalSlots': 2}), patch('hardware.ram.read_memory_slots', return_value=[]):
            result = get_ram_info()
        self.assertEqual(result['modules'][0]['type'], 'LPDDR4')
        self.assertIsNone(result['modules'][0]['rated_cl'])

    def test_malformed_firmware_table_is_ignored(self):
        self.assertEqual(parse_memory_slots(b'\x11\xff\0\0'), [])

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
