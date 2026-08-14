import json
import logging
import os
from typing import Any, Dict, List

logger = logging.getLogger(__name__)

DEFAULT_FILE_REQUIREMENTS = [
    {
        "id": "training_folder",
        "name": "Training Folder",
        "displayName": "Training Folder",
        "path": r"C:\CompanyFiles\Training",
        "type": "folder",
        "required": True
    },
    {
        "id": "desktop_tools",
        "name": "Desktop Tools",
        "displayName": "Desktop Tools",
        "path": r"C:\Users\Public\Desktop\CompanyTools",
        "type": "folder",
        "required": True
    },
    {
        "id": "system_hosts",
        "name": "System Hosts File",
        "displayName": "System Hosts File",
        "path": r"C:\Windows\System32\drivers\etc\hosts",
        "type": "file",
        "required": True
    }
]

def load_file_requirements() -> List[Dict[str, Any]]:
    """Loads required files/folders from config/file_requirements.json."""
    candidates = [
        os.path.join(os.getcwd(), "config", "file_requirements.json"),
        os.path.join(os.path.dirname(__file__), "..", "..", "config", "file_requirements.json"),
        os.path.join(os.path.dirname(__file__), "..", "config", "file_requirements.json"),
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
    Inspects whether configured required files and directories exist on the local file system.
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
            # Expand environment variables if present (e.g. %APPDATA% or %PUBLIC%)
            expanded_path = os.path.expandvars(target_path)
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
                "path": target_path,
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
