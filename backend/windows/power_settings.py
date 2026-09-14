"""Read and configure Windows power settings through the documented power APIs."""
import ctypes
import uuid


class GUID(ctypes.Structure):
    _fields_ = [('data1', ctypes.c_uint32), ('data2', ctypes.c_uint16),
                ('data3', ctypes.c_uint16), ('data4', ctypes.c_ubyte * 8)]

    @classmethod
    def parse(cls, value):
        return cls.from_buffer_copy(uuid.UUID(value).bytes_le)

    def text(self):
        return str(uuid.UUID(bytes_le=bytes(self)))


BALANCED = '00000000-0000-0000-0000-000000000000'
PERFORMANCE = 'ded574b5-45a0-4f42-8737-46345c09c238'
POWER_NAMES = {BALANCED: 'Balanced', PERFORMANCE: 'Best performance',
               '961cc777-2547-4f9d-8174-7d86181b8a7a': 'Best power efficiency'}
TIMEOUTS = {
    'screen': ('7516b95f-f776-4464-8c53-06167f40cc99', '3c0bc021-c8a8-4e07-a973-6b14cbcb2b7e'),
    'sleep': ('238c9fa8-0aad-41ed-83f4-97be242c8f20', '29f6c1db-86da-48c5-9fdb-f2b67b1f44da'),
    'hibernate': ('238c9fa8-0aad-41ed-83f4-97be242c8f20', '9d7815a6-7ee4-497e-8888-515a05f02364'),
}


def get_timeout_status():
    values = {}
    scheme = ctypes.POINTER(GUID)()
    try:
        api = ctypes.WinDLL('powrprof')
        api.PowerGetActiveScheme.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.POINTER(GUID))]
        api.PowerGetActiveScheme.restype = ctypes.c_uint32
        if api.PowerGetActiveScheme(None, ctypes.byref(scheme)):
            return {'all_never': None, 'values': {}}
        for mode in ('ac', 'dc'):
            reader = getattr(api, f'PowerRead{mode.upper()}ValueIndex')
            reader.argtypes = [ctypes.c_void_p, ctypes.POINTER(GUID), ctypes.POINTER(GUID),
                               ctypes.POINTER(GUID), ctypes.POINTER(ctypes.c_uint32)]
            reader.restype = ctypes.c_uint32
            for name, (subgroup, setting) in TIMEOUTS.items():
                result = ctypes.c_uint32()
                code = reader(None, scheme, ctypes.byref(GUID.parse(subgroup)),
                              ctypes.byref(GUID.parse(setting)), ctypes.byref(result))
                values[f'{name}_{mode}'] = result.value if code == 0 else None
    except (OSError, AttributeError):
        pass
    finally:
        if scheme:
            free = ctypes.WinDLL('kernel32').LocalFree
            free.argtypes = [ctypes.c_void_p]
            free.restype = ctypes.c_void_p
            free(scheme)
    known = len(values) == 6 and all(value is not None for value in values.values())
    return {'all_never': all(value == 0 for value in values.values()) if known else None,
            'values': values, 'unit': 'seconds'}


def get_power_mode_status():
    result = {'supported': False, 'configured': None, 'ac': 'Unknown', 'dc': 'Unknown'}
    try:
        api = ctypes.WinDLL('powrprof')
        for mode in ('ac', 'dc'):
            reader = getattr(api, f'PowerGetUserConfigured{mode.upper()}PowerMode')
            reader.argtypes = [ctypes.POINTER(GUID)]
            reader.restype = ctypes.c_uint32
            value = GUID()
            if reader(ctypes.byref(value)) != 0:
                return result
            result[mode + '_guid'] = value.text()
            result[mode] = POWER_NAMES.get(value.text(), value.text())
        result['supported'] = True
        result['configured'] = result['ac_guid'] == PERFORMANCE and result['dc_guid'] == BALANCED
    except (OSError, AttributeError):
        pass
    return result


def set_laptop_power_modes():
    before = get_power_mode_status()
    if not before['supported']:
        return {'success': False, 'unsupported': True,
                'message': 'این نسخهٔ ویندوز تنظیم جداگانهٔ Power mode برق و باتری را از طریق API پشتیبانی نمی‌کند.'}
    try:
        api = ctypes.WinDLL('powrprof')
        codes = {}
        for mode, target in [('ac', PERFORMANCE), ('dc', BALANCED)]:
            setter = getattr(api, f'PowerSetUserConfigured{mode.upper()}PowerMode')
            setter.argtypes = [ctypes.POINTER(GUID)]
            setter.restype = ctypes.c_uint32
            codes[mode] = setter(ctypes.byref(GUID.parse(target)))
        state = get_power_mode_status()
        ok = all(code == 0 for code in codes.values()) and state['configured'] is True
        return {'success': ok, 'power_modes': state,
                'message': ('برق متصل: Best performance؛ باتری: Balanced — تنظیمات تأیید شد.' if ok
                            else f'همهٔ تنظیمات تأیید نشد؛ وضعیت فعلی را بررسی کنید. کدها: {codes}')}
    except (OSError, AttributeError) as error:
        return {'success': False, 'message': str(error)}
