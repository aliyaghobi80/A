import os
import sys
import unittest
from unittest.mock import MagicMock, patch

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from packages.auto_wizard import InstallerAutoPilot


class InstallerSafetyTests(unittest.TestCase):
    def test_vc2010_license_enables_install_without_toggling_other_checkbox(self):
        pilot = InstallerAutoPilot(target_pids={123})
        pilot._get_child_windows = MagicMock(return_value=[
            (1, 'MICROSOFT SOFTWARE LICENSE TERMS', 'Static'),
            (2, 'I have read and accept the license terms.', 'Button'),
            (3, 'Yes, send information about my setup experiences to Microsoft Corporation.', 'Button'),
            (4, 'Install', 'Button'),
        ])
        pilot._check_control = MagicMock(return_value=True)
        pilot._click_button = MagicMock(return_value=True)
        with patch('packages.auto_wizard.user32') as api:
            api.IsWindowEnabled.return_value = True
            api.GetWindowLongPtrW.side_effect = lambda hwnd, _: 3 if hwnd in (2, 3) else 0
            self.assertTrue(pilot.process_window(10))
        pilot._check_control.assert_called_once_with(2, True)
        pilot._click_button.assert_called_once_with(4, 'Install')

    def test_child_and_grandchild_are_tracked_but_unrelated_process_is_not(self):
        pilot = InstallerAutoPilot(target_pids={123})
        with patch('packages.auto_wizard._process_parents', return_value={123: 50, 456: 123, 789: 456, 999: 50}):
            pilot._refresh_child_pids()
        self.assertEqual(pilot.target_pids, {123, 456, 789})

    def test_wait_does_not_finish_while_prerequisite_child_is_running(self):
        pilot = InstallerAutoPilot(target_pids={123})
        with patch('packages.auto_wizard._process_parents', return_value={456: 123}):
            self.assertFalse(pilot.wait_for_children(0))

    def test_generic_title_does_not_authorize_other_process(self):
        pilot = InstallerAutoPilot(target_pids={123}, target_title_keywords=['setup'])
        with patch('packages.auto_wizard.user32') as api, patch('packages.auto_wizard._get_process_id_for_window', return_value=456):
            api.IsWindowVisible.return_value = True
            self.assertFalse(pilot._is_relevant_window(1))

    def test_owned_process_is_eligible(self):
        pilot = InstallerAutoPilot(target_pids={123})
        with patch('packages.auto_wizard.user32') as api, patch('packages.auto_wizard._get_process_id_for_window', return_value=123):
            api.IsWindowVisible.return_value = True
            self.assertTrue(pilot._is_relevant_window(1))

    def test_reboot_dialog_without_later_choice_is_left_untouched(self):
        pilot = InstallerAutoPilot(target_pids={123})
        pilot._get_child_windows = MagicMock(return_value=[
            (1, 'Restart your computer now', 'Button'), (2, 'Finish', 'Button')])
        with patch('packages.auto_wizard.user32') as api:
            self.assertFalse(pilot.process_window(10))
            api.SendMessageW.assert_not_called()

    def test_reboot_later_is_selected_and_restart_now_is_not(self):
        pilot = InstallerAutoPilot(target_pids={123})
        pilot._get_child_windows = MagicMock(return_value=[
            (1, 'Restart now', 'Button'), (2, 'Restart later', 'Button'),
            (3, 'Finish', 'Button')])
        pilot._click_button = MagicMock(return_value=True)
        with patch('packages.auto_wizard.user32') as api:
            api.IsWindowEnabled.return_value = True
            api.SendMessageW.return_value = 0
            self.assertTrue(pilot.process_window(10))
            pilot._click_button.assert_called_once_with(2, 'Restart later')

    def test_checkbox_is_not_set_then_toggled_back(self):
        pilot = InstallerAutoPilot(target_pids={123})
        with patch('packages.auto_wizard.user32') as api:
            api.SendMessageW.side_effect = [0, 0, 1]
            self.assertTrue(pilot._check_control(1, True))
            self.assertEqual([call.args[1] for call in api.SendMessageW.call_args_list], [0xF0, 0xF5, 0xF0])

    def test_oem_license_checkbox_is_not_clicked_again_as_push_button(self):
        pilot = InstallerAutoPilot(target_pids={123})
        pilot._get_child_windows = MagicMock(return_value=[
            (1, 'License Agreement', 'Static'),
            (2, 'I have read and agree to the terms', 'Button'),
            (3, 'Next >', 'Button'),
        ])
        pilot._check_control = MagicMock(return_value=True)
        pilot._click_button = MagicMock(return_value=True)
        with patch('packages.auto_wizard.user32') as api:
            api.IsWindowEnabled.return_value = True
            api.GetWindowLongPtrW.side_effect = lambda hwnd, _: 2 if hwnd == 2 else 0
            self.assertTrue(pilot.process_window(10))
        pilot._check_control.assert_called_once_with(2, True)
        pilot._click_button.assert_called_once_with(3, 'Next >')
