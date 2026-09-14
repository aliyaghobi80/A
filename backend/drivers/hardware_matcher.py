# backend/drivers/hardware_matcher.py
"""
Intelligent Hardware Matcher & Relevance Engine.
Compares candidate driver packages against actual hardware present in the current machine:
- Enumerates PnP devices (Hardware IDs, Compatible IDs, Problem Codes, Device Classes)
- Queries installed driver versions (Win32_PnPSignedDriver)
- Evaluates Hardware ID matches, problem states (Code 28, 10, 43), and version comparisons
- Assigns match confidence: HIGH, MEDIUM, LOW, NOT_APPLICABLE
- Determines match status:
  * 'needs_install': Device is missing driver (Code 28) or has a driver problem
  * 'update_available': Machine has an older driver, package is newer
  * 'up_to_date': Machine already has this driver (same or newer version)
  * 'not_applicable': Hardware not present in current machine (e.g. NVIDIA on AMD-only)
"""

import logging
import platform
import re
from typing import Dict, Any, List, Optional, Tuple
from utils.powershell import run_powershell_json

logger = logging.getLogger(__name__)


def _parse_version_tuple(v_str: str) -> Tuple[int, ...]:
    """Extracts integer components from a version string (e.g. '10.0.19041.1' -> (10, 0, 19041, 1))."""
    if not v_str:
        return ()
    nums = re.findall(r"\d+", v_str)
    try:
        return tuple(int(n) for n in nums[:6])
    except Exception:
        return ()


def _compare_driver_versions(v1: str, v2: str) -> int:
    """
    Compares two version strings:
    Returns 1 if v1 > v2, -1 if v1 < v2, 0 if equal.
    """
    t1 = _parse_version_tuple(v1)
    t2 = _parse_version_tuple(v2)
    if not t1 or not t2:
        return 0
    if t1 > t2:
        return 1
    elif t1 < t2:
        return -1
    return 0


def get_current_system_hardware() -> List[Dict[str, Any]]:
    """
    Queries all active PnP devices on the system along with their Hardware IDs,
    driver versions, and problem codes using PowerShell.
    """
    ps_cmd = (
        "$devices = Get-CimInstance Win32_PnPEntity | Where-Object { $_.Present -eq $true } | "
        "Select-Object Name, Caption, Description, DeviceID, HardwareID, CompatibleID, "
        "PNPClass, ConfigManagerErrorCode, Status, Manufacturer; "
        "$drivers = Get-CimInstance Win32_PnPSignedDriver | "
        "Select-Object DeviceID, DeviceName, DriverVersion, DriverDate, DriverProviderName; "
        "$drvMap = @{}; "
        "foreach ($drv in $drivers) { if ($drv.DeviceID) { $drvMap[$drv.DeviceID] = $drv } } "
        "$out = foreach ($d in $devices) { "
        "  $drv = $drvMap[$d.DeviceID]; "
        "  [PSCustomObject]@{ "
        "    DeviceID = $d.DeviceID; "
        "    Name = if ($d.Name) { $d.Name } else { $d.Description }; "
        "    HardwareIDs = $d.HardwareID; "
        "    CompatibleIDs = $d.CompatibleID; "
        "    PNPClass = $d.PNPClass; "
        "    ProblemCode = [int]$d.ConfigManagerErrorCode; "
        "    Status = $d.Status; "
        "    Manufacturer = $d.Manufacturer; "
        "    DriverVersion = if ($drv) { $drv.DriverVersion } else { '' }; "
        "    DriverDate = if ($drv) { $drv.DriverDate } else { '' }; "
        "    DriverProvider = if ($drv) { $drv.DriverProviderName } else { '' }; "
        "  } "
        "}; "
        "$out | ConvertTo-Json -Depth 2 -Compress"
    )

    try:
        raw = run_powershell_json(ps_cmd, timeout=14)
        if isinstance(raw, list):
            return raw
        elif isinstance(raw, dict):
            return [raw]
    except Exception as e:
        logger.error(f"Error querying system hardware for driver matching: {e}")

    return []


def _normalize_hw_id(hw_id: str) -> str:
    """Normalizes Hardware ID string for reliable substring/prefix comparison."""
    if not hw_id:
        return ""
    # Strip revision / subsystem specifics for broader compatibility matching if needed
    cleaned = hw_id.strip().upper()
    return cleaned


