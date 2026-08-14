import logging
import subprocess
import winreg
from typing import List, Dict, Any

from utils.powershell import run_powershell_json
from utils.formatters import clean_string, format_bytes_to_gb

logger = logging.getLogger(__name__)

def _get_registry_gpu_memory() -> Dict[str, int]:
    """Reads precise 64-bit VRAM byte sizes from the Windows Display Adapter Registry Class."""
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

def _get_nvidia_smi_memory() -> Dict[str, int]:
    """Uses nvidia-smi if available to get exact NVIDIA GPU VRAM in bytes."""
    vram_map = {}
    try:
        proc = subprocess.run(
            ["nvidia-smi", "--query-gpu=name,memory.total", "--format=csv,noheader,nounits"],
            capture_output=True,
            text=True,
            timeout=3
        )
        if proc.returncode == 0 and proc.stdout.strip():
            for line in proc.stdout.strip().splitlines():
                if "," in line:
                    parts = line.split(",")
                    name = parts[0].strip().lower()
                    mb = int(parts[1].strip())
                    vram_map[name] = mb * 1024 * 1024
    except Exception:
        pass
    return vram_map

def get_gpu_info() -> List[Dict[str, Any]]:
    """
    Detects all installed graphics cards (GPUs).
    Returns a list of GPU objects:
        name: str
        manufacturer: str
        vram_bytes: int or None
        vram_gb: float or None
        vram_display: str
        driver_version: str
    """
    gpus: List[Dict[str, Any]] = []
    reg_vram = _get_registry_gpu_memory()
    nvidia_vram = _get_nvidia_smi_memory()

    try:
        script = (
            "Get-CimInstance Win32_VideoController | "
            "Select-Object Name, AdapterRAM, DriverVersion, VideoProcessor, AdapterCompatibility, PNPDeviceID | "
            "ConvertTo-Json"
        )
        data = run_powershell_json(script)
        
        if isinstance(data, dict):
            raw_gpus = [data]
        elif isinstance(data, list):
            raw_gpus = data
        else:
            raw_gpus = []

        seen_names = set()

        for raw in raw_gpus:
            if not isinstance(raw, dict):
                continue
                
            name = clean_string(raw.get("Name"))
            if name == "Not available" or name in seen_names:
                continue
            seen_names.add(name)

            manufacturer = clean_string(raw.get("AdapterCompatibility"), default="Not available")
            if manufacturer == "Not available" and "NVIDIA" in name:
                manufacturer = "NVIDIA"
            elif manufacturer == "Not available" and ("AMD" in name or "Radeon" in name):
                manufacturer = "AMD"
            elif manufacturer == "Not available" and "Intel" in name:
                manufacturer = "Intel"

            driver_ver = clean_string(raw.get("DriverVersion"), default="Not available")

            # Determine accurate VRAM
            vram_bytes = None
            name_lower = name.lower()

            # 1. Check registry qwMemorySize
            for reg_key, bytes_val in reg_vram.items():
                if reg_key in name_lower or name_lower in reg_key:
                    vram_bytes = bytes_val
                    break

            # 2. Check nvidia-smi if not found or nvidia
            if not vram_bytes:
                for nv_name, bytes_val in nvidia_vram.items():
                    if nv_name in name_lower or name_lower in nv_name:
                        vram_bytes = bytes_val
                        break

            # 3. Check WMI AdapterRAM
            if not vram_bytes:
                adapter_ram = raw.get("AdapterRAM")
                if adapter_ram:
                    try:
                        aram_int = int(adapter_ram)
                        if aram_int > 0:
                            vram_bytes = aram_int
                    except (ValueError, TypeError):
                        pass

            # Format VRAM display
            if vram_bytes and vram_bytes > 0:
                vram_gb = format_bytes_to_gb(vram_bytes)
                if vram_gb:
                    if vram_gb >= 1.0:
                        vram_display = f"{int(round(vram_gb))} GB VRAM"
                    else:
                        vram_display = f"{int(vram_bytes / (1024 * 1024))} MB VRAM"
                else:
                    vram_gb = None
                    vram_display = "Not available"
            else:
                vram_gb = None
                vram_display = "Not available"

            gpus.append({
                "name": name,
                "manufacturer": manufacturer,
                "vram_bytes": vram_bytes,
                "vram_gb": vram_gb,
                "vram_display": vram_display,
                "driver_version": driver_ver
            })

    except Exception as e:
        logger.error(f"Error detecting GPUs: {e}")

    # Fallback if no GPU was detected at all
    if not gpus:
        gpus.append({
            "name": "Not available",
            "manufacturer": "Not available",
            "vram_bytes": None,
            "vram_gb": None,
            "vram_display": "Not available",
            "driver_version": "Not available"
        })

    return gpus
