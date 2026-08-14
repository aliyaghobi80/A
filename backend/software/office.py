import logging
import os
import winreg
from typing import Dict, Optional

logger = logging.getLogger(__name__)

OFFICE_RELEASE_ID_MAP = {
    "ProPlus2024Retail": "Microsoft Office 2024 (Pro Plus)",
    "ProPlus2024Volume": "Microsoft Office LTSC 2024 (Pro Plus)",
    "Standard2024Volume": "Microsoft Office LTSC 2024 (Standard)",
    "HomeBusiness2024Retail": "Microsoft Office 2024 (Home & Business)",
    "HomeStudent2024Retail": "Microsoft Office 2024 (Home & Student)",
    "ProPlus2021Retail": "Microsoft Office 2021 (Pro Plus)",
    "ProPlus2021Volume": "Microsoft Office LTSC 2021 (Pro Plus)",
    "Standard2021Volume": "Microsoft Office LTSC 2021 (Standard)",
    "HomeBusiness2021Retail": "Microsoft Office 2021 (Home & Business)",
    "HomeStudent2021Retail": "Microsoft Office 2021 (Home & Student)",
    "ProPlus2019Retail": "Microsoft Office 2019 (Pro Plus)",
    "ProPlus2019Volume": "Microsoft Office 2019 (Pro Plus)",
    "Standard2019Volume": "Microsoft Office 2019 (Standard)",
    "HomeBusiness2019Retail": "Microsoft Office 2019 (Home & Business)",
    "HomeStudent2019Retail": "Microsoft Office 2019 (Home & Student)",
    "ProPlusRetail": "Microsoft Office 2016 / 365 (Pro Plus)",
    "O365ProPlusRetail": "Microsoft 365 (Enterprise)",
    "O365BusinessRetail": "Microsoft 365 (Business)",
    "O365HomePremRetail": "Microsoft 365 (Family / Personal)",
}

def detect_microsoft_office() -> Dict[str, any]:
    """
    Detects whether Microsoft Office is installed on the machine and retrieves product name
    and version without checking or altering activation.
    """
    # 1. Check Office Click-to-Run (C2R) Configuration
    c2r_info = _check_click_to_run()
    if c2r_info.get("installed"):
        return c2r_info

    # 2. Check Standard App Paths for Word / Excel
    app_path_info = _check_app_paths()
    if app_path_info.get("installed"):
        return app_path_info

    # 3. Check Traditional MSI Registry Keys
    msi_info = _check_msi_office()
    if msi_info.get("installed"):
        return msi_info

    # 4. Check Standard File Locations
    file_info = _check_file_system_locations()
    if file_info.get("installed"):
        return file_info

    return {
        "installed": False,
        "product_name": "Not available",
        "version": "Not available",
        "detection_source": "None",
        "install_location": "Not available",
    }

def _check_click_to_run() -> Dict[str, any]:
    for hive in [winreg.HKEY_LOCAL_MACHINE]:
        for subkey in [r"SOFTWARE\Microsoft\Office\ClickToRun\Configuration",
                       r"SOFTWARE\WOW6432Node\Microsoft\Office\ClickToRun\Configuration"]:
            try:
                with winreg.OpenKey(hive, subkey) as key:
                    product_ids = _query_string(key, "ProductReleaseIDs")
                    version_to_report = _query_string(key, "VersionToReport")
                    install_path = _query_string(key, "InstallationPath") or ""

                    if product_ids or version_to_report:
                        friendly_name = _map_product_id(product_ids)
                        return {
                            "installed": True,
                            "product_name": friendly_name,
                            "version": version_to_report or "Not available",
                            "detection_source": "Registry (Click-to-Run)",
                            "install_location": install_path or "Standard C2R Directory",
                        }
            except OSError:
                continue
    return {"installed": False}

def _check_app_paths() -> Dict[str, any]:
    for app in ["WINWORD.EXE", "EXCEL.EXE", "POWERPNT.EXE"]:
        try:
            with winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, rf"SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\{app}") as key:
                path, _ = winreg.QueryValueEx(key, "")
                if path and isinstance(path, str):
                    path = path.strip('"\t ')
                    if os.path.exists(path):
                        version = _get_binary_version(path)
                        product_name = _infer_product_from_version(version)
                        return {
                            "installed": True,
                            "product_name": product_name,
                            "version": version or "Not available",
                            "detection_source": f"App Paths ({app})",
                            "install_location": os.path.dirname(path),
                        }
        except OSError:
            continue
    return {"installed": False}

