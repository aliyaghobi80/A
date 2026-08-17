import logging
import winreg
from typing import Dict, Any

from utils.powershell import run_powershell_json
from utils.formatters import clean_string, parse_wmi_date

logger = logging.getLogger(__name__)

def _get_bios_registry() -> Dict[str, str]:
    """Fallback registry query for BIOS/UEFI information."""
    data = {}
    try:
        reg_path = r"HARDWARE\DESCRIPTION\System\BIOS"
        with winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, reg_path) as key:
            for field, reg_name in [
                ("manufacturer", "BIOSVendor"),
                ("version", "BIOSVersion"),
                ("date", "BIOSReleaseDate")
            ]:
                try:
                    val, _ = winreg.QueryValueEx(key, reg_name)
                    data[field] = clean_string(val)
                except Exception:
                    pass
    except Exception as e:
        logger.debug(f"Registry BIOS read failed: {e}")
    return data

def get_bios_info() -> Dict[str, Any]:
    """
    Detects BIOS / UEFI firmware information.
    Returns:
        manufacturer: str
        version: str
        date: str
    """
    bios_result = {
        "manufacturer": "Not available",
        "version": "Not available",
        "date": "Not available",
        "serial": "Not available"
    }

    try:
        script = (
            "Get-CimInstance Win32_BIOS | "
            "Select-Object Manufacturer, SMBIOSBIOSVersion, ReleaseDate, Version, SerialNumber | "
            "ConvertTo-Json"
        )
        data = run_powershell_json(script)
        if isinstance(data, list) and len(data) > 0:
            data = data[0]
        if isinstance(data, dict):
            if data.get("Manufacturer"):
                bios_result["manufacturer"] = clean_string(data["Manufacturer"])
            
            # Version preference: SMBIOSBIOSVersion (e.g. F22 or 1802) or Version
            ver = data.get("SMBIOSBIOSVersion") or data.get("Version")
            if ver:
                bios_result["version"] = clean_string(ver)

            if data.get("ReleaseDate"):
                bios_result["date"] = parse_wmi_date(data["ReleaseDate"])

            if data.get("SerialNumber"):
                bios_result["serial"] = clean_string(data["SerialNumber"])
    except Exception as e:
        logger.error(f"Error querying Win32_BIOS: {e}")

    # Fallback to Registry if missing
    reg_data = _get_bios_registry()
    if bios_result["manufacturer"] == "Not available" and reg_data.get("manufacturer"):
        bios_result["manufacturer"] = reg_data["manufacturer"]
    if bios_result["version"] == "Not available" and reg_data.get("version"):
        bios_result["version"] = reg_data["version"]
    if bios_result["date"] == "Not available" and reg_data.get("date"):
        bios_result["date"] = parse_wmi_date(reg_data["date"])

    return bios_result
