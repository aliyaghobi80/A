# backend/drivers/driver_installer.py
"""
Intelligent Driver Manager Coordinator.
Coordinates discovery, inspection, hardware matching, deduplication,
and priority installation of local driver packages:
- Configurable driver root (config/driver_directory.json)
- Auto-detection of removable USB driver repositories
- Deep package inspection (ZIP, RAR, 7Z, Extracted Folders, Self-extracting EXEs, INFs)
- Automatic extraction of archives into isolated dedicated subfolders
- Real-time matching against current hardware (Win32_PnPEntity / PnPSignedDriver)
- Deduplication and fingerprinting
- 9-Tier priority sequential queue execution
- Interactive / manual installation and folder navigation
- Zero internet download, zero blind execution of unknown files
"""

import json
import logging
import os
import shutil
import subprocess
import time
from typing import Dict, Any, List, Optional

from utils.powershell import run_powershell_json
from .archive_extractor import auto_unpack_driver_archives
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

# Cached scan result with TTL
_cached_scan_result: Optional[Dict[str, Any]] = None
_cached_packages_map: Dict[str, Dict[str, Any]] = {}
_cached_scan_time: float = 0.0
_SCAN_CACHE_TTL_SECONDS: float = 60.0  # Invalidate stale scan after 60 s


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


_IGNORED_DRIVER_DIR_NAMES = {"backend", "_internal", "build", "dist", "node_modules", ".git", "temp", "tmp", "logs", "__pycache__"}


def _has_direct_installer(dir_path: str) -> bool:
    """Checks if a directory has an installer right at its top level."""
    try:
        for f in os.listdir(dir_path):
            ext = os.path.splitext(f)[1].lower()
            fname = f.lower()
            if ext in (".inf", ".msi"):
                return True
            if ext == ".exe" and any(k in fname for k in ("setup", "install", "asus", "igxp", "dpinst", "rtk", "intel")):
                return True
            if ext in (".cmd", ".bat") and any(k in fname for k in ("install", "setup", "silent")):
                return True
    except Exception:
        pass
    return False


def _collect_driver_candidates(dir_path: str, current_depth: int = 0, max_depth: int = 2) -> List[str]:
    """Recursively collects driver package candidates or extracts from motherboard folders."""
    found = []
    if current_depth > max_depth or not os.path.isdir(dir_path):
        return found
    try:
        items = os.listdir(dir_path)
        subdirs = [
            os.path.join(dir_path, d) for d in items
            if os.path.isdir(os.path.join(dir_path, d))
            and d.lower() not in _IGNORED_DRIVER_DIR_NAMES
            and not d.startswith(".")
        ]

        # If this folder has direct installers, treat it as a driver package
        if _has_direct_installer(dir_path):
            found.append(dir_path)
            return found

        # If it has subdirectories (e.g. Motherboard folder with Audio, LAN, VGA...), explore them
        if subdirs:
            for sd in subdirs:
                found.extend(_collect_driver_candidates(sd, current_depth + 1, max_depth))
        else:
            # Leaf directory without direct installer: check if it has any INF/EXE files inside
            has_any_driver_file = False
            for _, _, files in os.walk(dir_path):
                if any(f.lower().endswith((".inf", ".exe", ".msi")) for f in files):
                    has_any_driver_file = True
                    break
            if has_any_driver_file:
                found.append(dir_path)
    except Exception as err:
        logger.warning(f"Error exploring {dir_path}: {err}")
    return found


def intelligent_scan_drivers(custom_dir: Optional[str] = None) -> Dict[str, Any]:
    """
    Performs intelligent discovery, inspection, hardware matching,
    and deduplication across the target driver directory.
    Automatically unpacks compressed archives (.zip, .rar, .7z) into dedicated subfolders.
    """
    global _cached_scan_result, _cached_packages_map, _cached_scan_time

    cfg = get_driver_directory_config()
    target_dir = os.path.abspath(custom_dir.strip()) if custom_dir and custom_dir.strip() else cfg["resolved_path"]

    # Fast path: return cached result if still fresh (within TTL) and same directory
    if (
        _cached_scan_result is not None
        and _cached_scan_result.get("driver_directory") == target_dir
        and (time.monotonic() - _cached_scan_time) < _SCAN_CACHE_TTL_SECONDS
    ):
        logger.debug("[IntelligentDriver] Returning cached scan result (TTL not expired).")
        return _cached_scan_result

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

    # 1. Automatically unpack any compressed archives (.zip, .rar, .7z)
    try:
        unpacked = auto_unpack_driver_archives(target_dir)
        if unpacked:
            logger.info(f"[IntelligentDriver] Unpacked {len(unpacked)} archive(s) into dedicated folders: {unpacked}")
    except Exception as e:
        logger.warning(f"[IntelligentDriver] Error during archive auto-unpacking: {e}")

    # 2. Discover candidate driver packages (folders and standalone installers)
    candidates: List[str] = []
    ignored_names = _IGNORED_DRIVER_DIR_NAMES

    try:
        # Check top-level items in target_dir
        for e in os.listdir(target_dir):
            if e.lower() in ignored_names or e.startswith("."):
                continue
            full = os.path.join(target_dir, e)
            if os.path.isdir(full):
                # May be a driver folder or a container folder (like Motherboard model)
                candidates.extend(_collect_driver_candidates(full, current_depth=0, max_depth=2))
            elif os.path.isfile(full):
                ext = os.path.splitext(e)[1].lower()
                if ext in (".exe", ".inf", ".msi"):
                    candidates.append(full)

        # Remove duplicate paths preserving order
        unique_candidates = []
        seen_cand = set()
        for c in candidates:
            c_norm = os.path.normcase(os.path.abspath(c))
            if c_norm not in seen_cand:
                seen_cand.add(c_norm)
                unique_candidates.append(c)
        candidates = unique_candidates

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
    _cached_scan_time = time.monotonic()

    return result


