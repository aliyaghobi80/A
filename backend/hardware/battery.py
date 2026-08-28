import logging
import ctypes
from ctypes import wintypes
import os
from typing import Dict, Any, Optional

from utils.powershell import run_powershell_json
from utils.formatters import clean_string, clean_serial_number

logger = logging.getLogger(__name__)

class SYSTEM_POWER_STATUS(ctypes.Structure):
    _fields_ = [
        ('ACLineStatus', wintypes.BYTE),
        ('BatteryFlag', wintypes.BYTE),
        ('BatteryLifePercent', wintypes.BYTE),
        ('SystemStatusFlag', wintypes.BYTE),
        ('BatteryLifeTime', wintypes.DWORD),
        ('BatteryFullLifeTime', wintypes.DWORD),
    ]

def _get_system_power_status() -> Dict[str, Any]:
    try:
        sps = SYSTEM_POWER_STATUS()
        if ctypes.windll.kernel32.GetSystemPowerStatus(ctypes.byref(sps)):
            ac_connected = sps.ACLineStatus == 1
            has_battery = sps.BatteryFlag != 128 and sps.BatteryFlag != 255
            is_charging = (sps.BatteryFlag & 8) != 0
            charge_percent = sps.BatteryLifePercent if sps.BatteryLifePercent <= 100 else None
            return {
                "has_battery": has_battery,
                "ac_connected": ac_connected,
                "is_charging": is_charging,
                "charge_percent": charge_percent,
                "battery_flag": sps.BatteryFlag,
            }
    except Exception as e:
        logger.debug(f"GetSystemPowerStatus failed: {e}")
    return {
        "has_battery": False,
        "ac_connected": True,
        "is_charging": False,
        "charge_percent": None,
        "battery_flag": 128,
    }

def _get_wmi_battery_info() -> Dict[str, Any]:
    res = {
        "has_battery": False,
        "name": "Not available",
        "manufacturer": "Not available",
        "serial": "Not available",
        "chemistry": "Li-Ion",
        "design_capacity_mwh": 0,
        "full_charge_capacity_mwh": 0,
        "cycle_count": None,
        "charge_percent": None,
        "voltage_mv": None,
    }

    try:
        ps_script = (
            "$b = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue | Select-Object -First 1 Name, DeviceID, EstimatedChargeRemaining, BatteryStatus, DesignVoltage; "
            "$s = Get-CimInstance -Namespace root/wmi -ClassName BatteryStaticData -ErrorAction SilentlyContinue | Select-Object -First 1 DesignedCapacity, DeviceName, ManufactureName, SerialNumber, Technology; "
            "$f = Get-CimInstance -Namespace root/wmi -ClassName BatteryFullChargedCapacity -ErrorAction SilentlyContinue | Select-Object -First 1 FullChargedCapacity; "
            "$c = Get-CimInstance -Namespace root/wmi -ClassName BatteryCycleCount -ErrorAction SilentlyContinue | Select-Object -First 1 CycleCount; "
            "[PSCustomObject]@{ Battery = $b; Static = $s; FullCharge = $f; Cycle = $c } | ConvertTo-Json -Depth 2"
        )
        data = run_powershell_json(ps_script)
        if isinstance(data, dict):
            b_data = data.get("Battery") or {}
            s_data = data.get("Static") or {}
            f_data = data.get("FullCharge") or {}
            c_data = data.get("Cycle") or {}

            if b_data or s_data or f_data:
                res["has_battery"] = True

                if s_data.get("DesignedCapacity"):
                    try:
                        res["design_capacity_mwh"] = int(s_data["DesignedCapacity"])
                    except (ValueError, TypeError):
                        pass

                if f_data.get("FullChargedCapacity"):
                    try:
                        res["full_charge_capacity_mwh"] = int(f_data["FullChargedCapacity"])
                    except (ValueError, TypeError):
                        pass

                if c_data.get("CycleCount"):
                    try:
                        res["cycle_count"] = int(c_data["CycleCount"])
                    except (ValueError, TypeError):
                        pass

                if s_data.get("DeviceName"):
                    res["name"] = clean_string(s_data["DeviceName"])
                elif b_data.get("Name"):
                    res["name"] = clean_string(b_data["Name"])

                if s_data.get("ManufactureName"):
                    res["manufacturer"] = clean_string(s_data["ManufactureName"])

                if s_data.get("SerialNumber"):
                    res["serial"] = clean_serial_number(s_data["SerialNumber"])

                if b_data.get("EstimatedChargeRemaining"):
                    try:
                        res["charge_percent"] = int(b_data["EstimatedChargeRemaining"])
                    except (ValueError, TypeError):
                        pass

                if b_data.get("DesignVoltage"):
                    try:
                        res["voltage_mv"] = int(b_data["DesignVoltage"])
                    except (ValueError, TypeError):
                        pass
    except Exception as e:
        logger.debug(f"WMI battery read error: {e}")

    return res

