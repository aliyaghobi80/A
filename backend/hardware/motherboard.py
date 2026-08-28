import logging
import winreg
from typing import Dict, Any

from utils.powershell import run_powershell_json
from utils.formatters import clean_string, clean_serial_number
from hardware.normalizer import normalize_motherboard_info

logger = logging.getLogger(__name__)

def get_motherboard_info() -> Dict[str, Any]:
    board_result = {
        "manufacturer": "Not available",
        "model": "Not available",
        "display_name": "Not available",
        "serial": "-",
        "uuid": "-",
        "version": "-"
    }

    try:
        script = (
            "$b = Get-CimInstance Win32_BaseBoard | Select-Object Manufacturer, Product, SerialNumber, Version; "
            "$cs = Get-CimInstance Win32_ComputerSystemProduct | Select-Object IdentifyingNumber, UUID, Name; "
            "[PSCustomObject]@{ "
            "  Manufacturer = $b.Manufacturer; "
            "  Product = $b.Product; "
            "  SerialNumber = $b.SerialNumber; "
            "  Version = $b.Version; "
            "  IdentifyingNumber = $cs.IdentifyingNumber; "
            "  UUID = $cs.UUID "
            "} | ConvertTo-Json"
        )
        data = run_powershell_json(script)
        if isinstance(data, list) and len(data) > 0:
            data = data[0]
        if isinstance(data, dict):
            mfg = clean_string(data.get("Manufacturer"))
            mdl = clean_string(data.get("Product"))
            norm = normalize_motherboard_info(mfg, mdl)

            board_result["manufacturer"] = mfg
            board_result["model"] = mdl
            board_result["display_name"] = norm["display_name"]
            board_result["serial"] = clean_serial_number(data.get("SerialNumber"), default="-")
            board_result["version"] = clean_string(data.get("Version"), default="-")
            board_result["uuid"] = clean_serial_number(data.get("UUID"), default="-")
    except Exception as e:
        logger.error(f"Failed to detect Motherboard: {e}")

    return board_result
