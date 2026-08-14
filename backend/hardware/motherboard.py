import logging
import winreg
from typing import Dict, Any

from utils.powershell import run_powershell_json
from utils.formatters import clean_string

logger = logging.getLogger(__name__)

def _get_motherboard_registry() -> Dict[str, str]:
    """Fallback registry query for motherboard information."""
    data = {}
    try:
        reg_path = r"HARDWARE\DESCRIPTION\System\BIOS"
        with winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, reg_path) as key:
            for field, reg_name in [("manufacturer", "BaseBoardManufacturer"), ("model", "BaseBoardProduct"), ("version", "BaseBoardVersion")]:
                try:
                    val, _ = winreg.QueryValueEx(key, reg_name)
                    data[field] = clean_string(val)
                except Exception:
                    pass
    except Exception as e:
        logger.debug(f"Registry motherboard read failed: {e}")
    return data

def get_motherboard_info() -> Dict[str, Any]:
    """
    Detects Motherboard (Baseboard) information using Win32_BaseBoard.
    Returns:
        manufacturer: str
        model: str
        serial: str
    """
    board_result = {
        "manufacturer": "Not available",
        "model": "Not available",
        "serial": "Not available"
    }

    try:
        script = (
            "Get-CimInstance Win32_BaseBoard | "
            "Select-Object Manufacturer, Product, SerialNumber, Version | "
            "ConvertTo-Json"
        )
        data = run_powershell_json(script)
        if isinstance(data, list) and len(data) > 0:
            data = data[0]
        if isinstance(data, dict):
            if data.get("Manufacturer"):
                board_result["manufacturer"] = clean_string(data["Manufacturer"])
            if data.get("Product"):
                board_result["model"] = clean_string(data["Product"])
            if data.get("SerialNumber"):
                board_result["serial"] = clean_string(data["SerialNumber"])
    except Exception as e:
        logger.error(f"Error querying Win32_BaseBoard: {e}")

    # Fallback to Registry if missing
    reg_data = _get_motherboard_registry()
    if board_result["manufacturer"] == "Not available" and reg_data.get("manufacturer"):
        board_result["manufacturer"] = reg_data["manufacturer"]
    if board_result["model"] == "Not available" and reg_data.get("model"):
        board_result["model"] = reg_data["model"]

    return board_result
