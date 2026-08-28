import logging
import subprocess
import winreg
from typing import List, Dict, Any

from utils.powershell import run_powershell_json, get_hidden_subprocess_kwargs
from utils.formatters import clean_string, format_bytes_to_gb
from hardware.normalizer import normalize_gpu_info

logger = logging.getLogger(__name__)

def _get_registry_gpu_memory() -> Dict[str, int]:
    gpu_mem = {}
    path = r"SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
    try:
        with winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, path) as key:
            i = 0
            while True:
                try:
                    subkey_name = winreg.EnumKey(key, i)
                    i += 1
                    if subkey_name.isdigit():
                        with winreg.OpenKey(key, subkey_name) as subkey:
                            try:
                                desc, _ = winreg.QueryValueEx(subkey, "DriverDesc")
                                mem_bytes = None
                                try:
                                    mem_bytes, _ = winreg.QueryValueEx(subkey, "HardwareInformation.qwMemorySize")
                                except FileNotFoundError:
                                    try:
                                        mem_bytes, _ = winreg.QueryValueEx(subkey, "HardwareInformation.MemorySize")
                                    except FileNotFoundError:
                                        pass
                                if desc and mem_bytes:
                                    gpu_mem[desc.strip().lower()] = int(mem_bytes)
                            except Exception:
                                pass
                except OSError:
                    break
    except Exception as e:
        logger.debug(f"Registry GPU memory lookup error: {e}")
    return gpu_mem

def get_gpu_info() -> List[Dict[str, Any]]:
    gpus: List[Dict[str, Any]] = []
    reg_vram_map = _get_registry_gpu_memory()

    try:
        script = (
            "Get-CimInstance Win32_VideoController | "
            "Select-Object Name, AdapterRAM, DriverVersion, VideoProcessor, PNPDeviceID | "
            "ConvertTo-Json"
        )
        data = run_powershell_json(script)
        if isinstance(data, dict):
            raw_list = [data]
        elif isinstance(data, list):
            raw_list = data
        else:
            raw_list = []

        for item in raw_list:
            if not isinstance(item, dict):
                continue

            raw_name = clean_string(item.get("Name"))
            norm = normalize_gpu_info(raw_name)

            driver_ver = clean_string(item.get("DriverVersion"), default="Not available")
            proc_name = clean_string(item.get("VideoProcessor"), default="")

            # VRAM Resolution
            vram_bytes = reg_vram_map.get(raw_name.lower())
            if not vram_bytes:
                vram_raw = item.get("AdapterRAM")
                if vram_raw:
                    try:
                        val = int(vram_raw)
                        if val > 0:
                            vram_bytes = val
                    except (ValueError, TypeError):
                        pass

            if vram_bytes and vram_bytes > 0:
                vram_gb = format_bytes_to_gb(vram_bytes)
                vram_display = f"{vram_gb:.0f} GB" if vram_gb >= 1.0 else f"{int(vram_bytes / (1024**2))} MB"
            else:
                vram_display = "Shared"

            gpus.append({
                "name": norm["display_name"],
                "raw_name": raw_name,
                "manufacturer": norm["vendor"],
                "vram_display": vram_display,
                "driver_version": driver_ver,
                "video_processor": proc_name
            })
    except Exception as e:
        logger.error(f"Failed to detect GPU: {e}")

    return gpus
