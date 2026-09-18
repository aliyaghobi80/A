import logging
from typing import List, Dict, Any

from utils.powershell import run_powershell_json
from utils.formatters import clean_string, clean_serial_number, clean_part_number, format_bytes_to_gb, format_bytes_display
from hardware.normalizer import normalize_storage_info
from hardware.storage_health import query_physical_drive_health

logger = logging.getLogger(__name__)


def check_physical_drive_is_removable_or_usb(drive_idx: int) -> bool:
    """Uses Win32 IOCTL_STORAGE_QUERY_PROPERTY on PhysicalDriveX to detect USB / removable bus in <1ms."""
    import ctypes
    import struct
    try:
        h = ctypes.windll.kernel32.CreateFileW(
            rf"\\.\PhysicalDrive{drive_idx}",
            0,
            1 | 2,  # FILE_SHARE_READ | FILE_SHARE_WRITE
            None,
            3,  # OPEN_EXISTING
            0,
            None
        )
        if h in (None, 0, -1, ctypes.c_void_p(-1).value):
            return False
        query = (ctypes.c_ulong * 3)(0, 0, 0)
        out_buf = ctypes.create_string_buffer(1024)
        bytes_returned = ctypes.c_ulong()
        res = ctypes.windll.kernel32.DeviceIoControl(
            h,
            0x002D1400,  # IOCTL_STORAGE_QUERY_PROPERTY
            query,
            ctypes.sizeof(query),
            out_buf,
            len(out_buf),
            ctypes.byref(bytes_returned),
            None
        )
        ctypes.windll.kernel32.CloseHandle(h)
        if res and bytes_returned.value >= 28:
            data = out_buf.raw[:bytes_returned.value]
            version, size, dev_type, dev_type_mod, removable, cmd_q, v_off, p_off, r_off, s_off, bus_type = struct.unpack_from('<LLBBBBLLLLL', data, 0)
            # bus_type 7 = Usb, 4 = 1394, 12 = Sd, 13 = Mmc
            if bus_type in (7, 4, 12, 13) or removable == 1:
                return True
    except Exception:
        pass
    return False


def is_removable_or_usb_physical_disk(disk: Dict[str, Any]) -> bool:
    """Return True when a physical disk belongs in the removable-media view.

    Win32_DiskDrive reports USB flash drives as ordinary ``DiskDrive`` objects
    (and many of them even report ``Fixed hard disk media``).  Showing those
    objects next to the customer's SSD/HDD is misleading, so use all identity
    signals Windows exposes instead of trusting MediaType alone.
    """
    def value(name: str) -> str:
        for k in (name, name.lower(), name.capitalize(), name.upper()):
            if k in disk and disk[k]:
                return str(disk[k]).strip().upper()
        return ""

    bus_type = value("BusType")
    interface = value("InterfaceType")
    if not interface:
        interface = value("interface")
    pnp_id = value("PNPDeviceID")
    media_type = value("MediaType")
    model = value("Model")
    raw_model = value("raw_model")
    friendly = value("FriendlyName")
    combined_model = f"{model} {raw_model} {friendly} {pnp_id}".upper()

    # Direct bus type / interface signals
    if bus_type in {"USB", "SD", "MMC", "1394"}:
        return True
    if interface == "USB":
        return True
    if pnp_id.startswith("USB\\") or "USBSTOR\\" in pnp_id or "USB" in bus_type:
        return True
    if "REMOVABLE" in media_type:
        return True

    # Check for known flash drive and removable device keywords
    flash_keywords = (
        "USB", "FLASH", "PENDRIVE", "PEN DRIVE", "THUMBDRIVE", "THUMB DRIVE",
        "UFD", "CRUZER", "DATATRAVELER", "JETFLASH", "ULTRA FIT", "CARD READER",
        "SDHC", "SDXC", "MICROSD", "ADATA USB", "ADATA UFD"
    )
    if any(k in combined_model for k in flash_keywords):
        return True

    # Many ADATA flash drives report as "ADATA USB Flash Drive" or similar, but even if
    # the word USB is obscured, ADATA flash media <= 65GB without SSD/NVMe keyword is a flash drive
    if "ADATA" in combined_model and not any(k in combined_model for k in ("SSD", "NVME", "SU650", "SU800", "SX8200", "XPG")):
        size_bytes = disk.get("Size") or disk.get("size")
        try:
            size_int = int(size_bytes) if size_bytes else 0
            if 0 < size_int <= 70 * 1024 * 1024 * 1024:
                return True
        except (ValueError, TypeError):
            pass

    # Some legacy card readers only expose the WMI removable capability bit.
    capabilities = disk.get("Capabilities")
    if not isinstance(capabilities, list):
        capabilities = [capabilities]
    try:
        # Win32_DiskDrive capability 7: Supports Removable Media.
        if 7 in {int(item) for item in capabilities if item is not None}:
            return True
    except (TypeError, ValueError):
        pass
    return False


