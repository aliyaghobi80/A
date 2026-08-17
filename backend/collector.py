import logging
import os
import sys
import time
from datetime import datetime
from concurrent.futures import ThreadPoolExecutor
from typing import Dict, Any

# Ensure backend directory is in sys.path
_backend_dir = os.path.dirname(os.path.abspath(__file__))
if _backend_dir not in sys.path:
    sys.path.insert(0, _backend_dir)

from hardware.cpu import get_cpu_info
from hardware.motherboard import get_motherboard_info
from hardware.ram import get_ram_info
from hardware.gpu import get_gpu_info
from hardware.storage import get_storage_info
from hardware.bios import get_bios_info
from windows.system import get_windows_and_system_info
from windows.network import get_network_info
from software.detector import detect_required_software
from files.checker import check_required_files
from drivers.checker import check_important_drivers
from activation.windows_activation import get_windows_activation_info
from activation.office_activation import get_office_activation_info
from hardware.battery import get_battery_info

logger = logging.getLogger(__name__)

def collect_all_system_info() -> Dict[str, Any]:
    """
    Collects complete hardware, Windows specifications, important device drivers,
    installed required software, required file/folder presence checks,
    battery health, and Windows & Microsoft Office activation status.
    Uses concurrent workers to inspect components in parallel.
    Guarantees a clean, non-crashing structured dictionary.
    """
    start_time = time.perf_counter()
    
    with ThreadPoolExecutor(max_workers=14) as executor:
        future_cpu = executor.submit(get_cpu_info)
        future_mb = executor.submit(get_motherboard_info)
        future_ram = executor.submit(get_ram_info)
        future_gpu = executor.submit(get_gpu_info)
        future_storage = executor.submit(get_storage_info)
        future_bios = executor.submit(get_bios_info)
        future_win_sys = executor.submit(get_windows_and_system_info)
        future_net = executor.submit(get_network_info)
        future_soft = executor.submit(detect_required_software)
        future_files = executor.submit(check_required_files)
        future_drivers = executor.submit(check_important_drivers)
        future_win_act = executor.submit(get_windows_activation_info)
        future_off_act = executor.submit(get_office_activation_info)
        future_battery = executor.submit(get_battery_info)

        def safe_get(future, default_val, name):
            try:
                return future.result()
            except Exception as e:
                logger.error(f"Collector error in {name}: {e}")
                return default_val

        cpu = safe_get(future_cpu, {}, "CPU")
        motherboard = safe_get(future_mb, {}, "Motherboard")
        ram = safe_get(future_ram, {}, "RAM")
        gpu = safe_get(future_gpu, [], "GPU")
        storage = safe_get(future_storage, [], "Storage")
        bios = safe_get(future_bios, {}, "BIOS")
        win_sys = safe_get(future_win_sys, {"windows": {}, "system": {}}, "Windows/System")
        network = safe_get(future_net, [], "Network")
        soft_data = safe_get(future_soft, {"items": [], "summary": {}}, "Software")
        files_data = safe_get(future_files, {"items": [], "summary": {}}, "Files")
        drivers_data = safe_get(future_drivers, {"drivers": [], "driver_summary": {}}, "Drivers")
        win_act_data = safe_get(future_win_act, {"installed": True, "activated": False, "status_text": "Not available"}, "Windows Activation")
        off_act_data = safe_get(future_off_act, {"installed": False, "activated": False, "status_text": "Not available"}, "Office Activation")
        battery_data = safe_get(future_battery, {"has_battery": False, "is_desktop": True}, "Battery")

    elapsed_ms = round((time.perf_counter() - start_time) * 1000, 2)

    return {
        "status": "success",
        "timestamp": datetime.now().isoformat(),
        "scan_duration_ms": elapsed_ms,
        "cpu": cpu,
        "motherboard": motherboard,
        "ram": ram,
        "gpu": gpu,
        "storage": storage,
        "windows": win_sys.get("windows", {}),
        "system": win_sys.get("system", {}),
        "bios": bios,
        "network": network,
        "drivers": drivers_data.get("drivers", []),
        "driver_summary": drivers_data.get("driver_summary", {}),
        "software": soft_data.get("items", []),
        "software_summary": soft_data.get("summary", {}),
        "required_files": files_data.get("items", []),
        "files_summary": files_data.get("summary", {}),
        "windows_activation": win_act_data,
        "office_activation": off_act_data,
        "battery": battery_data,
    }

