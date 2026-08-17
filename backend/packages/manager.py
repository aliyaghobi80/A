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
from ctypes import wintypes
import struct
import logging
import winreg
import subprocess
from typing import Dict, Any, List, Optional

from utils.powershell import get_hidden_subprocess_kwargs

logger = logging.getLogger(__name__)

def _find_repo_root() -> str:
    """Finds the root repository folder containing config/ and Packages/."""
    if getattr(sys, 'frozen', False):
        exe_dir = os.path.dirname(os.path.abspath(sys.executable))
        if os.path.basename(exe_dir).lower() == "backend":
            return os.path.dirname(exe_dir)
        return exe_dir

    curr = os.path.abspath(os.path.dirname(os.path.dirname(os.path.dirname(__file__))))
    candidates = [
        curr,
        os.getcwd(),
        os.path.abspath(os.path.join(curr, "..", "..", "..")),
        os.path.abspath(os.path.join(curr, "..", "..")),
        os.path.abspath(os.path.join(curr, "..")),
    ]
    for c in candidates:
        if os.path.isdir(os.path.join(c, "Packages")) or os.path.isdir(os.path.join(c, "config")):
            return c
    return curr

REPO_ROOT = _find_repo_root()
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
    r"""
    Resolves the configured Packages root directory.
    Priority:
    1. Custom path if provided and exists
    2. Config file config/software_directory.json
    3. Candidate locations across repo root and workspace
    4. Auto-detect removable USB drive (e.g. E:\Packages, D:\Packages, G:\Packages)
    """
    if custom_path and custom_path.strip():
        req_path = custom_path.strip()
        if not os.path.isabs(req_path):
            req_path = os.path.abspath(os.path.join(REPO_ROOT, req_path))
        if os.path.isdir(req_path):
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

    # Check all candidate locations
    candidates = [
        os.path.abspath(os.path.join(REPO_ROOT, "Packages")),
        r"G:\MarkaziSystem\Packages",
        os.path.abspath(os.path.join(os.getcwd(), "Packages")),
        os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "..", "Packages")),
        os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "Packages")),
    ]
    for c in candidates:
        if os.path.isdir(c):
            return c

    # Check all drive roots
    for drive in ["C", "D", "E", "F", "G", "H", "I", "U", "V", "W"]:
        usb_dir = f"{drive}:\\Packages"
        if os.path.isdir(usb_dir):
            return usb_dir

    return os.path.abspath(os.path.join(REPO_ROOT, "Packages"))

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


# Global in-memory cache for extracted icons: file_path -> base64 string
_GLOBAL_ICON_CACHE: Dict[str, Optional[str]] = {}


# Proper 64-bit Win32 types for icon extraction
HICON = wintypes.HANDLE
HBITMAP = wintypes.HANDLE
HDC = wintypes.HANDLE
HINSTANCE = wintypes.HANDLE
HWND = wintypes.HWND


class ICONINFO(ctypes.Structure):
    _fields_ = [
        ("fIcon", wintypes.BOOL),
        ("xHotspot", wintypes.DWORD),
        ("yHotspot", wintypes.DWORD),
        ("hbmMask", HBITMAP),
        ("hbmColor", HBITMAP),
    ]


class BITMAP(ctypes.Structure):
    _fields_ = [
        ("bmType", wintypes.LONG),
        ("bmWidth", wintypes.LONG),
        ("bmHeight", wintypes.LONG),
        ("bmWidthBytes", wintypes.LONG),
        ("bmPlanes", wintypes.WORD),
        ("bmBitsPixel", wintypes.WORD),
        ("bmBits", ctypes.c_void_p),
    ]


class BITMAPINFOHEADER(ctypes.Structure):
    _fields_ = [
        ("biSize", wintypes.DWORD),
        ("biWidth", wintypes.LONG),
        ("biHeight", wintypes.LONG),
        ("biPlanes", wintypes.WORD),
        ("biBitCount", wintypes.WORD),
        ("biCompression", wintypes.DWORD),
        ("biSizeImage", wintypes.DWORD),
        ("biXPelsPerMeter", wintypes.LONG),
        ("biYPelsPerMeter", wintypes.LONG),
        ("biClrUsed", wintypes.DWORD),
        ("biClrImportant", wintypes.DWORD),
    ]