def get_storage_info() -> List[Dict[str, Any]]:
    """
    Detects all physical storage devices and calculates health via the Storage Health Engine.
    """
    drives: List[Dict[str, Any]] = []

    try:
        # Fast query: Win32_DiskDrive via Get-CimInstance (~0.4s vs ~2.3s for Get-PhysicalDisk)
        script_wmi = (
            "$busByNumber = @{}; "
            "try { Get-Disk | ForEach-Object { $busByNumber[[string]$_.Number] = [string]$_.BusType } } catch {}; "
            "Get-CimInstance Win32_DiskDrive | "
            "Select-Object DeviceID, Index, Model, MediaType, Size, InterfaceType, PNPDeviceID, Capabilities, SerialNumber, PartNumber, "
            "@{Name='BusType';Expression={ $busByNumber[[string]$_.Index] }} | "
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
                # USB flash media is displayed only in the dedicated removable
                # drives section.  Do this before a health probe so an Adata
                # flash drive cannot be mistaken for an internal disk.
                if is_removable_or_usb_physical_disk(disk):
                    logger.debug("Excluded removable disk from storage list: %s", disk.get("Model"))
                    continue

                idx = disk.get("Index") if disk.get("Index") is not None else i
                try:
                    idx_int = int(idx)
                except (ValueError, TypeError):
                    idx_int = i

                if check_physical_drive_is_removable_or_usb(idx_int):
                    logger.debug("Excluded removable disk via IOCTL: %s (PhysicalDrive%d)", disk.get("Model"), idx_int)
                    continue

                friendly = clean_string(disk.get("Model"), default=f"Disk #{idx_int}")
                size_bytes = disk.get("Size")
                try:
                    size_int = int(size_bytes) if size_bytes else None
                except (ValueError, TypeError):
                    size_int = None

                cap_gb = format_bytes_to_gb(size_int)
                cap_display = format_bytes_display(size_int)
                serial = clean_serial_number(disk.get("SerialNumber"), default="-")
                bus_type = clean_string(
                    disk.get("BusType") or disk.get("InterfaceType"),
                    default="SATA",
                )
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
            if is_removable_or_usb_physical_disk(disk):
                continue

            dev_id_raw = disk.get("DeviceId") or "0"
            try:
                dev_idx = int(dev_id_raw)
            except (ValueError, TypeError):
                dev_idx = 0

            if check_physical_drive_is_removable_or_usb(dev_idx):
                logger.debug("Excluded removable disk via IOCTL: %s (PhysicalDrive%d)", disk.get("FriendlyName"), dev_idx)
                continue

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


def get_connected_usb_drives() -> List[Dict[str, Any]]:
    """
    Dynamically detects all connected USB flash drives and removable media.
    Uses Win32 ctypes API for fast, elevation-free querying of volume and bus properties.
    """
    import ctypes
    import struct
    import os
    from ctypes import wintypes

    drives: List[Dict[str, Any]] = []
    try:
        # Explicit pointer-sized signatures avoid truncating volume handles on
        # 64-bit Windows and preserve the full 64-bit capacity returned by Win32.
        api = ctypes.windll.kernel32
        api.CreateFileW.argtypes = [wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD,
                                   wintypes.LPVOID, wintypes.DWORD, wintypes.DWORD, wintypes.HANDLE]
        api.CreateFileW.restype = wintypes.HANDLE
        api.DeviceIoControl.argtypes = [wintypes.HANDLE, wintypes.DWORD, wintypes.LPVOID,
                                       wintypes.DWORD, wintypes.LPVOID, wintypes.DWORD,
                                       ctypes.POINTER(wintypes.DWORD), wintypes.LPVOID]
        api.CloseHandle.argtypes = [wintypes.HANDLE]
        api.GetDiskFreeSpaceExW.argtypes = [wintypes.LPCWSTR,
                                          ctypes.POINTER(ctypes.c_ulonglong),
                                          ctypes.POINTER(ctypes.c_ulonglong),
                                          ctypes.POINTER(ctypes.c_ulonglong)]
        api.GetDiskFreeSpaceExW.restype = wintypes.BOOL
        bitmask = ctypes.windll.kernel32.GetLogicalDrives()
        system_drive = (os.environ.get("SystemDrive") or "C:").upper().rstrip("\\")

        for i in range(26):
            if not (bitmask & (1 << i)):
                continue

            letter = chr(ord("A") + i) + ":"
            root_path = letter + "\\"
            drive_type = ctypes.windll.kernel32.GetDriveTypeW(root_path)

            # 2 = DRIVE_REMOVABLE, 3 = DRIVE_FIXED
            if drive_type not in (2, 3):
                continue

            if letter.upper() == system_drive:
                continue

            is_usb = (drive_type == 2)
            vendor = ""
            product = ""
            serial = ""

            # Query device descriptor via IOCTL_STORAGE_QUERY_PROPERTY
            try:
                h = ctypes.windll.kernel32.CreateFileW(
                    rf"\\.\{letter}",
                    0,  # Query access only (no admin required)
                    1 | 2,  # FILE_SHARE_READ | FILE_SHARE_WRITE
                    None,
                    3,  # OPEN_EXISTING
                    0,
                    None
                )
                if h not in (None, 0, -1, ctypes.c_void_p(-1).value):
                    query = (ctypes.c_ulong * 3)(0, 0, 0)
                    out_buf = ctypes.create_string_buffer(1024)
                    bytes_returned = ctypes.c_ulong()
                    res = ctypes.windll.kernel32.DeviceIoControl(
                        h,
                        0x002D1400,  # IOCTL_STORAGE_QUERY_PROPERTY
                        query,
                        ctypes.sizeof(query),
                        out_buf,
                        len(out_buf),
                        ctypes.byref(bytes_returned),
                        None
                    )
                    if res and bytes_returned.value >= 28:
                        data = out_buf.raw[:bytes_returned.value]
                        version, size, dev_type, dev_type_mod, removable, cmd_q, v_off, p_off, r_off, s_off, bus_type = struct.unpack_from('<LLBBBBLLLLL', data, 0)
                        if bus_type == 7 or removable == 1:
                            is_usb = True

                        def _get_str(off: int) -> str:
                            if 0 < off < len(data):
                                end = data.find(b"\x00", off)
                                raw = data[off:end] if end != -1 else data[off:]
                                return raw.decode("latin-1", errors="ignore").strip()
                            return ""

                        vendor = _get_str(v_off)
                        product = _get_str(p_off)
                        serial = _get_str(s_off)
                    ctypes.windll.kernel32.CloseHandle(h)
            except Exception as e:
                logger.debug(f"DeviceIoControl query failed for {letter}: {e}")

            if not is_usb:
                continue

            # Query volume information
            vol_name_buf = ctypes.create_unicode_buffer(261)
            fs_name_buf = ctypes.create_unicode_buffer(261)
            vol_serial = ctypes.c_ulong()
            max_comp = ctypes.c_ulong()
            flags = ctypes.c_ulong()
            ctypes.windll.kernel32.GetVolumeInformationW(
                root_path,
                vol_name_buf,
                260,
                ctypes.byref(vol_serial),
                ctypes.byref(max_comp),
                ctypes.byref(flags),
                fs_name_buf,
                260
            )

            # Query disk space
            free_bytes = ctypes.c_ulonglong(0)
            total_bytes = ctypes.c_ulonglong(0)
            total_free = ctypes.c_ulonglong(0)
            space_ok = ctypes.windll.kernel32.GetDiskFreeSpaceExW(
                root_path,
                ctypes.byref(free_bytes),
                ctypes.byref(total_bytes),
                ctypes.byref(total_free)
            )

            if not space_ok:
                logger.warning("Could not read capacity of volume %s", letter)
                continue

            t_bytes = total_bytes.value
            f_bytes = total_free.value
            u_bytes = max(0, t_bytes - f_bytes)
            t_gb = round(t_bytes / (1024 ** 3), 2) if t_bytes > 0 else 0.0
            f_gb = round(f_bytes / (1024 ** 3), 2) if t_bytes > 0 else 0.0
            u_gb = round(u_bytes / (1024 ** 3), 2) if t_bytes > 0 else 0.0
            pct = round((u_bytes / t_bytes * 100), 1) if t_bytes > 0 else 0.0

            drives.append({
                "drive_letter": letter,
                "volume_name": vol_name_buf.value or "فلش مموری",
                "file_system": fs_name_buf.value or "FAT32",
                "vendor": vendor,
                "product": product,
                "serial": serial,
                "total_bytes": t_bytes,
                "free_bytes": f_bytes,
                "used_bytes": u_bytes,
                "total_gb": t_gb,
                "free_gb": f_gb,
                "used_gb": u_gb,
                "percent_used": pct,
                "is_removable": True
            })
    except Exception as ex:
        logger.error(f"Error querying USB drives: {ex}")

    return drives


def safe_eject_drive(drive_letter: str) -> Dict[str, Any]:
    """
    Safely ejects / dismounts a USB removable drive using native Windows Shell COM.
    CRITICAL: Strictly dismounts/ejects without formatting or deleting anything.
    """
    import os
    import re
    import subprocess

    drive = str(drive_letter).strip().upper()
    if not drive.endswith(":"):
        drive = drive + ":"

    if not re.match(r"^[A-Z]:$", drive):
        return {"success": False, "message": "نام درایو نامعتبر است."}

    system_drive = (os.environ.get("SystemDrive") or "C:").upper().rstrip("\\")
    if drive == system_drive:
        return {"success": False, "message": "امکان خروج درایو سیستمی ویندوز وجود ندارد."}

    # Execute Explorer Shell native Eject verb
    ps_cmd = (
        f"$sh = New-Object -ComObject Shell.Application; "
        f"$item = $sh.Namespace(17).ParseName('{drive}'); "
        f"if ($item) {{ "
        f"  $ejected = $false; "
        f"  foreach ($v in $item.Verbs()) {{ "
        f"    if ($v.Name -match 'E.*ject|خروج|Eject') {{ "
        f"      $v.DoIt(); $ejected = $true; break "
        f"    }} "
        f"  }}; "
        f"  if (-not $ejected) {{ $item.InvokeVerb('E&ject') }}; "
        f"  Write-Output 'OK' "
        f"}} else {{ "
        f"  Write-Output 'NOT_FOUND' "
        f"}}"
    )

    try:
        proc = subprocess.run(
            ["powershell", "-NoProfile", "-Command", ps_cmd],
            capture_output=True,
            text=True,
            timeout=10
        )
        out = (proc.stdout or "").strip()
        if "NOT_FOUND" in out:
            return {"success": False, "message": f"درایو {drive} یافت نشد یا قبلاً خارج شده است."}

        return {
            "success": True,
            "message": f"فلش مموری ({drive}) با موفقیت به صورت ایمن خارج شد و اکنون قابل جدا کردن است."
        }
    except Exception as e:
        logger.error(f"Failed to safely eject {drive}: {e}")
        return {"success": False, "message": f"خطا در خروج ایمن درایو: {e}"}

