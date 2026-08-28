import re
from datetime import datetime
from typing import Any, Optional

GENERIC_PLACEHOLDERS = {
    "", "none", "null", "unknown", "default string", "to be filled by o.e.m.",
    "system manufacturer", "system product name", "chassis serial number",
    "base board serial number", "to be filled by o.e.m", "n/a", "not available",
    "undefined", "0", "00000000", "ffffffff"
}

def clean_string(val: Any, default: str = "Not available") -> str:
    """Cleans string values and normalizes OEM placeholders to standard default text."""
    if val is None:
        return default
    text = str(val).strip()
    if text.lower() in GENERIC_PLACEHOLDERS:
        return default
    return text

def format_bytes_to_gb(bytes_val: Any) -> Optional[float]:
    """Converts a byte count to gigabytes (rounded to 1 or 2 decimal places)."""
    try:
        if bytes_val is None:
            return None
        b = float(bytes_val)
        if b <= 0:
            return None
        return round(b / (1024 ** 3), 2)
    except (ValueError, TypeError):
        return None

def format_bytes_display(bytes_val: Any, default: str = "Not available") -> str:
    """Formats bytes into a readable string like '500 GB' or '1.0 TB'."""
    gb = format_bytes_to_gb(bytes_val)
    if gb is None:
        return default
    if gb >= 1000:
        tb = round(gb / 1024, 2)
        return f"{tb} TB ({int(gb)} GB)"
    return f"{int(round(gb))} GB"

def format_mhz(mhz_val: Any, default: str = "Not available") -> str:
    """Formats clock speed in MHz or GHz."""
    try:
        if mhz_val is None:
            return default
        mhz = float(mhz_val)
        if mhz <= 0:
            return default
        if mhz >= 1000:
            ghz = mhz / 1000.0
            return f"{ghz:.2f} GHz"
        return f"{int(mhz)} MHz"
    except (ValueError, TypeError):
        return default

def parse_wmi_date(date_val: Any, default: str = "Not available") -> str:
    """
    Parses various Windows / WMI date formats such as:
    - /Date(1686009600000)/
    - 20230606000000.000000+000
    - 06/06/2023
    - 2023-06-06
    """
    if not date_val:
        return default
    
    val_str = str(date_val).strip()
    
    # 1. Matches /Date(1686009600000)/ (PowerShell JSON serialization format)
    match_ms = re.search(r'/Date\((\d+)\)/', val_str)
    if match_ms:
        try:
            ts_ms = int(match_ms.group(1))
            dt = datetime.fromtimestamp(ts_ms / 1000.0)
            return dt.strftime("%Y-%m-%d")
        except Exception:
            pass

    # 2. Matches WMI DMTF format: YYYYMMDDHHMMSS...
    match_dmtf = re.match(r'^(\d{4})(\d{2})(\d{2})', val_str)
    if match_dmtf:
        year, month, day = match_dmtf.groups()
        return f"{year}-{month}-{day}"

    # 3. Matches standard MM/DD/YYYY or YYYY-MM-DD
    for fmt in ("%m/%d/%Y", "%Y-%m-%d", "%d/%m/%Y", "%m/%d/%y"):
        try:
            dt = datetime.strptime(val_str, fmt)
            return dt.strftime("%Y-%m-%d")
        except ValueError:
            continue

    return clean_string(val_str, default=default)

def clean_serial_number(val: Any, default: str = "-") -> str:
    """
    Cleans and validates hardware serial numbers.
    Filters out OEM defaults, dummy zeroes, and placeholder strings.
    Returns the real serial number or default ('-').
    """
    if val is None:
        return default
    text = str(val).strip()
    text_clean = text.strip("'\" \t\r\n")
    if not text_clean:
        return default
    lowered = text_clean.lower()
    if lowered in GENERIC_PLACEHOLDERS:
        return default
    if re.fullmatch(r"^[0_\.\-\s]+$", text_clean) or re.fullmatch(r"^[fF_\.\-\s]+$", text_clean):
        return default
    if lowered in ("to be filled by o.e.m.", "default string", "none", "null", "unknown", "system serial number", "chassis serial number", "na", "n/a", "not specified"):
        return default
    return text_clean

def clean_part_number(val: Any, default: str = "-") -> str:
    """Cleans hardware part numbers and model identifiers."""
    if val is None:
        return default
    text = str(val).strip()
    text_clean = text.strip("'\" \t\r\n")
    if not text_clean or text_clean.lower() in GENERIC_PLACEHOLDERS:
        return default
    if re.fullmatch(r"^[0_\.\-\s]+$", text_clean):
        return default
    return text_clean
