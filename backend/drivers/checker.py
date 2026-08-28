# backend/drivers/checker.py
"""
Comprehensive Windows Hardware Driver Status Checker
Accurately inspects ALL hardware device drivers on the system:
- Detects all missing / uninstalled drivers (Code 28, Code 10, Code 43, etc.)
- Detects all installed & healthy hardware across all major categories:
  * Graphics / Display Adapters (Intel, AMD, NVIDIA)
  * Audio & Sound Controllers (Realtek, Intel Smart Sound, AMD Audio, Cirrus, Conexant, etc.)
  * Wi-Fi / Wireless Network (Intel, Realtek, MediaTek, Qualcomm, Broadcom, Killer, etc.)
  * Ethernet / Wired LAN (Realtek, Intel, Killer, Broadcom, ASIX, etc.)
  * Bluetooth Controllers & Radios (gracefully identifies absence without false error)
  * Chipset & Core System Devices (Intel MEI/CSME, Serial IO, I2C, SPI, AMD PSP, SMBus, PCIe, Thunderbolt)
  * Webcams & Imaging Devices (Integrated laptop cameras, IR cameras)
  * Touchpads, Trackpads, Input & Biometrics (Synaptics, ELAN, I2C HID, Fingerprint sensors)
  * Storage & NVMe/SATA Controllers
Does NOT modify system state or install drivers.
"""

import logging
from typing import Dict, Any, List
from utils.powershell import run_powershell_json

logger = logging.getLogger(__name__)

# Complete Windows PnP Problem Code Descriptions (Persian & English)
PROBLEM_DESCRIPTIONS_FA = {
    0: "دستگاه به درستی کار می‌کند (سالم)",
    1: "دستگاه به درستی پیکربندی نشده است (Code 1)",
    3: "درایور این دستگاه ممکن است آسیب دیده باشد (Code 3)",
    10: "این دستگاه قادر به شروع به کار نیست (Code 10)",
    14: "دستگاه پس از راه‌اندازی مجدد سیستم فعال خواهد شد (Code 14)",
    18: "درایورهای این دستگاه باید مجدداً نصب شوند (Code 18)",
    22: "این دستگاه توسط کاربر یا سیستم غیرفعال شده است (Code 22)",
    24: "دستگاه شناسایی نشده یا با مشکل سخت‌افزاری مواجه است (Code 24)",
    28: "درایور این سخت‌افزار نصب نشده است (Code 28 - نیاز به نصب درایور)",
    31: "ویندوز قادر به بارگذاری درایور این دستگاه نیست (Code 31)",
    32: "سرویس مربوط به درایور این دستگاه غیرفعال است (Code 32)",
    37: "ویندوز نمی‌تواند درایور این سخت‌افزار را مقداردهی اولیه کند (Code 37)",
    39: "ویندوز نمی‌تواند درایور را بارگذاری کند؛ فایل درایور آسیب دیده است (Code 39)",
    43: "ویندوز به دلیل گزارش خطا این دستگاه را متوقف کرده است (Code 43)",
    48: "اجرای نرم‌افزار/درایور این دستگاه مسدود شده است (Code 48)",
    52: "ویندوز نمی‌تواند امضای دیجیتال درایور را تأیید کند (Code 52)",
}

PROBLEM_DESCRIPTIONS_EN = {
    0: "Device is operating normally",
    1: "Device is not configured correctly (Code 1)",
    3: "The driver for this device might be corrupted (Code 3)",
    10: "This device cannot start (Code 10)",
    14: "This device cannot work properly until you restart your computer (Code 14)",
    18: "Reinstall the drivers for this device (Code 18)",
    22: "This device is disabled (Code 22)",
    24: "Device is not present, not working properly, or does not have all drivers installed (Code 24)",
    28: "The drivers for this device are not installed (Code 28 - Driver Required)",
    31: "This device is not working properly because Windows cannot load the drivers (Code 31)",
    32: "A driver service for this device has been disabled (Code 32)",
    37: "Windows cannot initialize the device driver for this hardware (Code 37)",
    39: "Windows cannot load the device driver for this hardware (Code 39)",
    43: "Windows has stopped this device because it has reported problems (Code 43)",
    48: "The software for this device has been blocked from starting (Code 48)",
    52: "Windows cannot verify the digital signature for the drivers required (Code 52)",
}


