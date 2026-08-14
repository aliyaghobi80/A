# backend/packages/manager.py
"""
Software Package & Executable Scanner & Interactive Installer
Recursively discovers ALL .exe files inside the configured package directory,
extracts Windows binary metadata (ProductName, FileDescription, Publisher, Version),
extracts executable application icons, checks installation status against Windows registry (HKLM & HKCU),
and launches installers interactively so employees can customize installation paths and options.
"""

import os
import sys
import json
import ctypes
import struct
import logging
import winreg
import subprocess
from typing import Dict, Any, List, Optional

logger = logging.getLogger(__name__)

# Repository / Base Directory
REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__)))))
CONFIG_FILE = os.path.join(REPO_ROOT, "config", "software_directory.json")


def _format_file_size(bytes_val: int) -> str:
    """Formats file size into human-readable B, KB, MB, or GB."""
    if bytes_val < 1024:
        return f"{bytes_val} B"
    elif bytes_val < 1024 * 1024:
        return f"{bytes_val / 1024:.1f} KB"
    elif bytes_val < 1024 * 1024 * 1024:
        return f"{bytes_val / (1024 * 1024):.1f} MB"
    else:
        return f"{bytes_val / (1024 * 1024 * 1024):.2f} GB"


def get_packages_directory(custom_path: Optional[str] = None) -> str:
    """
    Resolves the configured Packages root directory.
    Priority:
    1. Custom path if provided
    2. Config file config/software_directory.json
    3. Default relative 'Packages' folder inside workspace
    4. Auto-detect removable USB drive (e.g. E:\\Packages, D:\\Packages)
    """
    if custom_path and custom_path.strip():
        req_path = custom_path.strip()
        if not os.path.isabs(req_path):
            req_path = os.path.abspath(os.path.join(REPO_ROOT, req_path))
        return req_path

    # Read config file
    if os.path.isfile(CONFIG_FILE):
        try:
            with open(CONFIG_FILE, "r", encoding="utf-8") as f:
                cfg = json.load(f)
                root_setting = cfg.get("packageRoot", "Packages").strip()
                if root_setting:
                    if not os.path.isabs(root_setting):
                        resolved = os.path.abspath(os.path.join(REPO_ROOT, root_setting))
                    else:
                        resolved = os.path.abspath(root_setting)
                    if os.path.isdir(resolved):
                        return resolved
        except Exception as e:
            logger.warning(f"Error reading software_directory.json: {e}")

    # Default workspace Packages folder
    default_dir = os.path.abspath(os.path.join(REPO_ROOT, "Packages"))
    if os.path.isdir(default_dir):
        return default_dir

    # Check removable USB drives
    for drive in ["D", "E", "F", "G", "H", "I", "U"]:
        usb_dir = f"{drive}:\\Packages"
        if os.path.isdir(usb_dir):
            logger.info(f"Auto-detected Packages directory on removable drive: {usb_dir}")
            return usb_dir

def get_package_icon_path(package_id: str, custom_dir: Optional[str] = None) -> Optional[str]:
    """Returns local icon path if present for given package id."""
    data = scan_packages(custom_dir)
    for pkg in data.get("packages", []):
        if pkg.get("id") == package_id or pkg.get("filename") == package_id:
            full_path = pkg.get("full_path", "")
            folder = os.path.dirname(full_path)
            for ico_name in ["app.ico", "icon.ico", "app.png", "icon.png"]:
                candidate = os.path.join(folder, ico_name)
                if os.path.isfile(candidate):
                    return candidate
    return None


def _is_safe_path(base_dir: str, target_path: str) -> bool:
    """Ensures target_path is strictly within base_dir without path traversal."""
    try:
        abs_base = os.path.abspath(base_dir)
        abs_target = os.path.abspath(target_path)
        return os.path.commonpath([abs_base]) == os.path.commonpath([abs_base, abs_target])
    except Exception:
        return False


