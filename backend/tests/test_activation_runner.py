import os
import sys
import unittest
from unittest.mock import patch


sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from activation.activation_tools import (
    _build_batch_command_parameters,
    _build_direct_batch_command_parameters,
    _build_batch_input,
    _build_batch_wrapper,
)
from drivers import archive_extractor


class ActivationRunnerTests(unittest.TestCase):
    def test_menu_input_contains_choice_and_completion_key(self):
        self.assertEqual(_build_batch_input(["1"]), b"1\r\nx\r\n")

    def test_unsafe_input_tokens_are_not_written_to_stdin(self):
        payload = _build_batch_input(["1 & calc.exe", "2"])
        self.assertEqual(payload, b"2\r\nx\r\n")
        self.assertNotIn(b"calc", payload)

    def test_batch_wrapper_pipes_choice_and_pause_keys(self):
        wrapper = _build_batch_wrapper(["1"]).decode("ascii")
        self.assertIn("echo 1", wrapper)
        self.assertIn("echo x", wrapper)
        self.assertIn(') | call "%~1"', wrapper)

    def test_batch_command_runs_the_owned_wrapper_elevated(self):
        command = _build_batch_command_parameters(
            r"C:\KMS v6\WINDOWS.cmd",
            r"C:\Temp Folder\activation-wrapper.cmd",
            r"C:\Temp Folder\activation.log",
        )

        self.assertIn('call "C:\\Temp Folder\\activation-wrapper.cmd"', command)
        self.assertIn('"C:\\KMS v6\\WINDOWS.cmd"', command)
        self.assertIn('> "C:\\Temp Folder\\activation.log" 2>&1', command)
        self.assertNotIn("<", command)

    def test_kms_unattended_command_uses_only_validated_switches(self):
        command = _build_direct_batch_command_parameters(
            r"C:\KMS v6\Window.cmd",
            ["/u", "/w", "& calc.exe"],
            r"C:\Temp Folder\activation.log",
        )
        self.assertIn('"C:\\KMS v6\\Window.cmd" /u /w', command)
        self.assertNotIn("calc", command)

    def test_windows_tar_alone_does_not_skip_winrar_prerequisite(self):
        with (
            patch.object(archive_extractor, "_find_winrar_or_rar_exe", return_value=None),
            patch.object(archive_extractor, "_find_7z_exe", return_value=None),
            patch.object(archive_extractor, "_find_tar_exe", return_value=r"C:\Windows\System32\tar.exe"),
        ):
            self.assertFalse(archive_extractor.has_rar_extractor())


if __name__ == "__main__":
    unittest.main()
