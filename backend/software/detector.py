import ctypes
import json
import logging
import os
import struct
from typing import Any, Dict, List, Optional

from .office import detect_microsoft_office
from .registry import get_app_path_from_registry, get_installed_applications_from_registry

logger = logging.getLogger(__name__)

DEFAULT_SOFTWARE_REQUIREMENTS = [
    {
        "id": "chrome",
        "name": "Google Chrome",
        "displayName": "Google Chrome",
        "required": True,
        "registryPatterns": ["Google Chrome", "Chrome"],
        "appPaths": ["chrome.exe"],
        "executablePaths": [
            r"C:\Program Files\Google\Chrome\Application\chrome.exe",
            r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
        ]
    },
    {
        "id": "winrar",
        "name": "WinRAR",
        "displayName": "WinRAR",
        "required": True,
        "registryPatterns": ["WinRAR"],
        "appPaths": ["WinRAR.exe"],
        "executablePaths": [
            r"C:\Program Files\WinRAR\WinRAR.exe",
            r"C:\Program Files (x86)\WinRAR\WinRAR.exe",
        ]
    },
    {
        "id": "vlc",
        "name": "VLC Media Player",
        "displayName": "VLC Media Player",
        "required": True,
        "registryPatterns": ["VLC media player", "VLC"],
        "appPaths": ["vlc.exe"],
        "executablePaths": [
            r"C:\Program Files\VideoLAN\VLC\vlc.exe",
            r"C:\Program Files (x86)\VideoLAN\VLC\vlc.exe",
        ]
    },
    {
        "id": "office",
        "name": "Microsoft Office",
        "displayName": "Microsoft Office",
        "required": True,
        "isOffice": True,
        "registryPatterns": ["Microsoft Office", "Office 16", "Microsoft 365"],
        "appPaths": ["WINWORD.EXE", "EXCEL.EXE"],
        "executablePaths": [
            r"C:\Program Files\Microsoft Office\root\Office16\WINWORD.EXE",
            r"C:\Program Files (x86)\Microsoft Office\root\Office16\WINWORD.EXE",
            r"C:\Program Files\Microsoft Office\Office16\WINWORD.EXE",
            r"C:\Program Files (x86)\Microsoft Office\Office16\WINWORD.EXE",
        ]
    }
]

def load_software_requirements() -> List[Dict[str, Any]]:
    """Loads required software from config/software_requirements.json."""
    candidates = [
        os.path.join(os.getcwd(), "config", "software_requirements.json"),
        os.path.join(os.path.dirname(__file__), "..", "..", "config", "software_requirements.json"),
        os.path.join(os.path.dirname(__file__), "..", "config", "software_requirements.json"),
    ]
    for path in candidates:
        abs_path = os.path.abspath(path)
        if os.path.exists(abs_path):
            try:
                with open(abs_path, "r", encoding="utf-8") as f:
                    data = json.load(f)
                    if isinstance(data, dict) and "software" in data:
                        return data["software"]
                    elif isinstance(data, list):
                        return data
            except Exception as e:
                logger.warning(f"Failed to read software config at {abs_path}: {e}")

    return DEFAULT_SOFTWARE_REQUIREMENTS

def get_file_version(filepath: str) -> Optional[str]:
    """Uses Win32 GetFileVersionInfo API via ctypes to extract exact binary version."""
    if not filepath or not os.path.exists(filepath):
        return None
    try:
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

