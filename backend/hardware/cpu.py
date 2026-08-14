import logging
import os
import winreg
from typing import Dict, Any, Optional

from utils.powershell import run_powershell_json
from utils.formatters import clean_string, format_mhz

logger = logging.getLogger(__name__)

def _normalize_manufacturer(mfg: str) -> str:
    cleaned = clean_string(mfg)
    if "GenuineIntel" in cleaned or "Intel" in cleaned:
        return "Intel"
    if "AuthenticAMD" in cleaned or "AMD" in cleaned:
        return "AMD"
    if "ARM" in cleaned:
        return "ARM"
    return cleaned

def _get_cpu_registry() -> Dict[str, Any]:
    """Fallback to read CPU properties directly from Windows Registry."""
    data = {}
    try:
        reg_path = r"HARDWARE\DESCRIPTION\System\CentralProcessor\0"
        with winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, reg_path) as key:
            try:
                name, _ = winreg.QueryValueEx(key, "ProcessorNameString")
                data["name"] = name.strip()
            except Exception:
                pass
            try:
                vendor, _ = winreg.QueryValueEx(key, "VendorIdentifier")
                data["manufacturer"] = vendor.strip()
            except Exception:
                pass
            try:
                mhz, _ = winreg.QueryValueEx(key, "~MHz")
                data["max_clock_mhz"] = int(mhz)
            except Exception:
                pass
    except Exception as e:
        logger.debug(f"Registry CPU read failed: {e}")
    return data

def get_cpu_info() -> Dict[str, Any]:
    """
    Detects CPU hardware information using Win32_Processor and Registry fallbacks.
    Returns:
        name: str
        manufacturer: str
        cores: int or str
        threads: int or str
        max_clock_mhz: int or None
        max_clock_display: str
    """
    cpu_result = {
        "name": "Not available",
        "manufacturer": "Not available",
        "cores": "Not available",
        "threads": "Not available",
        "max_clock_mhz": None,
        "max_clock_display": "Not available",
    }

    try:
        script = (
            "Get-CimInstance Win32_Processor | "
            "Select-Object Name, Manufacturer, NumberOfCores, NumberOfLogicalProcessors, MaxClockSpeed | "
            "ConvertTo-Json"
        )
        data = run_powershell_json(script)
        
        # If multiple physical sockets exist, data could be a list
        if isinstance(data, list) and len(data) > 0:
            primary = data[0]
            # Aggregate cores/threads if multiple sockets
            total_cores = sum(d.get("NumberOfCores", 0) for d in data if isinstance(d, dict))
            total_threads = sum(d.get("NumberOfLogicalProcessors", 0) for d in data if isinstance(d, dict))
        elif isinstance(data, dict):
            primary = data
            total_cores = primary.get("NumberOfCores")
            total_threads = primary.get("NumberOfLogicalProcessors")
        else:
            primary = {}
            total_cores = None
            total_threads = None

        if primary.get("Name"):
            cpu_result["name"] = clean_string(primary["Name"])
            
        if primary.get("Manufacturer"):
            cpu_result["manufacturer"] = _normalize_manufacturer(primary["Manufacturer"])
            
        if total_cores:
            cpu_result["cores"] = int(total_cores)
            
        if total_threads:
            cpu_result["threads"] = int(total_threads)
            
        if primary.get("MaxClockSpeed"):
            try:
                mhz = int(primary["MaxClockSpeed"])
                cpu_result["max_clock_mhz"] = mhz
                cpu_result["max_clock_display"] = format_mhz(mhz)
            except (ValueError, TypeError):
                pass
                
    except Exception as e:
        logger.error(f"Error querying Win32_Processor: {e}")

    # Fallback to Registry if any critical field is missing
    reg_data = _get_cpu_registry()
    if cpu_result["name"] == "Not available" and reg_data.get("name"):
        cpu_result["name"] = clean_string(reg_data["name"])
    if cpu_result["manufacturer"] == "Not available" and reg_data.get("manufacturer"):
        cpu_result["manufacturer"] = _normalize_manufacturer(reg_data["manufacturer"])
    if cpu_result["max_clock_mhz"] is None and reg_data.get("max_clock_mhz"):
        cpu_result["max_clock_mhz"] = reg_data["max_clock_mhz"]
        cpu_result["max_clock_display"] = format_mhz(reg_data["max_clock_mhz"])
    if cpu_result["threads"] == "Not available":
        logical_count = os.cpu_count()
        if logical_count:
            cpu_result["threads"] = logical_count

    return cpu_result
