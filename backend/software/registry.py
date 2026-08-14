import logging
import winreg
from typing import Dict, List, Optional

logger = logging.getLogger(__name__)

def get_installed_applications_from_registry() -> List[Dict[str, str]]:
    """
    Scans Windows registry uninstall keys across:
    1. HKLM 64-bit: HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall
    2. HKLM 32-bit: HKLM\\SOFTWARE\\WOW6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall
    3. HKCU: HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall
    """
    targets = [
        (winreg.HKEY_LOCAL_MACHINE, r"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall", "HKLM_64"),
        (winreg.HKEY_LOCAL_MACHINE, r"SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall", "HKLM_32"),
        (winreg.HKEY_CURRENT_USER, r"Software\Microsoft\Windows\CurrentVersion\Uninstall", "HKCU"),
    ]

    installed_apps: List[Dict[str, str]] = []
    seen_keys = set()

    for hive, subkey_path, source in targets:
        try:
            with winreg.OpenKey(hive, subkey_path) as key:
                num_subkeys, _, _ = winreg.QueryInfoKey(key)
                for i in range(num_subkeys):
                    try:
                        subkey_name = winreg.EnumKey(key, i)
                        full_key_id = f"{source}\\{subkey_name}"
                        if full_key_id in seen_keys:
                            continue
                        seen_keys.add(full_key_id)

                        with winreg.OpenKey(key, subkey_name) as app_key:
                            display_name = _query_reg_string(app_key, "DisplayName")
                            if not display_name:
                                continue

                            # Skip system components or updates if specified
                            system_component = _query_reg_dword(app_key, "SystemComponent")
                            if system_component == 1:
                                continue

                            display_version = _query_reg_string(app_key, "DisplayVersion") or "Not available"
                            install_location = _query_reg_string(app_key, "InstallLocation") or ""
                            publisher = _query_reg_string(app_key, "Publisher") or ""
                            uninstall_string = _query_reg_string(app_key, "UninstallString") or ""

                            installed_apps.append({
                                "display_name": display_name.strip(),
                                "display_version": display_version.strip(),
                                "install_location": install_location.strip(),
                                "publisher": publisher.strip(),
                                "uninstall_string": uninstall_string.strip(),
                                "source": source,
                            })
                    except OSError:
                        continue
        except OSError as e:
            logger.debug(f"Could not open registry path {subkey_path}: {e}")

    return installed_apps

def get_app_path_from_registry(exe_name: str) -> Optional[str]:
    """
    Looks up executable path in HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\App Paths.
    """
    for hive in [winreg.HKEY_LOCAL_MACHINE, winreg.HKEY_CURRENT_USER]:
        for prefix in [r"SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths",
                       r"SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths"]:
            key_path = f"{prefix}\\{exe_name}"
            try:
                with winreg.OpenKey(hive, key_path) as key:
                    val, _ = winreg.QueryValueEx(key, "")
                    if val and isinstance(val, str):
                        return val.strip('"\t ')
            except OSError:
                continue
    return None

def _query_reg_string(key, name: str) -> Optional[str]:
    try:
        val, _ = winreg.QueryValueEx(key, name)
        if isinstance(val, str):
            return val
        return str(val)
    except OSError:
        return None

def _query_reg_dword(key, name: str) -> Optional[int]:
    try:
        val, _ = winreg.QueryValueEx(key, name)
        if isinstance(val, int):
            return val
        return None
    except OSError:
        return None
