# backend/activation/windows_activation.py
"""
Windows Activation Detection Module
Queries official Windows licensing tools (slmgr.vbs) and WMI SoftwareLicensingProduct
to accurately detect activation state, channel, partial key, edition, and expiration.
"""

import os
import re
import subprocess
import logging
from typing import Dict, Any, Optional

from utils.formatters import clean_string
from activation.activation_tools import get_tool_status

logger = logging.getLogger(__name__)


def _query_slmgr_dli() -> Dict[str, Any]:
    """
    Executes slmgr.vbs /dli to retrieve edition, description, partial key, and license status.
    Fast (typically < 500ms) and accessible without administrator privileges.
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
            timeout=6
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
            timeout=5
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

    # Step 1: Query slmgr.vbs /dli (Fast & accurate)
    dli_data = _query_slmgr_dli()
    if dli_data:
        info["activated"] = dli_data.get("activated", False)
        info["status_text"] = dli_data.get("status_text", "Licensed" if info["activated"] else "Not Activated")
        info["status_code"] = 1 if info["activated"] else 0

        if dli_data.get("name"):
            clean_ed = clean_string(dli_data["name"]).replace("(R)", "").replace("(TM)", "").strip()
            info["edition"] = clean_ed

        if dli_data.get("description"):
            desc = clean_string(dli_data["description"])
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

        if dli_data.get("partial_key"):
            info["partial_key"] = clean_string(dli_data["partial_key"])

        # Check expiration
        xpr_exp = _query_slmgr_xpr()
        if xpr_exp:
            info["expiration"] = xpr_exp
            info["is_permanent"] = False
        else:
            info["expiration"] = None
            info["is_permanent"] = True

    # Step 2: Check Activation Tool Availability
    tool_status = get_tool_status("windows")
    info["tool_available"] = tool_status.get("available", False)
    info["tool_path"] = tool_status.get("tool_path")

    return info
