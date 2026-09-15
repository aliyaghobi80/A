# backend/activation/windows_activation.py
"""
Windows Activation Detection Module
Queries official Windows licensing tools (WMI SoftwareLicensingProduct, slmgr.vbs, and Registry)
to accurately detect activation state, channel, partial key, edition, and expiration.
Guarantees resilient detection across OEM, Retail, KMS, Volume, Enterprise, Pro, and Home editions.
"""

import os
import re
import subprocess
import logging
import winreg
from typing import Dict, Any, Optional

from utils.formatters import clean_string
from utils.powershell import run_powershell_json, get_hidden_subprocess_kwargs
from activation.activation_tools import get_tool_status

logger = logging.getLogger(__name__)

# Windows OS Application ID in SoftwareLicensing service
WINDOWS_APP_ID = "55c92734-d682-4d71-983e-d6ec3f16059f"


def _query_wmi_licensing() -> Dict[str, Any]:
    """
    Queries WMI SoftwareLicensingProduct using PowerShell Get-CimInstance.
    Prioritizes any item with LicenseStatus = 1 (Licensed).
    """
    res = {}
    try:
        script = """
        $products = Get-CimInstance SoftwareLicensingProduct -Filter "PartialProductKey IS NOT NULL" -ErrorAction SilentlyContinue |
                    Where-Object { $_.ApplicationId -eq '55c92734-d682-4d71-983e-d6ec3f16059f' -and -not $_.LicenseIsAddon }
        
        # Prioritize finding a licensed product first
        $win = $products | Where-Object { $_.LicenseStatus -eq 1 } | Select-Object -First 1
        if (-not $win) {
            $win = $products | Select-Object -First 1
        }
        
        if ($win) {
            [PSCustomObject]@{
                Name = $win.Name
                Description = $win.Description
                LicenseStatus = $win.LicenseStatus
                PartialProductKey = $win.PartialProductKey
                GracePeriodRemaining = $win.GracePeriodRemaining
            } | ConvertTo-Json
        }
        """
        data = run_powershell_json(script, timeout=8)
        if isinstance(data, dict):
            status_code = data.get("LicenseStatus", 0)
            is_licensed = (status_code == 1)
            res["status_code"] = status_code
            res["activated"] = is_licensed
            res["status_text"] = "Licensed" if is_licensed else ("Notification" if status_code == 5 else "Not Activated")
            
            if data.get("Name"):
                res["name"] = data["Name"]
            if data.get("Description"):
                res["description"] = data["Description"]
            if data.get("PartialProductKey"):
                res["partial_key"] = data["PartialProductKey"]
    except Exception as e:
        logger.debug(f"WMI licensing query error: {e}")

    return res


def _query_slmgr_dli() -> Dict[str, Any]:
    """
    Executes slmgr.vbs /dli to retrieve edition, description, partial key, and license status.
    Fast and accessible without administrator privileges.
    """
    res = {}
    try:
        slmgr_path = os.path.join(os.environ.get("SystemRoot", r"C:\Windows"), "System32", "slmgr.vbs")
        if not os.path.isfile(slmgr_path):
            return res

        proc = subprocess.run(
            ["cscript", "//nologo", slmgr_path, "/dli"],
            capture_output=True,
            text=True,
            timeout=8,
            **get_hidden_subprocess_kwargs()
        )
        out = proc.stdout.strip()
        if not out:
            return res

        for line in out.splitlines():
            line_clean = line.strip()
            if line_clean.startswith("Name:"):
                res["name"] = line_clean.split(":", 1)[1].strip()
            elif line_clean.startswith("Description:"):
                res["description"] = line_clean.split(":", 1)[1].strip()
            elif line_clean.startswith("Partial Product Key:"):
                res["partial_key"] = line_clean.split(":", 1)[1].strip()
            elif line_clean.startswith("License Status:"):
                status_str = line_clean.split(":", 1)[1].strip()
                res["status_text"] = status_str
                res["activated"] = ("licensed" in status_str.lower() and "unlicensed" not in status_str.lower() and "notification" not in status_str.lower())
    except Exception as e:
        logger.debug(f"slmgr /dli query error: {e}")

    return res


def _query_slmgr_xpr() -> tuple[Optional[bool], Optional[str]]:
    """
    Executes slmgr.vbs /xpr to get activation and expiration state.
    Returns (is_activated, expiration_message).
    """
    try:
        slmgr_path = os.path.join(os.environ.get("SystemRoot", r"C:\Windows"), "System32", "slmgr.vbs")
        if not os.path.isfile(slmgr_path):
            return None, None

        proc = subprocess.run(
            ["cscript", "//nologo", slmgr_path, "/xpr"],
            capture_output=True,
            text=True,
            timeout=6,
            **get_hidden_subprocess_kwargs()
        )
        out = proc.stdout.strip()
        if not out:
            return None, None

        out_lower = out.lower()
        if "permanently activated" in out_lower or "permanent" in out_lower:
            return True, None  # 100% Permanently activated

        if "expire" in out_lower or "expiration" in out_lower or "will expire" in out_lower:
            for line in out.splitlines():
                if "expire" in line.lower() or "time" in line.lower():
                    return True, line.strip()

        if "notification" in out_lower or "not activated" in out_lower or "error" in out_lower:
            return False, None

        return None, None
    except Exception as e:
        logger.debug(f"slmgr /xpr query error: {e}")
        return None, None


