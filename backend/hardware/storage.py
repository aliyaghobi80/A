import logging
from typing import List, Dict, Any

from utils.powershell import run_powershell_json
from utils.formatters import clean_string, clean_serial_number, clean_part_number, format_bytes_to_gb, format_bytes_display
from hardware.normalizer import normalize_storage_info
from hardware.storage_health import query_physical_drive_health

logger = logging.getLogger(__name__)

def get_storage_info() -> List[Dict[str, Any]]:
    """
    Detects all physical storage devices and calculates health via the Storage Health Engine.
    """
    drives: List[Dict[str, Any]] = []

    try:
        # Fast query: Win32_DiskDrive via Get-CimInstance (~0.4s vs ~2.3s for Get-PhysicalDisk)
        script_wmi = (
            "Get-CimInstance Win32_DiskDrive | "
            "Select-Object DeviceID, Index, Model, MediaType, Size, InterfaceType, SerialNumber, PartNumber | "
            "ConvertTo-Json"
        )
        data_wmi = run_powershell_json(script_wmi, timeout=6)
        if isinstance(data_wmi, dict):
            raw_wmi = [data_wmi]
        elif isinstance(data_wmi, list):
            raw_wmi = data_wmi
        else:
            raw_wmi = []

        if raw_wmi:
            for i, disk in enumerate(raw_wmi):
                idx = disk.get("Index") or i
                try:
                    idx_int = int(idx)
                except (ValueError, TypeError):
                    idx_int = i

                friendly = clean_string(disk.get("Model"), default=f"Disk #{idx_int}")
                size_bytes = disk.get("Size")
                try:
                    size_int = int(size_bytes) if size_bytes else None
                except (ValueError, TypeError):
                    size_int = None

                cap_gb = format_bytes_to_gb(size_int)
                cap_display = format_bytes_display(size_int)
                serial = clean_serial_number(disk.get("SerialNumber"), default="-")
                bus_type = clean_string(disk.get("InterfaceType"), default="SATA")
                media_type = clean_string(disk.get("MediaType"), default="Fixed hard disk media")

                health_data = query_physical_drive_health(idx_int, bus_type, media_type, friendly)

                # Refine bus & media type from NVMe direct IOCTL probe or model keywords
                if "NVMe" in health_data.get("source", "") or "NVMe" in health_data.get("health_source", "") or "NVME" in friendly.upper():
                    bus_type = "NVMe"
                    media_type = "SSD"
                elif bus_type.upper() in ("IDE", "SCSI", "ATAPI"):
                    bus_type = "SATA"

                norm = normalize_storage_info(friendly, friendly, bus_type, media_type)

                drives.append({
                    "device_id": str(idx_int),
                    "model": norm["display_name"],
                    "raw_model": friendly,
                    "type_description": norm["type_description"],
                    "part_number": clean_part_number(disk.get("PartNumber"), default="-"),
                    "type": media_type,
                    "bus_type": bus_type,
                    "capacity_bytes": size_int,
                    "capacity_gb": cap_gb,
                    "capacity_display": cap_display,
                    "serial": serial,
                    "health_status": health_data["health_grade_fa"],
                    "health_percent": health_data["health_percent"],
                    "health_type": health_data["health_type"],
                    "health_grade": health_data["health_grade"],
                    "health_grade_fa": health_data["health_grade_fa"],
                    "health_source": health_data["health_source"],
                    "source": health_data["source"],
                    "wear_percent": health_data["wear_percent"],
                    "temperature_c": health_data["temperature_c"],
                    "power_on_hours": health_data["power_on_hours"],
                    "power_cycles": health_data["power_cycles"],
                    "unsafe_shutdowns": health_data["unsafe_shutdowns"],
                    "media_errors": health_data["media_errors"],
                    "available_spare_percent": health_data["available_spare_percent"],
                    "reallocated_sectors": health_data["reallocated_sectors"],
                    "pending_sectors": health_data["pending_sectors"],
                    "smart_status": health_data["smart_status"],
                    "diagnostic_error": health_data["diagnostic_error"]
                })
            return drives

        # Fallback: Query MSFT_PhysicalDisk if Win32_DiskDrive was empty
        script_msft = (
            "Get-PhysicalDisk | "
            "Select-Object DeviceId, FriendlyName, MediaType, BusType, Size, SerialNumber, HealthStatus, OperationalStatus, Model, PartNumber | "
            "ConvertTo-Json"
        )
        data_msft = run_powershell_json(script_msft, timeout=8)

        if isinstance(data_msft, dict):
            raw_msft = [data_msft]
        elif isinstance(data_msft, list):
            raw_msft = data_msft
        else:
            raw_msft = []

        # Process MSFT_PhysicalDisk results
        for disk in raw_msft:
            if not isinstance(disk, dict):
                continue

            dev_id_raw = disk.get("DeviceId") or "0"
            try:
                dev_idx = int(dev_id_raw)
            except (ValueError, TypeError):
                dev_idx = 0

            friendly_name = clean_string(disk.get("FriendlyName"))
            disk_model = clean_string(disk.get("Model"), default=friendly_name)
            part_no = clean_part_number(disk.get("PartNumber"), default="-")

            media_type = clean_string(disk.get("MediaType"), default="Unknown")
            bus_type = clean_string(disk.get("BusType"), default="Not available")

            size_bytes = disk.get("Size")
            try:
                size_int = int(size_bytes) if size_bytes else None
            except (ValueError, TypeError):
                size_int = None

            cap_gb = format_bytes_to_gb(size_int)
            cap_display = format_bytes_display(size_int)
            serial = clean_serial_number(disk.get("SerialNumber"), default="-")

            norm = normalize_storage_info(disk_model, friendly_name, bus_type, media_type)
            health_data = query_physical_drive_health(dev_idx, bus_type, media_type, friendly_name)

            drives.append({
                "device_id": str(dev_idx),
                "model": norm["display_name"],
                "raw_model": disk_model,
                "type_description": norm["type_description"],
                "part_number": part_no if part_no != "-" else (disk_model if disk_model != friendly_name else "-"),
                "type": media_type,
                "bus_type": bus_type,
                "capacity_bytes": size_int,
                "capacity_gb": cap_gb,
                "capacity_display": cap_display,
                "serial": serial,
                "health_status": health_data["health_grade_fa"],
                "health_percent": health_data["health_percent"],
                "health_type": health_data["health_type"],
                "health_grade": health_data["health_grade"],
                "health_grade_fa": health_data["health_grade_fa"],
                "health_source": health_data["health_source"],
                "source": health_data["source"],
                "wear_percent": health_data["wear_percent"],
                "temperature_c": health_data["temperature_c"],
                "power_on_hours": health_data["power_on_hours"],
                "power_cycles": health_data["power_cycles"],
                "unsafe_shutdowns": health_data["unsafe_shutdowns"],
                "media_errors": health_data["media_errors"],
                "available_spare_percent": health_data["available_spare_percent"],
                "reallocated_sectors": health_data["reallocated_sectors"],
                "pending_sectors": health_data["pending_sectors"],
                "smart_status": health_data["smart_status"],
                "diagnostic_error": health_data["diagnostic_error"]
            })

    except Exception as e:
        logger.error(f"Failed to detect storage devices: {e}")

    return drives
