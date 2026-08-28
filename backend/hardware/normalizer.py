import re
from typing import Dict, Any

def normalize_cpu_info(raw_name: str, raw_manufacturer: str = "") -> Dict[str, Any]:
    name = (raw_name or "").strip()
    name = re.sub(r'\s+', ' ', name)

    vendor = "Intel(R)" if "intel" in name.lower() or "intel" in raw_manufacturer.lower() else ("AMD(R)" if "amd" in name.lower() or "amd" in raw_manufacturer.lower() else "")
    gen_match = re.search(r'(\d+)(?:th|rd|nd|st)\s+Gen', name, re.IGNORECASE)
    gen_str = f"{gen_match.group(1)}th Gen" if gen_match else ""

    intel_model_match = re.search(r'(i[3579]-[\w\d]+|Core\s+Ultra\s+\d+\s+[\w\d]+|Xeon\s+[\w\d\-]+(?:\s+v\d+)?|Pentium\s+[\w\d]+|Celeron\s+[\w\d]+)', name, re.IGNORECASE)
    amd_model_match = re.search(r'(Ryzen\s+[3579]\s+[\w\d]+|Threadripper\s+[\w\d]+|Athlon\s+[\w\d]+|EPYC\s+[\w\d]+)', name, re.IGNORECASE)

    model_str = ""
    family_str = ""

    if intel_model_match:
        model_str = intel_model_match.group(1).strip()
        family_str = "Core(TM)" if "Core" in name or model_str.startswith("i") else ""
    elif amd_model_match:
        model_str = amd_model_match.group(1).strip()
        family_str = "Ryzen(TM)"
    else:
        model_str = name
        family_str = ""

    parts = []
    if model_str:
        parts.append(model_str)
    if family_str and family_str.lower() not in model_str.lower():
        parts.append(family_str)
    if gen_str:
        parts.append(gen_str)
    if vendor:
        parts.append(vendor)

    normalized = " ".join(parts) if parts else name

    return {
        "raw_name": name,
        "normalized_name": normalized,
        "model": model_str if model_str else name,
        "generation": gen_str,
        "vendor": vendor if vendor else raw_manufacturer
    }

def normalize_motherboard_info(manufacturer: str, model: str) -> Dict[str, str]:
    mfg = (manufacturer or "").strip()
    mdl = (model or "").strip()

    clean_mfg = re.sub(r'(?:,\s*)?(?:Co\.|Ltd\.|Inc\.|Corp\.|Corporation)\b', '', mfg, flags=re.IGNORECASE).strip()
    clean_mfg = re.sub(r'[\s,]+$', '', clean_mfg)

    if clean_mfg and mdl.lower().startswith(clean_mfg.lower()):
        display_name = mdl
    elif mdl and mfg and mfg != "Not available":
        display_name = f"{mdl} {mfg}"
    else:
        display_name = mdl or mfg or "Motherboard"

    return {
        "raw_manufacturer": manufacturer,
        "raw_model": model,
        "display_name": display_name,
        "clean_manufacturer": clean_mfg if clean_mfg else mfg
    }

def normalize_gpu_info(raw_name: str, vram_display: str = "") -> Dict[str, str]:
    name = (raw_name or "").strip()
    vram_suffix = ""
    if vram_display and vram_display != "Shared":
        vram_suffix = re.sub(r'\s*GB\b', 'G', vram_display, flags=re.IGNORECASE).strip()

    if vram_suffix and vram_suffix not in name and vram_display not in name:
        display_name = f"{name} {vram_suffix}"
    else:
        display_name = name

    vendor = "NVIDIA" if "nvidia" in name.lower() else ("AMD" if "amd" in name.lower() or "radeon" in name.lower() else ("Intel" if "intel" in name.lower() else "Generic"))

    return {
        "raw_name": name,
        "display_name": display_name,
        "vendor": vendor
    }

def normalize_storage_info(raw_model: str, friendly_name: str, bus_type: str = "", media_type: str = "") -> Dict[str, str]:
    name = raw_model or friendly_name or ""
    name = re.sub(r'^\d+(?:\.\d+)?\s*(?:GB|TB|MB)\s*(?:NVMe|SATA|SSD|HDD)?\s*', '', name, flags=re.IGNORECASE)
    name = re.sub(r'^(?:NVMe|SATA|SCSI|USB)\s*', '', name, flags=re.IGNORECASE)

    if name.upper().startswith("INTEL "):
        name = "Intel " + name[6:].strip()
    elif name.upper().startswith("SAMSUNG "):
        name = "Samsung " + name[8:].strip()
    elif name.upper().startswith("KINGSTON "):
        name = "Kingston " + name[9:].strip()
    elif name.upper().startswith("CRUCIAL "):
        name = "Crucial " + name[8:].strip()
    elif name.upper().startswith("SANDISK "):
        name = "SanDisk " + name[8:].strip()

    is_usb = "usb" in bus_type.lower() or "usb" in media_type.lower() or "usb" in name.lower() or "removable" in media_type.lower()
    is_nvme = "nvme" in bus_type.lower() or "nvme" in media_type.lower() or "nvme" in name.lower()
    is_ssd = "ssd" in media_type.lower() or "ssd" in name.lower() or is_nvme

    if is_usb:
        type_desc = "USB Storage"
    elif is_nvme:
        type_desc = "NVMe M.2 PCIe SSD"
    elif is_ssd:
        type_desc = '2.5" SATA SSD'
    elif "removable" in media_type.lower():
        type_desc = "Removable Storage"
    else:
        type_desc = 'HDD 3.5" 7200 RPM'

    return {
        "raw_model": raw_model,
        "display_name": name.strip(),
        "type_description": type_desc
    }
