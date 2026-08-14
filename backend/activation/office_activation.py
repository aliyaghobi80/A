# backend/activation/office_activation.py
"""
Microsoft Office Detection & Licensing Status Module
Detects modern Office installations (Click-to-Run, Microsoft 365, Office 2024, 2021, 2019, 2016, MSI),
architecture, product edition, license status, channel, partial key, and activation tool availability.
"""

import os
import re
import winreg
import subprocess
import logging
from typing import Dict, Any, Optional, List

from utils.formatters import clean_string
from activation.activation_tools import get_tool_status

logger = logging.getLogger(__name__)

OFFICE_PRODUCT_NAMES = {
    "proplus2024retail": "Microsoft Office Professional Plus 2024",
    "proplus2024volume": "Microsoft Office Professional Plus 2024 (Volume)",
    "proplus2021retail": "Microsoft Office Professional Plus 2021",
    "proplus2021volume": "Microsoft Office Professional Plus 2021 (Volume)",
    "proplus2019retail": "Microsoft Office Professional Plus 2019",
    "proplus2019volume": "Microsoft Office Professional Plus 2019 (Volume)",
    "o365proplusretail": "Microsoft 365 Apps for enterprise",
    "o365businessretail": "Microsoft 365 Apps for business",
    "o365homepremretail": "Microsoft 365 Family / Personal",
    "standard2024volume": "Microsoft Office Standard 2024",
    "standard2021volume": "Microsoft Office Standard 2021",
    "standard2019volume": "Microsoft Office Standard 2019",
    "homebusiness2024retail": "Microsoft Office Home & Business 2024",
    "homebusiness2021retail": "Microsoft Office Home & Business 2021",
    "homebusiness2019retail": "Microsoft Office Home & Business 2019",
    "homestudent2024retail": "Microsoft Office Home & Student 2024",
    "homestudent2021retail": "Microsoft Office Home & Student 2021",
    "homestudent2019retail": "Microsoft Office Home & Student 2019",
}


def _detect_office_registry_installation() -> Dict[str, Any]:
    """
    Checks Click-to-Run and MSI registry keys for installed Microsoft Office.
    """
    res = {
        "installed": False,
        "product": "Not installed",
        "version": "Not available",
        "architecture": "Not available",
        "install_type": "Unknown",
        "install_path": None,
    }

    # 1. Check Click-to-Run configuration
    c2r_path = r"SOFTWARE\Microsoft\Office\ClickToRun\Configuration"
    try:
        with winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, c2r_path) as key:
            def get_val(vname):
                try:
                    v, _ = winreg.QueryValueEx(key, vname)
                    return str(v).strip()
                except Exception:
                    return ""

            release_ids = get_val("ProductReleaseIds")
            version = get_val("VersionToReport") or get_val("ClientVersionToReport")
            platform = get_val("Platform")
            install_path = get_val("InstallationPath")

            if release_ids or version:
                res["installed"] = True
                res["install_type"] = "Click-to-Run"
                res["version"] = version or "Unknown"
                res["architecture"] = platform or ("64-bit" if "x64" in str(platform).lower() else "32-bit")
                res["install_path"] = install_path

                first_release = release_ids.split(",")[0].strip().lower() if release_ids else ""
                res["product"] = OFFICE_PRODUCT_NAMES.get(first_release, f"Microsoft Office ({first_release})")
                return res
    except Exception:
        pass

    # 2. Check standard Office Common\InstallRoot keys (MSI / Volume installations)
    msi_roots = [
        (winreg.HKEY_LOCAL_MACHINE, r"SOFTWARE\Microsoft\Office\16.0\Common\InstallRoot", "2016/2019/2021/2024"),
        (winreg.HKEY_LOCAL_MACHINE, r"SOFTWARE\WOW6432Node\Microsoft\Office\16.0\Common\InstallRoot", "2016/2019/2021/2024 (32-bit)"),
        (winreg.HKEY_LOCAL_MACHINE, r"SOFTWARE\Microsoft\Office\15.0\Common\InstallRoot", "2013"),
        (winreg.HKEY_LOCAL_MACHINE, r"SOFTWARE\WOW6432Node\Microsoft\Office\15.0\Common\InstallRoot", "2013 (32-bit)"),
        (winreg.HKEY_LOCAL_MACHINE, r"SOFTWARE\Microsoft\Office\14.0\Common\InstallRoot", "2010"),
    ]

    for hive, subkey, ver_label in msi_roots:
        try:
            with winreg.OpenKey(hive, subkey) as key:
                path_val, _ = winreg.QueryValueEx(key, "Path")
                if path_val and os.path.isdir(str(path_val)):
                    res["installed"] = True
                    res["install_type"] = "MSI"
                    res["product"] = f"Microsoft Office {ver_label}"
                    res["install_path"] = str(path_val)
                    res["architecture"] = "32-bit" if "wow6432node" in subkey.lower() else "64-bit"
                    return res
        except Exception:
            pass

    return res


