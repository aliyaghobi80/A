import unittest
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from unittest.mock import patch, MagicMock
from subprocess import CompletedProcess
from activation.verification import verify_activation_result
from windows.desktop_time import show_desktop_icons, set_tehran_automatic_timezone, ICONS


class DesktopTimeActivationTests(unittest.TestCase):
    @patch('activation.verification.time.sleep')
    @patch('activation.verification._query_wmi_licensing')
    def test_delayed_license_overrides_process_failure(self, query, sleep):
        query.side_effect = [{'activated': False}, {'activated': True}]
        result = verify_activation_result('windows', {'success': False, 'exit_code': 1, 'output': 'large log'})
        self.assertTrue(result['success'])
        self.assertEqual(result['output'], '')
        self.assertEqual(query.call_count, 2)

    @patch('activation.verification._query_wmi_licensing', return_value={})
    def test_zero_exit_is_not_proof_of_activation(self, query):
        result = verify_activation_result('windows', {'success': True}, attempts=1)
        self.assertFalse(result['success'])
        self.assertEqual(result['verification'], 'unconfirmed')

    @patch('activation.verification._query_wmi_licensing')
    def test_cancel_stays_cancelled(self, query):
        self.assertTrue(verify_activation_result('windows', {'cancelled': True})['cancelled'])
        query.assert_not_called()

    @patch('windows.desktop_time.winreg.CreateKeyEx')
    @patch('windows.desktop_time._query_wmi_licensing', return_value={'activated': False})
    def test_icons_require_activation_without_writing(self, query, create):
        self.assertFalse(show_desktop_icons()['success'])
        create.assert_not_called()

    @patch('windows.desktop_time.ctypes.windll')
    @patch('windows.desktop_time.get_desktop_time_status', return_value={'desktop_icons_ready': True})
    @patch('windows.desktop_time.winreg.SetValueEx')
    @patch('windows.desktop_time.winreg.CreateKeyEx')
    @patch('windows.desktop_time._query_wmi_licensing', return_value={'activated': True})
    def test_only_three_icons_enabled_as_dword(self, query, create, write, status, dll):
        self.assertTrue(show_desktop_icons()['success'])
        self.assertEqual(write.call_count, 6)
        self.assertEqual({call.args[1] for call in write.call_args_list}, set(ICONS))
        self.assertTrue(all(call.args[-1] == 0 for call in write.call_args_list))

    @patch('windows.desktop_time.get_desktop_time_status')
    @patch('windows.desktop_time._run_elevated_powershell', return_value=CompletedProcess([], 0))
    def test_timezone_readback_and_location_warning(self, run, state):
        state.return_value = {'timezone': 'Iran Standard Time', 'automatic_timezone': True, 'location_enabled': False}
        result = set_tehran_automatic_timezone()
        self.assertTrue(result['success'])
        self.assertIn('Location', result['message'])
        script = run.call_args.args[0]
        self.assertIn('Iran Standard Time_dstoff', script)
        self.assertNotIn('ConsentStore', script)
        state.return_value['timezone'] = 'Pacific Standard Time'
        self.assertFalse(set_tehran_automatic_timezone()['success'])
