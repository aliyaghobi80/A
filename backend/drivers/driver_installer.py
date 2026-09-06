# backend/drivers/driver_installer.py
"""
Intelligent Driver Manager Coordinator.
Coordinates discovery, inspection, hardware matching, deduplication,
and priority installation of local driver packages:
- Configurable driver root (config/driver_directory.json)
- Auto-detection of removable USB driver repositories
- Deep package inspection (ZIP, Extracted Folders, Self-extracting EXEs, INFs)
- Real-time matching against current hardware (Win32_PnPEntity / PnPSignedDriver)
- Deduplication and fingerprinting
- 9-Tier priority sequential queue execution
- Zero internet download, zero blind execution of unknown files
"""

import json
import logging
import os
import shutil
from typing import Dict, Any, List, Optional

from utils.powershell import run_powershell_json
from .package_inspector import inspect_driver_package, DriverPackage
from .hardware_matcher import get_current_system_hardware, match_package_to_hardware
from .deduplicator import deduplicate_driver_packages
from .history import load_driver_history
from .queue_manager import (
    start_driver_queue,
    get_driver_queue_status,
    cancel_driver_queue,
    sort_driver_queue,
)

logger = logging.getLogger(__name__)

CONFIG_PATH = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "..", "..", "config", "driver_directory.json")
)

# Cached scan result
_cached_scan_result: Optional[Dict[str, Any]] = None
_cached_packages_map: Dict[str, Dict[str, Any]] = {}


def get_driver_directory_config() -> Dict[str, Any]:
    """Reads configured driver directory and discovers removable USB drives."""
    driver_root = "Drivers"
    if os.path.isfile(CONFIG_PATH):
        try:
            with open(CONFIG_PATH, "r", encoding="utf-8") as f:
                cfg = json.load(f)
                driver_root = cfg.get("driverRoot", "Drivers")
        except Exception as e:
            logger.warning(f"Error reading driver_directory.json: {e}")

    # Resolve absolute path
    app_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
    if not os.path.isabs(driver_root):
        resolved_root = os.path.abspath(os.path.join(app_root, driver_root))
    else:
        resolved_root = os.path.abspath(driver_root)

    # Discover removable drives with Drivers folder
    removable_sources = detect_removable_driver_sources()

    return {
        "configured_path": driver_root,
        "resolved_path": resolved_root,
        "exists": os.path.isdir(resolved_root),
        "removable_sources": removable_sources,
    }


def set_driver_directory_config(new_path: str) -> Dict[str, Any]:
    """Updates driver_directory.json with new user-chosen path."""
    new_path = new_path.strip()
    if not new_path:
        return {"success": False, "message": "مسیر پوشه نمی‌تواند خالی باشد."}

    os.makedirs(os.path.dirname(CONFIG_PATH), exist_ok=True)
    cfg = {
        "driverRoot": new_path,
        "description": "Relative or absolute directory path to scan for local driver packages"
    }
    try:
        with open(CONFIG_PATH, "w", encoding="utf-8") as f:
            json.dump(cfg, f, indent=2, ensure_ascii=False)
        return {"success": True, "message": "مسیر درایورها با موفقیت به‌روزرسانی شد.", "config": cfg}
    except Exception as e:
        return {"success": False, "message": f"خطا در ذخیره تنظیمات: {str(e)}"}


def detect_removable_driver_sources() -> List[Dict[str, Any]]:
    """Detects connected USB/Removable drives containing a Drivers folder."""
    ps_cmd = (
        "Get-CimInstance Win32_LogicalDisk | "
        "Where-Object { $_.DriveType -eq 2 } | "
        "Select-Object DeviceID, VolumeName, Size, FreeSpace | "
        "ConvertTo-Json -Compress"
    )
    sources = []
    try:
        raw = run_powershell_json(ps_cmd, timeout=6)
        disks = []
        if isinstance(raw, list):
            disks = raw
        elif isinstance(raw, dict):
            disks = [raw]

        for d in disks:
            dev_id = str(d.get("DeviceID") or "").rstrip("\\")
            vol_name = str(d.get("VolumeName") or "Flash Drive")
            if not dev_id:
                continue

            candidates = [
                os.path.join(f"{dev_id}\\", "Drivers"),
                os.path.join(f"{dev_id}\\", "MarkaziSystem", "Drivers"),
                os.path.join(f"{dev_id}\\", "Driver"),
            ]
            for cand in candidates:
                if os.path.isdir(cand):
                    sources.append({
                        "drive_letter": dev_id,
                        "volume_name": vol_name,
                        "driver_path": cand,
                        "display_name": f"{vol_name} ({dev_id}) - {os.path.basename(cand)}",
                    })
                    break
    except Exception as e:
        logger.debug(f"Error detecting removable driver drives: {e}")

    return sources


