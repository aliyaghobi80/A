"""Explicit technician actions; status checks never change settings."""
import ctypes
import winreg
from windows.device_settings import _run, _run_elevated_powershell
from activation.windows_activation import _query_wmi_licensing

ICONS = ('{20D04FE0-3AEA-1069-A2D8-08002B30309D}', '{5399E694-6CE5-4D6C-8FCE-1D8870FDCBA0}', '{645FF040-5081-101B-9F08-00AA002F954E}')
ICON_ROOT = r'Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons'

def _read(hive, path, name, default=None):
    try:
        with winreg.OpenKey(hive, path) as key:
            return winreg.QueryValueEx(key, name)[0]
    except FileNotFoundError:
        return default

def get_desktop_time_status():
    result = {'windows_activated': None, 'desktop_icons_ready': None, 'timezone': 'نامشخص', 'automatic_timezone': None, 'location_enabled': None}
    try:
        result['windows_activated'] = _query_wmi_licensing().get('activated')
        hidden = _read(winreg.HKEY_CURRENT_USER, r'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced', 'HideIcons', 0) == 1
        result['desktop_icons_ready'] = not hidden and all(_read(winreg.HKEY_CURRENT_USER, ICON_ROOT + '\\NewStartPanel', icon) == 0 for icon in ICONS)
        zone = _run(['tzutil.exe', '/g'])
        if zone.returncode == 0:
            result['timezone'] = zone.stdout.strip()
        result['automatic_timezone'] = _read(winreg.HKEY_LOCAL_MACHINE, r'SYSTEM\CurrentControlSet\Services\tzautoupdate', 'Start') == 3
        result['location_enabled'] = _read(winreg.HKEY_LOCAL_MACHINE, r'SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location', 'Value') == 'Allow'
    except (OSError, ValueError):
        pass
    return result

def show_desktop_icons():
    if _query_wmi_licensing().get('activated') is not True:
        return {'success': False, 'message': 'ابتدا ویندوز را فعال کنید؛ وضعیت فعال‌سازی باید تأیید شود.'}
    try:
        for panel in ('NewStartPanel', 'ClassicStartMenu'):
            with winreg.CreateKeyEx(winreg.HKEY_CURRENT_USER, ICON_ROOT + '\\' + panel, 0, winreg.KEY_SET_VALUE) as key:
                for icon in ICONS:
                    winreg.SetValueEx(key, icon, 0, winreg.REG_DWORD, 0)
        ctypes.windll.shell32.SHChangeNotify(0x08000000, 0, None, None)
        ready = get_desktop_time_status()['desktop_icons_ready'] is True
        return {'success': ready, 'message': 'This PC، Control Panel و Recycle Bin روی دسکتاپ فعال شدند.' if ready else 'نمایش آیکن‌ها تأیید نشد؛ گزینهٔ Show desktop icons و محدودیت‌های ویندوز را بررسی کنید.'}
    except OSError as error:
        return {'success': False, 'message': f'تنظیم آیکن‌ها انجام نشد: {error}'}

def set_tehran_automatic_timezone():
    # Do not silently change Location permission or organizational policies.
    script = """
    $ErrorActionPreference='Stop'
    & tzutil.exe /s 'Iran Standard Time_dstoff'
    if($LASTEXITCODE -ne 0){throw 'Timezone change failed'}
    Set-Service -Name tzautoupdate -StartupType Manual
    """
    try:
        execution = _run_elevated_powershell(script)
        state = get_desktop_time_status()
        ready = execution.returncode == 0 and state['timezone'].replace('_dstoff', '') == 'Iran Standard Time' and state['automatic_timezone'] is True
        message = ('تهران (UTC+03:30) و تشخیص خودکار منطقهٔ زمانی تنظیم شدند.' if ready else 'همهٔ تنظیمات زمان تأیید نشد؛ وضعیت فعلی را بررسی کنید.')
        if state['location_enabled'] is not True:
            message += ' برای تشخیص خودکار، Location را در تنظیمات ویندوز روشن کنید.'
        return {'success': ready, 'message': message, 'desktop_time': state}
    except (OSError, ValueError) as error:
        return {'success': False, 'message': f'تنظیم منطقهٔ زمانی انجام نشد: {error}'}
