# backend/packages/manager.py
"""
Software Package System & Manifest Manager
Scans the designated Packages directory, validates package.json manifests,
verifies installer existence, prevents path traversal, detects install status,
and provides safe execution of company software packages.
"""

import os
import sys
import json
import logging
import subprocess
from typing import Dict, Any, List, Optional
from software.detector import detect_required_software

logger = logging.getLogger(__name__)

# Default base directory for packages
DEFAULT_PACKAGES_DIR = os.path.abspath(
    os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "Packages")
)


def get_packages_directory(custom_path: Optional[str] = None) -> str:
    """
    Returns the active Packages directory.
    Checks:
    1. Custom requested path
    2. Default local 'Packages/' folder
    3. Removable USB drives (e.g., E:\\Packages, F:\\Packages, D:\\Packages)
    """
    if custom_path and os.path.isdir(custom_path):
        return os.path.abspath(custom_path)

    if os.path.isdir(DEFAULT_PACKAGES_DIR):
        return DEFAULT_PACKAGES_DIR

    # Check potential removable drive letters
    for drive in ["D", "E", "F", "G", "H", "I", "U"]:
        usb_pkg_dir = f"{drive}:\\Packages"
        if os.path.isdir(usb_pkg_dir):
            logger.info(f"Auto-detected Packages directory on USB drive: {usb_pkg_dir}")
            return usb_pkg_dir

    return DEFAULT_PACKAGES_DIR


def _is_safe_relative_path(base_dir: str, rel_path: str) -> bool:
    """
    Ensures rel_path is strictly within base_dir and does not escape via '..' or absolute paths.
    """
    if not rel_path or os.path.isabs(rel_path):
        return False
    target = os.path.abspath(os.path.join(base_dir, rel_path))
    return os.path.commonpath([base_dir]) == os.path.commonpath([base_dir, target])


def scan_packages(custom_dir: Optional[str] = None) -> Dict[str, Any]:
    """
    Scans the Packages directory for valid package folders.
    Validates manifest and checks installer existence.
    Matches with currently installed software to set install status.
    """
    pkg_dir = get_packages_directory(custom_dir)
    packages: List[Dict[str, Any]] = []

    if not os.path.isdir(pkg_dir):
        try:
            os.makedirs(pkg_dir, exist_ok=True)
        except Exception as e:
            logger.warning(f"Could not create Packages dir: {e}")

    # Fetch currently detected installed software for matching
    installed_software_data = detect_required_software()
    installed_items = installed_software_data.get("items", [])
    installed_lookup = {
        item.get("id", "").lower(): item
        for item in installed_items
    }
    # Also index by name for fuzzy lookup
    name_lookup = {
        item.get("name", "").lower(): item
        for item in installed_items
    }

    if os.path.isdir(pkg_dir):
        for entry in sorted(os.listdir(pkg_dir)):
            sub_path = os.path.join(pkg_dir, entry)
            if not os.path.isdir(sub_path):
                continue

            manifest_path = os.path.join(sub_path, "package.json")
            if not os.path.isfile(manifest_path):
                # Folder has no package.json -> invalid / ignored package folder
                continue

            try:
                with open(manifest_path, "r", encoding="utf-8") as f:
                    manifest = json.load(f)
            except Exception as e:
                packages.append({
                    "id": entry.lower(),
                    "name": entry,
                    "version": "Unknown",
                    "publisher": "Unknown",
                    "package_folder": entry,
                    "is_valid": False,
                    "validation_error": f"Invalid JSON format in package.json: {str(e)}",
                    "status": "Unknown",
                    "is_installed": False,
                    "install_allowed": False,
                    "icon_url": None,
                })
                continue

            # Validate required manifest schema
            pkg_id = str(manifest.get("id") or entry).strip().lower()
            pkg_name = str(manifest.get("name") or entry).strip()
            pkg_ver = str(manifest.get("version") or "1.0").strip()
            pkg_publisher = str(manifest.get("publisher") or "").strip()
            installer_rel = str(manifest.get("installer") or "").strip()
            icon_rel = str(manifest.get("icon") or "").strip()
            silent_args = str(manifest.get("silentArguments") or "").strip()
            detection_id = str(manifest.get("detectionId") or pkg_id).strip().lower()

            if not installer_rel:
                packages.append({
                    "id": pkg_id,
                    "name": pkg_name,
                    "version": pkg_ver,
                    "publisher": pkg_publisher,
                    "package_folder": entry,
                    "is_valid": False,
                    "validation_error": "Missing 'installer' field in package.json",
                    "status": "Unknown",
                    "is_installed": False,
                    "install_allowed": False,
                    "icon_url": None,
                })
                continue

            # Security: Validate installer does not traverse outside package folder
            if not _is_safe_relative_path(sub_path, installer_rel):
                packages.append({
                    "id": pkg_id,
                    "name": pkg_name,
                    "version": pkg_ver,
                    "publisher": pkg_publisher,
                    "package_folder": entry,
                    "is_valid": False,
                    "validation_error": f"Security violation: installer path '{installer_rel}' escapes package directory",
                    "status": "Unknown",
                    "is_installed": False,
                    "install_allowed": False,
                    "icon_url": None,
                })
                continue

            installer_abs = os.path.abspath(os.path.join(sub_path, installer_rel))
            installer_exists = os.path.isfile(installer_abs)

            if not installer_exists:
                packages.append({
                    "id": pkg_id,
                    "name": pkg_name,
                    "version": pkg_ver,
                    "publisher": pkg_publisher,
                    "package_folder": entry,
                    "installer_file": installer_rel,
                    "is_valid": False,
                    "validation_error": f"Installer file '{installer_rel}' not found in package directory",
                    "status": "Unknown",
                    "is_installed": False,
                    "install_allowed": False,
                    "icon_url": None,
                })
                continue

            # Check icon
            has_icon = False
            if icon_rel and _is_safe_relative_path(sub_path, icon_rel):
                icon_abs = os.path.abspath(os.path.join(sub_path, icon_rel))
                if os.path.isfile(icon_abs):
                    has_icon = True

            # Match with installed software
            matched_item = installed_lookup.get(detection_id) or name_lookup.get(pkg_name.lower())
            is_installed = False
            installed_version = "Not available"
            status = "Not Installed"

            if matched_item:
                is_installed = bool(matched_item.get("is_installed", False))
                installed_version = matched_item.get("version", "Not available")
                status = "Installed" if is_installed else "Not Installed"
            else:
                # If not in required list, check if name matches any detected product
                for item in installed_items:
                    if pkg_name.lower() in item.get("display_name", "").lower():
                        is_installed = bool(item.get("is_installed", False))
                        installed_version = item.get("version", "Not available")
                        status = "Installed" if is_installed else "Not Installed"
                        break

            packages.append({
                "id": pkg_id,
                "name": pkg_name,
                "version": pkg_ver,
                "publisher": pkg_publisher,
                "detection_id": detection_id,
                "package_folder": entry,
                "installer_file": installer_rel,
                "silent_arguments": silent_args,
                "is_valid": True,
                "validation_error": None,
                "status": status,
                "is_installed": is_installed,
                "installed_version": installed_version,
                "install_allowed": (not is_installed) and installer_exists,
                "has_icon": has_icon,
                "icon_url": f"/api/packages/icon?id={pkg_id}" if has_icon else None,
                "package_path": sub_path,
            })

    # Summary
    total_packages = len(packages)
    valid_packages = len([p for p in packages if p.get("is_valid")])
    installed_packages = len([p for p in packages if p.get("is_installed")])
    available_to_install = len([p for p in packages if p.get("install_allowed")])

    return {
        "packages_directory": pkg_dir,
        "packages": packages,
        "summary": {
            "total_packages": total_packages,
            "valid_packages": valid_packages,
            "installed_packages": installed_packages,
            "available_to_install": available_to_install,
        }
    }


