import os
import sys
import unittest
from unittest.mock import patch

backend_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if backend_dir not in sys.path:
    sys.path.insert(0, backend_dir)

from activation import windows_activation
from activation.windows_activation import (
    _preserve_recent_positive,
    _query_wmi_licensing,
    _resolve_activation_state,
)


class WindowsActivationStateTests(unittest.TestCase):
    def test_any_official_positive_signal_wins(self):
        self.assertTrue(
            _resolve_activation_state(
                {'activated': False},
                {'activated': True},
                False,
            )
        )
        self.assertTrue(
            _resolve_activation_state(
                {'activated': False},
                {},
                True,
            )
        )

    def test_no_positive_signal_is_inactive(self):
        self.assertFalse(
            _resolve_activation_state(
                {'activated': False},
                {'activated': False},
                None,
            )
        )

    def test_digital_home_license_does_not_require_partial_product_key(self):
        with patch.object(
            windows_activation,
            "run_powershell_json",
            return_value={
                "Name": "Windows 11 Home",
                "Description": "Windows Operating System, RETAIL channel",
                "LicenseStatus": 1,
            },
        ) as query:
            result = _query_wmi_licensing()

        self.assertTrue(result["activated"])
        script = query.call_args.args[0]
        self.assertIn("ApplicationID=", script)
        self.assertNotIn('PartialProductKey IS NOT NULL', script)

    def test_recent_official_positive_survives_transient_probe_failure(self):
        previous = windows_activation._positive_confirmation_at
        try:
            windows_activation._positive_confirmation_at = 0.0
            with patch.object(
                windows_activation.time,
                "monotonic",
                side_effect=[100.0, 101.0, 500.1],
            ):
                self.assertTrue(_preserve_recent_positive(True))
                self.assertTrue(_preserve_recent_positive(False))
                self.assertFalse(_preserve_recent_positive(False))
        finally:
            windows_activation._positive_confirmation_at = previous


if __name__ == '__main__':
    unittest.main()
