"""Read-only SMBIOS Type 16/17 slot inventory, including unpopulated slots."""
import ctypes
import struct


def parse_memory_slots(table: bytes):
    arrays, devices = set(), []
    pos = 0
    while pos + 4 <= len(table):
        kind, length, handle = struct.unpack_from('<BBH', table, pos)
        if length < 4 or pos + length > len(table):
            return []
        end = table.find(b'\0\0', pos + length)
        if end < 0:
            return []
        body = table[pos:pos + length]
        strings = table[pos + length:end].split(b'\0')
        def string_at(index):
            return strings[index - 1].decode('utf-8', errors='replace').strip() if 0 < index <= len(strings) else ''
        if kind == 16 and length >= 15 and body[5] == 3:
            arrays.add(handle)  # System memory, not video/cache memory.
        elif kind == 17 and length >= 21:
            size = struct.unpack_from('<H', body, 12)[0]
            devices.append({
                'array_handle': struct.unpack_from('<H', body, 4)[0],
                'device_locator': string_at(body[16]),
                'bank_label': string_at(body[17]),
                'occupied': None if size == 0xffff else size != 0,
            })
        pos = end + 2
        if kind == 127:
            break
    return [device for device in devices if device['array_handle'] in arrays]


def read_memory_slots():
    try:
        api = ctypes.WinDLL('kernel32', use_last_error=True).GetSystemFirmwareTable
        api.argtypes = [ctypes.c_uint32, ctypes.c_uint32, ctypes.c_void_p, ctypes.c_uint32]
        api.restype = ctypes.c_uint32
        provider = int.from_bytes(b'RSMB', 'big')
        size = api(provider, 0, None, 0)
        if not 8 <= size <= 16 * 1024 * 1024:
            return []
        buffer = ctypes.create_string_buffer(size)
        if api(provider, 0, buffer, size) != size:
            return []
        length = struct.unpack_from('<I', buffer.raw, 4)[0]
        if length > size - 8:
            return []
        return parse_memory_slots(buffer.raw[8:8 + length])
    except (OSError, AttributeError, ValueError):
        return []
