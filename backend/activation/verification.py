"""Reconcile an external process result with actual licensing state."""
import time
from activation.windows_activation import get_windows_activation_info
from activation.office_activation import get_office_activation_info

def verify_activation_result(target, result, attempts=6):
    if result.get('cancelled'):
        return result
    query = get_windows_activation_info if target == 'windows' else get_office_activation_info
    for attempt in range(attempts):
        state = query()
        if state.get('activated') is True:
            return {**result, 'success': True, 'output': '', 'verification': 'active', 'message': 'فعال‌سازی از سرویس لایسنس تأیید شد.'}
        if attempt + 1 < attempts:
            time.sleep(2)
    return {**result, 'success': False, 'output': '', 'verification': 'unconfirmed', 'message': 'فعال‌سازی هنوز تأیید نشده است؛ وضعیت لایسنس را دوباره بررسی کنید.'}