def get_all_installed_registry_apps() -> List[Dict[str, str]]:
    """
    Comprehensive scan of installed Windows applications across:
    - HKLM 64-bit Uninstall
    - HKLM 32-bit Uninstall (WOW6432Node)
    - HKCU User-level Uninstall (e.g. Electro, Chrome User, VS Code, Discord)
    """
    results: List[Dict[str, str]] = []
    roots = [
        (winreg.HKEY_LOCAL_MACHINE, r"Software\Microsoft\Windows\CurrentVersion\Uninstall", winreg.KEY_WOW64_64KEY),
        (winreg.HKEY_LOCAL_MACHINE, r"Software\Microsoft\Windows\CurrentVersion\Uninstall", winreg.KEY_WOW64_32KEY),
        (winreg.HKEY_CURRENT_USER, r"Software\Microsoft\Windows\CurrentVersion\Uninstall", 0),
    ]

    seen_names = set()

    for root_hive, subkey, flags in roots:
        try:
            with winreg.OpenKey(root_hive, subkey, 0, winreg.KEY_READ | flags) as key:
                num_subkeys, _, _ = winreg.QueryInfoKey(key)
                for i in range(num_subkeys):
                    try:
                        kname = winreg.EnumKey(key, i)
                        with winreg.OpenKey(key, kname) as app_key:
                            def get_val(vname):
                                try:
                                    v, _ = winreg.QueryValueEx(app_key, vname)
                                    return str(v).strip()
                                except Exception:
                                    return ""

                            dname = get_val("DisplayName")
                            if not dname:
                                continue

                            # Normalize key for deduplication
                            norm = dname.lower().strip()
                            if norm in seen_names:
                                continue
                            seen_names.add(norm)

                            dver = get_val("DisplayVersion")
                            dpub = get_val("Publisher")
                            dloc = get_val("InstallLocation")
                            dexe = get_val("DisplayIcon")

                            results.append({
                                "name": dname,
                                "version": dver or "Not available",
                                "publisher": dpub,
                                "location": dloc,
                                "icon": dexe,
                            })
                    except Exception:
                        pass
        except Exception:
            pass

    return results


def _extract_exe_metadata(file_path: str) -> Dict[str, str]:
    """
    Extracts Windows binary VersionInfo metadata from an .exe:
    - ProductName
    - FileDescription
    - CompanyName / Publisher
    - ProductVersion / FileVersion
    - OriginalFilename
    """
    filename_no_ext = os.path.splitext(os.path.basename(file_path))[0]
    meta = {
        "product_name": "",
        "file_description": "",
        "publisher": "",
        "version": "",
        "original_filename": "",
        "display_name": filename_no_ext,
    }

    try:
        size = ctypes.windll.version.GetFileVersionInfoSizeW(file_path, None)
        if not size:
            return meta

        buf = ctypes.create_string_buffer(size)
        if not ctypes.windll.version.GetFileVersionInfoW(file_path, 0, size, buf):
            return meta

        # Find translation codepage
        trans_ptr = ctypes.c_void_p()
        trans_len = ctypes.c_uint()
        trans_str = "040904b0"  # English US fallback

        if ctypes.windll.version.VerQueryValueW(buf, r"\VarFileInfo\Translation", ctypes.byref(trans_ptr), ctypes.byref(trans_len)) and trans_len.value >= 4:
            trans_data = ctypes.string_at(trans_ptr, 4)
            lang, codepage = struct.unpack("<HH", trans_data)
            trans_str = f"{lang:04x}{codepage:04x}"

        def query_key(key: str) -> str:
            ptr = ctypes.c_void_p()
            length = ctypes.c_uint()
            sub_block = f"\\StringFileInfo\\{trans_str}\\{key}"
            if ctypes.windll.version.VerQueryValueW(buf, sub_block, ctypes.byref(ptr), ctypes.byref(length)) and ptr.value:
                val = ctypes.wstring_at(ptr).strip()
                if val:
                    return val
            sub_block_en = f"\\StringFileInfo\\040904b0\\{key}"
            if ctypes.windll.version.VerQueryValueW(buf, sub_block_en, ctypes.byref(ptr), ctypes.byref(length)) and ptr.value:
                val = ctypes.wstring_at(ptr).strip()
                if val:
                    return val
            return ""

        prod_name = query_key("ProductName")
        file_desc = query_key("FileDescription")
        company = query_key("CompanyName")
        prod_ver = query_key("ProductVersion") or query_key("FileVersion")
        orig_file = query_key("OriginalFilename")

        meta["product_name"] = prod_name
        meta["file_description"] = file_desc
        meta["publisher"] = company
        meta["version"] = prod_ver
        meta["original_filename"] = orig_file

        is_generic_os = "operating system" in prod_name.lower() or "windows(r)" in prod_name.lower()

        if file_desc and not is_generic_os:
            meta["display_name"] = file_desc
        elif prod_name and not is_generic_os:
            meta["display_name"] = prod_name
        elif file_desc:
            meta["display_name"] = file_desc
        else:
            cleaned = filename_no_ext.replace("_", " ").replace("-", " ")
            meta["display_name"] = cleaned.strip()

    except Exception as e:
        logger.debug(f"Error extracting metadata from {file_path}: {e}")

    return meta


