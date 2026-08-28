import logging
import winreg
from typing import Dict, Any

from utils.powershell import run_powershell_json
from utils.formatters import clean_string, clean_serial_number, format_mhz
from hardware.normalizer import normalize_cpu_info

logger = logging.getLogger(__name__)

def _get_cpu_registry() -> Dict[str, Any]:
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
    cpu_result = {
        "name": "Not available",
        "raw_name": "Not available",
        "manufacturer": "Not available",
        "cores": "Not available",
        "threads": "Not available",
        "max_clock_mhz": None,
        "max_clock_display": "Not available",
        "serial": "Not available"
    }

    try:
        script = (
            "Get-CimInstance Win32_Processor | "
            "Select-Object Name, Manufacturer, NumberOfCores, NumberOfLogicalProcessors, MaxClockSpeed, ProcessorId | "
            "ConvertTo-Json"
        )
        data = run_powershell_json(script)
        if isinstance(data, list) and len(data) > 0:
            data = data[0]

        if isinstance(data, dict):
            raw_name = clean_string(data.get("Name"))
            raw_mfg = clean_string(data.get("Manufacturer"))
            norm = normalize_cpu_info(raw_name, raw_mfg)

            cpu_result["name"] = norm["normalized_name"]
            cpu_result["raw_name"] = raw_name
            cpu_result["manufacturer"] = norm["vendor"]
            cpu_result["cores"] = data.get("NumberOfCores", "Not available")
            cpu_result["threads"] = data.get("NumberOfLogicalProcessors", "Not available")

            max_clock = data.get("MaxClockSpeed")
            if max_clock:
                try:
                    mhz_val = int(max_clock)
                    cpu_result["max_clock_mhz"] = mhz_val
                    cpu_result["max_clock_display"] = format_mhz(mhz_val)
                except (ValueError, TypeError):
                    pass
            cpu_result["serial"] = clean_serial_number(data.get("ProcessorId"), default="Not available")

    except Exception as e:
        logger.error(f"Failed to detect CPU: {e}")

    # Fallback to Registry if missing
    if cpu_result["name"] == "Not available":
        reg = _get_cpu_registry()
        raw_name = reg.get("name", "Not available")
        raw_mfg = reg.get("manufacturer", "Not available")
        norm = normalize_cpu_info(raw_name, raw_mfg)
        cpu_result["name"] = norm["normalized_name"]
        cpu_result["raw_name"] = raw_name
        cpu_result["manufacturer"] = norm["vendor"]
        if reg.get("max_clock_mhz"):
            cpu_result["max_clock_mhz"] = reg["max_clock_mhz"]
            cpu_result["max_clock_display"] = format_mhz(reg["max_clock_mhz"])

    return cpu_result