def start_intelligent_driver_install(
    package_ids: Optional[List[str]] = None,
    custom_dir: Optional[str] = None,
) -> Dict[str, Any]:
    """
    Validates selected packages and starts the 9-tier priority queue.
    If package_ids is omitted or empty, selects all installable recommended packages.
    """
    global _cached_scan_result, _cached_packages_map

    scan = intelligent_scan_drivers(custom_dir)
    if not scan.get("success") or not scan.get("packages"):
        return {"success": False, "message": scan.get("message", "هیچ درایور معتبری برای نصب یافت نشد.")}

    all_pkgs = scan["packages"]

    if package_ids:
        id_set = set(package_ids)
        target_pkgs = [p for p in all_pkgs if p.get("package_id") in id_set]
    else:
        target_pkgs = [
            p for p in all_pkgs
            if p.get("is_valid", True)
            and p.get("match", {}).get("recommendation") != "skip"
        ]
        # Robust fallback: if nothing met strict filter, take all valid packages
        if not target_pkgs:
            target_pkgs = [p for p in all_pkgs if p.get("is_valid", True)]

    if not target_pkgs:
        return {
            "success": False,
            "message": "هیچ بسته درایور معتبری برای نصب یافت نشد.",
        }

    return start_driver_queue(target_pkgs)


def launch_interactive_driver_installer(package_id: str, custom_dir: Optional[str] = None) -> Dict[str, Any]:
    """
    Launches a driver package's installer interactively for manual installation.
    If it's an EXE/MSI/Script, launches it elevated without silent flags so the setup UI appears.
    Also starts InstallerAutoPilot in background to automatically handle dialogs.
    """
    global _cached_packages_map
    if not _cached_packages_map or package_id not in _cached_packages_map:
        intelligent_scan_drivers(custom_dir)

    pkg = _cached_packages_map.get(package_id)
    if not pkg:
        return {"success": False, "message": f"بسته درایور با شناسه {package_id} یافت نشد."}

    installer_path = pkg.get("installer_path") or pkg.get("installer_file") or pkg.get("source_path")
    if not installer_path or not os.path.exists(installer_path):
        return {"success": False, "message": f"فایل نصبی یافت نشد: {installer_path}"}

    working_dir = os.path.dirname(installer_path) if os.path.isfile(installer_path) else installer_path
    method = pkg.get("install_method", "setup_exe")
    display_name = pkg.get("display_name", "Driver Package")

    try:
        from packages.manager import _launch_elevated
        from packages.auto_wizard import InstallerAutoPilot

        # Start auto-pilot in background to assist with Language/OK/Next/Begin Install dialogs
        try:
            autopilot = InstallerAutoPilot(
                target_title_keywords=[display_name, os.path.basename(installer_path), "intel", "graphics", "driver"],
                timeout_seconds=90,
            )
            autopilot.run_in_background()
        except Exception:
            pass

        if method == "msiexec":
            sys_root = os.environ.get("SystemRoot", r"C:\Windows")
            msi_exe = os.path.join(sys_root, "System32", "msiexec.exe")
            ok, code, err = _launch_elevated(msi_exe, f'/i "{installer_path}"', working_dir)
        elif method == "pnputil":
            cmd_args = f'/c pnputil /add-driver "{installer_path}" /install & pause'
            ok, code, err = _launch_elevated("cmd.exe", cmd_args, working_dir)
        elif method == "script":
            ok, code, err = _launch_elevated("cmd.exe", f'/c "{installer_path}"', working_dir)
        else:
            # Standalone or vendor setup EXE
            ok, code, err = _launch_elevated(installer_path, "", working_dir)

        if ok:
            return {"success": True, "message": f"پنجره نصاب دستی «{display_name}» با موفقیت باز شد."}
        else:
            return {"success": False, "message": f"خطا در باز کردن نصاب: {err} (کد: {code})"}
    except Exception as e:
        return {"success": False, "message": f"خطا در اجرای نصاب: {str(e)}"}


def open_driver_package_folder(package_id: str, custom_dir: Optional[str] = None) -> Dict[str, Any]:
    """Opens Windows Explorer focused on the driver's folder."""
    global _cached_packages_map
    if not _cached_packages_map or package_id not in _cached_packages_map:
        intelligent_scan_drivers(custom_dir)

    pkg = _cached_packages_map.get(package_id)
    if not pkg:
        return {"success": False, "message": "بسته درایور یافت نشد."}

    path = pkg.get("source_path") or pkg.get("installer_file")
    if not path or not os.path.exists(path):
        return {"success": False, "message": f"مسیر درایور یافت نشد: {path}"}

    try:
        if os.path.isfile(path):
            subprocess.Popen(["explorer.exe", f"/select,{os.path.abspath(path)}"])
        else:
            subprocess.Popen(["explorer.exe", os.path.abspath(path)])
        return {"success": True, "message": "پوشه درایور باز شد."}
    except Exception as e:
        return {"success": False, "message": f"خطا در باز کردن پوشه: {str(e)}"}


# ---------------------------------------------------------------------------
# Backwards Compatibility Wrappers for existing API endpoints
# ---------------------------------------------------------------------------

def scan_driver_folder(folder_path: str) -> Dict[str, Any]:
    """Legacy compatibility wrapper for /api/drivers/scan-folder."""
    scan = intelligent_scan_drivers(custom_dir=folder_path)
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
