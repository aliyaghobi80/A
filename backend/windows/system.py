import logging
import platform
import socket
import os
import winreg
from typing import Dict, Any

from utils.powershell import run_powershell_json
from utils.formatters import clean_string

logger = logging.getLogger(__name__)

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
        "model": "Not available"
    }

    reg_info = _get_registry_windows_version()

    # Query OS & ComputerSystem
    try:
        script = (
            "$os = Get-CimInstance Win32_OperatingSystem | Select-Object Caption, Version, BuildNumber, OSArchitecture, CSName; "
            "$sys = Get-CimInstance Win32_ComputerSystem | Select-Object Manufacturer, Model, CSName; "
            "[PSCustomObject]@{ OS = $os; System = $sys } | ConvertTo-Json"
        )
        data = run_powershell_json(script)
        if isinstance(data, dict):
            os_data = data.get("OS") or {}
            sys_data = data.get("System") or {}

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

    except Exception as e:
        logger.error(f"Error querying Windows and System info: {e}")

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