# Setup proper ctypes function signatures
try:
    _shell32 = ctypes.windll.shell32
    _user32 = ctypes.windll.user32
    _gdi32 = ctypes.windll.gdi32
    _kernel32 = ctypes.windll.kernel32

    _shell32.ExtractAssociatedIconW.restype = HICON
    _shell32.ExtractAssociatedIconW.argtypes = [HINSTANCE, wintypes.LPCWSTR, ctypes.POINTER(ctypes.c_short)]

    _user32.PrivateExtractIconsW.restype = wintypes.UINT
    _user32.PrivateExtractIconsW.argtypes = [
        wintypes.LPCWSTR, ctypes.c_int, ctypes.c_int, ctypes.c_int,
        ctypes.POINTER(HICON), ctypes.POINTER(wintypes.UINT),
        wintypes.UINT, wintypes.UINT
    ]

    _user32.GetIconInfo.restype = wintypes.BOOL
    _user32.GetIconInfo.argtypes = [HICON, ctypes.POINTER(ICONINFO)]

    _user32.DestroyIcon.restype = wintypes.BOOL
    _user32.DestroyIcon.argtypes = [HICON]

    _user32.GetDC.restype = HDC
    _user32.GetDC.argtypes = [HWND]

    _user32.ReleaseDC.restype = ctypes.c_int
    _user32.ReleaseDC.argtypes = [HWND, HDC]

    _gdi32.CreateCompatibleDC.restype = HDC
    _gdi32.CreateCompatibleDC.argtypes = [HDC]

    _gdi32.DeleteDC.restype = wintypes.BOOL
    _gdi32.DeleteDC.argtypes = [HDC]

    _gdi32.GetObjectW.restype = ctypes.c_int
    _gdi32.GetObjectW.argtypes = [HBITMAP, ctypes.c_int, ctypes.c_void_p]

    _gdi32.GetDIBits.restype = ctypes.c_int
    _gdi32.GetDIBits.argtypes = [
        HDC, HBITMAP, wintypes.UINT, wintypes.UINT,
        ctypes.c_void_p, ctypes.c_void_p, wintypes.UINT
    ]

    _gdi32.DeleteObject.restype = wintypes.BOOL
    _gdi32.DeleteObject.argtypes = [HBITMAP]
except Exception as e:
    logger.debug(f"Win32 ctypes initialization note: {e}")


def _extract_single_icon_native(exe_path: str) -> Optional[str]:
    """Pure Win32 Ctypes icon extractor: 0 processes, 0 window flashes, instant speed."""
    if not os.path.isfile(exe_path):
        return None

    try:
        from PIL import Image
        import io
        import base64
    except ImportError:
        return None

    h_icon = None
    try:
        # Try PrivateExtractIconsW first for 48x48 icon
        h_icons = (HICON * 1)()
        icon_ids = (wintypes.UINT * 1)()
        num = _user32.PrivateExtractIconsW(exe_path, 0, 48, 48, h_icons, icon_ids, 1, 0)
        if num > 0 and h_icons[0]:
            h_icon = h_icons[0]

        if not h_icon:
            # Fallback to ExtractAssociatedIconW
            h_inst = _kernel32.GetModuleHandleW(None)
            icon_idx = ctypes.c_short(0)
            h_icon = _shell32.ExtractAssociatedIconW(h_inst, exe_path, ctypes.byref(icon_idx))

        if not h_icon:
            return None

        icon_info = ICONINFO()
        if not _user32.GetIconInfo(h_icon, ctypes.byref(icon_info)):
            return None

        hbm_color = icon_info.hbmColor
        hbm_mask = icon_info.hbmMask
        if not hbm_color:
            return None

        bmp = BITMAP()
        _gdi32.GetObjectW(hbm_color, ctypes.sizeof(BITMAP), ctypes.byref(bmp))
        width = bmp.bmWidth
        height = bmp.bmHeight
        if width <= 0 or height <= 0:
            return None

        hdc = _user32.GetDC(None)
        mem_dc = _gdi32.CreateCompatibleDC(hdc)

        bmi = BITMAPINFOHEADER()
        bmi.biSize = ctypes.sizeof(BITMAPINFOHEADER)
        bmi.biWidth = width
        bmi.biHeight = -height  # Top-down DIB
        bmi.biPlanes = 1
        bmi.biBitCount = 32
        bmi.biCompression = 0  # BI_RGB

        buffer_size = width * height * 4
        buf = (ctypes.c_ubyte * buffer_size)()

        _gdi32.GetDIBits(
            mem_dc,
            hbm_color,
            0,
            height,
            ctypes.byref(buf),
            ctypes.byref(bmi),
            0  # DIB_RGB_COLORS
        )

        _gdi32.DeleteDC(mem_dc)
        _user32.ReleaseDC(None, hdc)
        _gdi32.DeleteObject(hbm_color)
        if hbm_mask:
            _gdi32.DeleteObject(hbm_mask)

        raw_bytes = bytes(buf)
        img = Image.frombytes("RGBA", (width, height), raw_bytes, "raw", "BGRA")

        output = io.BytesIO()
        img.save(output, format="PNG")
        png_bytes = output.getvalue()

        b64 = base64.b64encode(png_bytes).decode("ascii")
        return f"data:image/png;base64,{b64}"
    except Exception as e:
        logger.debug(f"Native icon extraction error for {exe_path}: {e}")
        return None
    finally:
        if h_icon:
            _user32.DestroyIcon(h_icon)


