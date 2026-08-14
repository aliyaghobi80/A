"""Windows operating system detection modules."""
from .system import get_windows_and_system_info
from .network import get_network_info

__all__ = [
    "get_windows_and_system_info",
    "get_network_info",
]
