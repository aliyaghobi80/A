import logging
from typing import List, Dict, Any

from utils.powershell import run_powershell_json
from utils.formatters import clean_string, format_bytes_to_gb, format_bytes_display

logger = logging.getLogger(__name__)

def get_storage_info() -> List[Dict[str, Any]]:
    """
    Detects all physical storage devices installed in the system.
    Returns a list of disk objects:
        model: str
        type: str (SSD, HDD, SCM, Unspecified)
        bus_type: str (NVMe, SATA, USB, etc.)
        capacity_bytes: int or None
        capacity_gb: float or None
        capacity_display: str (e.g. '500 GB' or '1.0 TB (931 GB)')
        serial: str
        health_status: str
    """
    drives: List[Dict[str, Any]] = []

    try:
        # Strategy 1: Modern Windows Storage Management API (Get-PhysicalDisk)
        script_msft = (
            "Get-PhysicalDisk | "
            "Select-Object FriendlyName, MediaType, BusType, Size, SerialNumber, HealthStatus | "
            "ConvertTo-Json"
        )
        data_msft = run_powershell_json(script_msft)
        
        if isinstance(data_msft, dict):
            raw_msft = [data_msft]
        elif isinstance(data_msft, list):
            raw_msft = data_msft
        else:
            raw_msft = []

        # Strategy 2: Win32_DiskDrive fallback / supplementary query
        script_wmi = (
            "Get-CimInstance Win32_DiskDrive | "
            "Select-Object Model, MediaType, Size, InterfaceType, SerialNumber, DeviceID | "
            "ConvertTo-Json"
        )
        data_wmi = run_powershell_json(script_wmi)
        if isinstance(data_wmi, dict):
            raw_wmi = [data_wmi]
        elif isinstance(data_wmi, list):
            raw_wmi = data_wmi
        else:
            raw_wmi = []

        if raw_msft:
            for disk in raw_msft:
                if not isinstance(disk, dict):
                    continue

                model = clean_string(disk.get("FriendlyName"))
                media_type = clean_string(disk.get("MediaType"), default="Unknown")
                bus_type = clean_string(disk.get("BusType"), default="Not available")
                
                # If bus type is NVMe or model mentions NVMe, enrich media type
                if "nvme" in bus_type.lower() or "nvme" in model.lower():
                    if media_type in ("Unknown", "Unspecified"):
                        media_type = "NVMe SSD"
                    elif "SSD" in media_type and "NVMe" not in media_type:
                        media_type = f"NVMe {media_type}"

                size_bytes = disk.get("Size")
                try:
                    size_int = int(size_bytes) if size_bytes else None
                except (ValueError, TypeError):
                    size_int = None

                cap_gb = format_bytes_to_gb(size_int)
                cap_display = format_bytes_display(size_int)
                serial = clean_string(disk.get("SerialNumber"))
                health = clean_string(disk.get("HealthStatus"), default="Healthy")

                drives.append({
                    "model": model,
                    "type": media_type,
                    "bus_type": bus_type,
                    "capacity_bytes": size_int,
                    "capacity_gb": cap_gb,
                    "capacity_display": cap_display,
                    "serial": serial,
                    "health_status": health
                })

        elif raw_wmi:
            # Fallback to WMI
            for disk in raw_wmi:
                if not isinstance(disk, dict):
                    continue

                model = clean_string(disk.get("Model"))
                size_bytes = disk.get("Size")
                try:
                    size_int = int(size_bytes) if size_bytes else None
                except (ValueError, TypeError):
                    size_int = None

                cap_gb = format_bytes_to_gb(size_int)
                cap_display = format_bytes_display(size_int)
                
                # Guess SSD / HDD if model hints it
                media_hint = clean_string(disk.get("MediaType"), default="Disk Drive")
                if "ssd" in model.lower() or "nvme" in model.lower():
                    media_type = "SSD"
                elif "hdd" in model.lower():
                    media_type = "HDD"
                else:
                    media_type = media_hint

                interface_type = clean_string(disk.get("InterfaceType"), default="Not available")
                serial = clean_string(disk.get("SerialNumber"))

                drives.append({
                    "model": model,
                    "type": media_type,
                    "bus_type": interface_type,
                    "capacity_bytes": size_int,
                    "capacity_gb": cap_gb,
                    "capacity_display": cap_display,
                    "serial": serial,
                    "health_status": "Healthy"
                })

    except Exception as e:
        logger.error(f"Error detecting storage devices: {e}")

    if not drives:
        drives.append({
            "model": "Not available",
            "type": "Not available",
            "bus_type": "Not available",
            "capacity_bytes": None,
            "capacity_gb": None,
            "capacity_display": "Not available",
            "serial": "Not available",
            "health_status": "Not available"
        })

    return drives
