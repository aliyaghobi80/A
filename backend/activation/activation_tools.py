# backend/activation/activation_tools.py
"""
Activation Tools Manager
Handles secure configuration, path validation, and Administrator elevation (UAC)
for corporate Windows and Microsoft Office activation scripts.
"""

import os
import json
import ctypes
from ctypes import wintypes
import subprocess
import logging
from typing import Dict, Any, Optional, List
import sys

logger = logging.getLogger(__name__)

EXTERNAL_ACTIVATION_TOOLS_ENABLED = True

def _find_repo_root() -> str:
    """Finds the root repository folder containing config/ and Tools/."""
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
        if os.path.isdir(os.path.join(c, "Tools")) or os.path.isdir(os.path.join(c, "config")):
            return c
    return curr

REPO_ROOT = _find_repo_root()
CONFIG_FILE = os.path.join(REPO_ROOT, "config", "activation.json")
DEFAULT_TOOLS_DIR = os.path.abspath(os.path.join(REPO_ROOT, "Tools"))

def is_safe_tool_path(tool_path: str) -> bool:
    """Validates that tool path exists and is a supported script/binary."""
    if not tool_path:
        return False
    abs_p = os.path.abspath(tool_path)
    if not os.path.isfile(abs_p):
        return False
    ext = os.path.splitext(abs_p)[1].lower()
    return ext in [".cmd", ".bat", ".ps1", ".exe"]


# Win32 Constants for ShellExecuteExW
SEE_MASK_NOCLOSEPROCESS = 0x00000040
SW_HIDE = 0
SW_SHOWNORMAL = 1
ERROR_CANCELLED = 1223  # User clicked "No" on UAC prompt

class SHELLEXECUTEINFOW(ctypes.Structure):
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
        ("lpIDList", ctypes.c_void_p),
        ("lpClass", wintypes.LPCWSTR),
        ("hkeyClass", wintypes.HKEY),
        ("dwHotKey", wintypes.DWORD),
        ("hIcon", wintypes.HANDLE),
        ("hProcess", wintypes.HANDLE),
    ]