def get_package_icon_path(package_id: str, custom_dir: Optional[str] = None) -> Optional[str]:
    """
    Resolves the absolute path to the package icon if available.
    """
    pkg_dir = get_packages_directory(custom_dir)
    if not os.path.isdir(pkg_dir):
        return None

    for entry in os.listdir(pkg_dir):
        sub_path = os.path.join(pkg_dir, entry)
        if not os.path.isdir(sub_path):
            continue

        manifest_path = os.path.join(sub_path, "package.json")
        if not os.path.isfile(manifest_path):
            continue

        try:
            with open(manifest_path, "r", encoding="utf-8") as f:
                manifest = json.load(f)
            pkg_id = str(manifest.get("id") or entry).strip().lower()
            if pkg_id == package_id.strip().lower():
                icon_rel = str(manifest.get("icon") or "").strip()
                if icon_rel and _is_safe_relative_path(sub_path, icon_rel):
                    icon_abs = os.path.abspath(os.path.join(sub_path, icon_rel))
                    if os.path.isfile(icon_abs):
                        return icon_abs
        except Exception:
            continue

    return None


def install_package(package_id: str, custom_dir: Optional[str] = None) -> Dict[str, Any]:
    """
    Safely executes the installer for a validated package.
    Only allows installers within the package directory.
    Waits for process completion, re-detects installed software, and returns result.
    """
    data = scan_packages(custom_dir)
    target_pkg = None

    for pkg in data.get("packages", []):
        if pkg.get("id") == package_id.strip().lower():
            target_pkg = pkg
            break

    if not target_pkg:
        return {
            "success": False,
            "message": f"Package with ID '{package_id}' not found in Packages directory.",
            "exit_code": -1,
        }

    if not target_pkg.get("is_valid"):
        return {
            "success": False,
            "message": f"Cannot install invalid package: {target_pkg.get('validation_error')}",
            "exit_code": -1,
        }

    pkg_dir = target_pkg.get("package_path")
    installer_rel = target_pkg.get("installer_file")
    installer_abs = os.path.abspath(os.path.join(pkg_dir, installer_rel))

    if not os.path.isfile(installer_abs):
        return {
            "success": False,
            "message": f"Installer file does not exist: {installer_abs}",
            "exit_code": -1,
        }

    silent_args = target_pkg.get("silent_arguments", "").strip()
    cmd = [installer_abs]
    if silent_args:
        cmd.extend(silent_args.split())

    logger.info(f"Executing installer for {target_pkg.get('name')}: {cmd} in {pkg_dir}")

    try:
        # Run installer with working directory set to package folder
        proc = subprocess.run(
            cmd,
            cwd=pkg_dir,
            capture_output=True,
            text=True,
            timeout=300  # 5 min max for installer
        )

        exit_code = proc.returncode
        success = (exit_code == 0)

        # Re-scan installed software
        rescan_data = scan_packages(custom_dir)

        return {
            "success": success,
            "exit_code": exit_code,
            "message": "Installation process completed." if success else f"Installer exited with code {exit_code}.",
            "packages_result": rescan_data,
        }
    except subprocess.TimeoutExpired:
        return {
            "success": False,
            "message": "Installation timed out after 5 minutes.",
            "exit_code": -2,
        }
    except Exception as e:
        logger.error(f"Error executing installer: {e}")
        return {
            "success": False,
            "message": f"Failed to execute installer: {str(e)}",
            "exit_code": -3,
        }