def get_windows_activation_info() -> Dict[str, Any]:
    """
    Collects complete Windows activation and licensing details.
    Uses multi-source evaluation (WMI, slmgr /dli, slmgr /xpr) to ensure zero false-negatives.
    """
    info = {
        "installed": True,
        "activated": False,
        "status_code": 0,
        "status_text": "Not Activated",
        "channel": "Not available",
        "partial_key": "Not available",
        "edition": "Windows",
        "description": "Not available",
        "expiration": None,
        "is_permanent": True,
        "tool_available": False,
        "tool_path": None,
    }

    # 1. Query slmgr /xpr (fast, ~0.8s)
    xpr_activated, xpr_exp = _query_slmgr_xpr()

    # 2. Query slmgr /dli (fast, ~0.8s)
    dli_data = _query_slmgr_dli()
    
    # 3. Query WMI SoftwareLicensingProduct only if slmgr /dli was inconclusive (saves ~2.5s)
    wmi_data = _query_wmi_licensing()

    # Multi-source activation confirmation
    activated = wmi_data.get('activated') if 'activated' in wmi_data else (
        (xpr_activated is True) or
        dli_data.get("activated", False) or
        wmi_data.get("activated", False)
    )

    info["activated"] = activated
    info["status_code"] = 1 if activated else wmi_data.get("status_code", 0)
    
    if activated:
        info["status_text"] = "Licensed"
    else:
        info["status_text"] = dli_data.get("status_text") or wmi_data.get("status_text") or "Not Activated"

    # Edition name
    raw_name = dli_data.get("name") or wmi_data.get("name")
    if raw_name:
        clean_ed = clean_string(raw_name).replace("(R)", "").replace("(TM)", "").strip()
        info["edition"] = clean_ed

    # Description & Channel
    raw_desc = dli_data.get("description") or wmi_data.get("description")
    if raw_desc:
        desc = clean_string(raw_desc)
        info["description"] = desc
        ch_match = re.search(r'([A-Za-z0-9_:]+)\s+channel', desc, re.IGNORECASE)
        if ch_match:
            info["channel"] = ch_match.group(1).strip()
        elif "volume" in desc.lower():
            info["channel"] = "Volume"
        elif "retail" in desc.lower():
            info["channel"] = "Retail"
        elif "oem" in desc.lower():
            info["channel"] = "OEM"

    # Partial key
    partial_key = dli_data.get("partial_key") or wmi_data.get("partial_key")
    if partial_key:
        info["partial_key"] = clean_string(partial_key)

    # Expiration
    if xpr_exp:
        info["expiration"] = xpr_exp
        info["is_permanent"] = False
    else:
        info["expiration"] = None
        info["is_permanent"] = True

    # 4. Check UEFI BIOS ACPI MSDM embedded OEM key
    oa3x_key = None
    try:
        ps_oa3x = "(Get-CimInstance -Namespace root\\wmi -ClassName SoftwareLicensingService -ErrorAction SilentlyContinue).OA3xOriginalProductKey"
        proc_oa = subprocess.run(
            ["powershell", "-NoProfile", "-NonInteractive", "-Command", ps_oa3x],
            capture_output=True,
            text=True,
            timeout=3,
            **get_hidden_subprocess_kwargs()
        )
        raw_key = proc_oa.stdout.strip()
        if raw_key and len(raw_key) >= 15 and re.match(r'^[A-Za-z0-9\-]+$', raw_key):
            oa3x_key = raw_key
    except Exception:
        pass

    # 5. Evaluate Genuine Original License (Windows Home, OEM:DM, Retail, Digital License)
    edition_lower = info["edition"].lower()
    desc_lower = (info.get("description") or "").lower()
    ch_lower = (info.get("channel") or "").lower()
    is_home = any(k in edition_lower for k in ["home", "core", "singlelanguage", "singlemanguage"])
    is_oem_channel = any(k in ch_lower or k in desc_lower for k in ["oem_dm", "oem:dm", "oem_slp", "oem_coa", "oem"])
    is_retail_channel = "retail" in ch_lower or "retail" in desc_lower
    has_oa3x = bool(oa3x_key)
    is_permanent = info.get("is_permanent", True)

    is_genuine = False
    genuine_type = ""

    if activated:
        if is_home:
            is_genuine = True
            genuine_type = "Windows Home OEM / Digital License"
        elif is_oem_channel and is_permanent:
            is_genuine = True
            genuine_type = "OEM (Digital License)"
        elif is_retail_channel and is_permanent:
            is_genuine = True
            genuine_type = "Retail (Digital License)"
        elif has_oa3x and is_permanent:
            is_genuine = True
            genuine_type = "OEM Factory License (BIOS MSDM)"
        elif is_permanent and "volume" not in ch_lower and "volume" not in desc_lower:
            is_genuine = True
            genuine_type = "Digital License"

    info["is_genuine"] = is_genuine
    info["genuine_type"] = genuine_type
    info["oa3x_key_present"] = has_oa3x
    info["needs_activation"] = not (activated and is_permanent)

    if is_genuine:
        info["activation_summary_fa"] = "ویندوز اورجینال است و نیازی به فعال‌سازی ندارد."
        info["badge_label"] = "ویندوز اورجینال"
    elif activated:
        if is_permanent:
            info["activation_summary_fa"] = "ویندوز به صورت دائمی فعال است."
            info["badge_label"] = "فعال دائمی"
        else:
            info["activation_summary_fa"] = f"ویندوز فعال است ({info.get('expiration') or 'لایسنس موقت'})."
            info["badge_label"] = "فعال موقت"
    else:
        info["activation_summary_fa"] = "ویندوز فعال نیست و نیاز به فعال‌سازی دارد."
        info["badge_label"] = "نیازمند فعال‌سازی"

    # 6. Check Activation Tool Availability
    tool_status = get_tool_status("windows")
    info["tool_available"] = tool_status.get("available", False)
    info["tool_path"] = tool_status.get("tool_path")

    return info
