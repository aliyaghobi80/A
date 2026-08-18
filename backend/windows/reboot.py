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

    # 3. Pending File Rename Operations (e.g. driver .sys / .dll replacements)
    try:
        with winreg.OpenKey(
            winreg.HKEY_LOCAL_MACHINE,
            r"SYSTEM\CurrentControlSet\Control\Session Manager"
        ) as key:
            val, _ = winreg.QueryValueEx(key, "PendingFileRenameOperations")
            if val and len(val) > 0:
                reasons.append("جایگزینی فایل‌های درایور و کتابخانه‌های سیستمی")
                details.append("PendingFileRenameOperations")
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


def execute_system_restart(delay_seconds: int = 5, reason_msg: str = "Markazi System QC - Finalizing drivers and software") -> Dict[str, Any]:
    """
    Initiates a graceful system restart using shutdown.exe.
    """
    try:
        cmd = ["shutdown.exe", "/r", "/t", str(delay_seconds), "/c", reason_msg]
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
        if proc.returncode == 0:
            return {
                "success": True,
                "message": f"سیستم تا {delay_seconds} ثانیه دیگر ری‌استارت می‌شود...",
                "delay_seconds": delay_seconds,
            }
        else:
            return {
                "success": False,
                "message": f"خطا در اجرای ری‌استارت: {proc.stderr.strip()}",
                "error": proc.stderr.strip(),
            }
    except Exception as e:
        logger.error(f"Error executing restart: {e}")
        return {
            "success": False,
            "message": f"خطا در ری‌استارت سیستم: {str(e)}",
        }


def cancel_system_restart() -> Dict[str, Any]:
    """
    Cancels any scheduled system restart (shutdown.exe /a).
    """
    try:
        cmd = ["shutdown.exe", "/a"]
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
        return {
            "success": proc.returncode == 0,
            "message": "دستور ری‌استارت سیستم لغو شد." if proc.returncode == 0 else "دستور ری‌استارت فعالی یافت نشد.",
        }
    except Exception as e:
        return {
            "success": False,
            "message": f"خطا در لغو ری‌استارت: {str(e)}",
        }