def _extract_icons_batch(file_paths: List[str]) -> Dict[str, Optional[str]]:
    """
    Extracts embedded icons for a batch of .exe files using a single PowerShell invocation.
    Returns mapping of file_path -> base64 data URI string.
    """
    results: Dict[str, Optional[str]] = {p: None for p in file_paths}
    if not file_paths:
        return results

    # Check for local icon files first
    remaining_paths = []
    for path in file_paths:
        folder = os.path.dirname(path)
        found = False
        for ico_name in ["app.ico", "icon.ico", "app.png", "icon.png"]:
            candidate = os.path.join(folder, ico_name)
            if os.path.isfile(candidate):
                try:
                    import base64
                    with open(candidate, "rb") as f:
                        data = f.read()
                    ext = os.path.splitext(candidate)[1].lower().replace(".", "")
                    mime = "image/x-icon" if ext == "ico" else f"image/{ext}"
                    results[path] = f"data:{mime};base64,{base64.b64encode(data).decode('utf-8')}"
                    found = True
                    break
                except Exception:
                    pass
        if not found:
            remaining_paths.append(path)

    if not remaining_paths:
        return results

    # Batch PowerShell extraction for remaining files
    try:
        paths_json = json.dumps(remaining_paths)
        ps_script = f"""
Add-Type -AssemblyName System.Drawing
$paths = ConvertFrom-Json @'
{paths_json}
'@
$res = @{{}}
foreach ($p in $paths) {{
    try {{
        if (Test-Path $p) {{
            $icon = [System.Drawing.Icon]::ExtractAssociatedIcon($p)
            if ($icon) {{
                $ms = New-Object System.IO.MemoryStream
                $bmp = $icon.ToBitmap()
                $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
                $res[$p] = [Convert]::ToBase64String($ms.ToArray())
                $bmp.Dispose()
                $icon.Dispose()
                $ms.Dispose()
            }}
        }}
    }} catch {{}}
}}
$res | ConvertTo-Json -Compress
"""
        proc = subprocess.run(
            ["powershell.exe", "-NoProfile", "-NonInteractive", "-Command", ps_script],
            capture_output=True,
            text=True,
            timeout=8
        )
        out = proc.stdout.strip()
        if out:
            extracted_map = json.loads(out)
            if isinstance(extracted_map, dict):
                for p, b64 in extracted_map.items():
                    if b64:
                        results[p] = f"data:image/png;base64,{b64}"
    except Exception as e:
        logger.debug(f"Batch icon extraction error: {e}")

    return results


