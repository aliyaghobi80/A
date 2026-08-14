# backend/activation/__init__.py
"""
Activation Module for Windows and Microsoft Office
Provides legal licensing detection and controlled corporate activation tool execution.
"""

from .activation_tools import (
    get_activation_config,
    get_tool_status,
    execute_activation_tool,
    is_safe_tool_path,
)
from .windows_activation import get_windows_activation_info
from .office_activation import get_office_activation_info

__all__ = [
    "get_activation_config",
    "get_tool_status",
    "execute_activation_tool",
    "is_safe_tool_path",
    "get_windows_activation_info",
    "get_office_activation_info",
]
