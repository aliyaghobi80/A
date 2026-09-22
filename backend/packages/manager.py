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
import hashlib
import re
import shlex
import struct
import logging
import winreg
import subprocess
import time
from typing import Dict, Any, List, Optional

from utils.powershell import get_hidden_subprocess_kwargs
from software.registry import get_app_path_from_registry
from packages.office_shortcuts import ensure_office_desktop_shortcuts
from windows.device_settings import get_windows_identity, pin_to_taskbar

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

# Formats Windows can install directly. Batch/script files are deliberately not
# accepted: they are arbitrary code rather than self-describing installers.
SUPPORTED_PACKAGE_EXTENSIONS = {
    ".exe",
    ".msi",
    ".msp",
    ".msu",
    ".msix",
    ".msixbundle",
    ".appx",
    ".appxbundle",
}

_AUTO_EXE_INSTALLER_TYPES = {
    "innosetup",
    "nsis",
    "wix",
    "7zip",
    "winrar",
    "chrome",
    "vlc",
    "adobe",
}

_SYSTEM_BINARIES = {
    "cmd.exe",
    "conhost.exe",
    "explorer.exe",
    "mmc.exe",
    "mshta.exe",
    "notepad.exe",
    "powershell.exe",
    "pwsh.exe",
    "reg.exe",
    "regedit.exe",
    "rundll32.exe",
    "taskmgr.exe",
    "wscript.exe",
}

_KNOWN_PACKAGE_DETECTION: Dict[str, Dict[str, List[str]]] = {
    "vlc": {
        "aliases": ["vlc", "vlc media player", "videolan vlc"],
        "app_paths": ["vlc.exe"],
        "paths": [
            r"C:\Program Files\VideoLAN\VLC\vlc.exe",
            r"C:\Program Files (x86)\VideoLAN\VLC\vlc.exe",
        ],
    },
    "chrome": {
        "aliases": ["google chrome", "chrome"],
        "app_paths": ["chrome.exe"],
        "paths": [
            r"C:\Program Files\Google\Chrome\Application\chrome.exe",
            r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
        ],
    },
    "winrar": {
        "aliases": ["winrar"],
        "app_paths": ["winrar.exe"],
        "paths": [
            r"C:\Program Files\WinRAR\WinRAR.exe",
            r"C:\Program Files (x86)\WinRAR\WinRAR.exe",
        ],
    },
    "7zip": {
        "aliases": ["7-zip", "7zip"],
        "app_paths": ["7zfm.exe"],
        "paths": [
            r"C:\Program Files\7-Zip\7zFM.exe",
            r"C:\Program Files (x86)\7-Zip\7zFM.exe",
        ],
    },
    "acrobat": {
        "aliases": ["adobe acrobat", "adobe acrobat reader", "acrobat reader", "adobe reader", "acrobat", "adobe reader dc", "adobe acrobat dc", "adobe acrobat reader dc"],
        "app_paths": ["AcroRd32.exe", "Acrobat.exe"],
        "paths": [
            r"C:\Program Files\Adobe\Acrobat DC\Acrobat\Acrobat.exe",
            r"C:\Program Files (x86)\Adobe\Acrobat DC\Acrobat\Acrobat.exe",
            r"C:\Program Files\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe",
            r"C:\Program Files (x86)\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe",
            r"C:\Program Files\Adobe\Acrobat Reader 2024\Reader\AcroRd32.exe",
            r"C:\Program Files\Adobe\Acrobat Reader 2020\Reader\AcroRd32.exe",
            r"C:\Program Files (x86)\Adobe\Acrobat Reader 2020\Reader\AcroRd32.exe",
            r"C:\Program Files\Adobe\Acrobat Reader\Reader\AcroRd32.exe",
            r"C:\Program Files (x86)\Adobe\Acrobat Reader\Reader\AcroRd32.exe",
        ],
    },
    "kmplayer": {
        "aliases": ["kmplayer", "kmplayer 64x", "kmp64"],
        "app_paths": ["KMPlayer.exe", "KMPlayer64.exe"],
        "paths": [
            r"C:\Program Files\KMPlayer\KMPlayer.exe",
            r"C:\Program Files\KMPlayer 64X\KMPlayer64.exe",
            r"C:\Program Files (x86)\KMPlayer 64X\KMPlayer64.exe",
            r"C:\Program Files (x86)\The KMPlayer\KMPlayer.exe",
        ],
    },
    "fdm": {
        "aliases": ["free download manager", "fdm"],
        "app_paths": ["fdm.exe"],
        "paths": [
            r"C:\Program Files\FreeDownloadManager.ORG\Free Download Manager\fdm.exe",
            r"C:\Program Files (x86)\FreeDownloadManager.ORG\Free Download Manager\fdm.exe",
            r"C:\Program Files\SoftDeluxe\Free Download Manager\fdm.exe",
        ],
    },
    "firefox": {
        "aliases": ["mozilla firefox", "firefox"],
        "app_paths": ["firefox.exe"],
        "paths": [
            r"C:\Program Files\Mozilla Firefox\firefox.exe",
            r"C:\Program Files (x86)\Mozilla Firefox\firefox.exe",
        ],
    },
}


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

    # Auto-detect PROGRAM, Packages, or Software on external or USB drives
    for letter in ["H", "D", "E", "F", "G", "I", "J", "K", "L"]:
        for sub in ["PROGRAM", "Packages", "Software", "Programs"]:
            cand = f"{letter}:\\{sub}"
            if cand not in candidates and os.path.isdir(cand):
                candidates.append(cand)

    for c in candidates:
        if os.path.isdir(c):
            return c

    # Keep the intended default path so the API can report a clear
    # directory_exists=false response instead of returning None.
    return os.path.abspath(os.path.join(REPO_ROOT, "Packages"))

def set_packages_directory(custom_dir: str) -> Dict[str, Any]:
    """Updates and persists the active Packages directory in config/software_directory.json."""
    if not custom_dir or not os.path.isdir(custom_dir):
        return {"success": False, "message": f"Directory does not exist: {custom_dir}"}

    abs_dir = os.path.abspath(custom_dir)
    cfg = {"packageRoot": abs_dir}

    try:
        os.makedirs(os.path.dirname(CONFIG_FILE), exist_ok=True)
        with open(CONFIG_FILE, "w", encoding="utf-8") as f:
            json.dump(cfg, f, indent=2)
    except Exception as e:
        logger.warning(f"Failed to write software_directory.json: {e}")

    return {
        "success": True,
        "packages_directory": abs_dir,
    }


