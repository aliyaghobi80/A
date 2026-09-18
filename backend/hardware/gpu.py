import logging
import winreg
from typing import Any, Dict, Iterable, List

from utils.formatters import clean_string, format_bytes_to_gb
from utils.powershell import run_powershell_json
from hardware.normalizer import normalize_gpu_info

logger = logging.getLogger(__name__)


def _get_registry_gpu_memory() -> Dict[str, int]:
    gpu_mem: Dict[str, int] = {}
    path = r"SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
    try:
        with winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, path) as key:
            index = 0
            while True:
                try:
                    subkey_name = winreg.EnumKey(key, index)
                    index += 1
                    if not subkey_name.isdigit():
                        continue
                    with winreg.OpenKey(key, subkey_name) as subkey:
                        try:
                            desc, _ = winreg.QueryValueEx(subkey, "DriverDesc")
                            memory_bytes = None
                            try:
                                memory_bytes, _ = winreg.QueryValueEx(
                                    subkey, "HardwareInformation.qwMemorySize"
                                )
                            except FileNotFoundError:
                                try:
                                    memory_bytes, _ = winreg.QueryValueEx(
                                        subkey, "HardwareInformation.MemorySize"
                                    )
                                except FileNotFoundError:
                                    pass
                            if desc and memory_bytes:
                                gpu_mem[str(desc).strip().lower()] = int(memory_bytes)
                        except OSError:
                            pass
                except OSError:
                    break
    except OSError as exc:
        logger.debug("Registry GPU memory lookup error: %s", exc)
    return gpu_mem


def _records(value: Any) -> List[Dict[str, Any]]:
    if isinstance(value, dict):
        return [value]
    if isinstance(value, list):
        return [item for item in value if isinstance(item, dict)]
    return []


def _pnp_key(value: Any) -> str:
    return str(value or "").strip().upper()


def _is_basic_display_name(value: Any) -> bool:
    normalized = str(value or "").strip().lower()
    return "microsoft basic display adapter" in normalized or "basic render driver" in normalized


def _vendor_from_device(entity: Dict[str, Any], fallback_name: str = "") -> str:
    """Resolve the actual GPU vendor even while Windows uses its basic driver."""
    searchable: List[str] = [str(fallback_name or ""), str(entity.get("Name") or "")]
    hardware_ids = entity.get("HardwareID") or entity.get("HardwareIds") or []
    if not isinstance(hardware_ids, list):
        hardware_ids = [hardware_ids]
    searchable.extend(str(item or "") for item in hardware_ids)
    searchable.append(str(entity.get("Manufacturer") or ""))
    text = " ".join(searchable).upper()
    if "VEN_10DE" in text or "NVIDIA" in text:
        return "NVIDIA"
    if "VEN_1002" in text or "AMD" in text or "RADEON" in text or "ATI" in text:
        return "AMD"
    if "VEN_8086" in text or "INTEL" in text:
        return "Intel"
    return "Generic"


def _format_vram(vram_bytes: int | None) -> tuple[int | None, str]:
    if vram_bytes and vram_bytes > 0:
        vram_gb = format_bytes_to_gb(vram_bytes)
        if vram_gb is not None and vram_gb >= 1.0:
            return vram_bytes, f"{vram_gb:.0f} GB"
        return vram_bytes, f"{int(vram_bytes / (1024 ** 2))} MB"
    return None, "Shared"


def _classify_gpu_type(vendor: str, name: str) -> tuple[str, bool, bool]:
    """Classifies GPU into ('discrete' | 'integrated', is_discrete, is_integrated)."""
    vendor_u = (vendor or "").upper()
    name_u = (name or "").upper()

    if vendor_u == "NVIDIA":
        return "discrete", True, False
    if "ARC" in name_u:  # Intel Arc dedicated GPU
        return "discrete", True, False
    if vendor_u == "AMD":
        # Check for discrete AMD indicators
        if any(w in name_u for w in ("RX ", "RADEON RX", "PRO W", "FIREPRO", "R9 ", "R7 ", "R5 ")):
            return "discrete", True, False
        # Integrated APU indicators:
        if any(w in name_u for w in ("RADEON(TM) GRAPHICS", "RADEON GRAPHICS", "VEGA")):
            return "integrated", False, True
        return "discrete", True, False
    if vendor_u == "INTEL":
        return "integrated", False, True

    return "unknown", False, False


