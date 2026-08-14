# backend/test_activation.py
"""
Unit tests for Phase 3 Windows and Office activation detection and tool security.
"""

import os
import sys
import unittest

# Ensure backend directory is in sys.path
_backend_dir = os.path.dirname(os.path.abspath(__file__))
if _backend_dir not in sys.path:
    sys.path.insert(0, _backend_dir)

from activation.activation_tools import (
    is_safe_tool_path,
    get_activation_config,
    get_tool_status,
)
from activation.windows_activation import get_windows_activation_info
from activation.office_activation import get_office_activation_info
from collector import collect_all_system_info


class TestActivationModule(unittest.TestCase):

    def test_security_path_validation(self):
        # Disallowed traversal and arbitrary paths
        self.assertFalse(is_safe_tool_path("../secret.bat"))
        self.assertFalse(is_safe_tool_path("..\\windows\\system32\\cmd.exe"))
        self.assertFalse(is_safe_tool_path("C:\\Windows\\System32\\cmd.exe"))
        self.assertFalse(is_safe_tool_path("/etc/passwd"))
        self.assertFalse(is_safe_tool_path(""))
        self.assertFalse(is_safe_tool_path("   "))

        # Allowed paths inside Tools
        self.assertTrue(is_safe_tool_path("Tools/WindowsActivation/activate.cmd"))
        self.assertTrue(is_safe_tool_path("Tools\\OfficeActivation\\activate.cmd"))

    def test_config_loading(self):
        cfg = get_activation_config()
        self.assertIn("windows", cfg)
        self.assertIn("office", cfg)
        self.assertTrue(cfg["windows"].get("enabled", True))
        self.assertTrue(cfg["office"].get("enabled", True))

    def test_tool_status(self):
        win_tool = get_tool_status("windows")
        self.assertIn("available", win_tool)
        self.assertIn("tool_path", win_tool)

        off_tool = get_tool_status("office")
        self.assertIn("available", off_tool)
        self.assertIn("tool_path", off_tool)

    def test_windows_activation_info_structure(self):
        info = get_windows_activation_info()
        self.assertIsInstance(info, dict)
        self.assertIn("installed", info)
        self.assertIn("activated", info)
        self.assertIn("status_text", info)
        self.assertIn("channel", info)
        self.assertIn("partial_key", info)
        self.assertIn("edition", info)
        self.assertIn("tool_available", info)
        self.assertIsInstance(info["activated"], bool)
        self.assertIsInstance(info["tool_available"], bool)

    def test_office_activation_info_structure(self):
        info = get_office_activation_info()
        self.assertIsInstance(info, dict)
        self.assertIn("installed", info)
        self.assertIn("activated", info)
        self.assertIn("status_text", info)
        self.assertIn("channel", info)
        self.assertIn("partial_key", info)
        self.assertIn("product", info)
        self.assertIn("tool_available", info)
        self.assertIsInstance(info["installed"], bool)
        self.assertIsInstance(info["activated"], bool)

    def test_collector_integration(self):
        data = collect_all_system_info()
        self.assertEqual(data["status"], "success")
        self.assertIn("windows_activation", data)
        self.assertIn("office_activation", data)
        self.assertIsInstance(data["windows_activation"], dict)
        self.assertIsInstance(data["office_activation"], dict)
        self.assertIn("activated", data["windows_activation"])
        self.assertIn("installed", data["office_activation"])


if __name__ == "__main__":
    unittest.main()