def _clean_software_keywords(text: str) -> List[str]:
    """Generates search keywords from an app name or filename (e.g. 'Electro Setup' -> ['electro setup', 'electro'])."""
    t = text.lower().replace(".exe", "").replace("-", " ").replace("_", " ").strip()
    words = t.split()
    keywords = [t]
    cleaned = t.replace("setup", "").replace("installer", "").replace("x64", "").replace("x86", "").strip()
    if cleaned and cleaned != t:
        keywords.append(cleaned)
    if words:
        keywords.append(words[0])
    return [k for k in keywords if len(k) >= 3]


def scan_packages(custom_dir: Optional[str] = None) -> Dict[str, Any]:
    """
    Recursively scans the configured Packages directory for ALL .exe files.
    Extracts metadata, icons, file size, and detects installed status & version.
    """
    pkg_dir = get_packages_directory(custom_dir)
    dir_exists = os.path.isdir(pkg_dir)

    if not dir_exists:
        return {
            "directory_exists": False,
            "packages_directory": pkg_dir,
            "packages": [],
            "summary": {
                "total_packages": 0,
                "valid_packages": 0,
                "installed_packages": 0,
                "available_to_install": 0,
            }
        }

    # Fetch ALL installed applications from Windows Registry (HKLM & HKCU)
    installed_apps = get_all_installed_registry_apps()

    discovered_files: List[Dict[str, Any]] = []
    seen_paths = set()

    for root, _, files in os.walk(pkg_dir):
        for file in files:
            # Case-insensitive .exe matching
            if not file.lower().endswith(".exe"):
                continue

            full_path = os.path.abspath(os.path.join(root, file))
            if full_path in seen_paths:
                continue
            seen_paths.add(full_path)

            if not _is_safe_path(pkg_dir, full_path):
                continue

            rel_path = os.path.relpath(full_path, pkg_dir).replace("\\", "/")
            file_size = os.path.getsize(full_path) if os.path.isfile(full_path) else 0

            discovered_files.append({
                "file": file,
                "full_path": full_path,
                "root": root,
                "rel_path": rel_path,
                "file_size": file_size,
            })

    # Batch extract icons
    all_paths = [df["full_path"] for df in discovered_files]
    icons_map = _extract_icons_batch(all_paths)

    packages: List[Dict[str, Any]] = []

    for df in discovered_files:
        file = df["file"]
        full_path = df["full_path"]
        root = df["root"]
        rel_path = df["rel_path"]
        file_size = df["file_size"]

        # Extract binary metadata
        meta = _extract_exe_metadata(full_path)
        display_name = meta["display_name"]
        version = meta["version"] or ""
        publisher = meta["publisher"]
        product_name = meta["product_name"] or display_name

        # Check for optional package.json overrides
        manifest_path = os.path.join(root, "package.json")
        silent_args = ""
        detection_id = None

        if os.path.isfile(manifest_path):
            try:
                with open(manifest_path, "r", encoding="utf-8") as mf:
                    manifest = json.load(mf)
                    if isinstance(manifest, dict):
                        if manifest.get("name"):
                            display_name = manifest["name"]
                        if manifest.get("version"):
                            version = manifest["version"]
                        if manifest.get("publisher"):
                            publisher = manifest["publisher"]
                        if manifest.get("silentArguments"):
                            silent_args = manifest["silentArguments"]
                        if manifest.get("detectionId"):
                            detection_id = manifest["detectionId"]
            except Exception:
                pass

        pkg_id = os.path.splitext(file)[0].lower().replace(" ", "_")
        icon_data = icons_map.get(full_path)

        # Match against installed applications (Registry search)
        is_installed = False
        installed_version = ""
        installed_exe_path = None
        search_terms = _clean_software_keywords(display_name) + _clean_software_keywords(file) + _clean_software_keywords(product_name)
        if detection_id:
            search_terms.insert(0, detection_id.lower())

        for term in search_terms:
            if not term:
                continue
            for app in installed_apps:
                app_name_lower = app["name"].lower()
                # Exact or substring match
                if term == app_name_lower or term in app_name_lower or app_name_lower in term:
                    is_installed = True
                    if app.get("version") and app["version"] != "Not available":
                        installed_version = app["version"]

                    # Extract executable path
                    icon_val = app.get("icon", "")
                    if icon_val:
                        clean_ico = icon_val.split(",")[0].strip('"').strip()
                        if clean_ico.lower().endswith(".exe") and os.path.isfile(clean_ico):
                            installed_exe_path = clean_ico

                    if not installed_exe_path:
                        loc = app.get("location", "").strip('"').strip()
                        if loc and os.path.isdir(loc):
                            for f in os.listdir(loc):
                                if f.lower().endswith(".exe"):
                                    cand = os.path.join(loc, f)
                                    if os.path.isfile(cand):
                                        installed_exe_path = cand
                                        break
                    break
            if is_installed:
                break

        # Fallback version from installer metadata if not found in registry
        if not installed_version and version:
            installed_version = version

        status = "Installed" if is_installed else "Not Installed"

        packages.append({
            "id": pkg_id,
            "name": display_name,
            "filename": file,
            "relative_path": rel_path,
            "full_path": full_path,
            "version": version or installed_version or "Unknown",
            "publisher": publisher,
            "file_size_bytes": file_size,
            "file_size_display": _format_file_size(file_size),
            "is_valid": True,
            "validation_error": None,
            "status": status,
            "is_installed": is_installed,
            "installed_version": installed_version if is_installed else "Not available",
            "installed_exe_path": installed_exe_path,
            "install_allowed": not is_installed,
            "has_icon": icon_data is not None,
            "icon_base64": icon_data,
            "silent_arguments": silent_args,
        })

    # Sort alphabetically by display name
    packages.sort(key=lambda p: p["name"].lower())

    total_packages = len(packages)
    installed_packages = len([p for p in packages if p.get("is_installed")])
    available_to_install = len([p for p in packages if p.get("install_allowed")])

    return {
        "directory_exists": True,
        "packages_directory": pkg_dir,
        "packages": packages,
        "summary": {
            "total_packages": total_packages,
            "valid_packages": total_packages,
            "installed_packages": installed_packages,
            "available_to_install": available_to_install,
        }
    }


