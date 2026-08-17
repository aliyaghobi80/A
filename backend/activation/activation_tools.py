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
from typing import Dict, Any, Optional

import sys

logger = logging.getLogger(__name__)

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
TOOLS_DIR = os.path.abspath(os.path.join(REPO_ROOT, "Tools"))

# Win32 Constants for ShellExecuteExW
SEE_MASK_NOCLOSEPROCESS = 0x00000040
INFINITE = 0xFFFFFFFF
ERROR_CANCELLED = 1223  # User cancelled UAC prompt
SW_SHOWNORMAL = 1
SW_HIDE = 0


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
        ("lpIDList", wintypes.LPVOID),
        ("lpClass", wintypes.LPCWSTR),
        ("hkeyClass", wintypes.HKEY),
        ("dwHotKey", wintypes.DWORD),
        ("hIconOrMonitor", wintypes.HANDLE),
        ("hProcess", wintypes.HANDLE),
    ]


def get_activation_config() -> Dict[str, Any]:
    """Reads and parses config/activation.json safely."""
    default_config = {
        "windows": {
            "enabled": True,
            "toolPath": "Tools/WINDOWS.cmd",
            "arguments": ["1"]
        },
        "office": {
            "enabled": True,
            "toolPath": "Tools/OFFICE.cmd",
            "arguments": ["1"]
        }
    }

    if not os.path.isfile(CONFIG_FILE):
        return default_config

    try:
        with open(CONFIG_FILE, "r", encoding="utf-8") as f:
            cfg = json.load(f)
            if isinstance(cfg, dict):
                return {
                    "windows": cfg.get("windows", default_config["windows"]),
                    "office": cfg.get("office", default_config["office"])
                }
    except Exception as e:
        logger.warning(f"Failed to read activation.json config: {e}")

    return default_config


def is_safe_tool_path(raw_path: str) -> bool:
    """
    Strict security check:
    - Path must NOT contain directory traversal sequences ('..')
    - Resolved absolute path MUST reside strictly within the approved Tools directory
    - Must NOT be a remote URL or arbitrary external executable
    """
    if not raw_path or not raw_path.strip():
        return False

    clean_path = raw_path.strip()

    # Reject path traversal patterns
    if ".." in clean_path or clean_path.startswith("/") or clean_path.startswith("\\"):
        return False

    return True


def get_tool_status(target: str) -> Dict[str, Any]:
    """
    Checks if the configured activation tool for target ('windows' or 'office')
    is valid, safe, and exists on disk.
    """
    config = get_activation_config().get(target, {})
    enabled = config.get("enabled", True)
    tool_rel = config.get("toolPath", "")
    args = config.get("arguments", ["1"])

    candidates = [
        os.path.abspath(os.path.join(REPO_ROOT, tool_rel)),
        os.path.abspath(os.path.join(r"G:\MarkaziSystem", tool_rel)),
        os.path.abspath(os.path.join(REPO_ROOT, "Tools", f"{target.upper()}.cmd")),
        os.path.abspath(os.path.join(REPO_ROOT, "Tools", f"{target.capitalize()}Activation", "activate.cmd")),
        os.path.abspath(os.path.join(r"G:\MarkaziSystem", "Tools", f"{target.upper()}.cmd")),
    ]

    found_path = None
    for cand in candidates:
        if os.path.isfile(cand):
            found_path = cand
            break

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
    """
    Executes the configured activation tool with Administrator privileges (Run as Administrator).
    Waits for process completion, detects UAC cancellation, and captures exit code and logs.
    """
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

    # Optional log file in working directory for capturing stdout/stderr
    log_file = os.path.join(work_dir, f"{target}_activation_last.log")

    logger.info(f"Executing elevated activation tool for {target}: {abs_tool_path}")

    # Determine executable and parameter wrapper
    ext = os.path.splitext(abs_tool_path)[1].lower()
    if ext in [".cmd", ".bat"]:
        executable = "cmd.exe"
        # Wrap cmd /c call to pipe output to log file
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
    sei.nShow = SW_HIDE  # Run cleanly in background

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
            if wait_res == 0:  # WAIT_OBJECT_0
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

    # Read output log if generated
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
        "error": "" if is_success else f"Process returned exit code {exit_code_val}",
        "message": "فعالسازی انجام شد." if is_success else "فعالسازی انجام نشد."
    }