def match_package_to_hardware(
    package_dict: Dict[str, Any],
    hardware_list: List[Dict[str, Any]],
) -> Dict[str, Any]:
    """
    Evaluates a driver package against the system's hardware list.
    Returns matching details:
    {
      "is_matched": bool,
      "confidence": "HIGH" | "MEDIUM" | "LOW" | "NOT_APPLICABLE",
      "status": "needs_install" | "update_available" | "up_to_date" | "driver_problem" | "not_applicable",
      "status_fa": str,
      "status_en": str,
      "matched_device_name": str,
      "matched_device_id": str,
      "installed_version": str,
      "package_version": str,
      "recommendation": "recommended" | "optional" | "skip",
      "reasons": List[str]
    }
    """
    pkg_hw_ids = set(h.upper() for h in package_dict.get("hardware_ids", []))
    pkg_category = package_dict.get("category", "other")
    pkg_version = package_dict.get("driver_version", "")
    pkg_name = package_dict.get("display_name", "").lower()
    pkg_provider = package_dict.get("provider", "").lower()
    supported_windows = package_dict.get("supported_windows") or []
    current_windows = platform.release()
    if supported_windows and current_windows not in supported_windows:
        return {
            "is_matched": False,
            "confidence": "NOT_APPLICABLE",
            "status": "not_applicable",
            "status_fa": f"این بسته مخصوص ویندوز {'/'.join(supported_windows)} است؛ سیستم فعلی ویندوز {current_windows} است.",
            "status_en": f"Package targets Windows {'/'.join(supported_windows)}; current Windows is {current_windows}.",
            "matched_device_name": "",
            "matched_device_id": "",
            "installed_version": "",
            "package_version": pkg_version,
            "recommendation": "skip",
            "reasons": ["نسخه ویندوز با بسته درایور سازگار نیست."],
        }

    best_match_device = None
    best_match_score = 0  # 0: none, 1: category hint, 2: name/vendor hint, 3: compatible ID, 4: exact hardware ID
    matched_hw_id = ""

    for dev in hardware_list:
        dev_id = str(dev.get("DeviceID") or "")
        dev_name = str(dev.get("Name") or "").strip()
        dev_class = str(dev.get("PNPClass") or "").strip().lower()
        dev_mfg = str(dev.get("Manufacturer") or "").strip().lower()
        dev_prob = int(dev.get("ProblemCode") or 0)
        dev_hw_ids_raw = dev.get("HardwareIDs") or []
        if isinstance(dev_hw_ids_raw, str):
            dev_hw_ids_raw = [dev_hw_ids_raw]
        dev_hw_ids = set(h.upper() for h in dev_hw_ids_raw)

        # 1. Exact or Substring Hardware ID match
        common_hw = pkg_hw_ids.intersection(dev_hw_ids)
        if common_hw:
            score = 4
            best_match_score = score
            best_match_device = dev
            matched_hw_id = list(common_hw)[0]
            break

        # Check prefix match (e.g. PCI\VEN_10EC&DEV_8168 matches PCI\VEN_10EC&DEV_8168&SUBSYS...)
        prefix_matched = False
        for pkg_h in pkg_hw_ids:
            for dev_h in dev_hw_ids:
                if pkg_h in dev_h or dev_h in pkg_h:
                    if len(pkg_h) > 15 and len(dev_h) > 15:
                        score = 4
                        best_match_score = score
                        best_match_device = dev
                        matched_hw_id = pkg_h
                        prefix_matched = True
                        break
            if prefix_matched:
                break
        if prefix_matched:
            break

        # 2. Category & Class Matching. If the package declares hardware IDs,
        # require an ID match; a generic class must not recommend a driver for
        # a different device in the same class.
        score = 0
        name_lower = dev_name.lower()

        if pkg_hw_ids:
            continue
        if pkg_category == "gpu" and dev_class == "display":
            if any(v in pkg_name for v in ("nvidia", "geforce")) and any(v in name_lower for v in ("nvidia", "geforce")):
                score = 2
            elif any(v in pkg_name for v in ("amd", "radeon")) and any(v in name_lower for v in ("amd", "radeon")):
                score = 2
            elif "intel" in pkg_name and "intel" in name_lower:
                score = 2
            elif any(w in name_lower for w in ("basic display", "vga", "video controller", "display")):
                score = 2
        elif pkg_category == "audio" and dev_class in ("media", "audioendpoint"):
            if "realtek" in pkg_name and "realtek" in name_lower:
                score = 2
            elif "smart sound" in pkg_name and "smart sound" in name_lower:
                score = 2
            elif any(w in name_lower for w in ("high definition audio", "audio controller", "multimedia")):
                score = 2
        elif pkg_category == "lan" and dev_class == "net":
            if any(w in name_lower for w in ("ethernet", "gbe", "gigabit", "lan", "network controller")):
                score = 2
        elif pkg_category == "wifi" and dev_class == "net":
            if any(w in name_lower for w in ("wi-fi", "wifi", "wireless", "802.11", "network controller")):
                score = 2
        elif pkg_category == "bluetooth" and dev_class == "bluetooth":
            score = 2
        elif pkg_category == "chipset" and dev_class == "system":
            if any(w in name_lower for w in ("chipset", "smbus", "lpss", "serial io", "spi", "i2c", "pci", "unknown device")):
                score = 2
        elif pkg_category == "system_mei" and dev_class == "system":
            if any(w in name_lower for w in ("management engine", "mei", "heci", "pci simple communications controller")):
                score = 2

        # Prioritize problem devices (Code 28 missing driver, Code 10, Code 43)
        if score > 0 and dev_prob in (28, 10, 43):
            score += 2

        if score > best_match_score:
            best_match_score = score
            best_match_device = dev

    # Evaluate Result
    if best_match_score >= 4:
        confidence = "HIGH"
        is_matched = True
    elif best_match_score >= 2:
        confidence = "MEDIUM"
        is_matched = True
    elif best_match_score == 1:
        confidence = "LOW"
        is_matched = False
    else:
        confidence = "NOT_APPLICABLE"
        is_matched = False

    if not is_matched or not best_match_device:
        if not pkg_hw_ids and package_dict.get("install_method") in ("setup_exe", "msiexec", "asus_setup"):
            return {
                "is_matched": False, "confidence": "UNKNOWN",
                "status": "needs_install",
                "status_fa": "آماده اجرا؛ سازگاری توسط نصاب سازنده بررسی می‌شود",
                "status_en": "Ready; vendor installer checks compatibility",
                "matched_device_name": "", "matched_device_id": "",
                "installed_version": "", "package_version": pkg_version,
                "recommendation": "optional",
                "reasons": ["بسته شناسه سخت‌افزاری قابل استخراج ندارد؛ نام فایل دلیل رد آن نیست."],
            }
        return {
            "is_matched": False,
            "confidence": "NOT_APPLICABLE",
            "status": "not_applicable",
            "status_fa": "سخت‌افزار مرتبط در سیستم یافت نشد (نامربوط)",
            "status_en": "Not Applicable for this PC",
            "matched_device_name": "",
            "matched_device_id": "",
            "installed_version": "",
            "package_version": pkg_version,
            "recommendation": "skip",
            "reasons": ["دستگاه سخت‌افزاری متناظری برای این بسته در سیستم شناسایی نشد."],
        }

    dev_name = str(best_match_device.get("Name") or "دستگاه سخت‌افزاری")
    dev_id = str(best_match_device.get("DeviceID") or "")
    dev_prob = int(best_match_device.get("ProblemCode") or 0)
    installed_ver = str(best_match_device.get("DriverVersion") or "")

    reasons = []
    if dev_prob != 0:
        status = "needs_install"
        status_fa = f"نیاز فوری به نصب درایور (خطای سخت‌افزار کد {dev_prob})"
        status_en = f"Driver Missing / Error (Code {dev_prob})"
        recommendation = "recommended"
        reasons.append(f"دستگاه دارای خطای کد {dev_prob} در ویندوز است.")
    elif installed_ver and pkg_version:
        cmp = _compare_driver_versions(pkg_version, installed_ver)
        if cmp > 0:
            status = "update_available"
            status_fa = f"نسخه جدیدتر موجود است (سیستم: {installed_ver} ← بسته: {pkg_version})"
            status_en = f"Update Available ({installed_ver} -> {pkg_version})"
            recommendation = "recommended"
            reasons.append("بسته نصبی نسخه جدیدتری نسبت به درایور فعلی است.")
        else:
            status = "up_to_date"
            status_fa = f"درایور سیستم به‌روز است ({installed_ver})"
            status_en = f"Already up to date ({installed_ver})"
            recommendation = "skip"
            reasons.append("نسخه مساوی یا جدیدتر قبلاً روی سیستم نصب شده است.")
    else:
        status = "needs_install"
        status_fa = "آماده نصب برای سخت‌افزار شناسایی‌شده"
        status_en = "Ready for Installation"
        recommendation = "recommended"
        reasons.append("سخت‌افزار متناظر روی دستگاه شناسایی شد.")

    return {
        "is_matched": True,
        "confidence": confidence,
        "status": status,
        "status_fa": status_fa,
        "status_en": status_en,
        "matched_device_name": dev_name,
        "matched_device_id": dev_id,
        "installed_version": installed_ver,
        "package_version": pkg_version,
        "recommendation": recommendation,
        "reasons": reasons,
    }
