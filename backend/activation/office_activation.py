# backend/activation/office_activation.py
"""
Microsoft Office Detection & Licensing Status Module
Robustly detects modern Office installations (Click-to-Run, Microsoft 365, Office 2024, 2021, 2019, 2016, MSI),
architecture, product edition, license status, channel, partial key, and activation tool availability.
Guarantees accurate detection across Volume, KMS, Retail, OEM, and Ohook installations.
"""

import os
import re
import sys
import winreg
import subprocess
import logging
from typing import Dict, Any, Optional, List

from utils.formatters import clean_string
from utils.powershell import run_powershell_json, get_hidden_subprocess_kwargs
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


def _check_ohook_installed(install_path: Optional[str] = None) -> bool:
    """
    Checks if Ohook activation hook DLLs are present in Office runtime directories.
    Ohook places sppc.dll / version.dll / sppcs.dll inside root\\vfs\\System or Office16 directory.
    """
    candidates = [
        r"C:\Program Files\Microsoft Office\root\vfs\System",
        r"C:\Program Files\Microsoft Office\root\vfs\SystemX86",
        r"C:\Program Files\Microsoft Office\root\Office16",
        r"C:\Program Files\Microsoft Office\Office16",
        r"C:\Program Files (x86)\Microsoft Office\root\vfs\System",
        r"C:\Program Files (x86)\Microsoft Office\root\vfs\SystemX86",
        r"C:\Program Files (x86)\Microsoft Office\Office16",
    ]
    if install_path:
        candidates.extend([
            install_path,
            os.path.join(install_path, "root", "vfs", "System"),
            os.path.join(install_path, "root", "vfs", "SystemX86"),
            os.path.join(install_path, "root", "Office16"),
            os.path.join(install_path, "Office16"),
        ])

    for d in candidates:
        if os.path.isdir(d):
            for dll in ["sppc.dll", "sppcs.dll", "version.dll", "slc.dll"]:
                if os.path.isfile(os.path.join(d, dll)):
                    return True
    return False


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

    # 3. Check App Paths for WINWORD.EXE / EXCEL.EXE
    for app in ["WINWORD.EXE", "EXCEL.EXE", "POWERPNT.EXE"]:
        try:
            with winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, rf"SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\{app}") as key:
                path, _ = winreg.QueryValueEx(key, "")
                if path and os.path.isfile(str(path).strip('"\t ')):
                    clean_p = str(path).strip('"\t ')
                    res["installed"] = True
                    res["install_type"] = "Desktop App"
                    res["product"] = "Microsoft Office"
                    res["install_path"] = os.path.dirname(clean_p)
                    return res
        except Exception:
            pass

    return res


def _get_ospp_vbs_licensing(install_path: Optional[str] = None) -> Optional[Dict[str, Any]]:
    """
    Finds and executes ospp.vbs /dstatus across common Office paths to inspect licensing state.
    """
    program_files = os.environ.get("ProgramFiles", r"C:\Program Files")
    program_files_x86 = os.environ.get("ProgramFiles(x86)", r"C:\Program Files (x86)")
    program_w6432 = os.environ.get("ProgramW6432", r"C:\Program Files")

    ospp_candidates = []
    if install_path and os.path.isdir(install_path):
        ospp_candidates.extend([
            os.path.join(install_path, "OSPP.VBS"),
            os.path.join(install_path, "root", "Office16", "OSPP.VBS"),
            os.path.join(install_path, "Office16", "OSPP.VBS"),
            os.path.join(install_path, "Office15", "OSPP.VBS"),
        ])

    for pf in [program_files, program_w6432, program_files_x86]:
        if pf:
            ospp_candidates.extend([
                os.path.join(pf, r"Microsoft Office\root\Office16\OSPP.VBS"),
                os.path.join(pf, r"Microsoft Office\Office16\OSPP.VBS"),
                os.path.join(pf, r"Microsoft Office\root\Office15\OSPP.VBS"),
                os.path.join(pf, r"Microsoft Office\Office15\OSPP.VBS"),
                os.path.join(pf, r"Microsoft Office\Office14\OSPP.VBS"),
            ])

    seen = set()
    unique_candidates = []
    for c in ospp_candidates:
        c_norm = os.path.normpath(c)
        if c_norm not in seen:
            seen.add(c_norm)
            unique_candidates.append(c_norm)

    is_ohook = _check_ohook_installed(install_path)

    for ospp_path in unique_candidates:
        if os.path.isfile(ospp_path):
            try:
                proc = subprocess.run(
                    ["cscript", "//nologo", ospp_path, "/dstatus"],
                    capture_output=True,
                    text=True,
                    timeout=12,
                    **get_hidden_subprocess_kwargs()
                )
                out = proc.stdout
                if not out:
                    continue

                blocks = out.split("---------------------------------------")
                products = []
                for block in blocks:
                    if not block.strip():
                        continue
                    p_data = {"activated": False, "status_text": "Not Activated"}
                    has_license_info = False
                    for line in block.splitlines():
                        clean_l = line.strip()
                        if clean_l.startswith("LICENSE STATUS:"):
                            has_license_info = True
                            status_str = clean_l.split(":", 1)[1].strip()
                            p_data["status_raw"] = status_str
                            if "---LICENSED---" in status_str or "LICENSED" in status_str.upper():
                                p_data["status_text"] = "Licensed"
                                p_data["activated"] = True
                            elif "NOTIFICATIONS" in status_str.upper():
                                p_data["status_text"] = "Notification Mode"
                                p_data["activated"] = False
                            elif "GRACE" in status_str.upper():
                                p_data["status_text"] = "Grace Period"
                                p_data["activated"] = False
                            else:
                                p_data["status_text"] = status_str
                                p_data["activated"] = False
                        elif clean_l.startswith("LICENSE NAME:"):
                            has_license_info = True
                            p_data["license_name"] = clean_l.split(":", 1)[1].strip()
                        elif clean_l.startswith("LICENSE DESCRIPTION:"):
                            has_license_info = True
                            desc = clean_l.split(":", 1)[1].strip()
                            p_data["description"] = desc
                            ch_match = re.search(r'([A-Za-z0-9_:]+)\s+channel', desc, re.IGNORECASE)
                            if ch_match:
                                p_data["channel"] = ch_match.group(1).strip()
                        elif clean_l.startswith("Last 5 characters of installed product key:"):
                            p_data["partial_key"] = clean_l.split(":", 1)[1].strip()

                    if has_license_info:
                        if is_ohook:
                            p_data["activated"] = True
                            p_data["status_text"] = "Licensed"
                        products.append(p_data)

                if products:
                    # Prioritize any product that is LICENSED
                    for p in products:
                        if p.get("activated", False):
                            return p
                    return products[0]
            except Exception as e:
                logger.debug(f"ospp.vbs query error: {e}")

    return None


