import logging
import os
import subprocess
import winreg
from typing import Dict, Any, List

logger = logging.getLogger(__name__)

def check_pending_reboot() -> Dict[str, Any]:
    """
    Checks if Windows or installed drivers / updates are requesting a system reboot.
    Inspects standard Windows reboot pending registry keys:
    1. Component Based Servicing (CBS) RebootPending
    2. Windows Update RebootRequired
    3. Session Manager PendingFileRenameOperations
    4. Driver / Netlogon / ServerManager pending flags
    """
    reasons: List[str] = []
    details: List[str] = []

    # 1. CBS Reboot Pending
    try:
        with winreg.OpenKey(
            winreg.HKEY_LOCAL_MACHINE,
            r"SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending"
        ):
            reasons.append("نصب بسته‌ها و کامپوننت‌های ویندوز")
            details.append("CBS_RebootPending")
    except Exception:
        pass

    # 2. Windows Update Reboot Required
    try:
        with winreg.OpenKey(
            winreg.HKEY_LOCAL_MACHINE,
            r"SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"
        ):
            reasons.append("آپدیت‌های سیستمی و درایورها")
            details.append("WU_RebootRequired")
    except Exception:
        pass

    # 3. Pending File Rename Operations (only for real driver .sys files)
    try:
        with winreg.OpenKey(
            winreg.HKEY_LOCAL_MACHINE,
            r"SYSTEM\CurrentControlSet\Control\Session Manager"
        ) as key:
            val, _ = winreg.QueryValueEx(key, "PendingFileRenameOperations")
            if val and isinstance(val, (list, tuple)):
                driver_renames = [v for v in val if isinstance(v, str) and (v.lower().endswith(".sys") or "\\drivers\\" in v.lower())]
                if driver_renames:
                    reasons.append("جایگزینی فایل‌های درایور سیستمی")
                    details.append("PendingFileRenameOperations_Drivers")
    except Exception:
        pass

    # 4. ComputerName pending rename or Netlogon
    try:
        with winreg.OpenKey(
            winreg.HKEY_LOCAL_MACHINE,
            r"SYSTEM\CurrentControlSet\Control\ComputerName\ActiveComputerName"
        ) as active_key:
            active_name, _ = winreg.QueryValueEx(active_key, "ComputerName")
            with winreg.OpenKey(
                winreg.HKEY_LOCAL_MACHINE,
                r"SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName"
            ) as comp_key:
                comp_name, _ = winreg.QueryValueEx(comp_key, "ComputerName")
                if active_name != comp_name:
                    reasons.append("تغییر نام سیستم")
                    details.append("ComputerNamePending")
    except Exception:
        pass

    is_pending = len(reasons) > 0

    return {
        "reboot_required": is_pending,
        "reasons": reasons,
        "details": details,
        "summary": "جهت اعمال و شناسایی کامل درایورها و برنامه‌ها، ری‌استارت سیستم پیشنهاد می‌شود." if is_pending else "سیستم نیازی به ری‌استارت ندارد.",
        "summary_en": "System restart is recommended to finalize drivers and system changes." if is_pending else "No restart required."
    }


def _enable_shutdown_privilege() -> bool:
    """Enables SeShutdownPrivilege for the current process using ctypes."""
    try:
        import ctypes
        from ctypes import wintypes

        SE_SHUTDOWN_NAME = "SeShutdownPrivilege"
        TOKEN_ADJUST_PRIVILEGES = 0x0020
        TOKEN_QUERY = 0x0008
        SE_PRIVILEGE_ENABLED = 0x00000002

        class LUID(ctypes.Structure):
            _fields_ = [("LowPart", wintypes.DWORD), ("HighPart", wintypes.LONG)]

        class LUID_AND_ATTRIBUTES(ctypes.Structure):
            _fields_ = [("Luid", LUID), ("Attributes", wintypes.DWORD)]

        class TOKEN_PRIVILEGES(ctypes.Structure):
            _fields_ = [("PrivilegeCount", wintypes.DWORD), ("Privileges", LUID_AND_ATTRIBUTES * 1)]

        advapi32 = ctypes.windll.advapi32
        kernel32 = ctypes.windll.kernel32

        hToken = wintypes.HANDLE()
        if not advapi32.OpenProcessToken(
            kernel32.GetCurrentProcess(),
            TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY,
            ctypes.byref(hToken)
        ):
            return False

        luid = LUID()
        if not advapi32.LookupPrivilegeValueW(None, SE_SHUTDOWN_NAME, ctypes.byref(luid)):
            kernel32.CloseHandle(hToken)
            return False

        tp = TOKEN_PRIVILEGES()
        tp.PrivilegeCount = 1
        tp.Privileges[0].Luid = luid
        tp.Privileges[0].Attributes = SE_PRIVILEGE_ENABLED

        res = advapi32.AdjustTokenPrivileges(
            hToken,
            False,
            ctypes.byref(tp),
            ctypes.sizeof(TOKEN_PRIVILEGES),
            None,
            None
        )
        kernel32.CloseHandle(hToken)
        return bool(res)
    except Exception as e:
        logger.warning(f"Could not adjust shutdown privilege: {e}")
        return False


