import logging
import time
from datetime import datetime
from concurrent.futures import ThreadPoolExecutor
from typing import Dict, Any

from hardware.cpu import get_cpu_info
from hardware.motherboard import get_motherboard_info
from hardware.ram import get_ram_info
from hardware.gpu import get_gpu_info
from hardware.storage import get_storage_info
from hardware.bios import get_bios_info
from windows.system import get_windows_and_system_info
from windows.network import get_network_info

logger = logging.getLogger(__name__)

def collect_all_system_info() -> Dict[str, Any]:
    """
    Collects complete hardware and Windows system specifications.
    Uses concurrent workers to inspect hardware components in parallel.
    Guarantees a clean, non-crashing structured dictionary.
    """
    start_time = time.perf_counter()
    
    results = {}
    
    with ThreadPoolExecutor(max_workers=6) as executor:
        future_cpu = executor.submit(get_cpu_info)
        future_mb = executor.submit(get_motherboard_info)
        future_ram = executor.submit(get_ram_info)
        future_gpu = executor.submit(get_gpu_info)
        future_storage = executor.submit(get_storage_info)
        future_bios = executor.submit(get_bios_info)
        future_win_sys = executor.submit(get_windows_and_system_info)
        future_net = executor.submit(get_network_info)

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
        "network": network
    }
