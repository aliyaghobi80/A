# backend/activation/windows_activation.py
"""
Windows Activation Detection Module
Queries official Windows licensing tools (WMI SoftwareLicensingProduct, slmgr.vbs, and Registry)
to accurately detect activation state, channel, partial key, edition, and expiration.
"""

import os
import re
import subprocess
import logging
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
    This is the most reliable, direct method on Windows 10 & 11 (returns LicenseStatus: 1 for Licensed).
    """
    res = {}
    try:
        script = """
        $products = Get-CimInstance SoftwareLicensingProduct -Filter "PartialProductKey IS NOT NULL" -ErrorAction SilentlyContinue
        $win = $products | Where-Object { $_.ApplicationId -eq '55c92734-d682-4d71-983e-d6ec3f16059f' -or $_.Name -like '*Windows*' } | Select-Object -First 1
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


def _query_slmgr_xpr() -> Optional[str]:
    """
    Executes slmgr.vbs /xpr to get expiration information if volume/KMS/grace period.
    Returns None if permanently activated or not available.
    """
    try:
        slmgr_path = os.path.join(os.environ.get("SystemRoot", r"C:\Windows"), "System32", "slmgr.vbs")
        if not os.path.isfile(slmgr_path):
            return None

        proc = subprocess.run(
            ["cscript", "//nologo", slmgr_path, "/xpr"],
            capture_output=True,
            text=True,
            timeout=6,
            **get_hidden_subprocess_kwargs()
        )
        out = proc.stdout.strip()
        if not out:
            return None

        if "permanently activated" in out.lower() or "permanent" in out.lower():
            return None  # Permanent activation

        for line in out.splitlines():
            line_clean = line.strip()
            if "expire" in line_clean.lower() or "time" in line_clean.lower():
                return line_clean

        return None
    except Exception as e:
        logger.debug(f"slmgr /xpr query error: {e}")
        return None


def get_windows_activation_info() -> Dict[str, Any]:
    """
    Collects complete Windows activation and licensing details.
    Guarantees a clean, non-crashing structured dictionary.
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

    # Step 1: Query slmgr.vbs /dli
    dli_data = _query_slmgr_dli()
    
    # Step 2: Query WMI SoftwareLicensingProduct (robust fallback & verification)
    wmi_data = _query_wmi_licensing()

    # Combine results
    activated = dli_data.get("activated", False) or wmi_data.get("activated", False)
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

    # Check expiration
    xpr_exp = _query_slmgr_xpr()
    if xpr_exp:
        info["expiration"] = xpr_exp
        info["is_permanent"] = False
    else:
        info["expiration"] = None
        info["is_permanent"] = True

    # Step 3: Check Activation Tool Availability
    tool_status = get_tool_status("windows")
    info["tool_available"] = tool_status.get("available", False)
    info["tool_path"] = tool_status.get("tool_path")

    return info
