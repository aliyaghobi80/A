import ctypes
from ctypes import wintypes
import struct
import subprocess
import shutil
import logging
import os
from typing import Dict, Any, Optional

logger = logging.getLogger(__name__)

IOCTL_STORAGE_QUERY_PROPERTY = 0x002D1400
IOCTL_STORAGE_PREDICT_FAILURES = 0x002D1100
FILE_SHARE_READ = 0x00000001
FILE_SHARE_WRITE = 0x00000002
OPEN_EXISTING = 3

kernel32 = ctypes.WinDLL('kernel32', use_last_error=True)

def _query_smartctl(device_index: int) -> Optional[Dict[str, Any]]:
    """Query smartctl if present on the system."""
    smartctl_bin = shutil.which("smartctl")
    if not smartctl_bin:
        for candidate in [
            r"C:\Program Files\smartmontools\bin\smartctl.exe",
            r"C:\Program Files (x86)\smartmontools\bin\smartctl.exe",
            r"G:\MarkaziSystem\bin\smartctl.exe",
            r"G:\MarkaziSystem\backend\bin\smartctl.exe"
        ]:
            if os.path.isfile(candidate):
                smartctl_bin = candidate
                break

    if not smartctl_bin:
        return None

    try:
        startupinfo = subprocess.STARTUPINFO()
        startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW
        proc = subprocess.run(
            [smartctl_bin, "-j", "-a", f"/dev/pd{device_index}"],
            capture_output=True,
            text=True,
            timeout=4,
            startupinfo=startupinfo,
            creationflags=0x08000000
        )
        if proc.stdout.strip():
            import json
            return json.loads(proc.stdout)
    except Exception as e:
        logger.debug(f"[STORAGE HEALTH] smartctl query on pd{device_index} error: {e}")
    return None

