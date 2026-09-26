import os
import sys
import unittest
from unittest.mock import MagicMock, patch

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from packages.auto_wizard import InstallerAutoPilot
from packages import manager


class InstallerSafetyTests(unittest.TestCase):
    def test_queue_does_not_advance_while_child_wizard_is_still_open(self):
        process = MagicMock(pid=4321, returncode=0)
        autopilot = MagicMock()
        autopilot.wait_for_children.return_value = False
        with patch.object(manager.ctypes, 'windll') as dll, patch.object(
            manager.subprocess, 'Popen', return_value=process
        ), patch(
            'packages.auto_wizard.InstallerAutoPilot', return_value=autopilot
        ) as pilot_class:
            dll.shell32.IsUserAnAdmin.return_value = 1
            result = manager._run_elevated_and_wait(
                [r'C:\\Drivers\\SerialIO\\Setup.exe'],
                r'C:\\Drivers\\SerialIO',
                30,
            )
        self.assertEqual(result, -2)
        pilot_class.assert_called_once_with(
            target_title_keywords=[],
            timeout_seconds=30,
            trusted_roots=[r'C:\\Drivers\\SerialIO'],
        )
        autopilot.add_pid.assert_called_once_with(4321)
        autopilot.run_in_background.assert_called_once()
        autopilot.stop.assert_called_once()

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

    def test_short_lived_bootstrapper_lineage_is_preserved(self):
        with patch('packages.auto_wizard._process_parents', return_value={123: 50}):
            pilot = InstallerAutoPilot(target_pids={123})
        with patch('packages.auto_wizard._process_parents', return_value={456: 123}):
            pilot._refresh_child_pids()
        # The intermediate bootstrapper is now gone, but its child still
        # records 456 as its parent in the process snapshot.
        with patch('packages.auto_wizard._process_parents', return_value={789: 456}):
            pilot._refresh_child_pids()
        self.assertIn(789, pilot.target_pids)

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

    def test_owned_top_level_dialog_adopts_secondary_process(self):
        pilot = InstallerAutoPilot(target_pids={123})
        with patch('packages.auto_wizard.user32') as api, patch(
            'packages.auto_wizard._get_process_id_for_window',
            side_effect=lambda hwnd: 456 if hwnd == 10 else 123,
        ):
            api.IsWindowVisible.return_value = True
            api.GetWindow.side_effect = lambda hwnd, _: 20 if hwnd == 10 else 0
            self.assertTrue(pilot._is_relevant_window(10))
        self.assertIn(456, pilot.target_pids)

    def test_new_package_local_helper_is_eligible_but_preexisting_process_is_not(self):
        with patch('packages.auto_wizard._process_parents', return_value={111: 1}):
            pilot = InstallerAutoPilot(trusted_roots=[r'C:\\Drivers\\SerialIO'])
        with patch('packages.auto_wizard.user32') as api, patch(
            'packages.auto_wizard._get_process_id_for_window', return_value=222
        ), patch(
            'packages.auto_wizard._process_image_path',
            return_value=r'C:\\Drivers\\SerialIO\\x64\\Setup.exe',
        ):
            api.IsWindowVisible.return_value = True
            api.GetWindow.return_value = 0
            self.assertTrue(pilot._is_relevant_window(10))
        self.assertIn(222, pilot.target_pids)

        with patch('packages.auto_wizard._process_parents', return_value={333: 1}):
            old_pilot = InstallerAutoPilot(trusted_roots=[r'C:\\Drivers\\SerialIO'])
        with patch('packages.auto_wizard.user32') as api, patch(
            'packages.auto_wizard._get_process_id_for_window', return_value=333
        ), patch(
            'packages.auto_wizard._process_image_path',
            return_value=r'C:\\Drivers\\SerialIO\\Setup.exe',
        ):
            api.IsWindowVisible.return_value = True
            api.GetWindow.return_value = 0
            self.assertFalse(old_pilot._is_relevant_window(10))

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

    def test_checked_restart_now_checkbox_is_cleared_before_finish(self):
        pilot = InstallerAutoPilot(target_pids={123})
        pilot._get_child_windows = MagicMock(return_value=[
            (1, 'Setup must restart your computer.', 'Static'),
            (2, 'Restart now', 'Button'),
            (3, 'Finish', 'Button'),
        ])
        pilot._check_control = MagicMock(return_value=True)
        pilot._click_button = MagicMock(return_value=True)
        with patch('packages.auto_wizard.user32') as api, patch(
            'packages.auto_wizard._send_message_timeout', return_value=1
        ):
            api.IsWindowEnabled.return_value = True
            api.GetWindowLongPtrW.side_effect = lambda hwnd, _: 3 if hwnd == 2 else 0
            self.assertTrue(pilot.process_window(10))
        pilot._check_control.assert_called_once_with(2, False)
        pilot._click_button.assert_not_called()

    def test_no_restart_required_success_message_does_not_block_ok(self):
        pilot = InstallerAutoPilot(target_pids={123})
        pilot._get_child_windows = MagicMock(return_value=[
            (1, 'Installed successfully. No restart is required.', 'Static'),
            (2, 'OK', 'Button'),
        ])
        pilot._click_button = MagicMock(return_value=True)
        with patch('packages.auto_wizard.user32') as api:
            api.IsWindowEnabled.return_value = True
            api.GetWindowLongPtrW.return_value = 0
            self.assertTrue(pilot.process_window(10))
        pilot._click_button.assert_called_once_with(2, 'OK')

    def test_checkbox_is_not_set_then_toggled_back(self):
        pilot = InstallerAutoPilot(target_pids={123})
        with patch('packages.auto_wizard.user32') as api, patch(
            'packages.auto_wizard._send_message_timeout', side_effect=[0, 0, 1]
        ) as send:
            api.IsWindowEnabled.return_value = True
            api.GetAncestor.return_value = 10
            api.GetWindowTextLengthW.return_value = 0
            self.assertTrue(pilot._check_control(1, True))
            self.assertEqual([call.args[1] for call in send.call_args_list], [0xF0, 0xF5, 0xF0])

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

    def test_separate_license_text_selects_unlabeled_checkbox_not_static_label(self):
        pilot = InstallerAutoPilot(target_pids={123})
        pilot._get_child_windows = MagicMock(return_value=[
            (1, 'License Agreement', 'Static'),
            (2, 'I have read and accept the license terms.', 'Static'),
            (3, '', 'Button'),
            (4, 'Next >', 'Button'),
        ])
        pilot._check_control = MagicMock(return_value=True)
        pilot._click_button = MagicMock(return_value=True)
        with patch('packages.auto_wizard.user32') as api:
            api.IsWindowEnabled.return_value = True
            api.GetWindowLongPtrW.side_effect = lambda hwnd, _: 3 if hwnd == 3 else 0
            self.assertTrue(pilot.process_window(10))
        pilot._check_control.assert_called_once_with(3, True)
        pilot._click_button.assert_called_once_with(4, 'Next >')

    def test_welcome_wizard_clicks_next(self):
        pilot = InstallerAutoPilot(target_pids={123})
        pilot._get_child_windows = MagicMock(return_value=[
            (1, 'Welcome to the device-driver installation wizard.', 'Static'),
            (2, '< Back', 'Button'),
            (3, 'Next >', 'Button'),
            (4, 'Cancel', 'Button'),
        ])
        pilot._click_button = MagicMock(return_value=True)
        with patch('packages.auto_wizard.user32') as api:
            api.IsWindowEnabled.return_value = True
            api.GetWindowLongPtrW.return_value = 0
            self.assertTrue(pilot.process_window(10))
        pilot._click_button.assert_called_once_with(3, 'Next >')

    def test_maintenance_actions_are_never_treated_as_install(self):
        pilot = InstallerAutoPilot(target_pids={123})
        pilot._get_child_windows = MagicMock(return_value=[
            (1, 'Application Maintenance', 'Static'),
            (2, 'Uninstall', 'Button'),
            (3, 'Repair', 'Button'),
            (4, 'Cancel', 'Button'),
        ])
        pilot._click_button = MagicMock(return_value=True)
        with patch('packages.auto_wizard.user32') as api:
            api.IsWindowEnabled.return_value = True
            api.GetWindowLongPtrW.return_value = 0
            self.assertFalse(pilot.process_window(10))
        pilot._click_button.assert_not_called()

    def test_success_dialog_clicks_ok(self):
        pilot = InstallerAutoPilot(target_pids={123})
        pilot._get_child_windows = MagicMock(return_value=[
            (1, 'Intel Serial-IO Driver installed successfully.', 'Static'),
            (2, 'OK', 'Button'),
        ])
        pilot._click_button = MagicMock(return_value=True)
        with patch('packages.auto_wizard.user32') as api:
            api.IsWindowEnabled.return_value = True
            api.GetWindowLongPtrW.return_value = 0
            self.assertTrue(pilot.process_window(10))
        pilot._click_button.assert_called_once_with(2, 'OK')

    def test_click_activates_dialog_and_uses_bounded_message(self):
        pilot = InstallerAutoPilot(target_pids={123})
        with patch('packages.auto_wizard.user32') as api:
            api.IsWindowEnabled.return_value = True
            api.GetAncestor.return_value = 99
            api.SendMessageTimeoutW.return_value = 1
            self.assertTrue(pilot._click_button(7, 'OK'))
            api.SetActiveWindow.assert_called_once_with(99)
            api.SetForegroundWindow.assert_called_once_with(99)
            api.BringWindowToTop.assert_called_once_with(99)
            self.assertEqual(api.SendMessageTimeoutW.call_args.args[1], 0xF5)
            self.assertEqual(api.SendMessageTimeoutW.call_args.args[5], 1500)

    def test_unresponsive_button_is_not_reported_as_clicked(self):
        pilot = InstallerAutoPilot(target_pids={123})
        with patch('packages.auto_wizard.user32') as api:
            api.IsWindowEnabled.return_value = True
            api.GetAncestor.return_value = 99
            api.SendMessageTimeoutW.return_value = 0
            self.assertFalse(pilot._click_button(7, 'Next >'))
        self.assertEqual(pilot._action_count, 0)