def _extract_icons_batch(file_paths: List[str]) -> Dict[str, Optional[str]]:
    """
    Extracts embedded icons for a batch of .exe files using pure native in-process Win32 API.
    Zero subprocesses, zero window flashes, instant speed.
    """
    results: Dict[str, Optional[str]] = {}
    if not file_paths:
        return results

    for path in file_paths:
        if path in _GLOBAL_ICON_CACHE:
            results[path] = _GLOBAL_ICON_CACHE[path]
            continue

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
                    uri = f"data:{mime};base64,{base64.b64encode(data).decode('utf-8')}"
                    results[path] = uri
                    _GLOBAL_ICON_CACHE[path] = uri
                    found = True
                    break
                except Exception:
                    pass

        if not found:
            icon_data = _extract_single_icon_native(path)
            if icon_data:
                results[path] = icon_data
                _GLOBAL_ICON_CACHE[path] = icon_data

    return results


def _clean_software_keywords(text: str) -> List[str]:
    """Generates search keywords from an app name or filename (e.g. 'Electro Setup' -> ['electro', 'electro setup'])."""
    stop_words = {"windows", "microsoft", "operating", "system", "setup", "installer", "application", "tool", "editor", "explorer"}
    t = text.lower().replace(".exe", "").replace("-", " ").replace("_", " ").strip()
    words = [w for w in t.split() if w not in stop_words and len(w) >= 3]

    keywords = []
    cleaned = t.replace("setup", "").replace("installer", "").replace("x64", "").replace("x86", "").strip()
    if cleaned and cleaned not in stop_words and len(cleaned) >= 3:
        keywords.append(cleaned)
    if t and t not in stop_words and len(t) >= 3:
        keywords.append(t)
    for w in words:
        if w not in keywords:
            keywords.append(w)
    return keywords


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
        install_location = None
        matched_app_name = None
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
                    matched_app_name = app["name"]
                    if app.get("version") and app["version"] != "Not available":
                        installed_version = app["version"]

                    # Extract executable path
                    icon_val = app.get("icon", "")
                    if icon_val:
                        clean_ico = icon_val.split(",")[0].strip('"').strip()
                        if clean_ico.lower().endswith(".exe") and os.path.isfile(clean_ico):
                            installed_exe_path = clean_ico

                    loc = app.get("location", "").strip('"').strip()
                    if loc:
                        install_location = loc

                    if not installed_exe_path and loc and os.path.isdir(loc):
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

        # Resolve accurate display name
        prod_meta = meta.get("product_name", "").lower()
        is_generic_pe = "operating system" in prod_meta or "windows" in prod_meta
        clean_file_title = os.path.splitext(file)[0].replace("_", " ").replace("-", " ").replace(".", " ").strip().title()

        if is_installed and matched_app_name:
            final_name = matched_app_name
        elif display_name and not is_generic_pe:
            final_name = display_name
        else:
            final_name = clean_file_title or display_name

        packages.append({
            "id": pkg_id,
            "name": final_name,
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
            "install_location": install_location or (os.path.dirname(installed_exe_path) if installed_exe_path else None),
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
            proc = subprocess.run(
                ["powershell.exe", "-NoProfile", "-Command", ps_cmd],
                capture_output=True,
                timeout=5,
                **get_hidden_subprocess_kwargs()
            )
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
            subprocess.Popen([abs_path], cwd=working_dir, **get_hidden_subprocess_kwargs())
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