def query_physical_drive_health(device_index: int, bus_type: str = "", media_type: str = "", model_hint: str = "") -> Dict[str, Any]:
    """
    Robust Multi-Tier Storage Health Engine:
    1. Native Windows NVMe Protocol-Specific IOCTL (Log Page 0x02)
    2. Native Windows SATA SMART IOCTL (IOCTL_STORAGE_PREDICT_FAILURES)
    3. smartctl Fallback (if installed)
    4. Diagnostic logging on every tier
    """
    res = {
        "health_percent": None,
        "health_type": "UNKNOWN",
        "health_grade": "UNKNOWN",
        "health_grade_fa": "نامشخص",
        "health_source": "Unknown",
        "source": "Unknown",
        "wear_percent": None,
        "temperature_c": None,
        "power_on_hours": None,
        "power_cycles": None,
        "unsafe_shutdowns": None,
        "media_errors": None,
        "available_spare_percent": None,
        "reallocated_sectors": None,
        "pending_sectors": None,
        "uncorrectable_sectors": None,
        "smart_status": "UNKNOWN",
        "diagnostic_error": ""
    }

    path = f"\\\\.\\PhysicalDrive{device_index}"
    # Try open handle with access=0 (query device properties without requiring admin elevation)
    h = kernel32.CreateFileW(path, 0, FILE_SHARE_READ | FILE_SHARE_WRITE, None, OPEN_EXISTING, 0, None)
    if h == -1 or h == 0xFFFFFFFF:
        h = kernel32.CreateFileW(path, 0x80000000, FILE_SHARE_READ | FILE_SHARE_WRITE, None, OPEN_EXISTING, 0, None)
        if h == -1 or h == 0xFFFFFFFF:
            err = ctypes.get_last_error()
            res["diagnostic_error"] = f"CreateFileW failed with error {err}"
            logger.warning(f"[STORAGE HEALTH] Device: {path} - Failed to open handle: {err}")
            return res

    is_nvme_candidate = "nvme" in bus_type.lower() or "nvme" in media_type.lower() or "nvme" in model_hint.lower()
    is_ssd_candidate = is_nvme_candidate or "ssd" in media_type.lower() or "ssd" in model_hint.lower()

    try:
        # =====================================================================
        # METHOD 1: Native Windows NVMe SMART / Health Information Log (Page 0x02)
        # =====================================================================
        nvme_success = False
        for prop_id in [49, 48]:  # 49 = StorageAdapterProtocolSpecificProperty, 48 = StorageDeviceProtocolSpecificProperty
            query_header = struct.pack('II', prop_id, 0)
            # protocol_type=3 (NVMe), data_type=2 (LogPage), req_val=2 (HEALTH_INFO), offset=40, data_len=512
            proto_data = struct.pack('IIIIIIIIII', 3, 2, 2, 0, 40, 512, 0, 0, 0, 0)
            query_buf = query_header + proto_data

            out_buf = ctypes.create_string_buffer(1024)
            bytes_ret = wintypes.DWORD()
            success = kernel32.DeviceIoControl(
                h,
                IOCTL_STORAGE_QUERY_PROPERTY,
                query_buf,
                len(query_buf),
                out_buf,
                len(out_buf),
                ctypes.byref(bytes_ret),
                None
            )

            if success and bytes_ret.value >= 128:
                desc_offset = 40
                smart_log = out_buf.raw[desc_offset + 8: desc_offset + 8 + 512]
                crit_warn = smart_log[0]
                comp_temp_k = struct.unpack_from('<H', smart_log, 1)[0]
                temp_c = comp_temp_k - 273 if comp_temp_k > 273 else comp_temp_k
                avail_spare = smart_log[3]
                percent_used = smart_log[5]  # Wear

                power_cycles = int.from_bytes(smart_log[112:128], 'little')
                power_on_hours = int.from_bytes(smart_log[128:144], 'little')
                unsafe_shutdowns = int.from_bytes(smart_log[144:160], 'little')
                media_errors = int.from_bytes(smart_log[160:176], 'little')

                # Calculate real health
                real_health = max(0, 100 - percent_used)

                res["health_percent"] = real_health
                res["health_type"] = "REAL"
                res["health_source"] = "NVMe SMART / Health Information Log"
                res["source"] = "NVMe SMART / Health Information Log"
                res["wear_percent"] = percent_used
                res["available_spare_percent"] = avail_spare
                if 0 < temp_c < 120:
                    res["temperature_c"] = temp_c
                res["power_cycles"] = power_cycles
                res["power_on_hours"] = power_on_hours
                res["unsafe_shutdowns"] = unsafe_shutdowns
                res["media_errors"] = media_errors
                res["smart_status"] = "PASSED" if crit_warn == 0 else "WARNING"

                if real_health >= 90:
                    res["health_grade"] = "EXCELLENT"
                    res["health_grade_fa"] = "عالی"
                elif real_health >= 75:
                    res["health_grade"] = "GOOD"
                    res["health_grade_fa"] = "سالم"
                elif real_health >= 50:
                    res["health_grade"] = "WARNING"
                    res["health_grade_fa"] = "هشدار"
                else:
                    res["health_grade"] = "CRITICAL"
                    res["health_grade_fa"] = "بحرانی"

                logger.info(f"[STORAGE HEALTH] Native NVMe Success on {path}: Health={real_health}%, Wear={percent_used}%, Temp={temp_c}C")
                nvme_success = True
                break

        # =====================================================================
        # METHOD 2: SATA SMART Predict Failures & Dynamic Attribute Parser
        # =====================================================================
        if not nvme_success:
            out_buf_sata = ctypes.create_string_buffer(516)
            bytes_sata = wintypes.DWORD()
            success_sata = kernel32.DeviceIoControl(
                h,
                IOCTL_STORAGE_PREDICT_FAILURES,
                None,
                0,
                out_buf_sata,
                len(out_buf_sata),
                ctypes.byref(bytes_sata),
                None
            )

            if success_sata and bytes_sata.value >= 516:
                predict_fail = struct.unpack_from('I', out_buf_sata.raw, 0)[0]
                vendor_data = out_buf_sata.raw[4:516]
                res["health_source"] = "SATA SMART"
                res["source"] = "SATA SMART"
                res["smart_status"] = "FAILED" if predict_fail != 0 else "PASSED"

                attrs = {}
                for attr_idx in range(30):
                    off = 2 + (attr_idx * 12)
                    attr_id = vendor_data[off]
                    if attr_id == 0:
                        continue
                    curr_val = vendor_data[off + 3]
                    worst_val = vendor_data[off + 4]
                    raw_bytes = vendor_data[off + 5: off + 11]
                    raw_val = int.from_bytes(raw_bytes, 'little')
                    attrs[attr_id] = {
                        'current': curr_val,
                        'worst': worst_val,
                        'raw': raw_val
                    }

                realloc = attrs.get(5, {}).get('raw', 0)
                pending = attrs.get(197, {}).get('raw', 0)
                uncorr = attrs.get(198, {}).get('raw', 0)
                poh = attrs.get(9, {}).get('raw', 0)
                cycles = attrs.get(12, {}).get('raw', 0)

                temp_raw = attrs.get(194, {}).get('raw') or attrs.get(190, {}).get('raw')
                if temp_raw is not None:
                    temp_val = temp_raw & 0xFF
                    if 10 < temp_val < 100:
                        res["temperature_c"] = temp_val

                res["reallocated_sectors"] = realloc
                res["pending_sectors"] = pending
                res["uncorrectable_sectors"] = uncorr
                if poh > 0:
                    res["power_on_hours"] = poh
                if cycles > 0:
                    res["power_cycles"] = cycles

                # Evaluate SSD vs HDD
                if is_ssd_candidate:
                    # Dynamic Wear / Life Indicator search across common SSD vendors:
                    # ID 177: Wear Range Delta / SSD Wear Leveling Count (Samsung EVO / PRO)
                    # ID 231: SSD Life Left / Temperature (Kingston / Intel / Micron / Sandisk)
                    # ID 233: Media Wearout Indicator
                    # ID 202: Percent Lifetime Used
                    # ID 169: Remaining Lifetime
                    # ID 232: Available Reserved Space
                    found_wear = False

                    # Check ID 177 (Samsung Wear Leveling Count: current value = percentage remaining)
                    if 177 in attrs and 0 <= attrs[177]['current'] <= 100:
                        life_left = attrs[177]['current']
                        res["health_percent"] = life_left
                        res["wear_percent"] = 100 - life_left
                        res["health_type"] = "REAL"
                        found_wear = True
                    # Check ID 231 (SSD Life Left: current value = percentage remaining)
                    elif 231 in attrs and 0 <= attrs[231]['current'] <= 100:
                        life_left = attrs[231]['current']
                        res["health_percent"] = life_left
                        res["wear_percent"] = 100 - life_left
                        res["health_type"] = "REAL"
                        found_wear = True
                    # Check ID 202 (Percent Lifetime Used)
                    elif 202 in attrs:
                        wear_val = attrs[202]['raw']
                        if 0 <= wear_val <= 100:
                            res["wear_percent"] = wear_val
                            res["health_percent"] = 100 - wear_val
                            res["health_type"] = "REAL"
                            found_wear = True
                    # Check ID 233 (Media Wearout Indicator)
                    elif 233 in attrs and 0 <= attrs[233]['current'] <= 100:
                        life_left = attrs[233]['current']
                        res["health_percent"] = life_left
                        res["wear_percent"] = 100 - life_left
                        res["health_type"] = "REAL"
                        found_wear = True

                    if found_wear and res["health_percent"] is not None:
                        hp = res["health_percent"]
                        if hp >= 90:
                            res["health_grade"] = "EXCELLENT"
                            res["health_grade_fa"] = "عالی"
                        elif hp >= 75:
                            res["health_grade"] = "GOOD"
                            res["health_grade_fa"] = "سالم"
                        elif hp >= 50:
                            res["health_grade"] = "WARNING"
                            res["health_grade_fa"] = "هشدار"
                        else:
                            res["health_grade"] = "CRITICAL"
                            res["health_grade_fa"] = "بحرانی"
                    else:
                        res["health_percent"] = None
                        res["health_type"] = "UNKNOWN"
                        if predict_fail != 0:
                            res["health_grade"] = "CRITICAL"
                            res["health_grade_fa"] = "بحرانی"
                        elif realloc > 0 or pending > 0:
                            res["health_grade"] = "WARNING"
                            res["health_grade_fa"] = "هشدار"
                        else:
                            res["health_grade"] = "Healthy"
                            res["health_grade_fa"] = "سالم"

                else:
                    # Mechanical HDD:
                    # Never generate a fake percentage!
                    res["health_percent"] = None
                    res["health_type"] = "UNKNOWN"
                    res["wear_percent"] = None

                    if predict_fail != 0:
                        res["health_grade"] = "CRITICAL"
                        res["health_grade_fa"] = "بحرانی (پیش‌بینی خرابی)"
                    elif realloc > 10 or pending > 5 or uncorr > 0:
                        res["health_grade"] = "WARNING"
                        res["health_grade_fa"] = "هشدار (وجود سکتور خراب)"
                    elif realloc > 0 or pending > 0:
                        res["health_grade"] = "Good"
                        res["health_grade_fa"] = "خوب (سکتور مشکوک)"
                    else:
                        res["health_grade"] = "Healthy"
                        res["health_grade_fa"] = "سالم"

        # =====================================================================
        # METHOD 3: smartctl Fallback (if IOCTL had missing health percent)
        # =====================================================================
        if res["health_percent"] is None and is_ssd_candidate:
            smartctl_data = _query_smartctl(device_index)
            if smartctl_data:
                nvme_log = smartctl_data.get("nvme_smart_health_information_log", {})
                if "percentage_used" in nvme_log:
                    pu = nvme_log["percentage_used"]
                    res["wear_percent"] = pu
                    res["health_percent"] = max(0, 100 - pu)
                    res["health_type"] = "REAL"
                    res["health_source"] = "smartctl NVMe Log"
                    res["source"] = "smartctl NVMe Log"
                    res["health_grade"] = "EXCELLENT" if res["health_percent"] >= 90 else "GOOD"
                    res["health_grade_fa"] = "عالی" if res["health_percent"] >= 90 else "سالم"

    except Exception as e:
        logger.error(f"[STORAGE HEALTH] IOCTL Error on PhysicalDrive{device_index}: {e}")
        res["diagnostic_error"] = str(e)
    finally:
        kernel32.CloseHandle(h)

    return res