def intelligent_scan_drivers(custom_dir: Optional[str] = None) -> Dict[str, Any]:
    """
    Performs intelligent discovery, inspection, hardware matching,
    and deduplication across the target driver directory.
    """
    global _cached_scan_result, _cached_packages_map

    cfg = get_driver_directory_config()
    target_dir = os.path.abspath(custom_dir.strip()) if custom_dir and custom_dir.strip() else cfg["resolved_path"]

    if not os.path.isdir(target_dir):
        return {
            "success": False,
            "message": f"پوشه درایورها یافت نشد: {target_dir}",
            "driver_directory": target_dir,
            "total_packages": 0,
            "packages": [],
            "duplicates": [],
            "summary": {
                "total": 0,
                "matching": 0,
                "needs_install": 0,
                "update_available": 0,
                "up_to_date": 0,
                "not_applicable": 0,
                "duplicates": 0,
            },
        }

    logger.info(f"[IntelligentDriver] Starting scan in: {target_dir}")

    # Discover candidate entries:
    # 1. Immediate subdirectories (e.g. Drivers/ASUS_LAN/)
    # 2. Immediate ZIP archives (e.g. Drivers/WiFi.zip)
    # 3. Direct executable installers or INF files if placed directly in root
    candidates: List[str] = []
    ignored_names = {"backend", "_internal", "build", "dist", "node_modules", ".git", "temp", "tmp", "logs", "__pycache__"}

    try:
        entries = os.listdir(target_dir)
        for e in entries:
            if e.lower() in ignored_names or e.startswith("."):
                continue
            full = os.path.join(target_dir, e)
            if os.path.isdir(full):
                candidates.append(full)
            elif os.path.isfile(full):
                ext = os.path.splitext(e)[1].lower()
                if ext in (".zip", ".exe", ".inf", ".msi"):
                    candidates.append(full)

        # If no candidates at top-level, search 1 level deeper
        if not candidates:
            for root, dirs, files in os.walk(target_dir):
                dirs[:] = [d for d in dirs if d.lower() not in ignored_names and not d.startswith(".")]
                for d in dirs:
                    candidates.append(os.path.join(root, d))
                for f in files:
                    if f.lower().endswith((".zip", ".exe", ".inf", ".msi")):
                        candidates.append(os.path.join(root, f))
                break  # Only 1 depth
    except Exception as e:
        logger.error(f"Error enumerating candidates in {target_dir}: {e}")
        return {"success": False, "message": f"خطا در خواندن پوشه: {str(e)}", "packages": []}

    # Inspect packages
    discovered_pkgs: List[Dict[str, Any]] = []
    for cand in candidates:
        try:
            pkg = inspect_driver_package(cand, target_dir)
            if pkg and pkg.is_safe:
                discovered_pkgs.append(pkg.to_dict())
        except Exception as e:
            logger.warning(f"Error inspecting driver entry {cand}: {e}")

    # Fetch active system hardware
    hardware_list = get_current_system_hardware()

    # Match each package to current hardware
    for p in discovered_pkgs:
        match_info = match_package_to_hardware(p, hardware_list)
        p["match"] = match_info

    # Deduplicate packages
    unique_pkgs, dup_pkgs = deduplicate_driver_packages(discovered_pkgs)

    # Sort unique packages by 9-tier priority ordering
    sorted_unique = sort_driver_queue(unique_pkgs)

    # Compute summary counters
    matching_cnt = sum(1 for p in sorted_unique if p.get("match", {}).get("is_matched"))
    needs_install_cnt = sum(1 for p in sorted_unique if p.get("match", {}).get("status") == "needs_install")
    update_avail_cnt = sum(1 for p in sorted_unique if p.get("match", {}).get("status") == "update_available")
    up_to_date_cnt = sum(1 for p in sorted_unique if p.get("match", {}).get("status") == "up_to_date")
    not_applicable_cnt = sum(1 for p in sorted_unique if not p.get("match", {}).get("is_matched"))

    result = {
        "success": True,
        "message": f"{len(sorted_unique)} بسته درایور شناسایی و با سخت‌افزار سیستم تحلیل گردید.",
        "driver_directory": target_dir,
        "total_packages": len(sorted_unique),
        "packages": sorted_unique,
        "duplicates": dup_pkgs,
        "removable_sources": cfg.get("removable_sources", []),
        "summary": {
            "total": len(sorted_unique),
            "matching": matching_cnt,
            "needs_install": needs_install_cnt,
            "update_available": update_avail_cnt,
            "up_to_date": up_to_date_cnt,
            "not_applicable": not_applicable_cnt,
            "duplicates": len(dup_pkgs),
        },
    }

    _cached_scan_result = result
    _cached_packages_map = {p["package_id"]: p for p in sorted_unique}

    return result