def _get_wmi_office_licensing() -> Optional[Dict[str, Any]]:
    """
    Fallback WMI query to SoftwareLicensingProduct / OfficeSoftwareProtectionProduct.
    Prioritizes any product where LicenseStatus = 1 (Licensed).
    """
    try:
        ps_cmd = """
        $prods = Get-CimInstance SoftwareLicensingProduct -Filter "PartialProductKey IS NOT NULL" -ErrorAction SilentlyContinue |
                 Where-Object { $_.ApplicationId -eq '0ff1ce15-a989-479d-af46-f275c6370663' -or $_.ApplicationId -eq '0ff1ce15-a989-479d-af46-f275c6370523' -or $_.Name -like '*Office*' }

        $licensed = $prods | Where-Object { $_.LicenseStatus -eq 1 } | Select-Object -First 1
        if (-not $licensed) {
            $licensed = $prods | Select-Object -First 1
        }
        if ($licensed) {
            [PSCustomObject]@{
                Name = $licensed.Name
                Description = $licensed.Description
                LicenseStatus = $licensed.LicenseStatus
                PartialProductKey = $licensed.PartialProductKey
            } | ConvertTo-Json
        }
        """
        raw = run_powershell_json(ps_cmd, timeout=10)
        if isinstance(raw, dict):
            status_code = raw.get("LicenseStatus", 0)
            is_licensed = (status_code == 1)
            return {
                "activated": is_licensed,
                "status_text": "Licensed" if is_licensed else "Not Activated",
                "license_name": raw.get("Name"),
                "channel": raw.get("Description") or "VOLUME_KMSCLIENT",
                "partial_key": raw.get("PartialProductKey"),
            }
    except Exception as e:
        logger.debug(f"WMI Office check error: {e}")
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
        tool_status = get_tool_status("office")
        info["tool_available"] = False
        info["tool_path"] = tool_status.get("tool_path")
        return info

    is_ohook = _check_ohook_installed(reg_install.get("install_path"))

    # Step 2: Query licensing via ospp.vbs
    ospp_data = _get_ospp_vbs_licensing(reg_install.get("install_path"))
    if ospp_data:
        info["activated"] = ospp_data.get("activated", False) or is_ohook
        info["status_text"] = "Licensed" if info["activated"] else ospp_data.get("status_text", "Not Activated")
        info["status_code"] = 1 if info["activated"] else 0

        if ospp_data.get("channel"):
            info["channel"] = ospp_data["channel"]
        elif ospp_data.get("description"):
            info["channel"] = ospp_data["description"]

        if ospp_data.get("partial_key"):
            info["partial_key"] = ospp_data["partial_key"]

        if ospp_data.get("license_name") and (info["product"] == "Not installed" or "unknown" in info["product"].lower()):
            info["product"] = ospp_data["license_name"].split(",")[0].strip()

    # Step 3: If not confirmed yet, fallback to WMI
    if not info["activated"]:
        wmi_data = _get_wmi_office_licensing()
        if wmi_data:
            if wmi_data.get("activated") or is_ohook:
                info["activated"] = True
                info["status_text"] = "Licensed"
                info["status_code"] = 1
            if wmi_data.get("channel"):
                info["channel"] = wmi_data["channel"]
            if wmi_data.get("partial_key"):
                info["partial_key"] = wmi_data["partial_key"]

    # Step 4: If Ohook is installed anywhere, it is guaranteed Licensed
    if is_ohook and not info["activated"]:
        info["activated"] = True
        info["status_text"] = "Licensed"
        info["status_code"] = 1
        if info["channel"] == "Not available":
            info["channel"] = "Permanent (Ohook)"

    # Step 5: Check Activation Tool Availability
    tool_status = get_tool_status("office")
    info["tool_available"] = tool_status.get("available", False)
    info["tool_path"] = tool_status.get("tool_path")

    return info
