import logging
import platform
import socket
import os
import re
import winreg
from typing import Dict, Any

from utils.powershell import run_powershell_json
from utils.formatters import clean_serial_number, clean_string

logger = logging.getLogger(__name__)


_GENERIC_SYSTEM_VALUES = {
    "",
    "not available",
    "none",
    "default string",
    "system product name",
    "to be filled by o.e.m.",
    "to be filled by oem",
    "unknown",
}


def _meaningful_system_value(value: Any) -> str:
    cleaned = clean_string(value, default="")
    return "" if cleaned.strip().lower() in _GENERIC_SYSTEM_VALUES else cleaned.strip()


def build_device_display_name(
    manufacturer: Any,
    model: Any,
    sku: Any,
    product_name: Any = "",
    product_version: Any = "",
) -> Dict[str, str]:
    """Build a customer-facing device model instead of the Windows hostname."""
    maker = _meaningful_system_value(manufacturer)
    candidates = [
        _meaningful_system_value(model),
        _meaningful_system_value(product_version),
        _meaningful_system_value(product_name),
    ]
    base = next(
        (
            value
            for value in candidates
            if value
            and value.lower() != maker.lower()
            and not value.lower().endswith("computer")
        ),
        "",
    )
    raw_sku = _meaningful_system_value(sku)
    sku_text = re.sub(
        r"(?i)^(asus|lenovo|hp|dell|acer|msi)[_\s-]+"
        r"(notebook|desktop|aio|mb|mt)?[_\s-]*",
        "",
        raw_sku,
    ).replace("_", " ").strip()
    model_code = ""
    for source in (sku_text, base):
        matches = re.findall(
            r"\b(?=[A-Z0-9-]*\d)(?=[A-Z0-9-]*[A-Z])[A-Z][A-Z0-9-]{2,15}\b",
            source.upper(),
        )
        matches = [
            value
            for value in matches
            if not re.fullmatch(r"(?:LP)?DDR\d+", value)
        ]
        if matches:
            model_code = matches[0]
            break
    if not base:
        base = sku_text or model_code
    elif model_code and model_code.lower() not in base.lower():
        base = f"{base} {model_code}".strip()

    maker_alias = maker
    maker_upper = maker.upper()
    if "ASUSTEK" in maker_upper:
        maker_alias = "ASUS"
    elif "GIGABYTE" in maker_upper:
        maker_alias = "GIGABYTE"
    elif "MICRO-STAR" in maker_upper:
        maker_alias = "MSI"
    elif maker_upper.startswith("HP") or "HEWLETT" in maker_upper:
        maker_alias = "HP"

    display_name = base or maker_alias or "Not available"
    if (
        maker_alias
        and display_name != "Not available"
        and maker_alias.lower() not in display_name.lower()
    ):
        display_name = f"{maker_alias} {display_name}"
    return {
        "display_name": display_name,
        "model_code": model_code or "Not available",
    }


def _get_registry_windows_version() -> Dict[str, str]:
    """Reads accurate Windows 10/11 version and build metadata from CurrentVersion registry key."""
    info = {}
    path = r"SOFTWARE\Microsoft\Windows NT\CurrentVersion"
    try:
        with winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, path) as key:
            for name in ["DisplayVersion", "ReleaseId", "CurrentBuild", "UBR", "ProductName", "EditionID"]:
                try:
                    val, _ = winreg.QueryValueEx(key, name)
                    info[name] = str(val).strip()
                except Exception:
                    pass
    except Exception as e:
        logger.debug(f"Registry Windows version read error: {e}")
    return info

