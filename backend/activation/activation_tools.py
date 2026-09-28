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
import re
import tempfile
import time
from typing import Dict, Any, Optional, List, Callable
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
    """Allow executable tools only inside the bundled or user-selected KMS folder."""
    if not tool_path or not tool_path.strip():
        return False
    abs_p = os.path.realpath(os.path.abspath(tool_path))
    if not os.path.isfile(abs_p):
        return False
    ext = os.path.splitext(abs_p)[1].lower()
    if ext not in [".cmd", ".bat", ".ps1", ".exe"]:
        return False

    allowed_roots = [os.path.realpath(DEFAULT_TOOLS_DIR)]
    custom_dir = get_activation_config().get("customToolsDir")
    if custom_dir and os.path.isdir(custom_dir):
        allowed_roots.append(os.path.realpath(os.path.abspath(custom_dir)))

    # Also allow activation scripts discovered in active Packages / PROGRAM folder
    try:
        from packages.manager import get_packages_directory
        pkg_dir = get_packages_directory()
        if pkg_dir and os.path.isdir(pkg_dir):
            allowed_roots.append(os.path.realpath(os.path.abspath(pkg_dir)))
    except Exception:
        pass

    candidate = os.path.normcase(abs_p)
    for root in allowed_roots:
        try:
            if os.path.commonpath([candidate, os.path.normcase(root)]) == os.path.normcase(root):
                return True
        except ValueError:
            # Different Windows drives cannot share a common path.
            continue
    return False


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


def _read_activation_log(log_file: str) -> str:
    if not log_file or not os.path.isfile(log_file):
        return ""
    try:
        with open(log_file, "r", encoding="utf-8", errors="replace") as stream:
            return stream.read().strip()
    except OSError:
        return ""


def _build_batch_input(values: List[str]) -> bytes:
    """Build deterministic stdin for a menu script and its final ``pause``.

    KMS v6 consumes the first line as its menu choice and later waits at
    ``Press any key to continue``.  A second, harmless line is queued on the
    same stdin stream so the owned hidden console can finish by itself.
    """
    safe_values = [
        str(value)
        for value in values
        if re.fullmatch(r"[A-Za-z0-9_.-]+", str(value))
    ]
    if not safe_values:
        safe_values = ["1"]
    safe_values.append("x")
    return ("\r\n".join(safe_values) + "\r\n").encode("ascii")


def _build_batch_command_parameters(
    script_path: str,
    input_path: str,
    log_path: str,
) -> str:
    return (
        f'/d /s /c call "{os.path.abspath(script_path)}" '
        f'< "{os.path.abspath(input_path)}" '
        f'> "{os.path.abspath(log_path)}" 2>&1'
    )


