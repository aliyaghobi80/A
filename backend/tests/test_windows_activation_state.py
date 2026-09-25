import os
import sys
import unittest

backend_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if backend_dir not in sys.path:
    sys.path.insert(0, backend_dir)

from activation.windows_activation import _resolve_activation_state


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


if __name__ == '__main__':
    unittest.main()
