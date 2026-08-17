import logging
import ctypes
from typing import Dict, Any, List

from utils.powershell import run_powershell_json
from utils.formatters import clean_string, format_bytes_to_gb

logger = logging.getLogger(__name__)

SMBIOS_MEMORY_TYPES = {
    20: "DDR",
    21: "DDR2",
    22: "DDR2 FB-DIMM",
    24: "DDR3",
    26: "DDR4",
    30: "DDR5",
    34: "LPDDR4",
    35: "LPDDR5",
}

class MEMORYSTATUSEX(ctypes.Structure):
    _fields_ = [
        ("dwLength", ctypes.c_ulong),
        ("dwMemoryLoad", ctypes.c_ulong),
        ("ullTotalPhys", ctypes.c_ulonglong),
        ("ullAvailPhys", ctypes.c_ulonglong),
        ("ullTotalPageFile", ctypes.c_ulonglong),
        ("ullAvailPageFile", ctypes.c_ulonglong),
        ("ullTotalVirtual", ctypes.c_ulonglong),
        ("ullAvailVirtual", ctypes.c_ulonglong),
        ("sllAvailExtendedVirtual", ctypes.c_ulonglong),
    ]

def _get_total_ram_winapi() -> float:
    """Uses Win32 GlobalMemoryStatusEx as a fast fallback to get total physical RAM in GB."""
    try:
        stat = MEMORYSTATUSEX()
        stat.dwLength = ctypes.sizeof(MEMORYSTATUSEX)
        if ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(stat)):
            return round(stat.ullTotalPhys / (1024 ** 3), 2)
    except Exception as e:
        logger.debug(f"GlobalMemoryStatusEx failed: {e}")
    return 0.0

def get_ram_info() -> Dict[str, Any]:
    """
    Detects RAM capacity, speed, and module breakdown using Win32_PhysicalMemory.
    Returns:
        total_gb: float (e.g. 16.0)
        total_display: str (e.g. '16 GB')
        module_count: int
        module_summary: str (e.g. '8 GB + 8 GB')
        speed_mhz: int or str (e.g. 3200)
        modules: List[Dict]
    """
    ram_result = {
        "total_gb": 0.0,
        "total_display": "Not available",
        "module_count": 0,
        "module_summary": "Not available",
        "speed_mhz": "Not available",
        "speed_display": "Not available",
        "modules": []
    }

    try:
        script = (
            "Get-CimInstance Win32_PhysicalMemory | "
            "Select-Object Capacity, Speed, ConfiguredClockSpeed, Manufacturer, PartNumber, SerialNumber, DeviceLocator, BankLabel, SMBIOSMemoryType | "
            "ConvertTo-Json"
        )
        data = run_powershell_json(script)
        
        if isinstance(data, dict):
            raw_modules = [data]
        elif isinstance(data, list):
            raw_modules = data
        else:
            raw_modules = []

        modules_list = []
        total_bytes = 0
        speeds = []

        for idx, mod in enumerate(raw_modules):
            if not isinstance(mod, dict):
                continue
            
            cap_bytes = mod.get("Capacity", 0)
            try:
                cap_int = int(cap_bytes)
                total_bytes += cap_int
                mod_gb = round(cap_int / (1024 ** 3), 1)
                mod_cap_display = f"{int(mod_gb) if mod_gb.is_integer() else mod_gb} GB"
            except (ValueError, TypeError):
                mod_cap_display = "Not available"
                mod_gb = 0

            speed_val = mod.get("ConfiguredClockSpeed") or mod.get("Speed")
            try:
                speed_int = int(speed_val) if speed_val else None
                if speed_int and speed_int > 0:
                    speeds.append(speed_int)
                    speed_str = f"{speed_int} MHz"
                else:
                    speed_str = "Not available"
            except (ValueError, TypeError):
                speed_str = "Not available"
                speed_int = None

            smbios_type = mod.get("SMBIOSMemoryType")
            type_str = SMBIOS_MEMORY_TYPES.get(smbios_type, "RAM")

            slot_locator = clean_string(mod.get("DeviceLocator"), default=f"Slot {idx + 1}")
            manufacturer = clean_string(mod.get("Manufacturer"), default="Not available")
            part_number = clean_string(mod.get("PartNumber"), default="Not available")
            serial_number = clean_string(mod.get("SerialNumber"), default="Not available")

            modules_list.append({
                "slot": slot_locator,
                "capacity_gb": mod_gb,
                "capacity_display": mod_cap_display,
                "speed_mhz": speed_int,
                "speed_display": speed_str,
                "type": type_str,
                "manufacturer": manufacturer,
                "part_number": part_number,
                "serial": serial_number,
            })

        if total_bytes > 0:
            total_gb = round(total_bytes / (1024 ** 3), 1)
            ram_result["total_gb"] = total_gb
            ram_result["total_display"] = f"{int(round(total_gb))} GB"
            ram_result["module_count"] = len(modules_list)
            ram_result["modules"] = modules_list
            
            # Module summary like '8 GB + 8 GB'
            if modules_list:
                caps = [m["capacity_display"] for m in modules_list if m["capacity_display"] != "Not available"]
                if caps:
                    ram_result["module_summary"] = " + ".join(caps)
                
            # Speed display
            if speeds:
                max_speed = max(speeds)
                ram_result["speed_mhz"] = max_speed
                ram_result["speed_display"] = f"{max_speed} MHz"

    except Exception as e:
        logger.error(f"Error querying Win32_PhysicalMemory: {e}")

    # Fallback for Total RAM if 0 (e.g. in VMs without WMI memory slot emulation)
    if ram_result["total_gb"] == 0.0:
        winapi_gb = _get_total_ram_winapi()
        if winapi_gb > 0:
            ram_result["total_gb"] = winapi_gb
            ram_result["total_display"] = f"{int(round(winapi_gb))} GB"

    return ram_result