def start_intelligent_driver_install(
    package_ids: Optional[List[str]] = None,
    custom_dir: Optional[str] = None,
) -> Dict[str, Any]:
    """
    Validates selected packages and starts the 9-tier priority queue.
    If package_ids is omitted or empty, selects all installable recommended packages
    (needs_install or update_available with confidence != LOW and confidence != NOT_APPLICABLE).
    """
    global _cached_scan_result, _cached_packages_map

    scan = intelligent_scan_drivers(custom_dir)
    if not scan.get("success") or not scan.get("packages"):
        return {"success": False, "message": scan.get("message", "هیچ درایور معتبری برای نصب یافت نشد.")}

    all_pkgs = scan["packages"]

    if package_ids:
        # User explicitly checked specific packages
        id_set = set(package_ids)
        target_pkgs = [p for p in all_pkgs if p.get("package_id") in id_set]
    else:
        # Install All: only valid installable packages that are recommended
        target_pkgs = [
            p for p in all_pkgs
            if p.get("match", {}).get("recommendation") == "recommended"
            and p.get("match", {}).get("confidence") in ("HIGH", "MEDIUM")
            and p.get("match", {}).get("status") in ("needs_install", "update_available")
        ]

    if not target_pkgs:
        return {
            "success": False,
            "message": "هیچ بسته درایور واجد شرایط و سازگاری برای نصب خودکار یافت نشد.",
        }

    return start_driver_queue(target_pkgs)


# ---------------------------------------------------------------------------
# Backwards Compatibility Wrappers for existing API endpoints
# ---------------------------------------------------------------------------

def scan_driver_folder(folder_path: str) -> Dict[str, Any]:
    """Legacy compatibility wrapper for /api/drivers/scan-folder."""
    scan = intelligent_scan_drivers(custom_dir=folder_path)
    # Convert packages to legacy file list format for any caller expecting files
    legacy_files = []
    for p in scan.get("packages", []):
        legacy_files.append({
            "filename": p.get("installer_file") or os.path.basename(p.get("source_path")),
            "relative_path": p.get("relative_path"),
            "full_path": p.get("installer_path") or p.get("source_path"),
            "type": p.get("package_type"),
            "type_label": p.get("category_fa"),
            "install_method": p.get("install_method"),
            "auto_install_supported": True,
            "is_valid": True,
            "file_size_display": p.get("file_size_display"),
        })

    return {
        "success": scan.get("success", False),
        "message": scan.get("message", ""),
        "folder_path": scan.get("driver_directory", folder_path),
        "total": len(scan.get("packages", [])),
        "files": legacy_files,
        "intelligent_packages": scan.get("packages", []),
        "summary": scan.get("summary", {}),
    }


def start_batch_driver_install(folder_path: str, package_ids: Optional[List[str]] = None) -> Dict[str, Any]:
    """Legacy compatibility wrapper for starting driver batch."""
    return start_intelligent_driver_install(package_ids=package_ids, custom_dir=folder_path)


def get_driver_batch_status() -> Dict[str, Any]:
    """Returns queue status."""
    return get_driver_queue_status()


def cancel_driver_batch_install() -> Dict[str, Any]:
    """Cancels active driver queue."""
    return cancel_driver_queue()