def execute_system_restart(delay_seconds: int = 4, reason_msg: str = "") -> Dict[str, Any]:
    """
    Initiates a guaranteed, safe system restart with multi-tier fallbacks:
    1. C:\\Windows\\System32\\shutdown.exe /r /t <delay> /f
    2. PowerShell Restart-Computer -Force
    3. Win32 API ExitWindowsEx (EWX_REBOOT | EWX_FORCE)
    """
    delay = max(0, int(delay_seconds))
    system32 = os.path.join(os.environ.get("SystemRoot", "C:\\Windows"), "System32")
    shutdown_exe = os.path.join(system32, "shutdown.exe")
    if not os.path.isfile(shutdown_exe):
        shutdown_exe = "shutdown.exe"

    errors = []

    # Attempt 1: shutdown.exe /r /t <delay> /f
    try:
        # Note: Do not pass non-ASCII /c flags to shutdown.exe as it fails on various Windows codepages
        cmd = [shutdown_exe, "/r", "/t", str(delay), "/f"]
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=8)
        if proc.returncode == 0:
            logger.info(f"System restart scheduled successfully in {delay} seconds via shutdown.exe")
            return {
                "success": True,
                "message": f"سیستم تا {delay} ثانیه دیگر ری‌استارت می‌شود...",
                "delay_seconds": delay,
            }
        else:
            err_msg = (proc.stderr or proc.stdout or f"Exit code {proc.returncode}").strip()
            errors.append(f"shutdown.exe error: {err_msg}")
            logger.warning(f"shutdown.exe failed: {err_msg}")
    except Exception as e:
        errors.append(f"shutdown.exe exception: {e}")

    # Attempt 2: PowerShell Restart-Computer -Force
    try:
        ps_cmd = ["powershell.exe", "-NoProfile", "-NonInteractive", "-Command", "Restart-Computer -Force"]
        proc = subprocess.run(ps_cmd, capture_output=True, text=True, timeout=8)
        if proc.returncode == 0:
            logger.info("System restart initiated via PowerShell Restart-Computer")
            return {
                "success": True,
                "message": "سیستم در حال ری‌استارت است...",
                "delay_seconds": 1,
            }
        else:
            err_msg = (proc.stderr or proc.stdout or f"Exit code {proc.returncode}").strip()
            errors.append(f"PowerShell error: {err_msg}")
    except Exception as e:
        errors.append(f"PowerShell exception: {e}")

    # Attempt 3: Win32 API ExitWindowsEx
    try:
        _enable_shutdown_privilege()
        import ctypes
        EWX_REBOOT = 0x00000002
        EWX_FORCE = 0x00000004
        EWX_FORCEIFHUNG = 0x00000010
        SHTDN_REASON_MAJOR_OTHER = 0x00010000
        SHTDN_REASON_FLAG_PLANNED = 0x40000000

        flags = EWX_REBOOT | EWX_FORCEIFHUNG | EWX_FORCE
        reason = SHTDN_REASON_MAJOR_OTHER | SHTDN_REASON_FLAG_PLANNED
        res = ctypes.windll.user32.ExitWindowsEx(flags, reason)
        if res:
            logger.info("System restart initiated via ExitWindowsEx")
            return {
                "success": True,
                "message": "سیستم در حال ری‌استارت است...",
                "delay_seconds": 1,
            }
        else:
            err_code = ctypes.windll.kernel32.GetLastError()
            errors.append(f"ExitWindowsEx error code: {err_code}")
    except Exception as e:
        errors.append(f"Win32 API exception: {e}")

    # Attempt 4: Immediate shutdown /r /t 0 /f
    try:
        cmd = [shutdown_exe, "/r", "/t", "0", "/f"]
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=5)
        if proc.returncode == 0:
            return {
                "success": True,
                "message": "سیستم در حال ری‌استارت است...",
                "delay_seconds": 0,
            }
    except Exception:
        pass

    return {
        "success": False,
        "message": "خطا در اجرای ری‌استارت خودکار سیستم. لطفاً به صورت دستی سیستم را ری‌استارت کنید.",
        "details": errors,
    }


def cancel_system_restart() -> Dict[str, Any]:
    """
    Cancels any scheduled system restart (shutdown.exe /a).
    """
    try:
        system32 = os.path.join(os.environ.get("SystemRoot", "C:\\Windows"), "System32")
        shutdown_exe = os.path.join(system32, "shutdown.exe")
        if not os.path.isfile(shutdown_exe):
            shutdown_exe = "shutdown.exe"

        cmd = [shutdown_exe, "/a"]
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=8)
        is_ok = proc.returncode == 0
        return {
            "success": is_ok,
            "message": "دستور ری‌استارت سیستم با موفقیت لغو شد." if is_ok else "دستور ری‌استارت فعالی جهت لغو یافت نشد.",
        }
    except Exception as e:
        return {
            "success": False,
            "message": f"خطا در لغو ری‌استارت: {str(e)}",
        }