def install_package(target_identifier: str, custom_dir: Optional[str] = None) -> Dict[str, Any]:
    """
    Launches the selected .exe installer with Administrator privileges (Run as Administrator).
    Returns immediately so the employee can interact with the installer wizard.
    """
    data = scan_packages(custom_dir)
    if not data.get("directory_exists"):
        return {
            "success": False,
            "message": "Software directory not found.",
            "exit_code": -1,
        }

    target_pkg = None
    target_id_clean = target_identifier.strip().replace("\\", "/").lower()

    for pkg in data.get("packages", []):
        p_id = pkg.get("id", "").lower()
        p_rel = pkg.get("relative_path", "").lower()
        p_file = pkg.get("filename", "").lower()
        if target_id_clean in [p_id, p_rel, p_file]:
            target_pkg = pkg
            break

    if not target_pkg:
        return {
            "success": False,
            "message": f"Executable '{target_identifier}' not found in Packages directory.",
            "exit_code": -1,
        }

    full_path = target_pkg.get("full_path")
    pkg_dir = data.get("packages_directory")

    # Security check: must reside inside packages_directory
    if not _is_safe_path(pkg_dir, full_path) or not os.path.isfile(full_path):
        return {
            "success": False,
            "message": f"Security violation or invalid file path: {full_path}",
            "exit_code": -1,
        }

    abs_path = os.path.abspath(full_path)
    working_dir = os.path.dirname(abs_path)
    logger.info(f"Launching installer as Administrator: {abs_path} in {working_dir}")

    launched = False
    launch_err = ""

    # Method 1: Win32 ShellExecuteW with verb 'runas' (Triggers Windows UAC & Run as Administrator)
    try:
        ret = ctypes.windll.shell32.ShellExecuteW(None, "runas", abs_path, "", working_dir, 1)
        if ret > 32:
            launched = True
            logger.info(f"ShellExecuteW runas successful (code {ret}) for {abs_path}")
        else:
            launch_err = f"ShellExecute error code: {ret}"
    except Exception as e:
        launch_err = str(e)
        logger.warning(f"ShellExecuteW runas exception: {e}")

    # Method 2: os.startfile with 'runas'
    if not launched:
        try:
            os.startfile(abs_path, "runas")
            launched = True
            logger.info(f"os.startfile runas successful for {abs_path}")
        except Exception as e:
            launch_err = str(e)
            logger.warning(f"os.startfile runas exception: {e}")

    # Method 3: PowerShell Start-Process -Verb RunAs
    if not launched:
        try:
            ps_cmd = f'Start-Process -FilePath "{abs_path}" -WorkingDirectory "{working_dir}" -Verb RunAs'
            proc = subprocess.run(["powershell.exe", "-NoProfile", "-Command", ps_cmd], capture_output=True, timeout=5)
            if proc.returncode == 0:
                launched = True
                logger.info(f"PowerShell Start-Process -Verb RunAs successful for {abs_path}")
            else:
                launch_err = proc.stderr.strip() or f"PowerShell exit code: {proc.returncode}"
        except Exception as e:
            launch_err = str(e)
            logger.warning(f"PowerShell RunAs exception: {e}")

    # Method 4: Fallback standard subprocess.Popen
    if not launched:
        try:
            subprocess.Popen([abs_path], cwd=working_dir)
            launched = True
            logger.info(f"Standard subprocess.Popen successful for {abs_path}")
        except Exception as e:
            launch_err = str(e)
            logger.warning(f"Standard subprocess.Popen exception: {e}")

    if launched:
        return {
            "success": True,
            "launched": True,
            "package_id": target_pkg.get("id"),
            "name": target_pkg.get("name"),
            "message": f"پنجره نصب {target_pkg.get('name')} با دسترسی مدیر (Run as Administrator) باز شد.",
        }
    else:
        return {
            "success": False,
            "launched": False,
            "message": f"خطا در اجرای برنامه با دسترسی مدیر: {launch_err}",
            "exit_code": -3,
        }