def get_current_packages_directory() -> str:
    """Returns the currently active packages directory."""
    return get_packages_directory()

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
                            duninstall = get_val("UninstallString")
                            dquiet_uninstall = get_val("QuietUninstallString")

                            results.append({
                                "name": dname,
                                "version": dver or "Not available",
                                "publisher": dpub,
                                "location": dloc,
                                "icon": dexe,
                                "uninstall_string": duninstall,
                                "quiet_uninstall_string": dquiet_uninstall,
                                "registry_key": kname,
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


def _normalize_identity(value: str) -> str:
    """Normalizes product names without collapsing meaningful brand tokens."""
    value = (value or "").lower()
    value = re.sub(r"\.(exe|msi|msp|msu|msix|appx)(bundle)?$", "", value)
    value = re.sub(r"\b(setup|installer|install|offline|online|x64|x86|64-bit|32-bit)\b", " ", value)
    value = re.sub(r"\b(v?\d+(?:[._-]\d+){0,4})\b", " ", value)
    value = re.sub(r"[^a-z0-9\u0600-\u06ff]+", " ", value)
    return " ".join(value.split())


def _identity_tokens(value: str) -> set[str]:
    stop = {"the", "for", "and", "app", "application", "software", "player"}
    return {token for token in _normalize_identity(value).split() if len(token) >= 2 and token not in stop}


def _stable_package_id(relative_path: str) -> str:
    normalized = relative_path.replace("\\", "/").lower().strip()
    stem = _normalize_identity(os.path.splitext(os.path.basename(normalized))[0]).replace(" ", "_") or "package"
    digest = hashlib.sha256(normalized.encode("utf-8", errors="ignore")).hexdigest()[:10]
    return f"{stem}_{digest}"


def _load_matching_manifest(folder: str, filename: str) -> Dict[str, Any]:
    """Loads package.json only when it actually describes the discovered file."""
    manifest_path = os.path.join(folder, "package.json")
    if not os.path.isfile(manifest_path):
        return {}
    try:
        with open(manifest_path, "r", encoding="utf-8") as manifest_file:
            manifest = json.load(manifest_file)
        if not isinstance(manifest, dict):
            return {}
        declared = str(manifest.get("installer") or "").replace("\\", "/").strip()
        if declared and os.path.basename(declared).lower() != filename.lower():
            return {}
        return manifest
    except Exception as exc:
        logger.warning("Invalid package manifest at %s: %s", manifest_path, exc)
        return {}


_PORTABLE_TOOL_STEMS = {
    "wub", "wub_x64", "wub32", "wub_x86", "wubx64", "wubx86",
    "windowsupdateblocker", "windows_update_blocker",
    "dcontrol", "dcontrol_x64", "defendercontrol", "defender_control",
    "rufus", "rufus_x86", "rufus_x64",
    "cpuz", "cpu-z", "cpu_z", "cpuz_x64", "cpuz_x32",
    "gpuz", "gpu-z", "gpu_z",
    "hwmonitor", "hwmonitor_x64", "hwmonitor_x32",
    "crystaldiskinfo", "diskinfo", "diskinfo64", "diskinfo32",
    "crystaldiskmark", "diskmark", "diskmark64", "diskmark32",
    "coretemp", "core_temp", "core-temp",
    "kmsauto", "kmsauto_net", "kmsauto_lite",
    "aact", "aact_x64", "aact_portable",
    "mas", "mas_aio", "microsoft_activation_scripts",
    "heu_kms", "kms_vl_all",
    "teamviewer_qs", "teamviewerqs"
}

_PORTABLE_KEYWORDS = (
    "windows update blocker",
    "update blocker",
    "defender control",
    "rufus",
    "kmsauto",
    "aact portable",
    "crystaldiskinfo",
    "crystaldiskmark",
    "hwmonitor",
    "gpu-z",
    "cpu-z",
    "core temp",
)


def _is_portable_tool(
    file_path: str,
    metadata: Optional[Dict[str, str]] = None,
    manifest: Optional[Dict[str, Any]] = None,
) -> bool:
    """Checks whether an executable file is a standalone / portable utility rather than an installer."""
    if manifest:
        if (
            manifest.get("is_portable")
            or manifest.get("portable")
            or str(manifest.get("type", "")).lower() in ("portable", "tool", "standalone")
            or str(manifest.get("action", "")).lower() == "open"
            or str(manifest.get("category", "")).lower() in ("portable", "tool", "tools")
        ):
            return True

    filename = os.path.basename(file_path).lower()
    stem = os.path.splitext(filename)[0]
    bare_stem = re.sub(r'[_\-\.\s]*(x64|x86|64bit|32bit|v?[\d]+[\d\.]*)[_\-\.\s]*$', '', stem)

    # If filename clearly indicates an installer/setup, it is NOT a portable tool
    if any(k in stem for k in ("setup", "install", "installer", "silent", "update")):
        # Only override if explicit portable tool stem (e.g. update_blocker)
        if not any(stem.startswith(s) for s in ("wub", "update_blocker", "updateblocker")):
            return False

    if stem in _PORTABLE_TOOL_STEMS or bare_stem in _PORTABLE_TOOL_STEMS:
        return True

    if any(stem.startswith(s) for s in ("wub", "dcontrol", "rufus")):
        return True

    if "wub" in stem or "update_blocker" in stem or "updateblocker" in stem:
        return True

    parent_dir = os.path.basename(os.path.dirname(file_path)).lower()
    if parent_dir in ("portable", "wub", "kms") or "portable" in parent_dir:
        return True

    if metadata:
        meta_text = f"{metadata.get('product_name', '')} {metadata.get('file_description', '')}".lower()
        if any(kw in meta_text for kw in _PORTABLE_KEYWORDS):
            return True

    return False


def _validate_installer(
    file_path: str,
    metadata: Dict[str, str],
    installer_type: str,
    manifest: Dict[str, Any],
) -> Dict[str, Any]:
    """Classifies a candidate as automatic, manual-only, or blocked."""
    extension = os.path.splitext(file_path)[1].lower()
    filename = os.path.basename(file_path)

    if extension not in SUPPORTED_PACKAGE_EXTENSIONS:
        return {
            "is_valid": False,
            "validation_code": "unsupported_extension",
            "validation_error": f"Unsupported installer format: {extension or 'none'}",
            "auto_install_supported": False,
            "manual_install_supported": False,
            "trust_level": "blocked",
        }

    if extension == ".exe":
        original = os.path.basename(metadata.get("original_filename") or "").lower()
        product = (metadata.get("product_name") or "").lower()
        description = (metadata.get("file_description") or "").lower()
        publisher = (metadata.get("publisher") or "").lower()

        # A renamed Windows binary is not an installer. This catches files such
        # as notepad.exe renamed to vlc.exe before anything can execute them.
        if original in _SYSTEM_BINARIES and original != filename.lower():
            return {
                "is_valid": False,
                "validation_code": "identity_mismatch",
                "validation_error": (
                    f"File identity mismatch: {filename} is signed/described as {original}. "
                    "The file was blocked and will not be executed."
                ),
                "auto_install_supported": False,
                "manual_install_supported": False,
                "trust_level": "blocked",
            }

        is_windows_component = (
            "microsoft" in publisher
            and ("operating system" in product or original in _SYSTEM_BINARIES)
            and not any(word in description for word in ("setup", "installer", "update", "package"))
        )
        if is_windows_component:
            return {
                "is_valid": False,
                "validation_code": "system_binary",
                "validation_error": "This executable is a Windows component, not an application installer.",
                "auto_install_supported": False,
                "manual_install_supported": False,
                "trust_level": "blocked",
            }

        if _is_portable_tool(file_path, metadata, manifest):
            return {
                "is_valid": True,
                "is_portable_tool": True,
                "can_open_tool": True,
                "validation_code": "portable_tool",
                "validation_error": None,
                "auto_install_supported": False,
                "manual_install_supported": False,
                "trust_level": "portable_tool",
            }

        return {
            "is_valid": True,
            "validation_code": "ok",
            "validation_error": None,
            "auto_install_supported": True,
            "manual_install_supported": True,
            "trust_level": "verified_installer",
        }

    # MSI/MSP are handled by Windows Installer; APPX/MSIX by AppX deployment.
    return {
        "is_valid": True,
        "validation_code": "ok",
        "validation_error": None,
        "auto_install_supported": True,
        "manual_install_supported": True,
        "trust_level": "windows_package",
    }


def _known_detection_key(*values: str) -> Optional[str]:
    joined = " ".join(_normalize_identity(value) for value in values if value)
    tokens = _identity_tokens(joined)
    for key, rule in _KNOWN_PACKAGE_DETECTION.items():
        if key in tokens:
            return key
        if any(_normalize_identity(alias) in joined for alias in rule.get("aliases", [])):
            return key
    return None


def _resolve_known_executable(key: Optional[str]) -> Optional[str]:
    if not key:
        return None
    rule = _KNOWN_PACKAGE_DETECTION.get(key) or {}
    for app_name in rule.get("app_paths", []):
        try:
            candidate = get_app_path_from_registry(app_name)
            if candidate and os.path.isfile(candidate):
                return os.path.abspath(candidate)
        except Exception:
            pass
    for candidate in rule.get("paths", []):
        if os.path.isfile(candidate):
            return os.path.abspath(candidate)
    return None


def _match_installed_application(
    installed_apps: List[Dict[str, str]],
    identities: List[str],
    publisher: str = "",
) -> Optional[Dict[str, str]]:
    """Scores registry matches using whole tokens to avoid loose substrings."""
    normalized_identities = [_normalize_identity(value) for value in identities if _normalize_identity(value)]
    publisher_tokens = _identity_tokens(publisher)
    best: Optional[Dict[str, str]] = None
    best_score = 0

    for app in installed_apps:
        app_name = _normalize_identity(app.get("name", ""))
        if not app_name:
            continue
        app_tokens = _identity_tokens(app_name)
        score = 0
        for identity in normalized_identities:
            identity_tokens = _identity_tokens(identity)
            if not identity_tokens:
                continue
            if identity == app_name:
                score = max(score, 100)
            elif len(identity_tokens) >= 2 and identity_tokens.issubset(app_tokens):
                score = max(score, 85)
            elif len(identity_tokens) == 1 and next(iter(identity_tokens)) in app_tokens:
                token = next(iter(identity_tokens))
                if len(token) >= 3:
                    score = max(score, 75)

        if score and publisher_tokens:
            app_publisher_tokens = _identity_tokens(app.get("publisher", ""))
            if publisher_tokens & app_publisher_tokens:
                score += 10

        if score > best_score:
            best = app
            best_score = score

    return best if best_score >= 75 else None


def _detect_installed_package(
    installed_apps: List[Dict[str, str]],
    display_name: str,
    filename: str,
    product_name: str,
    publisher: str,
    detection_id: Optional[str],
    folder_name: Optional[str] = None,
) -> Dict[str, Any]:
    known_key = _known_detection_key(detection_id or "", display_name, filename, product_name, folder_name or "")
    known_executable = _resolve_known_executable(known_key)

    aliases: List[str] = [display_name, filename, product_name, folder_name or "", detection_id or ""]
    if known_key:
        aliases.extend(_KNOWN_PACKAGE_DETECTION[known_key].get("aliases", []))

    matched = _match_installed_application(installed_apps, aliases, publisher=publisher)
    if not matched and not known_executable:
        return {
            "is_installed": False,
            "installed_version": "",
            "installed_exe_path": None,
            "install_location": None,
            "matched_app_name": None,
            "detection_source": "none",
        }

    installed_exe_path = known_executable
    install_location = None
    installed_version = ""
    matched_name = None
    detection_source = "file_system" if known_executable else "registry"

    if matched:
        matched_name = matched.get("name")
        if matched_name:
            clean_name = re.sub(r"\s*\((?:remove|uninstall)\s*only\)", "", matched_name, flags=re.IGNORECASE).strip()
            matched_name = clean_name or matched_name
        version = matched.get("version")
        if version and version != "Not available":
            installed_version = version
        icon_value = matched.get("icon", "")
        if not installed_exe_path and icon_value:
            candidate = icon_value.split(",")[0].strip('"').strip()
            if candidate.lower().endswith(".exe") and os.path.isfile(candidate):
                installed_exe_path = candidate
        location = matched.get("location", "").strip('"').strip()
        if location:
            install_location = location
        detection_source = "registry+file" if known_executable else "registry"

    if not install_location and installed_exe_path:
        install_location = os.path.dirname(installed_exe_path)

    return {
        "is_installed": True,
        "installed_version": installed_version,
        "installed_exe_path": installed_exe_path,
        "install_location": install_location,
        "matched_app_name": matched_name,
        "detection_source": detection_source,
    }



def _normalize_package_identity(name: str, filename: str) -> str:
    """
    Cleans filename and software name to find the base identity for deduplication.
    Removes copy patterns like (1), (2), [1], _1, - Copy, etc.
    """
    stem = os.path.splitext(filename)[0]
    clean_stem = re.sub(r'[\s_\-\.\(\[]*(?:copy|\(?\d+\)?|نسخه|final|setup|installer|x64|x86|64bit|32bit|v\d+[\d\.]*)[\s_\-\.\)\]]*$', '', stem, flags=re.IGNORECASE).strip()
    clean_name = re.sub(r'[\s_\-\.\(\[]*(?:copy|\(?\d+\)?|نسخه|version\s+[\d\.]+|v[\d\.]+)[\s_\-\.\)\]]*$', '', name, flags=re.IGNORECASE).strip()
    
    key = re.sub(r'[^a-zA-Z0-9]', '', (clean_name or clean_stem).lower())
    return key or (clean_name or clean_stem).lower()


def _resolve_best_brand_icon(app_name: str, filename: str, installed_exe_path: Optional[str] = None) -> Optional[str]:
    """
    Attempts to extract the official high-resolution brand icon from installed binaries
    or standard program files locations for well-known software.
    """
    # 1. If installed_exe_path is known and valid, use it first
    if installed_exe_path and os.path.isfile(installed_exe_path):
        icon = _extract_single_icon_native(installed_exe_path)
        if icon:
            return icon

    combined = f"{app_name} {filename}".lower()

    # 2. Check standalone embedded brand icons (Chrome, VLC, Firefox, WinRAR, KMPlayer, FDM, Acrobat, etc.)
    try:
        from packages.brand_icons import get_embedded_brand_icon
        embedded = get_embedded_brand_icon(combined)
        if embedded:
            return embedded
    except Exception:
        pass

    # 3. Check standard installation paths for popular software
    common_app_paths = []

    if "chrome" in combined:
        common_app_paths = [
            r"C:\Program Files\Google\Chrome\Application\chrome.exe",
            r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
        ]
    elif "7z" in combined or "7-zip" in combined:
        common_app_paths = [
            r"C:\Program Files\7-Zip\7zFM.exe",
            r"C:\Program Files (x86)\7-Zip\7zFM.exe",
        ]
    elif "winrar" in combined:
        common_app_paths = [
            r"C:\Program Files\WinRAR\WinRAR.exe",
            r"C:\Program Files (x86)\WinRAR\WinRAR.exe",
        ]
    elif "vlc" in combined:
        common_app_paths = [
            r"C:\Program Files\VideoLAN\VLC\vlc.exe",
            r"C:\Program Files (x86)\VideoLAN\VLC\vlc.exe",
        ]
    elif "firefox" in combined:
        common_app_paths = [
            r"C:\Program Files\Mozilla Firefox\firefox.exe",
            r"C:\Program Files (x86)\Mozilla Firefox\firefox.exe",
        ]
    elif "acrobat" in combined or "adobe" in combined:
        common_app_paths = [
            r"C:\Program Files\Adobe\Acrobat DC\Acrobat\Acrobat.exe",
            r"C:\Program Files (x86)\Adobe\Acrobat DC\Acrobat\Acrobat.exe",
            r"C:\Program Files\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe",
            r"C:\Program Files (x86)\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe",
            r"C:\Program Files\Adobe\Acrobat Reader 2024\Reader\AcroRd32.exe",
            r"C:\Program Files\Adobe\Acrobat Reader 2020\Reader\AcroRd32.exe",
            r"C:\Program Files (x86)\Adobe\Acrobat Reader 2020\Reader\AcroRd32.exe",
            r"C:\Program Files\Adobe\Acrobat Reader\Reader\AcroRd32.exe",
            r"C:\Program Files (x86)\Adobe\Acrobat Reader\Reader\AcroRd32.exe",
        ]
    elif "kmplayer" in combined or "kmp" in combined:
        common_app_paths = [
            r"C:\Program Files\KMPlayer 64X\KMPlayer64.exe",
            r"C:\Program Files (x86)\KMPlayer 64X\KMPlayer64.exe",
            r"C:\Program Files\KMPlayer\KMPlayer.exe",
            r"C:\Program Files (x86)\The KMPlayer\KMPlayer.exe",
        ]
    elif "fdm" in combined or "download manager" in combined:
        common_app_paths = [
            r"C:\Program Files\FreeDownloadManager.ORG\Free Download Manager\fdm.exe",
            r"C:\Program Files (x86)\FreeDownloadManager.ORG\Free Download Manager\fdm.exe",
            r"C:\Program Files\SoftDeluxe\Free Download Manager\fdm.exe",
        ]
    elif "telegram" in combined:
        appdata = os.environ.get("APPDATA", "")
        common_app_paths = [
            os.path.join(appdata, "Telegram Desktop", "Telegram.exe"),
            r"C:\Program Files\Telegram Desktop\Telegram.exe",
        ]
    elif "notepad++" in combined or "notepad" in combined:
        common_app_paths = [
            r"C:\Program Files\Notepad++\notepad++.exe",
            r"C:\Program Files (x86)\Notepad++\notepad++.exe",
        ]
    elif "anydesk" in combined:
        common_app_paths = [
            r"C:\Program Files (x86)\AnyDesk\AnyDesk.exe",
            r"C:\Program Files\AnyDesk\AnyDesk.exe",
        ]

    for p in common_app_paths:
        if os.path.isfile(p):
            icon = _extract_single_icon_native(p)
            if icon:
                return icon

    return None


IGNORED_SCAN_DIR_NAMES = {
    "backend", "_internal", "build", "dist", "build_backend_out",
    "node_modules", ".git", ".github", ".idea", ".vscode", "temp", "tmp",
    "appdata", "windows", "$recycle.bin", "system volume information",
    "flutter_assets", "runner", "logs", "__pycache__", "obj", "bin"
}

IGNORED_FILE_PATTERNS = {
    "backend_server", "markazisystemchecker", "markazi_system_checker",
    "iscc", "flutter", "python", "pythonw", "pip", "runner"
}

# Filenames that are too generic to use as display names on their own.
# When one of these is the installer filename, the parent folder name is used instead.
_GENERIC_INSTALLER_STEMS = {
    "setup", "install", "installer", "autorun", "launch", "start",
    "run", "execute", "uninst", "uninstall"
}

# Root-level folder names that should NOT be used as a display name fallback
# (they are too generic or are the packages root itself).
_GENERIC_FOLDER_NAMES = {
    "packages", "program", "programs", "software", "install", "installer",
    "setup", "tools", "apps", "applications", "temp", "tmp", "downloads"
}

# Maximum file size in bytes for icon extraction (skip very large files for performance)
_MAX_ICON_EXTRACT_BYTES = 160 * 1024 * 1024  # 160 MB


def _folder_display_name(root: str, pkg_dir: str) -> Optional[str]:
    """
    Returns the parent folder name as a clean display name, or None if the
    folder is too generic or is the packages root itself.
    """
    abs_root = os.path.abspath(root)
    abs_pkg = os.path.abspath(pkg_dir)
    if abs_root == abs_pkg:
        return None
    folder_name = os.path.basename(abs_root)
    if not folder_name or folder_name.lower() in _GENERIC_FOLDER_NAMES:
        return None
    return folder_name.replace("_", " ").replace("-", " ").strip()

def _is_ignored_file_or_dir(root: str, filename: str, base_dir: Optional[str] = None) -> bool:
    """Checks if a file or directory is an internal backend/system artifact that must not be scanned."""
    fn_lower = filename.lower()
    root_lower = root.lower().replace("\\", "/")

    # Check root path components relative to base_dir if provided
    if base_dir:
        try:
            rel = os.path.relpath(root, base_dir).replace("\\", "/")
            if rel != ".":
                path_parts = [p.lower() for p in rel.split("/") if p]
            else:
                path_parts = []
        except Exception:
            path_parts = root_lower.split("/")
    else:
        path_parts = root_lower.split("/")

    if any(part in IGNORED_SCAN_DIR_NAMES for part in path_parts):
        return True

    # Check file patterns
    stem = os.path.splitext(fn_lower)[0]
    for pat in IGNORED_FILE_PATTERNS:
        if pat in fn_lower or pat in stem:
            return True

    return False


def _is_64_bit_windows() -> bool:
    """Detect the Windows OS architecture even from a 32-bit process."""
    architecture = " ".join(
        [
            os.environ.get("PROCESSOR_ARCHITECTURE", ""),
            os.environ.get("PROCESSOR_ARCHITEW6432", ""),
        ]
    ).lower()
    return "amd64" in architecture or "arm64" in architecture or ctypes.sizeof(ctypes.c_void_p) == 8


def _select_windows_update_blocker_variant(
    packages: List[Dict[str, Any]],
    *,
    is_64_bit: Optional[bool] = None,
) -> List[Dict[str, Any]]:
    """Expose only the WUB executable matching the current Windows architecture."""
    wub_packages = [package for package in packages if _is_windows_update_blocker(package)]
    if len(wub_packages) <= 1:
        return packages

    use_64_bit = _is_64_bit_windows() if is_64_bit is None else is_64_bit

    def is_x64_variant(package: Dict[str, Any]) -> bool:
        stem = os.path.splitext(str(package.get("filename", "")))[0].lower()
        return stem in {"wub_x64", "wubx64"}

    preferred = [
        package
        for package in wub_packages
        if is_x64_variant(package) == use_64_bit
    ]
    if not preferred:
        preferred = wub_packages

    keep_ids = {id(package) for package in preferred}
    return [
        package
        for package in packages
        if not _is_windows_update_blocker(package) or id(package) in keep_ids
    ]


def scan_packages(custom_dir: Optional[str] = None) -> Dict[str, Any]:
    """
    Recursively scans supported Windows installer formats, validates that EXE
    candidates are actual installers, and detects installed status & version.
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

    for root, dirs, files in os.walk(pkg_dir):
        # Prune internal and temporary directories in-place
        dirs[:] = [d for d in dirs if d.lower() not in IGNORED_SCAN_DIR_NAMES and not d.startswith(".")]

        # Check if this directory contains an Office setup script (e.g. Setup_Office 2024.cmd)
        office_cmds = [f for f in files if f.lower().startswith("setup_office") and f.lower().endswith(".cmd")]
        if office_cmds:
            # Prioritize Setup_Office 2024.cmd, then 2021, etc.
            office_cmds.sort(key=lambda x: "2024" not in x)
            chosen_office_cmd = office_cmds[0]
            cmd_full = os.path.abspath(os.path.join(root, chosen_office_cmd))
            if cmd_full not in seen_paths and _is_safe_path(pkg_dir, cmd_full):
                seen_paths.add(cmd_full)
                rel_p = os.path.relpath(cmd_full, pkg_dir).replace("\\", "/")
                sz = os.path.getsize(cmd_full) if os.path.isfile(cmd_full) else 0
                discovered_files.append({
                    "file": chosen_office_cmd,
                    "full_path": cmd_full,
                    "root": root,
                    "rel_path": rel_p,
                    "file_size": sz,
                    "parent_folder": os.path.basename(root),
                    "is_office_cmd": True,
                })

        for file in files:
            # If an Office setup script is present in this folder, do not enumerate ODT.exe or other internal helper files
            if office_cmds and (file.lower() in ("odt.exe", "setup.exe") or file.lower().endswith(".cmd")):
                continue

            extension = os.path.splitext(file)[1].lower()
            if extension not in SUPPORTED_PACKAGE_EXTENSIONS:
                continue

            if _is_ignored_file_or_dir(root, file, pkg_dir):
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
                "parent_folder": os.path.basename(root),
                "is_office_cmd": False,
            })

    # Only PE executables have embedded icons supported by the native extractor.
    # Skip very large files (> 160 MB) for performance — they are typically offline
    # full installers whose icon can often be resolved from the installed binary.
    all_paths = [
        df["full_path"]
        for df in discovered_files
        if df["file"].lower().endswith(".exe")
        and df["file_size"] <= _MAX_ICON_EXTRACT_BYTES
    ]
    icons_map = _extract_icons_batch(all_paths)

    packages: List[Dict[str, Any]] = []

    for df in discovered_files:
        file = df["file"]
        full_path = df["full_path"]
        root = df["root"]
        rel_path = df["rel_path"]
        file_size = df["file_size"]
        parent_folder = df.get("parent_folder", "")
        is_office_cmd = df.get("is_office_cmd", False)

        extension = os.path.splitext(file)[1].lower()
        if is_office_cmd:
            meta = {
                "product_name": "Microsoft Office 2024 (Pro Plus)",
                "file_description": "Microsoft Office 2024 Installer",
                "publisher": "Microsoft Corporation",
                "version": "2024",
                "original_filename": file,
                "display_name": "Microsoft Office 2024 Pro Plus",
            }
            display_name = "Microsoft Office 2024 Pro Plus"
            version = "2024"
            publisher = "Microsoft Corporation"
            product_name = "Microsoft Office 2024 (Pro Plus)"
            installer_type = "office_cmd"
            validation = {
                "is_valid": True,
                "validation_code": "ok",
                "validation_error": None,
                "auto_install_supported": True,
                "manual_install_supported": True,
                "trust_level": "verified_installer",
            }
        else:
            meta = _extract_exe_metadata(full_path) if extension == ".exe" else {
                "product_name": "",
                "file_description": "",
                "publisher": "",
                "version": "",
                "original_filename": "",
                "display_name": os.path.splitext(file)[0].replace("_", " ").replace("-", " "),
            }
            display_name = meta["display_name"]
            version = meta["version"] or ""
            publisher = meta["publisher"]
            product_name = meta["product_name"] or display_name
            installer_type = _guess_installer_type(full_path)

        # Determine if the installer filename is too generic to be a display name.
        # e.g. setup.exe, installer.exe, install.exe inside a named sub-folder.
        file_stem_lower = os.path.splitext(file)[0].lower()
        # Strip version suffixes and platform tags before checking genericness
        _bare_stem = re.sub(r'[_\-\.\s]*(x64|x86|64bit|32bit|v?[\d]+[\d\.]*)[_\-\.\s]*$', '', file_stem_lower)
        is_generic_filename = _bare_stem in _GENERIC_INSTALLER_STEMS
        folder_fallback_name = _folder_display_name(root, pkg_dir) if is_generic_filename else None

        # package.json is trusted only when its `installer` points to this file.
        manifest = _load_matching_manifest(root, file)
        silent_args = ""
        detection_id = None

        if manifest:
            display_name = str(manifest.get("name") or display_name)
            version = str(manifest.get("version") or version)
            publisher = str(manifest.get("publisher") or publisher)
            silent_args = str(manifest.get("silentArguments") or "")
            detection_id = manifest.get("detectionId") or manifest.get("id")

        if not is_office_cmd:
            validation = _validate_installer(full_path, meta, installer_type, manifest)
        pkg_id = "office_2024_pro_plus" if is_office_cmd else _stable_package_id(rel_path)
        icon_data = icons_map.get(full_path)

        # Resolve detection name
        effective_detect_name = folder_fallback_name if (folder_fallback_name and is_generic_filename) else display_name
        effective_product_name = folder_fallback_name if (folder_fallback_name and is_generic_filename) else product_name

        if is_office_cmd:
            from software.office import detect_microsoft_office
            off_info = detect_microsoft_office()
            is_installed = bool(off_info.get("installed", False))
            installed_version = off_info.get("version", "Not available")
            installed_exe_path = None
            install_location = off_info.get("install_location")
            matched_app_name = off_info.get("product_name", "Microsoft Office 2024")
            detection_id = "microsoft_office"
            icon_data = _resolve_best_brand_icon("office", file, None)
            detection = {
                "is_installed": is_installed,
                "installed_version": installed_version,
                "installed_exe_path": installed_exe_path,
                "install_location": install_location,
                "matched_app_name": matched_app_name,
                "detection_source": "office_registry",
            }
        else:
            detection = _detect_installed_package(
                installed_apps,
                effective_detect_name,
                file,
                effective_product_name,
                publisher,
                detection_id,
                folder_name=parent_folder or folder_fallback_name,
            )
            is_installed = bool(detection["is_installed"])
            installed_version = detection["installed_version"]
            installed_exe_path = detection["installed_exe_path"]
            install_location = detection["install_location"]
            matched_app_name = detection["matched_app_name"]

        # Fallback version from installer metadata if not found in registry
        if not installed_version and version:
            installed_version = version

        # 1. First try brand / installed icon resolution for accurate application icons
        brand_icon = _resolve_best_brand_icon(effective_detect_name or display_name, file, installed_exe_path)
        if brand_icon:
            icon_data = brand_icon
        elif not icon_data and installed_exe_path and os.path.isfile(installed_exe_path):
            icon_data = _extract_single_icon_native(installed_exe_path)

        # Fallback icon from manifest if specified
        if not icon_data and manifest and manifest.get("icon"):
            manifest_ico = os.path.join(root, str(manifest.get("icon")))
            if os.path.isfile(manifest_ico):
                try:
                    import base64
                    with open(manifest_ico, "rb") as f_ico:
                        ico_bytes = f_ico.read()
                    ext = os.path.splitext(manifest_ico)[1].lower().replace(".", "")
                    mime = "image/x-icon" if ext == "ico" else f"image/{ext}"
                    icon_data = f"data:{mime};base64,{base64.b64encode(ico_bytes).decode('utf-8')}"
                except Exception:
                    pass

        is_portable = bool(validation.get("is_portable_tool", False))
        if is_portable:
            installed_exe_path = full_path
            install_location = os.path.dirname(full_path)
            is_installed = True
            status = "Ready to Run"
        else:
            status = "Installed" if is_installed else "Not Installed"

        # Resolve accurate display name
        prod_meta = meta.get("product_name", "").lower()
        is_generic_pe = "operating system" in prod_meta or "windows" in prod_meta
        clean_file_title = os.path.splitext(file)[0].replace("_", " ").replace("-", " ").replace(".", " ").strip().title()

        _file_stem = os.path.splitext(file)[0].lower()
        if _file_stem in ("wub", "wub_x64", "wub32", "wub_x86", "wubx64"):
            display_name = "Windows Update Blocker"
        elif _file_stem in ("dcontrol", "dcontrol_x64"):
            display_name = "Defender Control"

        # Priority:
        # 1. Portable tool friendly name or display name
        # 2. Matched registry app name (if installed) - always most accurate
        # 3. Folder fallback name (if filename is generic like setup.exe) - user-visible folder name
        #    is more meaningful than internal branding like "Adobe Self Extractor"
        # 4. display_name from metadata/manifest (if not generic OS binary)
        # 5. Folder fallback name as secondary fallback
        # 6. Cleaned filename as last resort
        if is_portable:
            final_name = display_name or clean_file_title
        elif is_installed and matched_app_name:
            final_name = matched_app_name
        elif folder_fallback_name and is_generic_filename:
            # Folder name takes priority for generic installers (setup.exe, install.exe)
            # The parent folder name (e.g. "Acrobat Reader") is more meaningful to the user
            # than internal metadata like "Adobe Self Extractor".
            final_name = folder_fallback_name
        elif display_name and not is_generic_pe:
            final_name = display_name
        elif folder_fallback_name:
            final_name = folder_fallback_name
        else:
            final_name = clean_file_title or display_name

        packages.append({
            "id": pkg_id,
            "name": final_name,
            "filename": file,
            "folder_name": parent_folder,
            "relative_path": rel_path,
            "full_path": full_path,
            "version": version or installed_version or "Unknown",
            "publisher": publisher,
            "detection_id": detection_id,
            "file_size_bytes": file_size,
            "file_size_display": _format_file_size(file_size),
            "package_format": extension.lstrip(".").upper(),
            "installer_type": "portable" if is_portable else installer_type,
            "is_valid": validation["is_valid"],
            "validation_code": validation["validation_code"],
            "validation_error": validation["validation_error"],
            "trust_level": validation["trust_level"],
            "status": status,
            "is_installed": is_installed,
            "installed_version": installed_version if is_installed else "Not available",
            "installed_exe_path": installed_exe_path,
            "install_location": install_location or (os.path.dirname(installed_exe_path) if installed_exe_path else None),
            "detection_source": "portable_tool" if is_portable else detection["detection_source"],
            "is_portable_tool": is_portable,
            "can_open_tool": is_portable or bool(validation.get("can_open_tool", False)),
            "install_allowed": bool(validation["is_valid"] and validation["manual_install_supported"]),
            "auto_install_supported": bool(validation["auto_install_supported"]),
            "manual_install_supported": bool(validation["manual_install_supported"]),
            "has_icon": icon_data is not None,
            "icon_base64": icon_data,
            "silent_arguments": silent_args,
        })

    # WUB archives normally include both Wub.exe and Wub_x64.exe. Only expose
    # the executable matching the current OS; generic duplicate handling then
    # collapses any remaining copies of that same architecture.
    packages = _select_windows_update_blocker_variant(packages)

    # -------------------------------------------------------------
    # Deduplication Cluster Engine
    # -------------------------------------------------------------
    clusters: Dict[str, List[Dict[str, Any]]] = {}
    for p in packages:
        # For generic filenames (setup.exe), use folder name in deduplication key
        # so that e.g. "Acrobat Reader/setup.exe" and "VLC Player/setup.exe" are
        # treated as separate packages and NOT collapsed into one.
        file_stem_lower = os.path.splitext(p["filename"])[0].lower()
        _bare = re.sub(r'[_\-\.\s]*(x64|x86|64bit|32bit|v?[\d]+[\d\.]*)[_\-\.\s]*$', '', file_stem_lower)
        if _bare in _GENERIC_INSTALLER_STEMS and p.get("folder_name"):
            key = _normalize_package_identity(
                p["name"],
                p["folder_name"] + "_" + p["filename"]
            )
        else:
            key = _normalize_package_identity(p["name"], p["filename"])
        p["clean_identity"] = key
        clusters.setdefault(key, []).append(p)

    for key, group in clusters.items():
        if len(group) == 1:
            group[0]["is_duplicate"] = False
            group[0]["duplicate_of"] = None
            group[0]["duplicate_count"] = 0
            continue

        # Score candidates to pick the single canonical package
        def score_pkg(pkg: Dict[str, Any]) -> float:
            score = 0.0
            stem = os.path.splitext(pkg["filename"])[0]
            has_copy_pattern = bool(re.search(r'[\s_\-\.\(\[]*(?:copy|\(?\d+\)?|نسخه)[\s_\-\.\)\]]*$', stem, re.IGNORECASE))
            if not has_copy_pattern:
                score += 50.0
            if pkg.get("is_installed"):
                score += 100.0
            if pkg.get("is_valid"):
                score += 20.0
            if pkg.get("auto_install_supported"):
                score += 10.0
            # Higher size preference
            score += min(pkg.get("file_size_bytes", 0) / (1024 * 1024), 20.0)
            # Shallower path preference
            depth = pkg.get("relative_path", "").count("/")
            score -= depth * 2.0
            return score

        sorted_group = sorted(group, key=score_pkg, reverse=True)
        canonical = sorted_group[0]
        canonical["is_duplicate"] = False
        canonical["duplicate_of"] = None
        canonical["duplicate_count"] = len(group) - 1

        for dup in sorted_group[1:]:
            dup["is_duplicate"] = True
            dup["duplicate_of"] = canonical["id"]
            dup["duplicate_count"] = 0

    # Windows Update is a machine-wide state. Read it once and expose the same
    # verified state on every WUB executable (x86/x64) shown in the package list.
    wub_packages = [package for package in packages if _is_windows_update_blocker(package)]
    if wub_packages:
        update_state = _windows_update_service_status()
        state_known = update_state.get("start") is not None
        for package in wub_packages:
            package["windows_update_blocked"] = bool(update_state.get("disabled", False))
            package["windows_update_state_known"] = state_known

    # Sort alphabetically by display name
    packages.sort(key=lambda p: (p.get("is_duplicate", False), p["name"].lower()))

    total_packages = len(packages)
    valid_packages = len([p for p in packages if p.get("is_valid")])
    blocked_packages = total_packages - valid_packages
    installed_packages = len([p for p in packages if p.get("is_installed")])
    available_to_install = len([p for p in packages if p.get("install_allowed")])
    auto_installable = len([p for p in packages if p.get("auto_install_supported")])
    duplicate_packages = len([p for p in packages if p.get("is_duplicate")])
    manual_only = len([
        p for p in packages
        if p.get("install_allowed") and not p.get("auto_install_supported")
    ])

    return {
        "directory_exists": True,
        "packages_directory": pkg_dir,
        "packages": packages,
        "summary": {
            "total_packages": total_packages,
            "valid_packages": valid_packages,
            "blocked_packages": blocked_packages,
            "installed_packages": installed_packages,
            "available_to_install": available_to_install,
            "auto_installable": auto_installable,
            "manual_only": manual_only,
            "duplicate_packages": duplicate_packages,
        }
    }


def _find_package(data: Dict[str, Any], target_identifier: str) -> Optional[Dict[str, Any]]:
    target = (target_identifier or "").strip().replace("\\", "/").lower()
    if not target:
        return None
    for package in data.get("packages", []):
        candidates = {
            str(package.get("id") or "").lower(),
            str(package.get("relative_path") or "").replace("\\", "/").lower(),
            str(package.get("filename") or "").lower(),
            str(package.get("name") or "").lower(),
            str(package.get("folder_name") or "").lower(),
            str(package.get("clean_identity") or "").lower(),
        }
        if target in candidates or any(target == c or (len(target) >= 3 and target in c) for c in candidates if c):
            return package
    return None


def _manual_install_command(package: Dict[str, Any]) -> tuple[str, str]:
    path = os.path.abspath(package["full_path"])
    extension = os.path.splitext(path)[1].lower()
    if extension == ".msi":
        return os.path.join(os.environ.get("SystemRoot", r"C:\Windows"), "System32", "msiexec.exe"), subprocess.list2cmdline([
            "/i", path, "/norestart", "REBOOT=ReallySuppress"
        ])
    if extension == ".msp":
        return os.path.join(os.environ.get("SystemRoot", r"C:\Windows"), "System32", "msiexec.exe"), subprocess.list2cmdline([
            "/p", path, "/norestart", "REBOOT=ReallySuppress"
        ])
    if extension == ".msu":
        return os.path.join(os.environ.get("SystemRoot", r"C:\Windows"), "System32", "wusa.exe"), subprocess.list2cmdline([
            path, "/norestart"
        ])
    if extension in (".cmd", ".bat") or package.get("installer_type") == "office_cmd":
        return os.path.join(os.environ.get("SystemRoot", r"C:\Windows"), "System32", "cmd.exe"), f'/c "{path}"'
    # App Installer provides the appropriate interactive UI for AppX/MSIX.
    return path, ""


def _launch_elevated(executable: str, parameters: str, working_dir: str) -> tuple[bool, int, str]:
    """Launches one validated installer without invoking a command shell."""
    try:
        ctypes.set_last_error(0)
        result = ctypes.windll.shell32.ShellExecuteW(
            None,
            "runas",
            executable,
            parameters or None,
            working_dir,
            1,
        )
        if result > 32:
            return True, int(result), ""
        last_error = ctypes.get_last_error()
        if result == 5 or last_error == 1223:
            return False, 1223, "User cancelled the elevation request."
        return False, int(result), f"ShellExecute failed ({result}, Windows error {last_error})."
    except Exception as exc:
        return False, -1, str(exc)


def install_package(target_identifier: str, custom_dir: Optional[str] = None) -> Dict[str, Any]:
    """
    Launches a validated installer interactively. MSI/MSP packages always receive
    Windows Installer's no-restart policy; EXE/AppX installers retain their UI.
    """
    data = scan_packages(custom_dir)
    if not data.get("directory_exists"):
        return {
            "success": False,
            "message": "Software directory not found.",
            "exit_code": -1,
        }

    target_pkg = _find_package(data, target_identifier)

    if not target_pkg:
        return {
            "success": False,
            "message": f"Installer '{target_identifier}' was not found in the selected folder.",
            "exit_code": -1,
        }

    if not target_pkg.get("is_valid") or not target_pkg.get("manual_install_supported"):
        return {
            "success": False,
            "blocked": True,
            "message": target_pkg.get("validation_error") or "This file is not a validated installer and was blocked.",
            "exit_code": -2,
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
    executable, parameters = _manual_install_command(target_pkg)
    logger.info("Launching validated installer: %s %s", executable, parameters)
    launched, launch_code, launch_error = _launch_elevated(executable, parameters, working_dir)

    if launched:
        return {
            "success": True,
            "cancelled": False,
            "launched": True,
            "package_id": target_pkg.get("id"),
            "name": target_pkg.get("name"),
            "message": f"پنجره نصب {target_pkg.get('name')} باز شد. برنامه هیچ ری‌استارتی را تأیید نمی‌کند.",
        }

    return {
        "success": False,
        "cancelled": launch_code == 1223,
        "launched": False,
        "message": "عملیات نصب توسط کاربر لغو شد." if launch_code == 1223 else f"خطا در اجرای نصاب: {launch_error}",
        "exit_code": launch_code,
    }


# Switches that prevent automatic reboots
_NORESTART_SWITCHES = ["/NORESTART", "REBOOT=ReallySuppress", "/norestart", "--norestart", "/rs"]


def _guess_installer_type(exe_path: str) -> str:
    """Tries to detect installer type by examining the binary."""
    ext = os.path.splitext(exe_path)[1].lower()
    if ext in {".msi", ".msp", ".msu", ".msix", ".msixbundle", ".appx", ".appxbundle"}:
        return ext.lstrip(".")
    if ext != ".exe":
        return "unknown"

    if _is_portable_tool(exe_path):
        return "portable"

    fname = os.path.basename(exe_path).lower()
    parent = os.path.basename(os.path.dirname(exe_path)).lower()

    try:
        with open(exe_path, "rb") as f:
            data = f.read(1024 * 1024)  # Read first 1MB

            # Adobe / Acrobat (check early)
            if (b"Adobe Systems" in data or b"Adobe Setup" in data or
                b"Adobe Self Extractor" in data or b"AcroRead" in data or
                b"Acrobat" in data or "acrobat" in parent or "adobe" in parent):
                return "adobe"

            # Inno Setup (check first - avoids Delphi AnsiString nsis substring false positive)
            if (b"Inno Setup" in data or b"inno setup" in data.lower() or
                b"JR.Inno.Setup" in data or b"TSetupLanguage" in data or
                b"InnoCallback" in data or b"SetupLdr" in data or
                (b"TApplication" in data and b"TFolderTreeView" in data)):
                return "innosetup"

            # NSIS (Nullsoft) - use specific signatures
            if (b"NullsoftInst" in data or b"Nullsoft.NSIS" in data or
                b"~nsexec" in data or b"NSIS.Library" in data or b"\\NSIS\\" in data):
                return "nsis"

            # InstallShield
            if b"InstallShield" in data or b"InstallScript" in data or b"ISSetup" in data or b"ISBEW64" in data:
                return "installshield"

            # WiX / Burn
            if b"WixBurn" in data or b"BurnPipe" in data:
                return "wix"

            # 7-Zip SFX
            if b"7-Zip" in data or "7zip" in fname or "7-zip" in fname:
                return "7zip"

            # WinRAR SFX
            if b"WinRAR" in data or "winrar" in fname:
                return "winrar"

            # Google Chrome / Google Update
            if b"Google Update" in data or "chromesetup" in fname or "chrome" in fname:
                return "chrome"

            # VLC
            if "vlc" in fname or "vlc" in parent:
                return "vlc"

    except Exception:
        pass

    # Name-based fallbacks
    if "adobe" in fname or "acrobat" in fname or "acrobat" in parent or "adobe" in parent:
        return "adobe"
    if "7zip" in fname or "7-zip" in fname:
        return "7zip"
    if "winrar" in fname:
        return "winrar"
    if "chrome" in fname:
        return "chrome"
    if "vlc" in fname or "vlc" in parent:
        return "vlc"

    return "unknown"


def _get_silent_args(pkg: Dict[str, Any]) -> str:
    """
    Returns the best silent install arguments for a package.
    Priority: package.json silentArguments > installer type detection > generic /S
    Unknown executables deliberately return an empty value and stay manual-only.
    """
    # 1. If package.json defines silentArguments, use those
    silent_args = pkg.get("silent_arguments", "").strip()
    if silent_args:
        args_lower = silent_args.lower()
        has_norestart = any(sw.lower() in args_lower for sw in _NORESTART_SWITCHES)
        installer_type = pkg.get("installer_type") or _guess_installer_type(pkg.get("full_path", ""))
        if not has_norestart and installer_type in ("innosetup", "adobe", "wix"):
            silent_args += " /NORESTART"
        return silent_args

    # 2. Try to detect installer type
    exe_path = pkg.get("full_path", "")
    installer_type = pkg.get("installer_type") or _guess_installer_type(exe_path)

    if installer_type == "innosetup":
        return "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-"
    elif installer_type in ("nsis", "7zip", "vlc"):
        return "/S"
    elif installer_type == "winrar":
        return "/s"
    elif installer_type == "chrome":
        return "/silent /install"
    elif installer_type == "wix":
        return "/quiet /norestart"
    elif installer_type == "adobe":
        return "/sAll /rs /msi /norestart /quiet ALLUSERS=1 EULA_ACCEPT=YES"
    elif installer_type == "installshield":
        return '/s /v"/qn /norestart"'
    elif installer_type == "wise":
        return "/s"

    # 3. Name/product-based detection for popular applications
    fn_lower = os.path.basename(exe_path).lower()
    name_lower = str(pkg.get("name", "")).lower()
    combined = f"{fn_lower} {name_lower}"

    if "anydesk" in combined:
        return '--install "C:\\Program Files (x86)\\AnyDesk" --start-with-win --silent'
    elif "idm" in combined or "idman" in combined or "internet download manager" in combined:
        return "/skipdlgs"
    elif "telegram" in combined or "tsetup" in combined:
        return "/VERYSILENT /NORESTART /SP-"
    elif "firefox" in combined:
        return "-ms"
    elif "potplayer" in combined:
        return "/S"
    elif "teamviewer" in combined:
        return "/S"
    elif "foxit" in combined:
        return "/quiet /norestart"
    elif "notepad" in combined or "npp" in combined:
        return "/S"
    elif "git" in combined:
        return "/VERYSILENT /NORESTART"
    elif "python" in combined:
        return "/quiet InstallAllUsers=1 PrependPath=1"
    elif "node" in combined:
        return "/quiet /norestart"
    elif "zoom" in combined:
        return "/silent"

    # 4. Universal fallback switch for Windows installers
    return "/S"


SEE_MASK_NOCLOSEPROCESS = 0x00000040
ERROR_CANCELLED = 1223


class _SHELLEXECUTEINFOW(ctypes.Structure):
    _fields_ = [
        ("cbSize", wintypes.DWORD),
        ("fMask", wintypes.ULONG),
        ("hwnd", wintypes.HWND),
        ("lpVerb", wintypes.LPCWSTR),
        ("lpFile", wintypes.LPCWSTR),
        ("lpParameters", wintypes.LPCWSTR),
        ("lpDirectory", wintypes.LPCWSTR),
        ("nShow", ctypes.c_int),
        ("hInstApp", wintypes.HINSTANCE),
        ("lpIDList", wintypes.LPVOID),
        ("lpClass", wintypes.LPCWSTR),
        ("hkeyClass", wintypes.HKEY),
        ("dwHotKey", wintypes.DWORD),
        ("hIconOrMonitor", wintypes.HANDLE),
        ("hProcess", wintypes.HANDLE),
    ]


def _run_elevated_and_wait(command: List[str], working_dir: str, timeout_seconds: int, keywords: Optional[List[str]] = None) -> int:
    """Runs a command with elevation, launches auto-wizard autopilot, and returns its process exit code."""
    if not command:
        return -1

    # Start auto-pilot in background to automatically advance wizard dialogs (OK, Next, Agree, Finish, Reboot Later)
    from packages.auto_wizard import InstallerAutoPilot
    autopilot = InstallerAutoPilot(target_title_keywords=keywords or [], timeout_seconds=timeout_seconds)
    deadline = time.monotonic() + timeout_seconds

    try:
        is_admin = bool(ctypes.windll.shell32.IsUserAnAdmin())
    except Exception:
        is_admin = False

    if is_admin:
        try:
            process = subprocess.Popen(
                command,
                cwd=working_dir,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                **get_hidden_subprocess_kwargs(),
            )
            autopilot.add_pid(process.pid)
            autopilot.run_in_background()
            try:
                process.wait(timeout=timeout_seconds)
            except subprocess.TimeoutExpired:
                # Do not kill an installer halfway through a transaction.
                return -2
            wait_for_remaining = max(0.5, deadline - time.monotonic())
            autopilot.wait_for_children(wait_for_remaining)
            return int(process.returncode)
        finally:
            autopilot.stop()

    info = _SHELLEXECUTEINFOW()
    native_kernel = ctypes.windll.kernel32
    native_kernel.GetProcessId.argtypes = [wintypes.HANDLE]
    native_kernel.GetProcessId.restype = wintypes.DWORD
    native_kernel.WaitForSingleObject.argtypes = [wintypes.HANDLE, wintypes.DWORD]
    native_kernel.WaitForSingleObject.restype = wintypes.DWORD
    native_kernel.GetExitCodeProcess.argtypes = [wintypes.HANDLE, ctypes.POINTER(wintypes.DWORD)]
    native_kernel.CloseHandle.argtypes = [wintypes.HANDLE]
    info.cbSize = ctypes.sizeof(_SHELLEXECUTEINFOW)
    info.fMask = SEE_MASK_NOCLOSEPROCESS
    info.lpVerb = "runas"
    info.lpFile = command[0]
    info.lpParameters = subprocess.list2cmdline(command[1:])
    info.lpDirectory = working_dir
    info.nShow = 1

    ctypes.set_last_error(0)
    if not ctypes.windll.shell32.ShellExecuteExW(ctypes.byref(info)):
        autopilot.stop()
        error = ctypes.get_last_error() or ctypes.windll.kernel32.GetLastError()
        return ERROR_CANCELLED if error == ERROR_CANCELLED else -int(error or 1)
    if not info.hProcess:
        autopilot.stop()
        return 0

    try:
        try:
            pid = ctypes.windll.kernel32.GetProcessId(info.hProcess)
            if pid:
                autopilot.add_pid(pid)
                autopilot.run_in_background()
        except Exception:
            pass

        wait_result = ctypes.windll.kernel32.WaitForSingleObject(info.hProcess, timeout_seconds * 1000)
        if wait_result != 0:
            return -2
        exit_code = wintypes.DWORD()
        if not ctypes.windll.kernel32.GetExitCodeProcess(info.hProcess, ctypes.byref(exit_code)):
            return -3
        wait_for_remaining = max(0.5, deadline - time.monotonic())
        autopilot.wait_for_children(wait_for_remaining)
        return int(exit_code.value)
    finally:
        autopilot.stop()
        ctypes.windll.kernel32.CloseHandle(info.hProcess)


def _run_elevated_raw_and_wait(
    executable: str,
    parameters: str,
    working_dir: str,
    timeout_seconds: int,
) -> int:
    """Run an official uninstall command and wait for its process handle."""
    info = _SHELLEXECUTEINFOW()
    native_kernel = ctypes.windll.kernel32
    native_kernel.WaitForSingleObject.argtypes = [wintypes.HANDLE, wintypes.DWORD]
    native_kernel.WaitForSingleObject.restype = wintypes.DWORD
    native_kernel.GetExitCodeProcess.argtypes = [wintypes.HANDLE, ctypes.POINTER(wintypes.DWORD)]
    native_kernel.CloseHandle.argtypes = [wintypes.HANDLE]
    info.cbSize = ctypes.sizeof(_SHELLEXECUTEINFOW)
    info.fMask = SEE_MASK_NOCLOSEPROCESS
    info.lpVerb = "runas"
    info.lpFile = executable
    info.lpParameters = parameters or None
    info.lpDirectory = working_dir or None
    info.nShow = 1

    ctypes.set_last_error(0)
    if not ctypes.windll.shell32.ShellExecuteExW(ctypes.byref(info)):
        error = ctypes.get_last_error() or native_kernel.GetLastError()
        return ERROR_CANCELLED if error == ERROR_CANCELLED else -int(error or 1)
    if not info.hProcess:
        return 0

    try:
        wait_result = native_kernel.WaitForSingleObject(info.hProcess, timeout_seconds * 1000)
        if wait_result != 0:
            return -2
        exit_code = wintypes.DWORD()
        if not native_kernel.GetExitCodeProcess(info.hProcess, ctypes.byref(exit_code)):
            return -3
        return int(exit_code.value)
    finally:
        native_kernel.CloseHandle(info.hProcess)


def _silent_install_command(pkg: Dict[str, Any]) -> List[str]:
    path = os.path.abspath(pkg.get("full_path", ""))
    extension = os.path.splitext(path)[1].lower()
    system_root = os.environ.get("SystemRoot", r"C:\Windows")
    if extension == ".msi":
        return [os.path.join(system_root, "System32", "msiexec.exe"), "/i", path, "/qn", "/norestart", "REBOOT=ReallySuppress"]
    if extension == ".msp":
        return [os.path.join(system_root, "System32", "msiexec.exe"), "/p", path, "/qn", "/norestart", "REBOOT=ReallySuppress"]
    if extension == ".msu":
        return [os.path.join(system_root, "System32", "wusa.exe"), path, "/quiet", "/norestart"]
    if extension in {".msix", ".msixbundle", ".appx", ".appxbundle"}:
        escaped_path = path.replace("'", "''")
        script = f"$ErrorActionPreference='Stop'; Add-AppxPackage -LiteralPath '{escaped_path}'"
        return ["powershell.exe", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "RemoteSigned", "-Command", script]
    if extension == ".exe":
        silent_args = _get_silent_args(pkg)
        if not silent_args:
            return []
        try:
            parsed = shlex.split(silent_args, posix=False)
        except ValueError:
            return []
        return [path, *parsed]
    return []


def _is_windows_update_blocker(pkg: Dict[str, Any]) -> bool:
    haystack = " ".join(
        str(pkg.get(key, ""))
        for key in ("name", "filename", "relative_path", "full_path", "product_name")
    ).lower()
    compact = re.sub(r"[^a-z0-9]+", "", haystack)
    return "windowsupdateblocker" in compact or re.search(r"(?:^|[^a-z])wub(?:_x64)?\.exe", haystack) is not None


def _windows_update_service_status() -> Dict[str, Any]:
    status: Dict[str, Any] = {"service": "wuauserv", "running": None, "start": None}
    if os.name != "nt":
        return status
    try:
        query = subprocess.run(
            ["sc.exe", "query", "wuauserv"], capture_output=True, text=True,
            timeout=15, **get_hidden_subprocess_kwargs()
        )
        output = f"{query.stdout}\n{query.stderr}".lower()
        status["running"] = "running" in output
    except Exception:
        pass
    try:
        with winreg.OpenKey(
            winreg.HKEY_LOCAL_MACHINE,
            r"SYSTEM\CurrentControlSet\Services\wuauserv",
        ) as key:
            status["start"] = int(winreg.QueryValueEx(key, "Start")[0])
    except Exception:
        pass
    status["disabled"] = status.get("start") == 4 and status.get("running") is False
    return status


def _disable_windows_update_with_wub(
    pkg: Dict[str, Any], *, allow_home: bool = False, automatic: bool = False
) -> Dict[str, Any]:
    identity = get_windows_identity()
    if identity.get("is_home") and not allow_home:
        message = (
            f"{identity.get('label', 'Windows Home')} اورجینال است؛ بهتر است Windows Update باز بماند. "
            + ("اجرای خودکار WUB رد شد." if automatic else "برای ادامه، تأیید شما لازم است.")
        )
        return {
            "success": bool(automatic),
            "skipped": bool(automatic),
            "requires_confirmation": not automatic,
            "home_guard": True,
            "windows": identity,
            "message": message,
            "package_id": pkg.get("id"),
            "name": pkg.get("name", "Windows Update Blocker"),
        }

    executable = os.path.abspath(pkg.get("full_path", ""))
    if not os.path.isfile(executable):
        return {"success": False, "message": "فایل اجرایی Windows Update Blocker پیدا نشد."}
    try:
        # Official WUB switches: Disable service + Protect service settings.
        exit_code = _run_elevated_and_wait([executable, "/D", "/P"], os.path.dirname(executable), 90)
        state = _windows_update_service_status()
        state_known = state.get("start") is not None
        verified_disabled = bool(state.get("disabled", False))
        success = exit_code == 0 and (verified_disabled or not state_known)
        return {
            "success": success,
            "skipped": False,
            "exit_code": exit_code,
            "update_service": state,
            "windows_update_blocked": verified_disabled,
            "package_id": pkg.get("id"),
            "name": pkg.get("name", "Windows Update Blocker"),
            "message": (
                "Windows Update غیرفعال و تنظیمات سرویس محافظت شد؛ ری‌استارت انجام نمی‌شود."
                if success
                else f"Windows Update Blocker با کد {exit_code} پایان یافت، اما غیرفعال‌شدن سرویس تأیید نشد."
            ),
        }
    except Exception as exc:
        return {"success": False, "message": f"اجرای Windows Update Blocker ناموفق بود: {exc}"}


def _enable_windows_update_with_wub(pkg: Dict[str, Any]) -> Dict[str, Any]:
    """Enable Windows Update with WUB without forcing a restart."""
    executable = os.path.abspath(pkg.get("full_path", ""))
    if not os.path.isfile(executable):
        return {"success": False, "message": "فایل اجرایی Windows Update Blocker پیدا نشد."}
    try:
        exit_code = _run_elevated_and_wait([executable, "/E"], os.path.dirname(executable), 90)
        state = _windows_update_service_status()
        state_known = state.get("start") is not None
        verified_enabled = state_known and state.get("start") != 4
        success = exit_code == 0 and (verified_enabled or not state_known)
        return {
            "success": success,
            "skipped": False,
            "exit_code": exit_code,
            "update_service": state,
            "windows_update_blocked": bool(state.get("disabled", False)),
            "package_id": pkg.get("id"),
            "name": pkg.get("name", "Windows Update Blocker"),
            "message": (
                "Windows Update فعال شد؛ برای این عملیات ری‌استارت انجام نشد."
                if success
                else "فعال‌سازی Windows Update تأیید نشد؛ وضعیت سرویس را بررسی کنید."
            ),
        }
    except Exception as exc:
        return {"success": False, "message": f"فعال‌سازی Windows Update ناموفق بود: {exc}"}


def set_windows_update_state(
    target_identifier: str,
    *,
    enable: bool,
    custom_dir: Optional[str] = None,
    confirm_home_update_block: bool = False,
) -> Dict[str, Any]:
    """Set the requested Windows Update state using the selected WUB package."""
    data = scan_packages(custom_dir)
    target_pkg = _find_package(data, target_identifier)
    if not target_pkg or not _is_windows_update_blocker(target_pkg):
        return {"success": False, "message": "Windows Update Blocker در پوشه نرم‌افزارها پیدا نشد."}
    if enable:
        return _enable_windows_update_with_wub(target_pkg)
    return _disable_windows_update_with_wub(
        target_pkg,
        allow_home=confirm_home_update_block,
        automatic=False,
    )


def pin_package_to_taskbar(target_identifier: str, custom_dir: Optional[str] = None) -> Dict[str, Any]:
    data = scan_packages(custom_dir)
    pkg = _find_package(data, target_identifier)
    if not pkg:
        return {"success": False, "message": "برنامه برای ساخت میانبر Taskbar پیدا نشد."}
    executable = os.path.abspath(pkg.get("full_path", ""))
    if not os.path.isfile(executable):
        return {"success": False, "message": "فایل اجرایی برنامه پیدا نشد."}
    return pin_to_taskbar(pkg.get("name", "Program"), executable, icon=f"{executable},0")


def _install_office_automated(pkg: Dict[str, Any], timeout_seconds: int = 900) -> Dict[str, Any]:
    """Automates Setup_Office 2024.cmd execution by piping option '1' (All Products) and verifying installation."""
    cmd_path = os.path.abspath(pkg.get("full_path", ""))
    office_dir = os.path.dirname(cmd_path)
    if not os.path.isfile(cmd_path):
        return {
            "success": False,
            "message": f"فایل نصاب آفیس یافت نشد: {cmd_path}",
            "verified_installed": False,
            "exit_code": -1,
            "package_id": pkg.get("id"),
            "name": pkg.get("name", "Microsoft Office 2024"),
        }

    logger.info(f"[OfficeInstall] Starting automated Office 2024 install from: {cmd_path}")

    import tempfile
    temp_dir = tempfile.gettempdir()
    runner_path = os.path.join(temp_dir, "run_office_2024_auto.cmd")
    runner_content = (
        "@echo off\r\n"
        f"cd /d \"{office_dir}\"\r\n"
        f"(echo 1 & echo.) | \"{cmd_path}\"\r\n"
        "exit /b %ERRORLEVEL%\r\n"
    )
    try:
        with open(runner_path, "w", encoding="ascii", errors="ignore") as f:
            f.write(runner_content)
    except Exception as e:
        logger.warning(f"[OfficeInstall] Error writing runner script: {e}")
        runner_path = cmd_path

    try:
        exit_code = _run_elevated_and_wait([runner_path], office_dir, timeout_seconds=timeout_seconds)
    finally:
        if os.path.isfile(runner_path) and runner_path != cmd_path:
            try:
                os.remove(runner_path)
            except Exception:
                pass

    from software.office import detect_microsoft_office
    import time
    time.sleep(3)
    off_info = detect_microsoft_office()
    if off_info.get("installed"):
        ver = off_info.get("version", "")
        prod = off_info.get("product_name", "Microsoft Office 2024")
        shortcuts = ensure_office_desktop_shortcuts()
        return {
            "success": True,
            "skipped": False,
            "message": f"✓ {prod}" + (f" (نسخه {ver})" if ver else "") + " با موفقیت نصب و شناسایی شد.",
            "verified_installed": True,
            "installed_version": ver,
            "exit_code": exit_code,
            "reboot_required": False,
            "verification_state": "verified",
            "package_id": pkg.get("id"),
            "name": pkg.get("name", prod),
            "desktop_shortcuts": shortcuts,
        }
    elif exit_code == 0:
        shortcuts = ensure_office_desktop_shortcuts()
        return {
            "success": True,
            "skipped": False,
            "message": "عملیات نصب آفیس با موفقیت به پایان رسید.",
            "verified_installed": True,
            "installed_version": "2024",
            "exit_code": exit_code,
            "reboot_required": False,
            "verification_state": "exit_code_only",
            "package_id": pkg.get("id"),
            "name": pkg.get("name", "Microsoft Office 2024"),
            "desktop_shortcuts": shortcuts,
        }
    else:
        return {
            "success": False,
            "skipped": False,
            "message": f"نصب آفیس با کد خروجی {exit_code} به پایان رسید اما در سیستم تأیید نشد.",
            "verified_installed": False,
            "exit_code": exit_code,
            "reboot_required": False,
            "verification_state": "failed",
            "package_id": pkg.get("id"),
            "name": pkg.get("name", "Microsoft Office 2024"),
        }


def silent_install_package(target_identifier: str, custom_dir: Optional[str] = None, timeout_seconds: int = 300) -> Dict[str, Any]:
    """
    Installs a package SILENTLY (no GUI wizard), waits for completion, and verifies installation.
    Used by the batch auto-install queue.

    Args:
        target_identifier: Package ID, relative path, or filename
        custom_dir: Optional custom packages directory
        timeout_seconds: Max seconds to wait for installer to finish (default 5 min)

    Returns:
        {success, exit_code, verified_installed, installed_version, message, ...}
    """
    data = scan_packages(custom_dir)
    if not data.get("directory_exists"):
        return {
            "success": False,
            "message": "فولدر نرم‌افزارها یافت نشد.",
            "exit_code": -1,
            "verified_installed": False,
        }

    target_pkg = _find_package(data, target_identifier)

    if not target_pkg:
        return {
            "success": False,
            "message": f"بسته '{target_identifier}' یافت نشد.",
            "exit_code": -1,
            "verified_installed": False,
        }

    if _is_windows_update_blocker(target_pkg):
        return _disable_windows_update_with_wub(target_pkg, automatic=True)

    # Special handling for Microsoft Office automation
    if target_pkg.get("installer_type") == "office_cmd" or "setup_office" in os.path.basename(target_pkg.get("full_path", "")).lower():
        if target_pkg.get("is_installed"):
            shortcuts = ensure_office_desktop_shortcuts()
            return {
                "success": True,
                "skipped": True,
                "message": f"آفیس قبلاً نصب شده است. {shortcuts.get('message', '')}",
                "verified_installed": True,
                "desktop_shortcuts": shortcuts,
                "package_id": target_pkg.get("id"),
                "name": target_pkg.get("name"),
            }
        return _install_office_automated(target_pkg, timeout_seconds=max(timeout_seconds, 900))

    # Skip if already installed
    if target_pkg.get("is_installed"):
        return {
            "success": True,
            "skipped": True,
            "message": f"{target_pkg.get('name')} قبلاً نصب شده است.",
            "verified_installed": True,
            "installed_version": target_pkg.get("installed_version", ""),
            "package_id": target_pkg.get("id"),
            "name": target_pkg.get("name"),
        }

    if not target_pkg.get("is_valid"):
        return {
            "success": False,
            "blocked": True,
            "message": target_pkg.get("validation_error") or "فایل مشکوک است و اجازه اجرا ندارد.",
            "exit_code": -2,
            "verified_installed": False,
        }

    if not target_pkg.get("auto_install_supported"):
        return {
            "success": False,
            "manual_required": True,
            "message": f"نوع نصب خودکار {target_pkg.get('name')} شناخته‌شده نیست؛ لطفاً نصب دستی را انتخاب کنید.",
            "exit_code": -4,
            "verified_installed": False,
            "package_id": target_pkg.get("id"),
            "name": target_pkg.get("name"),
        }

    full_path = target_pkg.get("full_path")
    pkg_dir = data.get("packages_directory")

    if not _is_safe_path(pkg_dir, full_path) or not os.path.isfile(full_path):
        return {
            "success": False,
            "message": f"مسیر فایل نامعتبر: {full_path}",
            "exit_code": -1,
            "verified_installed": False,
        }

    abs_path = os.path.abspath(full_path)
    working_dir = os.path.dirname(abs_path)
    pkg_name = target_pkg.get("name", target_identifier)
    command = _silent_install_command(target_pkg)
    if not command:
        return {
            "success": False,
            "manual_required": True,
            "message": f"برای {pkg_name} سوییچ نصب خودکار امن پیدا نشد؛ نصب دستی لازم است.",
            "exit_code": -4,
            "verified_installed": False,
            "package_id": target_pkg.get("id"),
            "name": pkg_name,
        }

    logger.info("[BatchInstall] Installing validated package: %s | Command: %s", pkg_name, command[0])

    exit_code = -1
    install_error = ""

    keywords = [pkg_name, target_pkg.get("filename", ""), target_pkg.get("folder_name", "")]

    try:
        exit_code = _run_elevated_and_wait(command, working_dir, timeout_seconds, keywords=keywords)

    except subprocess.TimeoutExpired:
        install_error = f"نصب {pkg_name} پس از {timeout_seconds} ثانیه تایم‌اوت شد."
        logger.warning(f"[BatchInstall] Timeout for {pkg_name} after {timeout_seconds}s")
    except Exception as e:
        install_error = f"خطا در نصب {pkg_name}: {str(e)}"
        logger.error(f"[BatchInstall] Error installing {pkg_name}: {e}")

    # Verify installation by re-scanning registry
    import time
    time.sleep(2)  # Allow uninstall/app-path registration to settle.

    verified = False
    installed_version = ""

    try:
        detection = _detect_installed_package(
            get_all_installed_registry_apps(),
            pkg_name,
            target_pkg.get("filename", ""),
            pkg_name,
            target_pkg.get("publisher", ""),
            target_pkg.get("detection_id"),
        )
        verified = bool(detection["is_installed"])
        installed_version = detection["installed_version"]
    except Exception as e:
        logger.debug(f"[BatchInstall] Verification error: {e}")

    success_exit_codes = {0, 3010, 1638}
    success = verified or exit_code in success_exit_codes
    reboot_required = exit_code == 3010

    if success and verified:
        msg = f"✓ {pkg_name} با موفقیت نصب شد." + (f" (نسخه {installed_version})" if installed_version else "")
    elif success and not verified:
        msg = f"⚠ نصب {pkg_name} اجرا شد (کد خروج: {exit_code}) اما در رجیستری تأیید نشد."
    elif install_error:
        msg = install_error
    else:
        msg = f"✗ نصب {pkg_name} ناموفق بود (کد خروج: {exit_code})."

    logger.info(f"[BatchInstall] Result for {pkg_name}: success={success}, verified={verified}, exit_code={exit_code}")

    return {
        "success": success,
        "skipped": False,
        "exit_code": exit_code,
        "verified_installed": verified,
        "installed_version": installed_version,
        "reboot_required": reboot_required,
        "verification_state": "verified" if verified else ("exit_code_only" if success else "failed"),
        "package_id": target_pkg.get("id"),
        "name": pkg_name,
        "message": msg,
    }


def open_package(
    target_identifier: str,
    custom_dir: Optional[str] = None,
    *,
    confirm_home_update_block: bool = False,
) -> Dict[str, Any]:
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

    if _is_windows_update_blocker(target_pkg):
        return _disable_windows_update_with_wub(
            target_pkg,
            allow_home=confirm_home_update_block,
            automatic=False,
        )

    exe_path = target_pkg.get("installed_exe_path")
    if not exe_path or not os.path.isfile(exe_path):
        full_path = target_pkg.get("full_path")
        if full_path and os.path.isfile(full_path):
            exe_path = full_path

    if exe_path and os.path.isfile(exe_path):
        work_dir = os.path.dirname(exe_path)
        try:
            ret = ctypes.windll.shell32.ShellExecuteW(None, "runas", exe_path, "", work_dir, 1)
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


def open_office_folder(custom_dir: Optional[str] = None) -> Dict[str, Any]:
    """
    Finds and opens the Microsoft Office folder inside the configured/selected packages directory
    or common disk locations in Windows Explorer.
    Matches variations such as 'office', 'microsoft office', 'office 2024', 'office 2021', 'آفیس', etc.
    """
    pkg_dir = get_packages_directory(custom_dir)
    if not pkg_dir or not os.path.isdir(pkg_dir):
        return {
            "success": False,
            "message": "فولدر نرم‌افزارها مشخص یا موجود نیست.",
        }

    office_keywords = [
        "office",
        "آفیس",
        "microsoft office",
        "office 2024",
        "office2024",
        "office 2021",
        "office2021",
        "office 2019",
        "office2019",
        "office 2016",
        "office2016",
        "msoffice",
        "ms office",
        "مایکروسافت آفیس",
    ]

    matched_folder = None

    # 1. Search directly inside pkg_dir
    try:
        for entry in os.listdir(pkg_dir):
            full_entry = os.path.join(pkg_dir, entry)
            if os.path.isdir(full_entry):
                entry_lower = entry.lower()
                if any(kw in entry_lower for kw in office_keywords):
                    matched_folder = full_entry
                    break
    except Exception as e:
        logger.warning(f"Error scanning directories in {pkg_dir}: {e}")

    # 2. Search 1 level deeper inside subdirectories if not found
    if not matched_folder:
        try:
            for root, dirs, _ in os.walk(pkg_dir):
                rel = os.path.relpath(root, pkg_dir)
                depth = len(rel.split(os.sep)) if rel != "." else 0
                if depth > 2:
                    continue
                for d in dirs:
                    d_lower = d.lower()
                    if any(kw in d_lower for kw in office_keywords):
                        matched_folder = os.path.join(root, d)
                        break
                if matched_folder:
                    break
        except Exception as e:
            logger.warning(f"Error recursive scanning for office in {pkg_dir}: {e}")

    # 3. Check parent directory of pkg_dir
    if not matched_folder:
        try:
            parent_dir = os.path.dirname(pkg_dir)
            if parent_dir and os.path.isdir(parent_dir):
                for entry in os.listdir(parent_dir):
                    full_entry = os.path.join(parent_dir, entry)
                    if os.path.isdir(full_entry):
                        entry_lower = entry.lower()
                        if any(kw in entry_lower for kw in office_keywords):
                            matched_folder = full_entry
                            break
        except Exception:
            pass

    target_to_open = matched_folder if matched_folder else pkg_dir
    is_direct_match = matched_folder is not None

    try:
        os.startfile(target_to_open)
        if is_direct_match:
            return {
                "success": True,
                "found": True,
                "path": target_to_open,
                "message": f"پوشه آفیس ({os.path.basename(target_to_open)}) باز شد.",
            }
        else:
            return {
                "success": True,
                "found": False,
                "path": target_to_open,
                "message": "پوشه اختصاصی آفیس یافت نشد؛ پوشه اصلی نرم‌افزارها باز شد.",
            }
    except Exception as e:
        try:
            subprocess.Popen(["explorer.exe", target_to_open])
            return {
                "success": True,
                "found": is_direct_match,
                "path": target_to_open,
                "message": f"پوشه {os.path.basename(target_to_open)} باز شد.",
            }
        except Exception as e2:
            return {
                "success": False,
                "message": f"خطا در باز کردن پوشه: {str(e2)}",
            }


def uninstall_package(target_identifier: str, custom_dir: Optional[str] = None) -> Dict[str, Any]:
    """
    Uninstalls an installed application using its Windows registry UninstallString.
    Searches HKLM (64/32-bit) and HKCU for matching display name, then runs the
    uninstaller with admin elevation via ShellExecuteW("runas").
    """
    # First, find the package name from our scanned packages
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
        return {"success": False, "message": f"بسته {target_identifier} یافت نشد."}

    pkg_name = target_pkg.get("name", target_identifier)

    if not target_pkg.get("is_installed", False):
        return {"success": False, "message": f"{pkg_name} روی سیستم نصب نیست."}

    # Resolve the installed application's official registry entry. Never use
    # the setup file from Packages as an uninstaller.
    known_key = _known_detection_key(
        pkg_name,
        target_pkg.get("filename", ""),
        target_pkg.get("publisher", ""),
        target_pkg.get("detection_id", ""),
    )
    aliases = [
        pkg_name,
        target_pkg.get("matched_app_name", ""),
        target_pkg.get("product_name", ""),
    ]
    if known_key:
        aliases.extend(_KNOWN_PACKAGE_DETECTION[known_key].get("aliases", []))
    uninstall_entry = _find_uninstall_entry(
        pkg_name,
        aliases=aliases,
        publisher=target_pkg.get("publisher", ""),
        install_location=target_pkg.get("install_location", ""),
    )

    if not uninstall_entry:
        opened = _open_installed_apps_settings()
        return {
            "success": opened,
            "manual_required": opened,
            "message": (
                f"حذف‌کنندهٔ مطمئن برای {pkg_name} پیدا نشد؛ بخش Installed Apps ویندوز برای حذف دستی باز شد."
                if opened
                else f"رشته حذف (UninstallString) برای {pkg_name} در رجیستری ویندوز یافت نشد."
            ),
        }

    uninstall_cmd = uninstall_entry["command"]
    logger.info(f"Uninstalling {pkg_name} via: {uninstall_cmd}")

    try:
        exe_path, args = _build_uninstall_invocation(uninstall_entry)

        work_dir = os.path.dirname(exe_path) if os.path.exists(os.path.dirname(exe_path)) else ""

        exit_code = _run_elevated_raw_and_wait(
            exe_path,
            args,
            work_dir,
            timeout_seconds=300,
        )

        if exit_code == ERROR_CANCELLED:
            return {
                "success": False,
                "cancelled": True,
                "message": f"عملیات حذف {pkg_name} توسط کاربر لغو شد.",
            }
        if exit_code == -2:
            return {
                "success": False,
                "timed_out": True,
                "message": f"زمان انتظار برای حذف {pkg_name} تمام شد؛ فرآیند در حال اجرا رها شد تا حذف ناقص نشود.",
            }
        if exit_code not in (0, 3010):
            return {
                "success": False,
                "exit_code": exit_code,
                "message": f"حذف {pkg_name} با کد {exit_code} به پایان رسید و موفق تأیید نشد.",
            }

        verified = _wait_for_uninstall_registration_removal(
            pkg_name,
            aliases=aliases,
            publisher=target_pkg.get("publisher", ""),
            install_location=target_pkg.get("install_location", ""),
        )
        if not verified:
            return {
                "success": False,
                "verified_uninstalled": False,
                "exit_code": exit_code,
                "message": f"حذف‌کننده {pkg_name} بسته شد، اما برنامه هنوز در ویندوز ثبت شده است.",
            }

        return {
            "success": True,
            "verified_uninstalled": True,
            "exit_code": exit_code,
            "reboot_required": exit_code == 3010,
            "message": f"✓ {pkg_name} به‌طور کامل حذف و نتیجه در ویندوز تأیید شد.",
        }

    except Exception as e:
        logger.error(f"Uninstall error for {pkg_name}: {e}")
        return {
            "success": False,
            "message": f"خطا در حذف {pkg_name}: {str(e)}",
        }


_MSI_PRODUCT_CODE_RE = re.compile(
    r"^\{[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}\}$",
    re.IGNORECASE,
)


def _split_uninstall_command(command: str) -> tuple[str, str]:
    """Split a Windows uninstall command without breaking unquoted EXE paths."""
    stripped = os.path.expandvars(command.strip())
    if not stripped:
        raise ValueError("فرمان حذف خالی است.")
    if stripped.startswith('"'):
        end_quote = stripped.find('"', 1)
        if end_quote < 0:
            raise ValueError("مسیر نقل‌قول‌شدهٔ حذف‌کننده ناقص است.")
        return stripped[1:end_quote], stripped[end_quote + 1:].strip()

    msi_match = re.match(r"(?i)^\s*(?:[^\s]*\\)?msiexec(?:\.exe)?\b(.*)$", stripped)
    if msi_match:
        return "msiexec.exe", msi_match.group(1).strip()

    exe_match = re.match(r"(?is)^\s*(.+?\.exe)\b(.*)$", stripped)
    if exe_match:
        return exe_match.group(1).strip(' "'), exe_match.group(2).strip()

    parts = stripped.split(" ", 1)
    return parts[0].strip('"'), parts[1].strip() if len(parts) > 1 else ""


def _detect_uninstaller_family(exe_path: str) -> str:
    """Identify well-known uninstall engines from the executable itself."""
    if not exe_path or not os.path.isfile(exe_path):
        return ""

    try:
        # NSIS launchers keep one of these signatures in the executable image.
        # Limiting the read keeps this check cheap even for unusually large files.
        with open(exe_path, "rb") as executable:
            image = executable.read(16 * 1024 * 1024).lower()
        if b"nullsoft" in image or b"nsis" in image:
            return "nsis"
    except OSError as exc:
        logger.debug("Could not inspect uninstaller %s: %s", exe_path, exc)

    return ""


def _build_uninstall_invocation(entry: Dict[str, Any]) -> tuple[str, str]:
    """Build a safe, no-restart invocation from an official uninstall entry."""
    command = str(entry.get("command") or "").strip()
    product_code = str(entry.get("product_code") or "").strip()
    windows_installer = bool(entry.get("windows_installer"))
    exe_path, args = _split_uninstall_command(command)
    is_msiexec = os.path.basename(exe_path).lower() in {"msiexec", "msiexec.exe"}

    if windows_installer and _MSI_PRODUCT_CODE_RE.fullmatch(product_code):
        target = product_code
    elif is_msiexec:
        product_match = re.search(
            r"\{[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}\}",
            args,
            re.IGNORECASE,
        )
        target = product_match.group(0) if product_match else ""
    else:
        target = ""

    if windows_installer or is_msiexec:
        system_root = os.environ.get("SystemRoot", r"C:\Windows")
        exe_path = os.path.join(system_root, "System32", "msiexec.exe")
        if target:
            # Vendors such as Adobe register /I (maintenance) instead of /X.
            # Product-code based /X reliably performs an uninstall.
            args = subprocess.list2cmdline([
                "/x",
                target,
                "/passive",
                "/norestart",
                "REBOOT=ReallySuppress",
            ])
        else:
            args = re.sub(
                r"(?i)(^|\s)/i(?=\s|\{|\"|$)",
                r"\1/x",
                args,
                count=1,
            )
            if not re.search(r"(?i)(^|\s)/(?:quiet|qn|qb|passive)\b", args):
                args += " /passive"
            if not re.search(r"(?i)(^|\s)/norestart\b", args):
                args += " /norestart"
            if "REBOOT=" not in args.upper():
                args += " REBOOT=ReallySuppress"
    elif _detect_uninstaller_family(exe_path) == "nsis":
        # NSIS uses the case-sensitive /S switch for a fully unattended
        # uninstall. Normalize an incorrectly-cased token if one was stored.
        if re.search(r"(?i)(^|\s)/s(?=\s|$)", args):
            args = re.sub(r"(?i)(^|\s)/s(?=\s|$)", r"\1/S", args, count=1)
        else:
            args = f"/S {args}".strip()

    return exe_path, args.strip()


def _wait_for_uninstall_registration_removal(
    display_name: str,
    *,
    aliases: Optional[List[str]] = None,
    publisher: str = "",
    install_location: str = "",
    timeout_seconds: float = 15.0,
) -> bool:
    """Poll Windows ARP registration until removal is verifiably complete."""
    deadline = time.monotonic() + max(timeout_seconds, 0.0)
    while True:
        remaining = _find_uninstall_entry(
            display_name,
            aliases=aliases,
            publisher=publisher,
            install_location=install_location,
        )
        if remaining is None:
            return True
        if time.monotonic() >= deadline:
            return False
        time.sleep(0.5)


_UNINSTALL_NAME_SUFFIX_RE = re.compile(
    r"\s*[\(\[]\s*(?:remove|uninstall)\s+only\s*[\)\]]\s*$",
    re.IGNORECASE,
)


def _canonical_uninstall_name(value: str) -> str:
    """Normalize safe ARP qualifiers without reducing names to substrings."""
    value = _UNINSTALL_NAME_SUFFIX_RE.sub("", value or "")
    value = re.sub(r"\s+-\s+[a-z]{2}(?:-[a-z]{2})?\s*$", "", value, flags=re.IGNORECASE)
    value = re.sub(r"\bprofessional\b", "pro", value, flags=re.IGNORECASE)
    return _normalize_identity(value)


def _uninstall_match_score(
    candidate: Dict[str, Any],
    aliases: List[str],
    publisher: str = "",
    install_location: str = "",
) -> int:
    candidate_name = str(candidate.get("display_name") or "")
    candidate_raw = candidate_name.casefold().strip()
    candidate_canonical = _canonical_uninstall_name(candidate_name)
    candidate_tokens = _identity_tokens(candidate_canonical)
    score = 0

    for alias in aliases:
        if not alias:
            continue
        alias_raw = str(alias).casefold().strip()
        alias_canonical = _canonical_uninstall_name(str(alias))
        alias_tokens = _identity_tokens(alias_canonical)
        if alias_raw == candidate_raw:
            score = max(score, 1000)
        elif alias_canonical and alias_canonical == candidate_canonical:
            score = max(score, 950)
        elif alias_tokens and alias_tokens == candidate_tokens:
            score = max(score, 900)
        elif (
            len(alias_tokens) >= 2
            and alias_tokens.issubset(candidate_tokens)
            and candidate_tokens - alias_tokens <= {"remove", "only", "uninstall"}
        ):
            score = max(score, 850)

    if score == 0:
        return 0

    publisher_tokens = _identity_tokens(publisher)
    candidate_publisher_tokens = _identity_tokens(str(candidate.get("publisher") or ""))
    if publisher_tokens and publisher_tokens & candidate_publisher_tokens:
        score += 30

    wanted_location = os.path.normcase(os.path.normpath(install_location)) if install_location else ""
    candidate_location = str(candidate.get("install_location") or "")
    normalized_location = os.path.normcase(os.path.normpath(candidate_location)) if candidate_location else ""
    if wanted_location and normalized_location and wanted_location == normalized_location:
        score += 50
    return score


def _open_installed_apps_settings() -> bool:
    try:
        os.startfile("ms-settings:appsfeatures")
        return True
    except Exception:
        try:
            subprocess.Popen(["explorer.exe", "ms-settings:appsfeatures"])
            return True
        except Exception:
            return False


def _find_uninstall_entry(
    app_display_name: str,
    aliases: Optional[List[str]] = None,
    publisher: str = "",
    install_location: str = "",
) -> Optional[Dict[str, Any]]:
    """
    Find the exact installed-app registry entry and its official uninstall data.
    """
    roots = [
        (winreg.HKEY_LOCAL_MACHINE, r"Software\Microsoft\Windows\CurrentVersion\Uninstall", winreg.KEY_WOW64_64KEY),
        (winreg.HKEY_LOCAL_MACHINE, r"Software\Microsoft\Windows\CurrentVersion\Uninstall", winreg.KEY_WOW64_32KEY),
        (winreg.HKEY_CURRENT_USER, r"Software\Microsoft\Windows\CurrentVersion\Uninstall", 0),
    ]

    match_aliases = [app_display_name]
    match_aliases.extend(value for value in (aliases or []) if value)
    candidates: List[Dict[str, Any]] = []

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

                            if get_val("SystemComponent") == "1" or get_val("NoRemove") == "1":
                                continue
                            quiet = get_val("QuietUninstallString")
                            uninstall = get_val("UninstallString")
                            command = quiet or uninstall
                            if command:
                                entry = {
                                    "command": command,
                                    "display_name": dname,
                                    "publisher": get_val("Publisher"),
                                    "install_location": get_val("InstallLocation"),
                                    "product_code": kname,
                                    "windows_installer": get_val("WindowsInstaller") == "1",
                                    "quiet": bool(quiet),
                                }
                                score = _uninstall_match_score(
                                    entry,
                                    match_aliases,
                                    publisher=publisher,
                                    install_location=install_location,
                                )
                                if score:
                                    entry["match_score"] = score
                                    candidates.append(entry)
                    except Exception:
                        pass
        except Exception:
            pass

    if not candidates:
        return None
    candidates.sort(key=lambda item: int(item["match_score"]), reverse=True)
    best = candidates[0]
    if len(candidates) > 1:
        second = candidates[1]
        if (
            int(second["match_score"]) == int(best["match_score"])
            and second["command"] != best["command"]
        ):
            logger.warning(
                "Ambiguous uninstall match for %s: %s and %s",
                app_display_name,
                best["display_name"],
                second["display_name"],
            )
            return None
    return best


def _find_uninstall_string(app_display_name: str) -> Optional[str]:
    """Compatibility wrapper returning only the registered command."""
    entry = _find_uninstall_entry(app_display_name)
    return str(entry["command"]) if entry else None