def execute_elevated_batch_script(
    script_path: str,
    *,
    input_values: Optional[List[str]] = None,
    timeout_seconds: int = 180,
    log_file: Optional[str] = None,
    status_probe: Optional[Callable[[], bool]] = None,
) -> Dict[str, Any]:
    """Run one trusted CMD/BAT with UAC, deterministic stdin and a hard wait.

    The function does not claim success merely because a licensing probe turns
    positive: it keeps ownership of the process until the script consumes its
    final ``pause`` input and exits.  This prevents an invisible command window
    from being left behind after activation.
    """
    abs_script = os.path.abspath(script_path or "")
    if not os.path.isfile(abs_script):
        return {
            "success": False,
            "cancelled": False,
            "timed_out": False,
            "exit_code": -1,
            "output": "",
            "error": "Activation script was not found.",
            "message": "اسکریپت فعال‌سازی پیدا نشد.",
        }

    work_dir = os.path.dirname(abs_script)
    log_path = os.path.abspath(
        log_file
        or os.path.join(
            tempfile.gettempdir(),
            f"markazi_activation_{os.getpid()}_{int(time.time() * 1000)}.log",
        )
    )
    input_path = ""
    process_handle = None
    kernel32 = None
    observed_status = False
    prompt_seen = False

    try:
        fd, input_path = tempfile.mkstemp(
            prefix="markazi_activation_input_",
            suffix=".txt",
        )
        with os.fdopen(fd, "wb") as input_stream:
            input_stream.write(_build_batch_input(input_values or ["1"]))

        # /c consumes the rest of the command line. Keeping the script, input,
        # and log paths individually quoted avoids the fragile nested quoting
        # used by the older ``(echo 1) | call ...`` implementation.
        parameters = _build_batch_command_parameters(
            abs_script,
            input_path,
            log_path,
        )

        sei = SHELLEXECUTEINFOW()
        sei.cbSize = ctypes.sizeof(SHELLEXECUTEINFOW)
        sei.fMask = SEE_MASK_NOCLOSEPROCESS
        sei.hwnd = None
        sei.lpVerb = "runas"
        sei.lpFile = "cmd.exe"
        sei.lpParameters = parameters
        sei.lpDirectory = work_dir
        sei.nShow = SW_HIDE

        shell32 = ctypes.windll.shell32
        kernel32 = ctypes.windll.kernel32
        shell32.ShellExecuteExW.argtypes = [ctypes.POINTER(SHELLEXECUTEINFOW)]
        shell32.ShellExecuteExW.restype = wintypes.BOOL
        kernel32.WaitForSingleObject.argtypes = [wintypes.HANDLE, wintypes.DWORD]
        kernel32.WaitForSingleObject.restype = wintypes.DWORD
        kernel32.GetExitCodeProcess.argtypes = [
            wintypes.HANDLE,
            ctypes.POINTER(wintypes.DWORD),
        ]
        kernel32.GetExitCodeProcess.restype = wintypes.BOOL
        kernel32.TerminateProcess.argtypes = [wintypes.HANDLE, wintypes.UINT]
        kernel32.TerminateProcess.restype = wintypes.BOOL
        kernel32.CloseHandle.argtypes = [wintypes.HANDLE]
        kernel32.CloseHandle.restype = wintypes.BOOL

        if not shell32.ShellExecuteExW(ctypes.byref(sei)):
            error_code = ctypes.GetLastError()
            cancelled = error_code == ERROR_CANCELLED
            return {
                "success": False,
                "cancelled": cancelled,
                "timed_out": False,
                "exit_code": error_code,
                "output": _read_activation_log(log_path),
                "error": (
                    "User cancelled UAC elevation."
                    if cancelled
                    else f"Failed to launch elevated process (error {error_code})."
                ),
                "message": (
                    "فعال‌سازی لغو شد."
                    if cancelled
                    else "اجرای اسکریپت با دسترسی مدیر انجام نشد."
                ),
            }

        process_handle = sei.hProcess
        if not process_handle:
            return {
                "success": False,
                "cancelled": False,
                "timed_out": False,
                "exit_code": -1,
                "output": _read_activation_log(log_path),
                "error": "ShellExecuteEx did not return a process handle.",
                "message": "پردازش فعال‌سازی قابل پیگیری نیست.",
            }

        deadline = time.monotonic() + max(1, timeout_seconds)
        process_exited = False
        while time.monotonic() < deadline:
            wait_result = kernel32.WaitForSingleObject(process_handle, 750)
            output = _read_activation_log(log_path)
            output_lower = output.lower()
            prompt_seen = prompt_seen or any(
                marker in output_lower
                for marker in (
                    "press any key",
                    "any key to continue",
                    "برای ادامه",
                )
            )
            if status_probe is not None and not observed_status:
                try:
                    observed_status = bool(status_probe())
                except Exception:
                    pass
            if wait_result == 0:  # WAIT_OBJECT_0
                process_exited = True
                break

        if not process_exited:
            logger.warning(
                "Elevated activation script timed out after %s seconds: %s",
                timeout_seconds,
                abs_script,
            )
            kernel32.TerminateProcess(process_handle, 1)
            kernel32.WaitForSingleObject(process_handle, 3000)
            return {
                "success": False,
                "cancelled": False,
                "timed_out": True,
                "exit_code": -2,
                "output": _read_activation_log(log_path),
                "status_observed": observed_status,
                "completion_prompt_seen": prompt_seen,
                "error": "Activation script timed out.",
                "message": "اسکریپت فعال‌سازی در زمان تعیین‌شده بسته نشد.",
            }

        exit_code_buffer = wintypes.DWORD()
        kernel32.GetExitCodeProcess(
            process_handle,
            ctypes.byref(exit_code_buffer),
        )
        exit_code = int(exit_code_buffer.value)
        return {
            "success": exit_code == 0,
            "cancelled": False,
            "timed_out": False,
            "exit_code": exit_code,
            "output": _read_activation_log(log_path),
            "status_observed": observed_status,
            "completion_prompt_seen": prompt_seen,
            "error": None if exit_code == 0 else f"Script exited with code {exit_code}.",
            "message": (
                "اسکریپت فعال‌سازی کامل شد."
                if exit_code == 0
                else "اسکریپت فعال‌سازی با خطا بسته شد."
            ),
        }
    except Exception as exc:
        logger.exception("Elevated activation script failed: %s", exc)
        return {
            "success": False,
            "cancelled": False,
            "timed_out": False,
            "exit_code": -1,
            "output": _read_activation_log(log_path),
            "status_observed": observed_status,
            "completion_prompt_seen": prompt_seen,
            "error": str(exc),
            "message": f"خطا در اجرای اسکریپت فعال‌سازی: {exc}",
        }
    finally:
        if process_handle and kernel32 is not None:
            try:
                kernel32.CloseHandle(process_handle)
            except Exception:
                pass
        if input_path:
            try:
                os.remove(input_path)
            except OSError:
                pass


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

    # Never rely solely on disabled UI controls. A stale frontend, batch
    # worker, or direct API call must still be unable to run an activator on
    # Windows 10/11 Home.
    from windows.device_settings import get_windows_identity
    identity = get_windows_identity()
    if identity.get("is_home") is True:
        label = str(identity.get("label") or "Windows Home")
        return {
            "success": False,
            "skipped": True,
            "blocked": True,
            "home_guard": True,
            "cancelled": False,
            "exit_code": 0,
            "output": "",
            "error": "Activation is disabled by the Windows Home policy.",
            "windows": identity,
            "message": f"{label} اورجینال شناسایی شد؛ ابزار فعال‌سازی اجرا نشد.",
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
    if not is_safe_tool_path(abs_tool_path):
        logger.error("Rejected activation tool outside the authorized tools directory: %s", abs_tool_path)
        return {
            "success": False,
            "cancelled": False,
            "exit_code": -1,
            "output": "",
            "error": "Activation tool path is outside the authorized tools directory.",
            "message": "مسیر ابزار فعال‌سازی مجاز نیست.",
        }
    work_dir = os.path.dirname(abs_tool_path)
    args_list = status.get("arguments", [])
    args_str = " ".join(f'"{a}"' if " " in str(a) else str(a) for a in args_list)

    log_file = os.path.join(work_dir, f"{target}_activation_last.log")
    logger.info(f"Executing elevated activation tool for {target}: {abs_tool_path}")

    ext = os.path.splitext(abs_tool_path)[1].lower()
    if ext in [".cmd", ".bat"]:
        result = execute_elevated_batch_script(
            abs_tool_path,
            input_values=[str(value) for value in args_list],
            timeout_seconds=timeout_seconds,
            log_file=log_file,
        )
        result["message"] = (
            f"عملیات فعال‌سازی {target} انجام شد."
            if result.get("success")
            else result.get("message")
            or f"خطا در اجرای اسکریپت فعال‌سازی {target}."
        )
        return result
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

    shell32 = ctypes.windll.shell32
    kernel32 = ctypes.windll.kernel32
    shell32.ShellExecuteExW.argtypes = [ctypes.POINTER(SHELLEXECUTEINFOW)]
    shell32.ShellExecuteExW.restype = wintypes.BOOL
    kernel32.WaitForSingleObject.argtypes = [wintypes.HANDLE, wintypes.DWORD]
    kernel32.WaitForSingleObject.restype = wintypes.DWORD
    kernel32.GetExitCodeProcess.argtypes = [wintypes.HANDLE, ctypes.POINTER(wintypes.DWORD)]
    kernel32.CloseHandle.argtypes = [wintypes.HANDLE]
    success = shell32.ShellExecuteExW(ctypes.byref(sei))

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
            wait_res = kernel32.WaitForSingleObject(h_process, timeout_ms)
            if wait_res == 0:
                exit_code_buf = wintypes.DWORD()
                kernel32.GetExitCodeProcess(h_process, ctypes.byref(exit_code_buf))
                exit_code_val = exit_code_buf.value
            else:
                logger.warning(f"Process timed out after {timeout_seconds} seconds")
                exit_code_val = -2
        finally:
            kernel32.CloseHandle(h_process)
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