def open_package(target_identifier: str, custom_dir: Optional[str] = None) -> Dict[str, Any]:
    """
    Opens/launches the installed application on Windows.
    """
    data = scan_packages(custom_dir)
    target_pkg = None
    target_id_clean = target_identifier.strip().replace("\\", "/").lower()

    for pkg in data.get("packages", []):
        p_id = pkg.get("id", "").lower()
        p_rel = pkg.get("relative_path", "").lower()
        p_file = pkg.get("filename", "").lower()
        p_name = pkg.get("name", "").lower()
        if target_id_clean in [p_id, p_rel, p_file, p_name]:
            target_pkg = pkg
            break

    if not target_pkg:
        return {"success": False, "message": f"برنامه {target_identifier} یافت نشد."}

    exe_path = target_pkg.get("installed_exe_path")
    if exe_path and os.path.isfile(exe_path):
        work_dir = os.path.dirname(exe_path)
        try:
            ret = ctypes.windll.shell32.ShellExecuteW(None, "open", exe_path, "", work_dir, 1)
            if ret > 32:
                return {"success": True, "message": f"برنامه {target_pkg.get('name')} با موفقیت باز شد."}
        except Exception:
            pass

        try:
            os.startfile(exe_path)
            return {"success": True, "message": f"برنامه {target_pkg.get('name')} با موفقیت باز شد."}
        except Exception:
            pass

    return {"success": False, "message": "مسیر فایل اجرایی نرم‌افزار نصب‌شده یافت نشد."}


