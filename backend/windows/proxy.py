import logging
import winreg
import ctypes
import subprocess
from typing import Dict, Any, Tuple

logger = logging.getLogger(__name__)

INTERNET_OPTION_SETTINGS_CHANGED = 39
INTERNET_OPTION_REFRESH = 37

def _parse_server(server_str: str) -> Tuple[str, str]:
    """
    Parses '172.186.53.21:8051' or 'http=1.2.3.4:8080;https=1.2.3.4:8080'
    into (ip, port).
    """
    if not server_str:
        return "", ""
    
    clean = server_str.strip()
    if ";" in clean:
        # e.g. http=1.2.3.4:8080;https=1.2.3.4:8080
        parts = clean.split(";")
        for p in parts:
            if "=" in p:
                clean = p.split("=")[-1].strip()
                break

    if ":" in clean:
        ip, port = clean.rsplit(":", 1)
        return ip.strip(), port.strip()
    
    return clean, ""


def get_proxy_info() -> Dict[str, Any]:
    """
    Reads Windows Manual Proxy settings from HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings
    """
    enabled = False
    server = ""
    override = ""
    ip = ""
    port = ""

    try:
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, r"Software\Microsoft\Windows\CurrentVersion\Internet Settings") as key:
            try:
                val, _ = winreg.QueryValueEx(key, "ProxyEnable")
                enabled = bool(val == 1)
            except Exception:
                enabled = False

            try:
                server, _ = winreg.QueryValueEx(key, "ProxyServer")
                server = str(server).strip()
            except Exception:
                server = ""

            try:
                override, _ = winreg.QueryValueEx(key, "ProxyOverride")
                override = str(override).strip()
            except Exception:
                override = ""

        if server:
            ip, port = _parse_server(server)

    except Exception as e:
        logger.error(f"Error querying Windows proxy settings: {e}")

    has_manual_proxy = enabled and bool(server or enabled)

    return {
        "enabled": enabled,
        "server": server,
        "ip": ip,
        "port": port,
        "override": override,
        "has_manual_proxy": has_manual_proxy,
        "is_warning": has_manual_proxy,
        "status_text": f"روشن ({server})" if has_manual_proxy else ("روشن" if enabled else "خاموش"),
        "status_text_en": f"Enabled ({server})" if has_manual_proxy else ("Enabled" if enabled else "Disabled"),
    }


def disable_proxy() -> Dict[str, Any]:
    """
    Disables the manual proxy in Windows registry (HKCU) and notifies the OS (WinINet).
    """
    try:
        # 1. Update HKCU Internet Settings
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, r"Software\Microsoft\Windows\CurrentVersion\Internet Settings", 0, winreg.KEY_SET_VALUE) as key:
            winreg.SetValueEx(key, "ProxyEnable", 0, winreg.REG_DWORD, 0)

        # 2. Tell WinINet that proxy settings changed
        try:
            wininet = ctypes.windll.wininet
            wininet.InternetSetOptionW(0, INTERNET_OPTION_SETTINGS_CHANGED, 0, 0)
            wininet.InternetSetOptionW(0, INTERNET_OPTION_REFRESH, 0, 0)
        except Exception as e:
            logger.warning(f"WinINet refresh warning: {e}")

        # 3. Also reset WinHTTP proxy if any
        try:
            subprocess.run(["netsh", "winhttp", "reset", "proxy"], capture_output=True, timeout=5)
        except Exception:
            pass

        logger.info("Manual Windows proxy disabled successfully.")
        return {
            "success": True,
            "message": "پروکسی دستی ویندوز با موفقیت خاموش شد.",
            "proxy": get_proxy_info()
        }

    except Exception as e:
        logger.error(f"Error disabling manual proxy: {e}")
        return {
            "success": False,
            "message": f"خطا در غیرفعال‌سازی پروکسی: {str(e)}",
            "proxy": get_proxy_info()
        }