def get_activation_config() -> Dict[str, Any]:
    """Loads activation tools configuration from config/activation.json or defaults."""
    if os.path.isfile(CONFIG_FILE):
        try:
            with open(CONFIG_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception as e:
            logger.warning(f"Error reading {CONFIG_FILE}: {e}")

    return {
        "windows": {
            "enabled": True,
            "toolPath": "Tools/WINDOWS.cmd",
            "arguments": ["1"],
            "description": "Windows OEM / Digital License Activation Script"
        },
        "office": {
            "enabled": True,
            "toolPath": "Tools/OFFICE.cmd",
            "arguments": ["1"],
            "description": "Microsoft Office Corporate Activation Script"
        },
        "customToolsDir": None
    }


def get_current_tools_directory() -> str:
    """Returns the active Tools directory (custom or default)."""
    cfg = get_activation_config()
    custom = cfg.get("customToolsDir")
    if custom and os.path.isdir(custom):
        return os.path.abspath(custom)
    if os.path.isdir(DEFAULT_TOOLS_DIR):
        return DEFAULT_TOOLS_DIR
    return DEFAULT_TOOLS_DIR


def scan_tools_directory(target_dir: Optional[str] = None) -> List[Dict[str, Any]]:
    """Scans the tools directory for executable activation scripts."""
    active_dir = target_dir or get_current_tools_directory()
    if not os.path.isdir(active_dir):
        return []

    valid_extensions = {".cmd", ".bat", ".ps1", ".exe"}
    discovered = []

    for root, _, files in os.walk(active_dir):
        for f in files:
            ext = os.path.splitext(f)[1].lower()
            if ext in valid_extensions:
                full_p = os.path.abspath(os.path.join(root, f))
                rel_p = os.path.relpath(full_p, active_dir).replace("\\", "/")
                
                # Assign friendly Persian descriptions
                desc = "ابزار فعال‌سازی سیستم"
                f_lower = f.lower()
                if "win" in f_lower:
                    desc = "اسکریپت فعال‌سازی ویندوز"
                elif "off" in f_lower:
                    desc = "اسکریپت فعال‌سازی آفیس"
                elif "mas" in f_lower or "kms" in f_lower:
                    desc = "مجموعه ابزار فعال‌سازی چندمنظوره"

                discovered.append({
                    "name": f,
                    "relative_path": rel_p,
                    "full_path": full_p,
                    "extension": ext.lstrip(".").upper(),
                    "description": desc,
                    "status_text": "آماده",
                    "is_valid": True,
                })

    return discovered


def get_tools_directory_status() -> Dict[str, Any]:
    """Returns full status of the tools directory for UI presentation."""
    active_dir = get_current_tools_directory()
    is_conf = os.path.isdir(active_dir)
    tools = scan_tools_directory(active_dir) if is_conf else []

    return {
        "success": True,
        "tools_directory": active_dir,
        "is_configured": is_conf and len(tools) > 0,
        "total_tools": len(tools),
        "tools": tools,
    }


def set_tools_directory(custom_dir: str) -> Dict[str, Any]:
    """Updates and persists the active Tools / KMS activation directory."""
    if not custom_dir or not os.path.isdir(custom_dir):
        return {"success": False, "message": f"Directory does not exist: {custom_dir}"}

    abs_dir = os.path.abspath(custom_dir)
    cfg = get_activation_config()

    # Search for Windows and Office tools in custom directory using fuzzy match
    win_tool = _find_best_tool(abs_dir, "windows") or os.path.join(abs_dir, "Window.cmd")
    off_tool = _find_best_tool(abs_dir, "office") or win_tool or os.path.join(abs_dir, "OFFICE.cmd")

    if "windows" not in cfg:
        cfg["windows"] = {}
    if "office" not in cfg:
        cfg["office"] = {}

    cfg["windows"]["toolPath"] = win_tool if os.path.isfile(win_tool) else os.path.join(abs_dir, "WINDOWS.cmd")
    cfg["office"]["toolPath"] = off_tool if os.path.isfile(off_tool) else os.path.join(abs_dir, "OFFICE.cmd")
    cfg["customToolsDir"] = abs_dir

    try:
        os.makedirs(os.path.dirname(CONFIG_FILE), exist_ok=True)
        with open(CONFIG_FILE, "w", encoding="utf-8") as f:
            json.dump(cfg, f, indent=2)
    except Exception as e:
        logger.warning(f"Failed to write activation.json: {e}")

    tools = scan_tools_directory(abs_dir)

    return {
        "success": True,
        "tools_directory": abs_dir,
        "is_configured": len(tools) > 0,
        "total_tools": len(tools),
        "tools": tools,
        "windows_tool": cfg["windows"]["toolPath"],
        "office_tool": cfg["office"]["toolPath"],
    }



def _find_best_tool(target_dir: str, target: str) -> Optional[str]:
    """Finds the best matching script in target_dir for target ('windows' or 'office')."""
    if not os.path.isdir(target_dir):
        return None

    target = target.lower()
    discovered_files = []
    for root, _, files in os.walk(target_dir):
        for f in files:
            ext = os.path.splitext(f)[1].lower()
            if ext in [".cmd", ".bat", ".ps1", ".exe"]:
                discovered_files.append(os.path.abspath(os.path.join(root, f)))

    if not discovered_files:
        return None

    # Priority matches
    if target == "windows":
        priority_names = [
            "window.cmd", "windows.cmd", "win.cmd", "activate.cmd", "mas_aio.cmd",
            "mas.cmd", "kms.cmd", "kms_vl_all.cmd", "kmsauto.exe", "kmsauto.cmd",
            "window.bat", "windows.bat", "win.bat", "activate.bat"
        ]
    else:
        priority_names = [
            "office.cmd", "off.cmd", "office_activation.cmd", "activate_office.cmd",
            "mas_aio.cmd", "mas.cmd", "kms.cmd", "kms_vl_all.cmd", "kmsauto.exe",
            "office.bat", "off.bat"
        ]

    for p_name in priority_names:
        for f_path in discovered_files:
            if os.path.basename(f_path).lower() == p_name:
                return f_path

    # Secondary token matching
    for f_path in discovered_files:
        b_name = os.path.basename(f_path).lower()
        if (target == "windows" and ("win" in b_name or "kms" in b_name or "mas" in b_name)) or \
           (target == "office" and ("off" in b_name or "kms" in b_name or "mas" in b_name)):
            return f_path

    # Fallback to first .cmd/.bat if only one exists
    cmd_files = [f for f in discovered_files if f.lower().endswith((".cmd", ".bat"))]
    if len(cmd_files) == 1:
        return cmd_files[0]

    return discovered_files[0] if discovered_files else None

def get_tool_status(target: str) -> Dict[str, Any]:
    """Checks if the configured activation tool for target is valid and available."""
    config = get_activation_config().get(target, {})
    enabled = config.get("enabled", True)
    tool_rel = config.get("toolPath", "")
    args = config.get("arguments", ["1"])

    found_path = None
    curr_tools_dir = get_current_tools_directory()

    if tool_rel:
        abs_t = tool_rel if os.path.isabs(tool_rel) else os.path.abspath(os.path.join(REPO_ROOT, tool_rel))
        if os.path.isfile(abs_t):
            found_path = abs_t

    if not found_path and os.path.isdir(curr_tools_dir):
        found_path = _find_best_tool(curr_tools_dir, target)

    if not found_path and os.path.isdir(DEFAULT_TOOLS_DIR):
        found_path = _find_best_tool(DEFAULT_TOOLS_DIR, target)

    exists = found_path is not None

    return {
        "enabled": enabled and exists,
        "available": exists,
        "tool_path": (found_path or tool_rel).replace("\\", "/"),
        "absolute_path": found_path,
        "arguments": args,
        "error": None if exists else "Activation tool not found on disk"
    }


def execute_activation_tool(target: str, timeout_seconds: int = 180) -> Dict[str, Any]:
    """Executes the configured activation tool with Administrator privileges (UAC)."""
    target = target.lower().strip()
    if target not in ["windows", "office"]:
        return {
            "success": False,
            "cancelled": False,
            "exit_code": -1,
            "output": "",
            "error": f"Invalid activation target '{target}'.",
            "message": "هدف فعالسازی نامعتبر است."
        }

    status = get_tool_status(target)
    if not status.get("available") or not status.get("absolute_path"):
        err_msg = status.get("error") or "ابزار فعالسازی پیدا نشد."
        return {
            "success": False,
            "cancelled": False,
            "exit_code": -1,
            "output": "",
            "error": err_msg,
            "message": "ابزار فعالسازی پیدا نشد."
        }

    abs_tool_path = status["absolute_path"]
    work_dir = os.path.dirname(abs_tool_path)
    args_list = status.get("arguments", [])
    args_str = " ".join(f'"{a}"' if " " in str(a) else str(a) for a in args_list)

    log_file = os.path.join(work_dir, f"{target}_activation_last.log")
    logger.info(f"Executing elevated activation tool for {target}: {abs_tool_path}")

    ext = os.path.splitext(abs_tool_path)[1].lower()
    if ext in [".cmd", ".bat"]:
        executable = "cmd.exe"
        log_redirect = f' > "{log_file}" 2>&1'
        parameters = f'/c ""{abs_tool_path}" {args_str}{log_redirect}"'
    elif ext == ".ps1":
        executable = "powershell.exe"
        log_redirect = f' *>&1 | Out-File -FilePath "{log_file}" -Encoding UTF8'
        parameters = f'-NoProfile -ExecutionPolicy Bypass -Command "& \'{abs_tool_path}\' {args_str}{log_redirect}"'
    else:
        executable = abs_tool_path
        parameters = args_str

    sei = SHELLEXECUTEINFOW()
    sei.cbSize = ctypes.sizeof(SHELLEXECUTEINFOW)
    sei.fMask = SEE_MASK_NOCLOSEPROCESS
    sei.hwnd = None
    sei.lpVerb = "runas"  # Request Admin Elevation / UAC
    sei.lpFile = executable
    sei.lpParameters = parameters
    sei.lpDirectory = work_dir
    sei.nShow = SW_HIDE

    success = ctypes.windll.shell32.ShellExecuteExW(ctypes.byref(sei))

    if not success:
        err = ctypes.GetLastError()
        if err == ERROR_CANCELLED:
            logger.info(f"User cancelled UAC elevation for {target} activation.")
            return {
                "success": False,
                "cancelled": True,
                "exit_code": 1223,
                "output": "",
                "error": "User cancelled UAC elevation.",
                "message": "فعالسازی لغو شد."
            }
        logger.error(f"ShellExecuteExW failed with error code {err}")
        return {
            "success": False,
            "cancelled": False,
            "exit_code": err,
            "output": "",
            "error": f"Failed to launch elevated process (error {err}).",
            "message": "فعالسازی انجام نشد."
        }

    h_process = sei.hProcess
    exit_code_val = -1

    if h_process:
        try:
            timeout_ms = timeout_seconds * 1000
            wait_res = ctypes.windll.kernel32.WaitForSingleObject(h_process, timeout_ms)
            if wait_res == 0:
                exit_code_buf = wintypes.DWORD()
                ctypes.windll.kernel32.GetExitCodeProcess(h_process, ctypes.byref(exit_code_buf))
                exit_code_val = exit_code_buf.value
            else:
                logger.warning(f"Process timed out after {timeout_seconds} seconds")
                exit_code_val = -2
        finally:
            ctypes.windll.kernel32.CloseHandle(h_process)
    else:
        exit_code_val = 0

    output_text = ""
    if os.path.isfile(log_file):
        try:
            with open(log_file, "r", encoding="utf-8", errors="replace") as f:
                output_text = f.read().strip()
        except Exception:
            pass

    is_success = (exit_code_val == 0)

    return {
        "success": is_success,
        "cancelled": False,
        "exit_code": exit_code_val,
        "output": output_text,
        "message": f"عملیات فعال‌سازی {target} انجام شد." if is_success else f"خطا در اجرای اسکریپت فعال‌سازی {target}."
    }
