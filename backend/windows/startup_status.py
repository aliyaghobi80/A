"""Read-only verification of the startup sources controlled by device settings."""
import os
import winreg
from pathlib import Path


def _values(hive, path):
    try:
        with winreg.OpenKey(hive, path) as key:
            return {name: value for name, value, _ in
                    (winreg.EnumValue(key, i) for i in range(winreg.QueryInfoKey(key)[1]))}
    except FileNotFoundError:
        return {}


def _subkeys(hive, path):
    try:
        with winreg.OpenKey(hive, path) as key:
            return [winreg.EnumKey(key, i) for i in range(winreg.QueryInfoKey(key)[0])]
    except FileNotFoundError:
        return []


def get_startup_status():
    total = enabled = 0
    try:
        base = r'Software\Microsoft\Windows\CurrentVersion'
        approved = base + r'\Explorer\StartupApproved'
        for hive, env in [(winreg.HKEY_CURRENT_USER, 'APPDATA'), (winreg.HKEY_LOCAL_MACHINE, 'PROGRAMDATA')]:
            for category, source in [('Run', base + r'\Run'),
                                     ('Run32', r'Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'),
                                     ('StartupFolder', None)]:
                statuses = _values(hive, approved + '\\' + category)
                names = set(statuses)
                if source:
                    names.update(_values(hive, source))
                elif os.environ.get(env):
                    folder = Path(os.environ[env]) / 'Microsoft/Windows/Start Menu/Programs/Startup'
                    if folder.is_dir():
                        names.update(p.name for p in folder.iterdir() if p.is_file() and p.name.lower() != 'desktop.ini')
                for name in names:
                    data = statuses.get(name)
                    disabled = isinstance(data, bytes) and len(data) >= 4 and int.from_bytes(data[:4], 'little') in (3, 7)
                    total += 1
                    enabled += not disabled
        app_root = r'Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData'
        for package in _subkeys(winreg.HKEY_CURRENT_USER, app_root):
            path = app_root + '\\' + package
            for task in _subkeys(winreg.HKEY_CURRENT_USER, path):
                state = _values(winreg.HKEY_CURRENT_USER, path + '\\' + task).get('State')
                if state is not None:
                    total += 1
                    enabled += state in (2, 4)
        return {'all_disabled': enabled == 0, 'enabled_count': enabled, 'total': total}
    except OSError as error:
        return {'all_disabled': None, 'enabled_count': None, 'total': total, 'error': str(error)}


def get_background_status(is_windows10):
    if not is_windows10:
        return {'supported': False, 'all_disabled': None}
    try:
        value = _values(winreg.HKEY_CURRENT_USER,
                        r'Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications').get('GlobalUserDisabled', 0)
        policy = _values(winreg.HKEY_LOCAL_MACHINE,
                         r'SOFTWARE\Policies\Microsoft\Windows\AppPrivacy').get('LetAppsRunInBackground')
        disabled = policy == 2 if policy in (1, 2) else value == 1
        return {'supported': True, 'all_disabled': disabled, 'policy': policy}
    except OSError as error:
        return {'supported': True, 'all_disabled': None, 'error': str(error)}
