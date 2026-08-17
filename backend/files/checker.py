# backend/files/checker.py
"""
Required Files & Corporate Folders Status Checker
Inspects whether configured required files and directories exist on the local file system or USB flash drive.
Supports portable {APP_DIR} and {ROOT_DIR} macros as well as Windows environment variables (%USERPROFILE%, %APPDATA%, etc.).
Does NOT modify the file system.
"""

import json
import logging
import os
import sys
from typing import Any, Dict, List

logger = logging.getLogger(__name__)


def get_app_root() -> str:
    """Finds the root application folder dynamically (sys.frozen aware for portable USB drives)."""
    if getattr(sys, 'frozen', False):
        exe_dir = os.path.dirname(os.path.abspath(sys.executable))
        if os.path.basename(exe_dir).lower() == "backend":
            return os.path.dirname(exe_dir)
        return exe_dir

    curr = os.path.abspath(os.path.dirname(os.path.dirname(os.path.dirname(__file__))))
    for c in [curr, os.getcwd(), os.path.dirname(curr)]:
        if os.path.isdir(os.path.join(c, "config")) or os.path.isdir(os.path.join(c, "Tools")) or os.path.isdir(os.path.join(c, "Packages")):
            return c
    return curr


def resolve_portable_path(raw_path: str) -> str:
    """
    Expands macros like {APP_DIR}, {ROOT_DIR}, and environment variables (%APPDATA%, %SYSTEMDRIVE%),
    and resolves relative paths relative to the application/USB root.
    """
    if not raw_path:
        return ""
    app_root = get_app_root()
    p = raw_path.replace("{APP_DIR}", app_root).replace("{ROOT_DIR}", app_root)
    p = os.path.expandvars(p)
    if not os.path.isabs(p):
        p = os.path.abspath(os.path.join(app_root, p))
    return os.path.normpath(p)


DEFAULT_FILE_REQUIREMENTS = [
    {
        "id": "packages_folder",
        "name": "Software Packages",
        "displayName": "Software Packages (پوشه نرم‌افزارها)",
        "path": r"{APP_DIR}\Packages",
        "type": "folder",
        "required": True
    },
    {
        "id": "tools_folder",
        "name": "Activation Tools",
        "displayName": "Activation Tools (ابزارهای فعالسازی)",
        "path": r"{APP_DIR}\Tools",
        "type": "folder",
        "required": True
    },
    {
        "id": "system_hosts",
        "name": "System Hosts File",
        "displayName": "System Hosts File (فایل سیستم ویندوز)",
        "path": r"%SYSTEMDRIVE%\Windows\System32\drivers\etc\hosts",
        "type": "file",
        "required": True
    }
]


def load_file_requirements() -> List[Dict[str, Any]]:
    """Loads required files/folders from config/file_requirements.json."""
    app_root = get_app_root()
    candidates = [
        os.path.join(app_root, "config", "file_requirements.json"),
        os.path.join(os.getcwd(), "config", "file_requirements.json"),
        os.path.join(os.path.dirname(__file__), "..", "..", "config", "file_requirements.json"),
    ]
    for path in candidates:
        abs_path = os.path.abspath(path)
        if os.path.exists(abs_path):
            try:
                with open(abs_path, "r", encoding="utf-8") as f:
                    data = json.load(f)
                    if isinstance(data, dict) and "items" in data:
                        return data["items"]
                    elif isinstance(data, list):
                        return data
            except Exception as e:
                logger.warning(f"Failed to read file config at {abs_path}: {e}")

    return DEFAULT_FILE_REQUIREMENTS


def check_required_files() -> Dict[str, Any]:
    """
    Inspects whether configured required files and directories exist on the local file system or USB drive.
    Does NOT modify the file system.
    """
    requirements = load_file_requirements()
    results: List[Dict[str, Any]] = []

    for req in requirements:
        req_id = req.get("id", "unknown")
        req_name = req.get("displayName") or req.get("name", "Unknown File")
        target_path = req.get("path", "")
        item_type = req.get("type", "folder").lower()
        is_required = req.get("required", True)

        try:
            expanded_path = resolve_portable_path(target_path)
            exists = os.path.exists(expanded_path)

            if exists:
                if item_type == "folder" and not os.path.isdir(expanded_path):
                    status = "Present (File)"
                elif item_type == "file" and not os.path.isfile(expanded_path):
                    status = "Present (Folder)"
                else:
                    status = "Present"
            else:
                status = "Missing"

            results.append({
                "id": req_id,
                "name": req_name,
                "display_name": req_name,
                "path": expanded_path,
                "raw_path": target_path,
                "type": item_type,
                "status": status,
                "exists": exists,
                "required": is_required,
                "error_message": None,
            })
        except Exception as e:
            logger.error(f"Error checking file path {target_path}: {e}")
            results.append({
                "id": req_id,
                "name": req_name,
                "display_name": req_name,
                "path": target_path,
                "raw_path": target_path,
                "type": item_type,
                "status": "Unknown",
                "exists": False,
                "required": is_required,
                "error_message": str(e),
            })

    present_count = sum(1 for r in results if r["exists"])
    total_count = len(results)
    all_present = (present_count == total_count) if total_count > 0 else True

    return {
        "items": results,
        "summary": {
            "present_count": present_count,
            "total_count": total_count,
            "all_present": all_present,
        }
    }


def set_file_requirement_path(req_id: str, new_path: str) -> Dict[str, Any]:
    """Updates a file/folder requirement path and persists to config/file_requirements.json."""
    app_root = get_app_root()
    cfg_file = os.path.join(app_root, "config", "file_requirements.json")
    reqs = load_file_requirements()

    found = False
    for item in reqs:
        if item.get("id") == req_id or item.get("name") == req_id:
            item["path"] = new_path
            found = True
            break

    if not found:
        # Add new requirement
        reqs.append({
            "id": req_id,
            "name": req_id.replace("_", " ").title(),
            "displayName": req_id.replace("_", " ").title(),
            "path": new_path,
            "type": "folder" if os.path.isdir(new_path) else "file",
            "required": True,
        })

    try:
        os.makedirs(os.path.dirname(cfg_file), exist_ok=True)
        with open(cfg_file, "w", encoding="utf-8") as f:
            json.dump({"items": reqs}, f, indent=2)
    except Exception as e:
        logger.warning(f"Failed to save file_requirements.json: {e}")

    return {
        "success": True,
        "id": req_id,
        "path": new_path,
    }