def _get_problem_desc_fa(code: int, status_str: str) -> str:
    if code in PROBLEM_DESCRIPTIONS_FA:
        return PROBLEM_DESCRIPTIONS_FA[code]
    if code == 0:
        return "دستگاه به درستی کار می‌کند (سالم)"
    return f"خطای درایور شناسایی شد (کد {code})"


def _get_problem_desc_en(code: int, status_str: str) -> str:
    if code in PROBLEM_DESCRIPTIONS_EN:
        return PROBLEM_DESCRIPTIONS_EN[code]
    if code == 0:
        return "Device is operating normally"
    return f"Driver issue detected (Code {code})"


def check_important_drivers() -> Dict[str, Any]:
    """
    Scans all Windows PnP hardware devices using Win32_PnPEntity.
    Inspects and classifies all hardware into comprehensive driver categories,
    accurately detecting all installed working drivers and all missing/problematic drivers.
    """
    ps_cmd = (
        "$pnp = Get-CimInstance Win32_PnPEntity | Where-Object { $_.Present -eq $true } | "
        "  Select-Object Name, Description, Caption, DeviceID, PNPClass, ConfigManagerErrorCode, Status, Manufacturer, Service; "
        "$pnp | ConvertTo-Json -Depth 2 -Compress"
    )

    raw = run_powershell_json(ps_cmd, timeout=12)
    devices_raw: List[Dict[str, Any]] = []

    if isinstance(raw, list):
        devices_raw = raw
    elif isinstance(raw, dict):
        devices_raw = [raw]

    driver_items: List[Dict[str, Any]] = []
    missing_drivers: List[Dict[str, Any]] = []

    # Filter virtual software adapters that should not falsely alert technicians
    virtual_sw_patterns = [
        "virtual", "tap-", "wintun", "loopback", "wan miniport", "camo",
        "droidcam", "hyper-v", "packet scheduler", "ndis", "teredo", "isatap", "ras async"
    ]

    for d in devices_raw:
        name = (d.get("Name") or d.get("Caption") or d.get("Description") or "Unknown Hardware Device").strip()
        pnp_class = (d.get("PNPClass") or "").strip()
        prob = int(d.get("ConfigManagerErrorCode") or 0)
        status_str = (d.get("Status") or "OK").strip()
        device_id = (d.get("DeviceID") or "Unknown").strip()
        manufacturer = (d.get("Manufacturer") or "Unknown").strip()
        name_lower = name.lower()

        is_disabled = (prob == 22)
        is_virtual = any(v in name_lower for v in virtual_sw_patterns)

        # ---------------------------------------------------------------------
        # 1. MISSING / UNKNOWN / PROBLEM DEVICES (e.g. Code 28, Code 10, Code 43)
        # ---------------------------------------------------------------------
        if prob != 0 and not is_disabled and not is_virtual:
            desc_fa = _get_problem_desc_fa(prob, status_str)
            desc_en = _get_problem_desc_en(prob, status_str)
            status_title = "Driver Missing" if prob == 28 else "Driver Problem"

            missing_item = {
                "id": f"missing_{len(missing_drivers)}_{device_id[:16]}",
                "name": name,
                "display_name": name,
                "device_name": name,
                "category": "Unknown / Missing",
                "category_fa": "درایورهای ناشناخته و ناقص",
                "status": status_title,
                "is_healthy": False,
                "is_present": True,
                "problem_code": prob,
                "status_description": desc_fa,
                "status_description_en": desc_en,
                "instance_id": device_id,
                "manufacturer": manufacturer,
                "pnp_class": pnp_class or "Unknown",
            }
            missing_drivers.append(missing_item)
            driver_items.append(missing_item)
            continue

        # ---------------------------------------------------------------------
        # 2. HARDWARE CATEGORY CLASSIFICATION
        # ---------------------------------------------------------------------
        category = None
        category_fa = None

        if pnp_class == "Display":
            category = "Display"
            category_fa = "کارت گرافیک و تصویر"
        elif pnp_class in ["MEDIA", "AudioEndpoint"] and not is_virtual:
            category = "Audio"
            category_fa = "کارت صدا و مالتی‌مدیا"
        elif pnp_class == "Net":
            if any(w in name_lower for w in ["wi-fi", "wifi", "wireless", "802.11", "wlan", "aironet", "centrino"]):
                category = "Wi-Fi"
                category_fa = "کارت شبکه وای‌فای (Wi-Fi)"
            elif any(e in name_lower for e in ["ethernet", "gbe", "gigabit", "pcie fe", "lan", "i219", "i225", "killer e", "realtek pcie", "fast ethernet"]) and not is_virtual:
                category = "Ethernet"
                category_fa = "کارت شبکه کابلی (LAN / Ethernet)"
        elif pnp_class == "Bluetooth":
            category = "Bluetooth"
            category_fa = "بلوتوث (Bluetooth)"
        elif pnp_class in ["Camera", "Image"] and not is_virtual:
            category = "Camera"
            category_fa = "دوربین و وب‌کم"
        elif pnp_class in ["HDC", "SCSIAdapter", "DiskDrive"] and not is_virtual:
            if any(s in name_lower for s in ["nvme", "nvm express", "sata ahci", "raid", "rapid storage", "rst", "chipset sata"]):
                category = "Storage Controller"
                category_fa = "کنترلر حافظه و ذخیره‌سازی"
        elif pnp_class in ["Mouse", "Keyboard", "HIDClass", "Biometric"]:
            if any(t in name_lower for t in ["touchpad", "trackpad", "touch pad", "i2c hid", "precision", "elan", "synaptics", "fingerprint", "sensor", "touch screen"]):
                category = "Input & Touchpad"
                category_fa = "تاچ‌پد، ورودی و حسگرها"
        elif pnp_class == "System":
            if any(c in name_lower for c in ["management engine", "serial io", "spi", "i2c", "lpss", "chipset", "smbus", "psp", "dynamic tuning", "gaussian", "thermal", "pcie root", "thunderbolt"]):
                category = "Chipset & System"
                category_fa = "چیپست و دستگاه‌های سیستم"

        if category:
            is_healthy = (prob == 0 and status_str == "OK")
            driver_items.append({
                "id": f"drv_{len(driver_items)}_{category.lower()}",
                "name": name,
                "display_name": name,
                "device_name": name,
                "category": category,
                "category_fa": category_fa,
                "status": "OK" if is_healthy else "Driver Problem",
                "is_healthy": is_healthy,
                "is_present": True,
                "problem_code": prob,
                "status_description": "دستگاه به درستی کار می‌کند (سالم)" if is_healthy else _get_problem_desc_fa(prob, status_str),
                "status_description_en": "Device is operating normally" if is_healthy else _get_problem_desc_en(prob, status_str),
                "instance_id": device_id,
                "manufacturer": manufacturer,
                "pnp_class": pnp_class,
            })

    # Summary
    present_items = [d for d in driver_items if d.get("is_present", True)]
    healthy_items = [d for d in present_items if d["is_healthy"]]
    problem_items = [d for d in present_items if not d["is_healthy"]]

    total_present = len(present_items)
    healthy_count = len(healthy_items)
    problem_count = len(problem_items)
    missing_count = len(missing_drivers)
    all_healthy = (problem_count == 0)

    summary = {
        "total_scanned_count": len(driver_items),
        "total_present_count": total_present,
        "healthy_count": healthy_count,
        "problem_count": problem_count,
        "missing_count": missing_count,
        "all_healthy": all_healthy,
        "has_missing_drivers": missing_count > 0,
        "has_problem": problem_count > 0,
        "status_text": "Ready" if all_healthy else "Needs Attention",
        "missing_devices": missing_drivers,
    }

    return {
        "drivers": driver_items,
        "driver_summary": summary,
        "missing_drivers": missing_drivers,
    }
