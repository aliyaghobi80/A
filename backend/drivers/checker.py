# backend/drivers/checker.py
"""
Important Hardware Driver Status Checker
Inspects critical device drivers (Graphics, Audio, Ethernet, Wi-Fi, Bluetooth, Chipset)
using Windows PnP / WMI without modifying system state or installing drivers.
"""

import logging
from typing import Dict, Any, List
from utils.powershell import run_powershell_json

logger = logging.getLogger(__name__)

# Common Windows PnP problem code descriptions
PROBLEM_DESCRIPTIONS = {
    0: "Device is working properly",
    1: "Device is not configured correctly",
    10: "This device cannot start",
    14: "This device cannot work properly until you restart your computer",
    18: "Reinstall the drivers for this device",
    22: "This device is disabled",
    28: "The drivers for this device are not installed",
    31: "This device is not working properly because Windows cannot load the drivers",
    43: "Windows has stopped this device because it has reported problems",
}


def _get_problem_description(code: int, default_status: str) -> str:
    if code in PROBLEM_DESCRIPTIONS:
        return PROBLEM_DESCRIPTIONS[code]
    if code == 0:
        return "Device is operating normally"
    return f"Driver issue detected (Code {code})"


def check_important_drivers() -> Dict[str, Any]:
    """
    Scans Windows PnP devices for important categories:
    - Graphics / GPU
    - Audio
    - Ethernet
    - Wi-Fi
    - Bluetooth (gracefully handles absence without error)
    - Chipset / System
    """
    ps_cmd = (
        "$devs = Get-PnpDevice -ErrorAction SilentlyContinue | "
        "  Where-Object { $_.Present -eq $true } | "
        "  Select-Object FriendlyName, Class, Status, Problem, Present, InstanceId; "
        "$devs | ConvertTo-Json -Depth 2"
    )

    raw = run_powershell_json(ps_cmd, timeout=10)
    devices_raw: List[Dict[str, Any]] = []

    if isinstance(raw, list):
        devices_raw = raw
    elif isinstance(raw, dict):
        devices_raw = [raw]

    # Categorize devices
    driver_items: List[Dict[str, Any]] = []

    # 1. Graphics / Display
    display_devs = [
        d for d in devices_raw
        if d.get("Class") == "Display" and d.get("Present", True)
    ]
    if display_devs:
        d = display_devs[0]
        prob = int(d.get("Problem", 0) or 0)
        status_str = "OK" if prob == 0 and d.get("Status") == "OK" else "Driver Problem"
        driver_items.append({
            "id": "graphics",
            "name": "Graphics / GPU",
            "display_name": "Graphics / GPU",
            "device_name": d.get("FriendlyName") or "Graphics Adapter",
            "category": "Display",
            "status": status_str,
            "is_healthy": status_str == "OK",
            "is_present": True,
            "problem_code": prob,
            "status_description": _get_problem_description(prob, d.get("Status", "OK")),
            "instance_id": d.get("InstanceId") or "Not available",
        })
    else:
        driver_items.append({
            "id": "graphics",
            "name": "Graphics / GPU",
            "display_name": "Graphics / GPU",
            "device_name": "Not detected",
            "category": "Display",
            "status": "Unknown",
            "is_healthy": False,
            "is_present": True,
            "problem_code": 0,
            "status_description": "No display device found in PnP query",
            "instance_id": "Not available",
        })

    # 2. Audio
    audio_devs = [
        d for d in devices_raw
        if d.get("Class") == "MEDIA" and d.get("Present", True) and
        any(k in str(d.get("FriendlyName", "")).lower() for k in ["audio", "sound", "realtek", "high definition", "speakers"]) and
        not any(v in str(d.get("FriendlyName", "")).lower() for v in ["virtual", "droidcam"])
    ]
    if not audio_devs:
        audio_devs = [d for d in devices_raw if d.get("Class") == "MEDIA" and d.get("Present", True)]

    if audio_devs:
        d = audio_devs[0]
        prob = int(d.get("Problem", 0) or 0)
        status_str = "OK" if prob == 0 and d.get("Status") == "OK" else "Driver Problem"
        driver_items.append({
            "id": "audio",
            "name": "Audio Controller",
            "display_name": "Audio Controller",
            "device_name": d.get("FriendlyName") or "High Definition Audio",
            "category": "Audio",
            "status": status_str,
            "is_healthy": status_str == "OK",
            "is_present": True,
            "problem_code": prob,
            "status_description": _get_problem_description(prob, d.get("Status", "OK")),
            "instance_id": d.get("InstanceId") or "Not available",
        })
    else:
        driver_items.append({
            "id": "audio",
            "name": "Audio Controller",
            "display_name": "Audio Controller",
            "device_name": "Not detected",
            "category": "Audio",
            "status": "Not Present",
            "is_healthy": True,
            "is_present": False,
            "problem_code": 0,
            "status_description": "No physical audio controller detected",
            "instance_id": "Not available",
        })

    # 3. Ethernet
    ethernet_devs = [
        d for d in devices_raw
        if d.get("Class") == "Net" and d.get("Present", True) and
        any(k in str(d.get("FriendlyName", "")).lower() for k in ["ethernet", "gbe", "pcie", "gigabit", "realtek pcie", "intel(r) ethernet"]) and
        not any(v in str(d.get("FriendlyName", "")).lower() for v in ["virtual", "hyper-v", "tap", "vpn", "tunnel", "loopback", "wintun"])
    ]
    if ethernet_devs:
        d = ethernet_devs[0]
        prob = int(d.get("Problem", 0) or 0)
        status_str = "OK" if prob == 0 and d.get("Status") == "OK" else "Driver Problem"
        driver_items.append({
            "id": "ethernet",
            "name": "Ethernet Controller",
            "display_name": "Ethernet Controller",
            "device_name": d.get("FriendlyName") or "Ethernet Adapter",
            "category": "Network",
            "status": status_str,
            "is_healthy": status_str == "OK",
            "is_present": True,
            "problem_code": prob,
            "status_description": _get_problem_description(prob, d.get("Status", "OK")),
            "instance_id": d.get("InstanceId") or "Not available",
        })
    else:
        driver_items.append({
            "id": "ethernet",
            "name": "Ethernet Controller",
            "display_name": "Ethernet Controller",
            "device_name": "Not detected",
            "category": "Network",
            "status": "Not Present",
            "is_healthy": True,
            "is_present": False,
            "problem_code": 0,
            "status_description": "No physical Ethernet adapter present",
            "instance_id": "Not available",
        })

    # 4. Wi-Fi
    wifi_devs = [
        d for d in devices_raw
        if d.get("Class") == "Net" and d.get("Present", True) and
        any(k in str(d.get("FriendlyName", "")).lower() for k in ["wi-fi", "wireless", "802.11", "wlan"])
    ]
    if wifi_devs:
        d = wifi_devs[0]
        prob = int(d.get("Problem", 0) or 0)
        status_str = "OK" if prob == 0 and d.get("Status") == "OK" else "Driver Problem"
        driver_items.append({
            "id": "wifi",
            "name": "Wi-Fi Adapter",
            "display_name": "Wi-Fi Adapter",
            "device_name": d.get("FriendlyName") or "Wireless Adapter",
            "category": "Network",
            "status": status_str,
            "is_healthy": status_str == "OK",
            "is_present": True,
            "problem_code": prob,
            "status_description": _get_problem_description(prob, d.get("Status", "OK")),
            "instance_id": d.get("InstanceId") or "Not available",
        })
    else:
        driver_items.append({
            "id": "wifi",
            "name": "Wi-Fi Adapter",
            "display_name": "Wi-Fi Adapter",
            "device_name": "Not present",
            "category": "Network",
            "status": "Not Present",
            "is_healthy": True,
            "is_present": False,
            "problem_code": 0,
            "status_description": "Wireless network hardware is not present",
            "instance_id": "Not available",
        })

    # 5. Bluetooth
    bt_devs = [
        d for d in devices_raw
        if d.get("Class") == "Bluetooth" and d.get("Present", True)
    ]
    if bt_devs:
        d = bt_devs[0]
        prob = int(d.get("Problem", 0) or 0)
        status_str = "OK" if prob == 0 and d.get("Status") == "OK" else "Driver Problem"
        driver_items.append({
            "id": "bluetooth",
            "name": "Bluetooth Adapter",
            "display_name": "Bluetooth Adapter",
            "device_name": d.get("FriendlyName") or "Bluetooth Device",
            "category": "Bluetooth",
            "status": status_str,
            "is_healthy": status_str == "OK",
            "is_present": True,
            "problem_code": prob,
            "status_description": _get_problem_description(prob, d.get("Status", "OK")),
            "instance_id": d.get("InstanceId") or "Not available",
        })
    else:
        driver_items.append({
            "id": "bluetooth",
            "name": "Bluetooth Adapter",
            "display_name": "Bluetooth Adapter",
            "device_name": "Not present",
            "category": "Bluetooth",
            "status": "Not Present",
            "is_healthy": True,
            "is_present": False,
            "problem_code": 0,
            "status_description": "Bluetooth hardware is not present on this motherboard",
            "instance_id": "Not available",
        })

    # 6. Chipset & System Devices (Detect physical missing drivers like Code 28, Code 10, Code 43)
    pnp_issues = [
        d for d in devices_raw
        if d.get("Present", True) and
        int(d.get("Problem", 0) or 0) not in [0, 22] and
        not any(sw in str(d.get("FriendlyName", "")).lower() for sw in ["camo", "virtual", "tap-", "wintun", "droidcam"])
    ]

    if pnp_issues:
        d = pnp_issues[0]
        prob = int(d.get("Problem", 0) or 0)
        driver_items.append({
            "id": "chipset",
            "name": "Chipset & System Devices",
            "display_name": "Chipset & System Devices",
            "device_name": f"{d.get('FriendlyName') or 'PCI/System Device'}",
            "category": "System",
            "status": "Driver Problem",
            "is_healthy": False,
            "is_present": True,
            "problem_code": prob,
            "status_description": _get_problem_description(prob, d.get("Status", "Error")),
            "instance_id": d.get("InstanceId") or "Not available",
        })
    else:
        driver_items.append({
            "id": "chipset",
            "name": "Chipset & System Devices",
            "display_name": "Chipset & System Devices",
            "device_name": "Intel/AMD Motherboard Chipset",
            "category": "System",
            "status": "OK",
            "is_healthy": True,
            "is_present": True,
            "problem_code": 0,
            "status_description": "All system and chipset devices are operating normally",
            "instance_id": "Not available",
        })

    # Summary
    present_items = [d for d in driver_items if d["is_present"]]
    healthy_present_items = [d for d in present_items if d["is_healthy"]]
    has_problem = any(d["status"] == "Driver Problem" for d in driver_items)

    total_present = len(present_items)
    healthy_count = len(healthy_present_items)
    all_healthy = (healthy_count == total_present) and not has_problem

    summary = {
        "healthy_count": healthy_count,
        "total_present_count": total_present,
        "all_healthy": all_healthy,
        "has_problem": has_problem,
        "status_text": "Ready" if all_healthy else "Needs Attention",
    }

    return {
        "drivers": driver_items,
        "driver_summary": summary,
    }
