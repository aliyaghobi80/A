import unittest
from unittest.mock import patch, MagicMock
from windows import device_settings, power_settings
from qc.qc_engine import evaluate_system_qc


class PreparationTests(unittest.TestCase):
    def test_successful_command_is_not_success_without_verified_never_values(self):
        with patch.object(device_settings, '_run', return_value=MagicMock(returncode=0)), patch.object(power_settings, 'get_timeout_status', return_value={'all_never': False}):
            self.assertFalse(device_settings.set_sleep_never()['success'])

    def test_startup_partial_success_is_not_reported_as_all_disabled(self):
        with patch.object(device_settings, '_run_elevated_powershell', return_value=MagicMock(returncode=0, stdout='{}')), patch.object(device_settings, '_open_settings'), patch('windows.startup_status.get_startup_status', return_value={'all_disabled': False, 'enabled_count': 1}):
            self.assertFalse(device_settings.disable_all_startup_apps()['success'])

    def test_qc_warns_on_missing_never_and_clears_after_verified_snapshot(self):
        for ready in (False, None, True):
            status = {'timeouts': {'all_never': ready}, 'startup': {'all_disabled': True}}
            report = evaluate_system_qc({}, {}, status)
            issues = [p for p in report['problems'] if p['id'] == 'preparation_timeouts']
            self.assertEqual(bool(issues), ready is not True)
            if ready is not True:
                self.assertEqual(issues[0]['severity'], 'WARNING')

    def test_power_modes_use_separate_ac_and_dc_guids_and_verify(self):
        api = MagicMock()
        api.PowerSetUserConfiguredACPowerMode.return_value = 0
        api.PowerSetUserConfiguredDCPowerMode.return_value = 0
        with patch.object(power_settings.ctypes, 'WinDLL', return_value=api), patch.object(power_settings, 'get_power_mode_status', side_effect=[{'supported': True}, {'configured': True}]):
            self.assertTrue(power_settings.set_laptop_power_modes()['success'])
        ac = api.PowerSetUserConfiguredACPowerMode.call_args.args[0]._obj.text()
        dc = api.PowerSetUserConfiguredDCPowerMode.call_args.args[0]._obj.text()
        self.assertEqual(ac, power_settings.PERFORMANCE)
        self.assertEqual(dc, power_settings.BALANCED)

    def test_unsupported_power_api_never_claims_success(self):
        with patch.object(power_settings, 'get_power_mode_status', return_value={'supported': False}), patch.object(power_settings.ctypes, 'WinDLL') as dll:
            self.assertTrue(power_settings.set_laptop_power_modes()['unsupported'])
            dll.assert_not_called()

    def test_windows10_background_policy_can_prevent_success(self):
        import winreg
        with patch.object(device_settings, 'get_windows_identity', return_value={'generation': 'Windows 10'}), patch.object(winreg, 'CreateKeyEx'), patch.object(winreg, 'SetValueEx'), patch.object(device_settings, '_open_settings'), patch('windows.startup_status.get_background_status', return_value={'all_disabled': False}):
            self.assertFalse(device_settings.disable_windows10_background_apps()['success'])
