import logging
import ctypes
from ctypes import wintypes
import os
import xml.etree.ElementTree as ET
from typing import Dict, Any, Optional

from utils.powershell import run_powershell_json, get_hidden_subprocess_kwargs
from utils.formatters import clean_string

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
    """Queries Win32 GetSystemPowerStatus via Kernel32."""
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
    """Queries WMI & CIM namespaces for battery capacity, cycle count, and static data."""
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
        "status_code": 0,
    }

    try:
        ps_script = (
            "$b = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue | Select-Object -First 1 Name, DeviceID, EstimatedChargeRemaining, BatteryStatus; "
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
                    res["serial"] = clean_string(s_data["SerialNumber"])
                elif b_data.get("DeviceID"):
                    res["serial"] = clean_string(b_data["DeviceID"])

                if b_data.get("EstimatedChargeRemaining") is not None:
                    try:
                        res["charge_percent"] = int(b_data["EstimatedChargeRemaining"])
                    except (ValueError, TypeError):
                        pass

                if b_data.get("BatteryStatus") is not None:
                    try:
                        res["status_code"] = int(b_data["BatteryStatus"])
                    except (ValueError, TypeError):
                        pass
    except Exception as e:
        logger.debug(f"WMI battery query failed: {e}")

    return res

def _parse_battery_report_xml(xml_path: str) -> Dict[str, Any]:
    """Parses Windows generated battery report XML."""
    data = {}
    try:
        if os.path.isfile(xml_path):
            tree = ET.parse(xml_path)
            root = tree.getroot()
            # Namespace handling
            ns = {'ns': root.tag.split('}')[0].strip('{')} if '}' in root.tag else {}
            
            # Find Battery element
            bat = root.find('.//ns:Battery', ns) if ns else root.find('.//Battery')
            if bat is not None:
                def _find_text(tag):
                    elem = bat.find(f'ns:{tag}', ns) if ns else bat.find(tag)
                    return elem.text.strip() if elem is not None and elem.text else None

                design_cap = _find_text('DesignCapacity')
                full_cap = _find_text('FullChargeCapacity')
                cycle = _find_text('CycleCount')
                mfg = _find_text('Manufacturer')
                serial = _find_text('SerialNumber')
                chem = _find_text('Chemistry')

                if design_cap:
                    try:
                        data['design_capacity_mwh'] = int(design_cap)
                    except ValueError:
                        pass
                if full_cap:
                    try:
                        data['full_charge_capacity_mwh'] = int(full_cap)
                    except ValueError:
                        pass
                if cycle:
                    try:
                        data['cycle_count'] = int(cycle)
                    except ValueError:
                        pass
                if mfg:
                    data['manufacturer'] = mfg
                if serial:
                    data['serial'] = serial
                if chem:
                    data['chemistry'] = chem
    except Exception as e:
        logger.debug(f"Failed parsing battery report XML: {e}")
    return data

def get_battery_info() -> Dict[str, Any]:
    """
    Comprehensive Battery Health & Status Check.
    Returns structured data for desktop and laptop devices:
      - has_battery: bool (True for laptops, False for desktops)
      - health_percent: float (e.g. 92.5%)
      - health_grade: str ('Excellent' / 'Good' / 'Moderate' / 'Poor')
      - health_grade_fa: str ('عالی' / 'سالم' / 'متوسط' / 'ضعیف')
      - design_capacity_mwh: int
      - full_charge_capacity_mwh: int
      - current_charge_percent: int
      - is_charging: bool
      - ac_connected: bool
      - power_source: str ('AC Adapter' / 'Battery')
      - power_source_fa: str ('برق مستقیم (آداپتور)' / 'باتری')
      - cycle_count: int or None
      - name: str
      - manufacturer: str
      - serial: str
      - chemistry: str
      - is_healthy: bool
      - summary_message: str
      - summary_message_fa: str
    """
    power_status = _get_system_power_status()

    # Fast-path for desktops without batteries (0ms query time)
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
            "power_source_fa": "برق مستقیم (آداپتور / برق شهری)",
            "cycle_count": None,
            "name": "Desktop (No Battery)",
            "manufacturer": "Not available",
            "serial": "Not available",
            "chemistry": "N/A",
            "is_healthy": True,
            "summary_message": "Desktop computer running on direct AC power.",
            "summary_message_fa": "دستگاه رومیزی است و به برق مستقیم شهری متصل می‌باشد.",
        }

    # Laptop with battery: Query WMI & Battery Report
    wmi_data = _get_wmi_battery_info()

    # Laptop with battery
    design_cap = wmi_data.get("design_capacity_mwh", 0)
    full_cap = wmi_data.get("full_charge_capacity_mwh", 0)
    cycle_count = wmi_data.get("cycle_count")
    charge_pct = power_status.get("charge_percent") or wmi_data.get("charge_percent") or 0
    is_charging = power_status.get("is_charging", False)
    ac_connected = power_status.get("ac_connected", False)
    name = wmi_data.get("name", "Standard Laptop Battery")
    manufacturer = wmi_data.get("manufacturer", "Unknown")
    serial = wmi_data.get("serial", "Not available")
    chemistry = wmi_data.get("chemistry", "Li-Ion")

    # If capacity is missing from WMI, fallback to powercfg /batteryreport
    if design_cap <= 0 or full_cap <= 0:
        temp_dir = os.environ.get("TEMP", "C:\\temp")
        xml_path = os.path.join(temp_dir, "msc_battery_report.xml")
        try:
            import subprocess
            subprocess.run(
                ["powercfg", "/batteryreport", "/xml", "/output", xml_path],
                capture_output=True,
                timeout=5,
                **get_hidden_subprocess_kwargs()
            )
            report_data = _parse_battery_report_xml(xml_path)
            if report_data.get("design_capacity_mwh"):
                design_cap = report_data["design_capacity_mwh"]
            if report_data.get("full_charge_capacity_mwh"):
                full_cap = report_data["full_charge_capacity_mwh"]
            if report_data.get("cycle_count"):
                cycle_count = report_data["cycle_count"]
            if report_data.get("manufacturer") and manufacturer in ["Not available", "Unknown"]:
                manufacturer = report_data["manufacturer"]
            if report_data.get("serial") and serial in ["Not available", "Unknown"]:
                serial = report_data["serial"]
            if report_data.get("chemistry"):
                chemistry = report_data["chemistry"]
            
            if os.path.exists(xml_path):
                os.remove(xml_path)
        except Exception as e:
            logger.debug(f"powercfg battery report execution failed: {e}")

    # Calculate Health Percentage
    if design_cap > 0 and full_cap > 0:
        health_pct = round(min((full_cap / design_cap) * 100.0, 100.0), 1)
    elif full_cap > 0:
        health_pct = 100.0
    else:
        health_pct = 100.0 if charge_pct > 0 else 0.0

    # Determine Grade and Health Status
    if health_pct >= 85.0:
        grade = "Excellent"
        grade_fa = "عالی (سالم)"
        is_healthy = True
        msg_fa = f"سلامت باتری {health_pct}٪ و در وضعیت عالی است."
    elif health_pct >= 70.0:
        grade = "Good"
        grade_fa = "خوب (سالم)"
        is_healthy = True
        msg_fa = f"سلامت باتری {health_pct}٪ و مناسب استفاده عادی است."
    elif health_pct >= 50.0:
        grade = "Moderate"
        grade_fa = "متوسط (کارکرده)"
        is_healthy = True
        msg_fa = f"سلامت باتری {health_pct}٪ است (افت ظرفیت دارد اما کار می‌کند)."
    else:
        grade = "Poor"
        grade_fa = "ضعیف (نیاز به تعویض)"
        is_healthy = False
        msg_fa = f"سلامت باتری {health_pct}٪ است و نیاز به تعویض دارد."

    power_source = "AC Power (Charging)" if (ac_connected and is_charging) else ("AC Power" if ac_connected else "Battery")
    power_source_fa = "متصل به شارژر (در حال شارژ)" if (ac_connected and is_charging) else ("متصل به شارژر" if ac_connected else "در حال استفاده از باتری")

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
        "power_source": power_source,
        "power_source_fa": power_source_fa,
        "cycle_count": cycle_count,
        "name": name,
        "manufacturer": manufacturer,
        "serial": serial,
        "chemistry": chemistry,
        "is_healthy": is_healthy,
        "summary_message": f"Battery health is {health_pct}%. Status: {grade}.",
        "summary_message_fa": msg_fa,
    }