def detect_required_software() -> Dict[str, Any]:
    """
    Evaluates each required software item against Windows registry, App Paths,
    and executable binary files.
    """
    requirements = load_software_requirements()
    installed_reg_apps = get_installed_applications_from_registry()

    results: List[Dict[str, Any]] = []

    for req in requirements:
        req_id = req.get("id", "unknown")
        req_name = req.get("displayName") or req.get("name", "Unknown Application")
        is_required = req.get("required", True)
        is_office = req.get("isOffice", False)

        try:
            if is_office or "office" in req_id.lower() or "microsoft office" in req_name.lower():
                office_res = detect_microsoft_office()
                is_inst = office_res.get("installed", False)
                results.append({
                    "id": req_id,
                    "name": req_name,
                    "display_name": req_name,
                    "status": "Installed" if is_inst else "Not Installed",
                    "is_installed": is_inst,
                    "version": office_res.get("version") or "Not available",
                    "product_name": office_res.get("product_name") or req_name,
                    "detection_source": office_res.get("detection_source") or "None",
                    "install_location": office_res.get("install_location") or "Not available",
                    "required": is_required,
                })
                continue

            # 1. Check Registry Uninstall database
            matched_app = None
            patterns = [p.lower() for p in req.get("registryPatterns", [req_name])]
            for app in installed_reg_apps:
                dname_lower = app["display_name"].lower()
                for pat in patterns:
                    if pat in dname_lower:
                        matched_app = app
                        break
                if matched_app:
                    break

            if matched_app:
                ver = matched_app["display_version"]
                location = matched_app["install_location"]
                
                # If version is missing or generic, try extracting from location or app path
                if not ver or ver == "Not available":
                    app_paths = req.get("appPaths", [])
                    for exe in app_paths:
                        found_path = get_app_path_from_registry(exe)
                        if found_path:
                            file_ver = get_file_version(found_path)
                            if file_ver:
                                ver = file_ver
                                break

                results.append({
                    "id": req_id,
                    "name": req_name,
                    "display_name": req_name,
                    "status": "Installed",
                    "is_installed": True,
                    "version": ver if ver else "Not available",
                    "product_name": matched_app["display_name"],
                    "detection_source": f"Registry ({matched_app['source']})",
                    "install_location": location if location else "Standard Program Directory",
                    "required": is_required,
                })
                continue

            # 2. Check App Paths in Registry
            app_paths = req.get("appPaths", [])
            found_app_path = None
            for exe in app_paths:
                resolved_path = get_app_path_from_registry(exe)
                if resolved_path and os.path.exists(resolved_path):
                    found_app_path = resolved_path
                    break

            if found_app_path:
                ver = get_file_version(found_app_path) or "Not available"
                results.append({
                    "id": req_id,
                    "name": req_name,
                    "display_name": req_name,
                    "status": "Installed",
                    "is_installed": True,
                    "version": ver,
                    "product_name": req_name,
                    "detection_source": "Registry App Paths",
                    "install_location": os.path.dirname(found_app_path),
                    "required": is_required,
                })
                continue

            # 3. Check Standard Executable Files on Disk
            found_file_path = None
            exec_paths = req.get("executablePaths", [])
            for ep in exec_paths:
                if os.path.exists(ep):
                    found_file_path = ep
                    break

            if found_file_path:
                ver = get_file_version(found_file_path) or "Not available"
                results.append({
                    "id": req_id,
                    "name": req_name,
                    "display_name": req_name,
                    "status": "Installed",
                    "is_installed": True,
                    "version": ver,
                    "product_name": req_name,
                    "detection_source": "File System",
                    "install_location": os.path.dirname(found_file_path),
                    "required": is_required,
                })
                continue

            # Software is not found
            results.append({
                "id": req_id,
                "name": req_name,
                "display_name": req_name,
                "status": "Not Installed",
                "is_installed": False,
                "version": "Not available",
                "product_name": req_name,
                "detection_source": "None",
                "install_location": "Not available",
                "required": is_required,
            })

        except Exception as e:
            logger.error(f"Error checking software {req_name}: {e}", exc_info=True)
            results.append({
                "id": req_id,
                "name": req_name,
                "display_name": req_name,
                "status": "Unknown",
                "is_installed": False,
                "version": "Not available",
                "product_name": req_name,
                "detection_source": "Error",
                "install_location": "Not available",
                "required": is_required,
            })

    installed_count = sum(1 for r in results if r["is_installed"])
    total_count = len(results)
    all_installed = (installed_count == total_count) if total_count > 0 else True

    return {
        "items": results,
        "summary": {
            "installed_count": installed_count,
            "total_count": total_count,
            "all_installed": all_installed,
        }
    }