def merge_gpu_records(
    video_controllers: Iterable[Dict[str, Any]],
    display_devices: Iterable[Dict[str, Any]],
    registry_vram: Dict[str, int] | None = None,
) -> List[Dict[str, Any]]:
    """Merge WMI controllers with PnP Display devices without losing a GPU.

    ``Win32_VideoController`` can collapse a hybrid system to Microsoft Basic
    Display Adapter before vendor drivers are installed.  PnP Display still
    exposes every physical adapter, so it drives enumeration while VideoController
    fills in VRAM and driver-version details when they are available.
    """
    registry_vram = registry_vram or {}
    controllers = list(video_controllers)
    displays = list(display_devices)
    by_pnp = {
        _pnp_key(item.get("PNPDeviceID")): item
        for item in controllers
        if _pnp_key(item.get("PNPDeviceID"))
    }
    consumed: set[str] = set()
    merged: List[Dict[str, Any]] = []

    def create(
        controller: Dict[str, Any] | None, display: Dict[str, Any] | None
    ) -> Dict[str, Any]:
        controller = controller or {}
        display = display or {}
        controller_name = clean_string(controller.get("Name"), default="")
        display_name = clean_string(display.get("Name"), default="")
        raw_name = controller_name or display_name or "Display adapter"
        is_basic = _is_basic_display_name(controller_name) or _is_basic_display_name(display_name)
        try:
            error_code = int(display.get("ConfigManagerErrorCode") or 0)
        except (TypeError, ValueError):
            error_code = 0
        vendor = _vendor_from_device(display, raw_name)
        if vendor == "Generic":
            vendor = normalize_gpu_info(raw_name).get("vendor", "Generic")

        # Never present the generic Microsoft fallback as the customer's GPU.
        # When Windows has not supplied a model yet, identify only the vendor.
        model_name = (
            display_name
            if display_name and not _is_basic_display_name(display_name)
            else controller_name
        )
        if is_basic and (not model_name or _is_basic_display_name(model_name)):
            model_name = (
                f"{vendor} graphics adapter (driver not installed)"
                if vendor != "Generic"
                else "Microsoft Basic Display Adapter"
            )
        normalized = normalize_gpu_info(model_name)

        vram_bytes = registry_vram.get(raw_name.lower()) or registry_vram.get(model_name.lower())
        if not vram_bytes:
            try:
                reported_vram = int(controller.get("AdapterRAM") or 0)
                vram_bytes = reported_vram if reported_vram > 0 else None
            except (TypeError, ValueError):
                vram_bytes = None
        vram_bytes, vram_display = _format_vram(vram_bytes)
        missing = is_basic or error_code in (22, 28, 31, 43)
        if missing and is_basic:
            state = "basic_display_driver"
        elif missing:
            state = "device_problem"
        else:
            state = "installed"

        gpu_type, is_disc, is_integ = _classify_gpu_type(vendor, normalized["display_name"])

        return {
            "name": normalized["display_name"],
            "raw_name": raw_name,
            "manufacturer": vendor,
            "vram_bytes": vram_bytes,
            "vram_display": vram_display,
            "driver_version": clean_string(
                controller.get("DriverVersion"), default="Not available"
            ),
            "video_processor": clean_string(controller.get("VideoProcessor"), default=""),
            "pnp_device_id": _pnp_key(
                display.get("PNPDeviceID") or controller.get("PNPDeviceID")
            ),
            "driver_missing": missing,
            "driver_state": state,
            "gpu_type": gpu_type,
            "is_discrete": is_disc,
            "is_integrated": is_integ,
            "needs_driver": missing or is_basic,
        }

    # Display class contains one item per physical GPU, including both GPUs on
    # a hybrid notebook.
    for display in displays:
        pnp_id = _pnp_key(display.get("PNPDeviceID"))
        controller = by_pnp.get(pnp_id)
        if pnp_id:
            consumed.add(pnp_id)
        merged.append(create(controller, display))

    # Preserve legacy/video adapters that did not have a matching PnP entry.
    for controller in controllers:
        pnp_id = _pnp_key(controller.get("PNPDeviceID"))
        if pnp_id and pnp_id in consumed:
            continue
        candidate = create(controller, None)
        duplicate = any(
            (candidate["pnp_device_id"] and candidate["pnp_device_id"] == item["pnp_device_id"])
            or (
                not candidate["pnp_device_id"]
                and candidate["raw_name"].lower() == item["raw_name"].lower()
            )
            for item in merged
        )
        if not duplicate:
            merged.append(candidate)

    # Sort: Discrete GPUs first, then Integrated, then unknown
    def _gpu_sort_key(item: Dict[str, Any]) -> int:
        if item.get("is_discrete"):
            return 0
        if item.get("is_integrated"):
            return 1
        return 2

    merged.sort(key=_gpu_sort_key)
    return merged


def get_gpu_info() -> List[Dict[str, Any]]:
    try:
        controller_data = run_powershell_json(
            "Get-CimInstance Win32_VideoController | "
            "Select-Object Name, AdapterRAM, DriverVersion, VideoProcessor, PNPDeviceID | ConvertTo-Json",
            timeout=8,
        )
        display_data = run_powershell_json(
            "Get-CimInstance Win32_PnPEntity | Where-Object { "
            "$_.PNPClass -eq 'Display' -or "
            "$_.Name -like '*3D Video*' -or "
            "$_.Name -like '*Video Controller*' -or "
            "($_.CompatibleID -and ($_.CompatibleID -contains 'PCI\\CC_0300' -or $_.CompatibleID -contains 'PCI\\CC_0302' -or $_.CompatibleID -like '*CC_03*')) "
            "} | Select-Object Name, Manufacturer, PNPDeviceID, ConfigManagerErrorCode, Status, HardwareID | ConvertTo-Json",
            timeout=8,
        )
        return merge_gpu_records(
            _records(controller_data), _records(display_data), _get_registry_gpu_memory()
        )
    except Exception as exc:
        logger.error("Failed to detect GPU: %s", exc)
        return []