def _get_psu_hardware_info() -> Dict[str, Any]:
    """
    Checks if a real digital PSU is connected and reported via SMBIOS/WMI Win32_PowerSupply.
    Never guesses or invents wattage numbers.
    """
    try:
        ps_script = "Get-CimInstance Win32_PowerSupply -ErrorAction SilentlyContinue | Select-Object -First 1 Name, DeviceID, TotalOutputPower, Description | ConvertTo-Json"
        data = run_powershell_json(ps_script)
        if isinstance(data, dict):
            watts = data.get("TotalOutputPower")
            if watts and int(watts) > 0:
                return {
                    "psu_wattage": int(watts),
                    "psu_display": f"PSU: {int(watts)} W",
                    "psu_detected": True
                }
    except Exception:
        pass

    return {
        "psu_wattage": None,
        "psu_display": "PSU: Not Detected",
        "psu_detected": False
    }

def get_battery_info() -> Dict[str, Any]:
    """
    Detects power subsystem:
    - Desktop: Direct AC Power + PSU Detection (without fake guessing)
    - Laptop: Battery Health + Capacity Metrics
    """
    power_status = _get_system_power_status()
    psu_info = _get_psu_hardware_info()

    if not power_status["has_battery"]:
        return {
            "has_battery": False,
            "is_desktop": True,
            "health_percent": None,
            "health_grade": "Not Applicable",
            "health_grade_fa": "بدون باتری (سیستم رومیزی)",
            "design_capacity_mwh": 0,
            "full_charge_capacity_mwh": 0,
            "current_charge_percent": None,
            "is_charging": False,
            "ac_connected": power_status["ac_connected"],
            "power_source": "AC Power",
            "power_source_fa": "برق شهری (AC Line Power)",
            "psu_wattage": psu_info["psu_wattage"],
            "psu_display": psu_info["psu_display"],
            "psu_detected": psu_info["psu_detected"],
            "cycle_count": None,
            "voltage_mv": None,
            "name": "Desktop (No Battery)",
            "manufacturer": "Not available",
            "serial": "-",
            "chemistry": "N/A",
            "is_healthy": True,
            "summary_message": f"Desktop computer on AC power. {psu_info['psu_display']}",
            "summary_message_fa": f"سیستم رومیزی متصل به برق شهری. {psu_info['psu_display']}"
        }

    # Laptop with Battery
    wmi_data = _get_wmi_battery_info()
    design_cap = wmi_data.get("design_capacity_mwh", 0)
    full_cap = wmi_data.get("full_charge_capacity_mwh", 0)
    cycle_count = wmi_data.get("cycle_count")
    charge_pct = power_status.get("charge_percent") or wmi_data.get("charge_percent") or 0
    is_charging = power_status.get("is_charging", False)
    ac_connected = power_status.get("ac_connected", False)

    health_pct = None
    if design_cap > 0 and full_cap > 0:
        raw_pct = (full_cap / design_cap) * 100.0
        health_pct = round(min(100.0, max(0.0, raw_pct)), 1)

    if ac_connected:
        if is_charging:
            power_src = "AC (Charging)"
            power_src_fa = "برق مستقیم (در حال شارژ)"
        else:
            power_src = "AC (Fully Charged)"
            power_src_fa = "برق مستقیم (شارژ کامل)"
    else:
        power_src = "Battery"
        power_src_fa = "استفاده از باتری"

    if health_pct is not None:
        if health_pct >= 85:
            grade = "Excellent"
            grade_fa = "عالی"
        elif health_pct >= 70:
            grade = "Good"
            grade_fa = "سالم"
        elif health_pct >= 50:
            grade = "Moderate"
            grade_fa = "متوسط"
        else:
            grade = "Poor"
            grade_fa = "ضعیف / نیاز به تعویض"
    else:
        grade = "Unknown"
        grade_fa = "نامشخص"

    return {
        "has_battery": True,
        "is_desktop": False,
        "health_percent": health_pct,
        "health_grade": grade,
        "health_grade_fa": grade_fa,
        "design_capacity_mwh": design_cap,
        "full_charge_capacity_mwh": full_cap,
        "current_charge_percent": charge_pct,
        "is_charging": is_charging,
        "ac_connected": ac_connected,
        "power_source": power_src,
        "power_source_fa": power_src_fa,
        "psu_wattage": None,
        "psu_display": "Laptop Power Adapter",
        "psu_detected": False,
        "cycle_count": cycle_count,
        "voltage_mv": wmi_data.get("voltage_mv"),
        "name": wmi_data.get("name", "Laptop Battery"),
        "manufacturer": wmi_data.get("manufacturer", "OEM"),
        "serial": wmi_data.get("serial", "-"),
        "chemistry": wmi_data.get("chemistry", "Li-Ion"),
        "is_healthy": (health_pct is None or health_pct >= 50),
        "summary_message": f"Battery Health: {health_pct}% ({grade})" if health_pct else "Battery Health: Unknown",
        "summary_message_fa": f"سلامت باتری: {int(health_pct)}% ({grade_fa})" if health_pct else "سلامت باتری: نامشخص"
    }
