"""Hardware detection modules for PC System Inspector."""
from .cpu import get_cpu_info
from .motherboard import get_motherboard_info
from .ram import get_ram_info
from .gpu import get_gpu_info
from .storage import get_storage_info
from .bios import get_bios_info

__all__ = [
    "get_cpu_info",
    "get_motherboard_info",
    "get_ram_info",
    "get_gpu_info",
    "get_storage_info",
    "get_bios_info",
]