def _check_msi_office() -> Dict[str, any]:
    # Check Office 16.0 (2016), 15.0 (2013), 14.0 (2010), 12.0 (2007)
    for ver_num, label in [("16.0", "Office 2016+"), ("15.0", "Office 2013"), ("14.0", "Office 2010"), ("12.0", "Office 2007")]:
        for hive in [winreg.HKEY_LOCAL_MACHINE, winreg.HKEY_CURRENT_USER]:
            try:
                with winreg.OpenKey(hive, rf"SOFTWARE\Microsoft\Office\{ver_num}\Common\InstallRoot") as key:
                    path = _query_string(key, "Path")
                    if path and os.path.exists(path):
                        word_exe = os.path.join(path, "WINWORD.EXE")
                        version = _get_binary_version(word_exe) if os.path.exists(word_exe) else "Not available"
                        return {
                            "installed": True,
                            "product_name": f"Microsoft {label}",
                            "version": version,
                            "detection_source": f"Registry (Office {ver_num})",
                            "install_location": path,
                        }
            except OSError:
                continue
    return {"installed": False}

def _check_file_system_locations() -> Dict[str, any]:
    candidates = [
        r"C:\Program Files\Microsoft Office\root\Office16\WINWORD.EXE",
        r"C:\Program Files (x86)\Microsoft Office\root\Office16\WINWORD.EXE",
        r"C:\Program Files\Microsoft Office\Office16\WINWORD.EXE",
        r"C:\Program Files (x86)\Microsoft Office\Office16\WINWORD.EXE",
        r"C:\Program Files\Microsoft Office\Office15\WINWORD.EXE",
        r"C:\Program Files (x86)\Microsoft Office\Office15\WINWORD.EXE",
        r"C:\Program Files\Microsoft Office\Office14\WINWORD.EXE",
        r"C:\Program Files (x86)\Microsoft Office\Office14\WINWORD.EXE",
    ]
    for candidate in candidates:
        if os.path.exists(candidate):
            version = _get_binary_version(candidate)
            product_name = _infer_product_from_version(version)
            return {
                "installed": True,
                "product_name": product_name,
                "version": version or "Not available",
                "detection_source": "File System",
                "install_location": os.path.dirname(candidate),
            }
    return {"installed": False}

def _map_product_id(product_ids: Optional[str]) -> str:
    if not product_ids:
        return "Microsoft Office"
    
    # Can contain comma-separated IDs, e.g. "ProPlus2024Retail,VisioPro2024Retail"
    primary_id = product_ids.split(",")[0].strip()
    if primary_id in OFFICE_RELEASE_ID_MAP:
        return OFFICE_RELEASE_ID_MAP[primary_id]
    
    if "2024" in primary_id:
        return "Microsoft Office 2024"
    elif "2021" in primary_id:
        return "Microsoft Office 2021"
    elif "2019" in primary_id:
        return "Microsoft Office 2019"
    elif "365" in primary_id or "O365" in primary_id:
        return "Microsoft 365"
    elif "2016" in primary_id:
        return "Microsoft Office 2016"
    return f"Microsoft Office ({primary_id})"

def _infer_product_from_version(version: Optional[str]) -> str:
    if not version or version == "Not available":
        return "Microsoft Office"
    try:
        parts = version.split(".")
        major = int(parts[0])
        minor = int(parts[1]) if len(parts) > 1 else 0
        build = int(parts[2]) if len(parts) > 2 else 0

        if major == 16:
            # 16.0.20000+ -> Office 2024 / M365
            if build >= 17900:
                return "Microsoft Office 2024"
            elif build >= 14300:
                return "Microsoft Office 2021"
            elif build >= 10700:
                return "Microsoft Office 2019"
            else:
                return "Microsoft Office 2016"
        elif major == 15:
            return "Microsoft Office 2013"
        elif major == 14:
            return "Microsoft Office 2010"
        elif major == 12:
            return "Microsoft Office 2007"
    except Exception:
        pass
    return "Microsoft Office"

def _query_string(key, name: str) -> Optional[str]:
    try:
        val, _ = winreg.QueryValueEx(key, name)
        if isinstance(val, str):
            return val
        return str(val)
    except OSError:
        return None

def _get_binary_version(filepath: str) -> Optional[str]:
    if not os.path.exists(filepath):
        return None
    try:
        import ctypes
        import struct
        size = ctypes.windll.version.GetFileVersionInfoSizeW(filepath, None)
        if size == 0:
            return None
        res = ctypes.create_string_buffer(size)
        ctypes.windll.version.GetFileVersionInfoW(filepath, 0, size, res)
        r = ctypes.c_void_p()
        l = ctypes.c_uint()
        ctypes.windll.version.VerQueryValueW(res, "\\", ctypes.byref(r), ctypes.byref(l))
        data = ctypes.string_at(r, l.value)
        sig, struct_ver, file_ver_ms, file_ver_ls = struct.unpack('<IIII', data[:16])
        return f"{file_ver_ms >> 16}.{file_ver_ms & 0xFFFF}.{file_ver_ls >> 16}.{file_ver_ls & 0xFFFF}"
    except Exception:
        return None
