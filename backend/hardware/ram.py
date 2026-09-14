import logging
import ctypes
import re
from typing import Dict, Any, List

from utils.powershell import run_powershell_json
from utils.formatters import clean_string, clean_serial_number, clean_part_number, format_bytes_to_gb
from hardware.memory_slots import read_memory_slots

logger = logging.getLogger(__name__)

SMBIOS_MEMORY_TYPES = {
    20: "DDR",
    21: "DDR2",
    22: "DDR2 FB-DIMM",
    24: "DDR3",
    26: "DDR4",
    27: "LPDDR",
    28: "LPDDR2",
    29: "LPDDR3",
    30: "LPDDR4",
    34: "DDR5",
    35: "LPDDR5",
}


def normalize_ram_slot(device_locator: Any, bank_label: Any) -> Dict[str, str]:
    """Return a readable physical slot while preserving firmware-reported values.

    Win32_PhysicalMemory exposes SMBIOS Type 17 DeviceLocator and BankLabel.
    These fields are the most reliable non-invasive source available on Windows,
    but their text is chosen by the firmware vendor. We only normalize patterns
    whose mapping is unambiguous and never invent a slot from the module order.
    """
    locator = clean_string(device_locator, default="")
    bank = clean_string(bank_label, default="")
    combined = f"{locator} {bank}".upper()

    direct = re.search(r"(?:\b(?:DIMM|SLOT)[\s_-]*|^)([A-H])[\s_-]*([1-8])\b", locator.upper())
    if direct:
        physical = f"{direct.group(1)}{direct.group(2)}"
        confidence = "high"
    elif "CONTROLLER" not in combined:
        channel_dimm = re.search(
            r"CHANNEL[\s_-]*([A-H]).*?DIMM[\s_-]*(\d+)", combined
        )
        if channel_dimm:
            # Channel numbering does not establish the PCB's printed slot name.
            physical = locator or bank
            confidence = "firmware"
        else:
            physical = locator or bank or "نامشخص"
            confidence = "firmware" if (locator or bank) else "unknown"
    else:
        controller_slot = re.search(
            r"CONTROLLER[\s_-]*(\d+).*?CHANNEL[\s_-]*([A-H]).*?DIMM[\s_-]*(\d+)",
            combined,
        )
        if controller_slot:
            physical = (
                f"Controller {controller_slot.group(1)} / "
                f"Channel {controller_slot.group(2)} / "
                f"DIMM {controller_slot.group(3)}"
            )
        else:
            physical = locator or bank or "نامشخص"
        confidence = "firmware" if (locator or bank) else "unknown"

    details = [value for value in (locator, bank) if value and value != physical]
    return {
        "slot": physical,
        "device_locator": locator or "Not available",
        "bank_label": bank or "Not available",
        "slot_details": " | ".join(dict.fromkeys(details)),
        "slot_confidence": confidence,
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
        "total_slots": None,
        "slots": [],
        "modules": []
    }

    try:
        script = (
            "$modules = @(Get-CimInstance Win32_PhysicalMemory | "
            "Select-Object Capacity, Speed, ConfiguredClockSpeed, Manufacturer, PartNumber, SerialNumber, DeviceLocator, BankLabel, SMBIOSMemoryType, FormFactor); "
            "$slotCount = (Get-CimInstance Win32_PhysicalMemoryArray | Where-Object { $_.Use -eq 3 } | Measure-Object -Property MemoryDevices -Sum).Sum; "
            "[PSCustomObject]@{ Modules = $modules; TotalSlots = $slotCount } | "
            "ConvertTo-Json -Depth 4"
        )
        data = run_powershell_json(script)
        if isinstance(data, dict) and "Modules" in data:
            module_data = data.get("Modules") or []
            raw_modules = module_data if isinstance(module_data, list) else [module_data]
            try:
                total_slots = int(data.get("TotalSlots") or 0)
                if total_slots >= len(raw_modules) and total_slots > 0:
                    ram_result["total_slots"] = total_slots
            except (TypeError, ValueError):
                pass
        elif isinstance(data, dict):
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

            try:
                smbios_type = int(mod.get("SMBIOSMemoryType") or 0)
            except (TypeError, ValueError):
                smbios_type = 0
            type_str = SMBIOS_MEMORY_TYPES.get(smbios_type, "RAM")

            slot_info = normalize_ram_slot(
                mod.get("DeviceLocator"), mod.get("BankLabel")
            )
            manufacturer = clean_string(mod.get("Manufacturer"), default="Not available")
            part_number = clean_part_number(mod.get("PartNumber"), default="-")
            serial_number = clean_serial_number(mod.get("SerialNumber"), default="-")
            cl_match = re.search(r'(?<![A-Z0-9])CL[\s-]*(\d{1,3})(?!\d)', part_number.upper())
            rated_cl = int(cl_match.group(1)) if cl_match else None

            modules_list.append({
                **slot_info,
                "capacity_gb": mod_gb,
                "capacity_display": mod_cap_display,
                "speed_mhz": speed_int,
                "speed_display": speed_str,
                "type": type_str,
                "form_factor": {8: "DIMM", 12: "SO-DIMM"}.get(mod.get("FormFactor"), "Not available"),
                "rated_cl": rated_cl,
                "cl_source": "part_number" if rated_cl else "unknown",
                "active_cl": None,
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
            inventory = read_memory_slots()
            slots = []
            mapped = set()
            for device in inventory:
                slot = normalize_ram_slot(device['device_locator'], device['bank_label'])
                matches = [i for i, module in enumerate(modules_list)
                           if module['device_locator'].casefold() == slot['device_locator'].casefold()
                           and module['bank_label'].casefold() == slot['bank_label'].casefold()
                           and slot['device_locator'] != 'Not available']
                index = matches[0] if len(matches) == 1 and matches[0] not in mapped and device['occupied'] is not False else None
                if index is not None:
                    mapped.add(index)
                slots.append({**slot, 'occupied': device['occupied'], 'module_index': index})
            if inventory and len(mapped) == len(modules_list):
                ram_result['slots'] = slots
                # Do not override a larger array count with a partial table.
                ram_result['total_slots'] = max(len(slots), ram_result['total_slots'] or 0)
            else:
                ram_result['slots'] = [{**{key: module[key] for key in ('slot', 'device_locator', 'bank_label')},
                                        'occupied': True, 'module_index': i}
                                       for i, module in enumerate(modules_list)]
            while len(ram_result['slots']) < (ram_result['total_slots'] or 0):
                ram_result['slots'].append({'slot': 'محل گزارش نشده', 'occupied': None, 'module_index': None})
            
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