def _get_ospp_vbs_licensing() -> Optional[Dict[str, Any]]:
    """
    Finds and executes ospp.vbs /dstatus across common Office paths to inspect licensing state.
    """
    program_files = os.environ.get("ProgramFiles", r"C:\Program Files")
    program_files_x86 = os.environ.get("ProgramFiles(x86)", r"C:\Program Files (x86)")

    ospp_candidates = [
        os.path.join(program_files, r"Microsoft Office\root\Office16\OSPP.VBS"),
        os.path.join(program_files_x86, r"Microsoft Office\root\Office16\OSPP.VBS"),
        os.path.join(program_files, r"Microsoft Office\Office16\OSPP.VBS"),
        os.path.join(program_files_x86, r"Microsoft Office\Office16\OSPP.VBS"),
        os.path.join(program_files, r"Microsoft Office\root\Office15\OSPP.VBS"),
        os.path.join(program_files_x86, r"Microsoft Office\root\Office15\OSPP.VBS"),
        os.path.join(program_files, r"Microsoft Office\Office15\OSPP.VBS"),
        os.path.join(program_files_x86, r"Microsoft Office\Office15\OSPP.VBS"),
        os.path.join(program_files, r"Microsoft Office\Office14\OSPP.VBS"),
        os.path.join(program_files_x86, r"Microsoft Office\Office14\OSPP.VBS"),
    ]

    for ospp_path in ospp_candidates:
        if os.path.isfile(ospp_path):
            try:
                proc = subprocess.run(
                    ["cscript", "//nologo", ospp_path, "/dstatus"],
                    capture_output=True,
                    text=True,
                    timeout=6
                )
                out = proc.stdout
                if not out:
                    continue

                res = {}
                for line in out.splitlines():
                    clean_l = line.strip()
                    if clean_l.startswith("LICENSE STATUS:"):
                        status_str = clean_l.split(":", 1)[1].strip()
                        res["status_raw"] = status_str
                        if "---LICENSED---" in status_str or "LICENSED" in status_str:
                            res["status_text"] = "Licensed"
                            res["activated"] = True
                        elif "NOTIFICATIONS" in status_str:
                            res["status_text"] = "Notification Mode"
                            res["activated"] = False
                        elif "GRACE" in status_str:
                            res["status_text"] = "Grace Period"
                            res["activated"] = False
                        else:
                            res["status_text"] = status_str
                            res["activated"] = False
                    elif clean_l.startswith("LICENSE NAME:"):
                        res["license_name"] = clean_l.split(":", 1)[1].strip()
                    elif clean_l.startswith("LICENSE DESCRIPTION:"):
                        desc = clean_l.split(":", 1)[1].strip()
                        res["description"] = desc
                        ch_match = re.search(r'([A-Za-z0-9_:]+)\s+channel', desc, re.IGNORECASE)
                        if ch_match:
                            res["channel"] = ch_match.group(1).strip()
                    elif clean_l.startswith("Last 5 characters of installed product key:"):
                        res["partial_key"] = clean_l.split(":", 1)[1].strip()

                if res:
                    return res
            except Exception as e:
                logger.debug(f"ospp.vbs query error: {e}")

    return None


def get_office_activation_info() -> Dict[str, Any]:
    """
    Collects complete Microsoft Office installation and activation details.
    Guarantees a clean, non-crashing structured dictionary.
    """
    # Step 1: Detect Office installation
    reg_install = _detect_office_registry_installation()
    is_installed = reg_install["installed"]

    info = {
        "installed": is_installed,
        "product": reg_install["product"] if is_installed else "Not installed",
        "version": reg_install["version"],
        "architecture": reg_install["architecture"],
        "install_type": reg_install["install_type"],
        "activated": False,
        "status_code": 0,
        "status_text": "Not Installed" if not is_installed else "Not Activated",
        "channel": "Not available",
        "partial_key": "Not available",
        "expiration": None,
        "tool_available": False,
        "tool_path": None,
    }

    if not is_installed:
        # If not installed, never show tool available or activation button
        tool_status = get_tool_status("office")
        info["tool_available"] = False
        info["tool_path"] = tool_status.get("tool_path")
        return info

    # Step 2: Query licensing via ospp.vbs (Fast & exact)
    ospp_data = _get_ospp_vbs_licensing()
    if ospp_data:
        info["activated"] = ospp_data.get("activated", False)
        info["status_text"] = ospp_data.get("status_text", "Licensed" if info["activated"] else "Not Activated")
        info["status_code"] = 1 if info["activated"] else 0

        if ospp_data.get("channel"):
            info["channel"] = ospp_data["channel"]
        elif ospp_data.get("description"):
            info["channel"] = ospp_data["description"]

        if ospp_data.get("partial_key"):
            info["partial_key"] = ospp_data["partial_key"]

        if ospp_data.get("license_name") and (info["product"] == "Not installed" or "unknown" in info["product"].lower()):
            info["product"] = ospp_data["license_name"].split(",")[0].strip()

    # Step 3: Check Activation Tool Availability
    tool_status = get_tool_status("office")
    info["tool_available"] = tool_status.get("available", False)
    info["tool_path"] = tool_status.get("tool_path")

    return info