def get_windows_and_system_info() -> Dict[str, Any]:
    """
    Detects Windows OS details and Computer System model/manufacturer.
    Returns:
        windows: {
            edition: str,
            version: str,
            build: str,
            architecture: str
        },
        system: {
            computer_name: str,
            manufacturer: str,
            model: str
        }
    """
    windows_res = {
        "edition": "Not available",
        "version": "Not available",
        "build": "Not available",
        "architecture": "Not available"
    }

    system_res = {
        "computer_name": clean_string(socket.gethostname(), default="Not available"),
        "manufacturer": "Not available",
        "model": "Not available",
        "serial": "Not available",
        "uuid": "Not available",
        "sku": "Not available",
        "asset_tag": "Not available",
        "chassis_type": "Unknown",
        "display_name": "Not available",
        "model_code": "Not available",
    }
    os_data: Dict[str, Any] = {}

    reg_info = _get_registry_windows_version()

    # Query OS, ComputerSystem & ComputerSystemProduct
    try:
        script = (
            "$os = Get-CimInstance Win32_OperatingSystem | Select-Object Caption, Version, BuildNumber, OSArchitecture, CSName; "
            "$sys = Get-CimInstance Win32_ComputerSystem | Select-Object Manufacturer, Model, CSName, SystemSKUNumber; "
            "$csp = Get-CimInstance Win32_ComputerSystemProduct | Select-Object IdentifyingNumber, UUID, SKUNumber, Name, Vendor, Version; "
            "$enc = Get-CimInstance Win32_SystemEnclosure | Select-Object SerialNumber, SMBIOSAssetTag, ChassisTypes; "
            "$bios = Get-CimInstance Win32_BIOS | Select-Object SerialNumber; "
            "[PSCustomObject]@{ OS = $os; System = $sys; Product = $csp; Enclosure = $enc; BIOS = $bios } | ConvertTo-Json"
        )
        data = run_powershell_json(script)
        if isinstance(data, dict):
            os_data = data.get("OS") or {}
            sys_data = data.get("System") or {}
            csp_data = data.get("Product") or {}
            enclosure_data = data.get("Enclosure") or {}
            bios_data = data.get("BIOS") or {}

            # OS Edition
            caption = os_data.get("Caption")
            if caption:
                clean_cap = clean_string(caption)
                if clean_cap.startswith("Microsoft "):
                    clean_cap = clean_cap[10:].strip()
                windows_res["edition"] = clean_cap
            elif reg_info.get("ProductName"):
                windows_res["edition"] = reg_info["ProductName"]

            # Architecture
            arch = os_data.get("OSArchitecture")
            if arch:
                windows_res["architecture"] = clean_string(arch)
            else:
                windows_res["architecture"] = "64-bit" if platform.machine().endswith("64") else "32-bit"

            # Computer Name
            cs_name = os_data.get("CSName") or sys_data.get("CSName")
            if cs_name:
                system_res["computer_name"] = clean_string(cs_name)

            # System Manufacturer and Model
            if sys_data.get("Manufacturer"):
                system_res["manufacturer"] = clean_string(sys_data["Manufacturer"])
            if sys_data.get("Model"):
                system_res["model"] = clean_string(sys_data["Model"])
            raw_serial = (
                csp_data.get("IdentifyingNumber")
                or enclosure_data.get("SerialNumber")
                or bios_data.get("SerialNumber")
            )
            system_res["serial"] = clean_serial_number(raw_serial, default="Not available")
            system_res["uuid"] = clean_serial_number(csp_data.get("UUID"), default="Not available")
            system_res["sku"] = (clean_string(sys_data.get("SystemSKUNumber"), default="")
                                 or clean_string(csp_data.get("SKUNumber"), default="Not available"))
            system_res["asset_tag"] = clean_serial_number(
                enclosure_data.get("SMBIOSAssetTag"),
                default="Not available",
            )

            chassis_values = enclosure_data.get("ChassisTypes") or []
            if not isinstance(chassis_values, list):
                chassis_values = [chassis_values]
            chassis_codes = {int(value) for value in chassis_values if str(value).isdigit()}
            portable_codes = {8, 9, 10, 11, 12, 14, 18, 21, 30, 31, 32}
            desktop_codes = {3, 4, 5, 6, 7, 13, 15, 16, 24, 35, 36}
            if chassis_codes & portable_codes:
                system_res["chassis_type"] = "Laptop"
            elif chassis_codes & desktop_codes:
                system_res["chassis_type"] = "Desktop"

    except Exception as e:
        logger.error(f"Error querying Windows and System info: {e}")

    # Same firmware identity backing System Information's System SKU.
    try:
        with winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, r'HARDWARE\DESCRIPTION\System\BIOS') as key:
            for field, name in [('sku', 'SystemSKU'), ('model', 'SystemProductName'), ('manufacturer', 'SystemManufacturer')]:
                if system_res[field] == 'Not available':
                    try:
                        system_res[field] = clean_string(winreg.QueryValueEx(key, name)[0])
                    except OSError:
                        pass
    except OSError:
        pass
    if system_res['model'] == 'Not available' and system_res['sku'] != 'Not available':
        system_res['model'] = system_res['sku']

    display_identity = build_device_display_name(
        system_res["manufacturer"],
        system_res["model"],
        system_res["sku"],
        csp_data.get("Name") if "csp_data" in locals() else "",
        csp_data.get("Version") if "csp_data" in locals() else "",
    )
    system_res.update(display_identity)

    # Fallback / Enrich Version & Build from Registry
    disp_ver = reg_info.get("DisplayVersion") or reg_info.get("ReleaseId")
    if disp_ver:
        windows_res["version"] = f"Version {disp_ver}" if not disp_ver.lower().startswith("version") else disp_ver
    
    current_build = reg_info.get("CurrentBuild")
    ubr = reg_info.get("UBR")
    if current_build:
        if ubr:
            windows_res["build"] = f"{current_build}.{ubr}"
        else:
            windows_res["build"] = current_build
    elif windows_res["build"] == "Not available" and os_data.get("BuildNumber"):
        windows_res["build"] = str(os_data["BuildNumber"])

    if windows_res["architecture"] == "Not available":
        windows_res["architecture"] = "64-bit" if platform.architecture()[0] == "64bit" else "32-bit"

    return {
        "windows": windows_res,
        "system": system_res
    }
