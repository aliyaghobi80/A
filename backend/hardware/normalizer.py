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

def normalize_motherboard_info(manufacturer: str, model: str) -> Dict[str, Any]:
    raw_mfg = (manufacturer or "").strip()
    raw_mdl = (model or "").strip()
    combined = f"{raw_mfg} {raw_mdl}".lower()

    brand = "Unknown"
    brand_fa = "نامشخص"
    brand_slug = "generic"

    if re.search(r'\b(asustek|asus|rog|tuf)\b', combined):
        brand = "ASUS"
        brand_fa = "ایسوس"
        brand_slug = "asus"
    elif re.search(r'\b(gigabyte|giga-byte|aorus)\b', combined):
        brand = "GIGABYTE"
        brand_fa = "گیگابایت"
        brand_slug = "gigabyte"
    elif re.search(r'\b(micro-star|msi|meg|mpg|mag)\b', combined):
        brand = "MSI"
        brand_fa = "ام‌اس‌آی"
        brand_slug = "msi"
    elif re.search(r'\b(asrock)\b', combined):
        brand = "ASRock"
        brand_fa = "ازراک"
        brand_slug = "asrock"
    elif re.search(r'\b(biostar)\b', combined):
        brand = "BIOSTAR"
        brand_fa = "بایواستار"
        brand_slug = "biostar"
    elif re.search(r'\b(lenovo|legion|thinkcentre)\b', combined):
        brand = "Lenovo"
        brand_fa = "لنوو"
        brand_slug = "lenovo"
    elif re.search(r'\b(dell|alienware)\b', combined):
        brand = "Dell"
        brand_fa = "دل"
        brand_slug = "dell"
    elif re.search(r'\b(hp|hewlett-packard|omen)\b', combined):
        brand = "HP"
        brand_fa = "اچ‌پی"
        brand_slug = "hp"
    elif re.search(r'\b(acer|predator)\b', combined):
        brand = "Acer"
        brand_fa = "ایسر"
        brand_slug = "acer"
    elif re.search(r'\b(colorful|colorfly)\b', combined):
        brand = "Colorful"
        brand_fa = "کالرفول"
        brand_slug = "colorful"
    elif re.search(r'\b(maxsun)\b', combined):
        brand = "MAXSUN"
        brand_fa = "مکس‌سان"
        brand_slug = "maxsun"
    elif re.search(r'\b(nzxt)\b', combined):
        brand = "NZXT"
        brand_fa = "ان‌زد‌اکس‌تی"
        brand_slug = "nzxt"
    elif re.search(r'\b(evga)\b', combined):
        brand = "EVGA"
        brand_fa = "ای‌وی‌جی‌ای"
        brand_slug = "evga"
    elif re.search(r'\b(intel)\b', combined):
        brand = "Intel"
        brand_fa = "اینتل"
        brand_slug = "intel"
    elif re.search(r'\b(machinist)\b', combined):
        brand = "Machinist"
        brand_fa = "ماکینیست"
        brand_slug = "machinist"
    elif re.search(r'\b(huananzhi|huanan)\b', combined):
        brand = "Huananzhi"
        brand_fa = "هوانانژی"
        brand_slug = "huananzhi"
    elif re.search(r'\b(jingsha)\b', combined):
        brand = "JingSha"
        brand_fa = "جینگ‌شا"
        brand_slug = "jingsha"
    elif re.search(r'\b(szmz)\b', combined):
        brand = "SZMZ"
        brand_fa = "اس‌زد‌ام‌زد"
        brand_slug = "szmz"
    elif re.search(r'\b(soyo)\b', combined):
        brand = "SOYO"
        brand_fa = "سویو"
        brand_slug = "soyo"
    elif raw_mfg and raw_mfg != "Not available":
        clean = re.sub(r'(?:,\s*)?(?:Co\.|Ltd\.|Inc\.|Corp\.|Corporation)\b', '', raw_mfg, flags=re.IGNORECASE).strip()
        clean = re.sub(r'[\s,]+$', '', clean)
        brand = clean if clean else raw_mfg
        brand_fa = brand
        brand_slug = brand.lower().replace(" ", "_")

    # Clean model: strip redundant manufacturer or brand prefixes
    clean_model = raw_mdl
    if brand != "Unknown":
        pattern = rf'^(?:{re.escape(brand)}|{re.escape(raw_mfg)})\s+'
        clean_model = re.sub(pattern, '', clean_model, flags=re.IGNORECASE).strip()

    # Formatted display name: e.g. "GIGABYTE H610M K DDR4" or "ASUS PRIME B660-PLUS D4"
    if brand != "Unknown":
        if clean_model.lower().startswith(brand.lower()):
            display_name = clean_model
        else:
            display_name = f"{brand} {clean_model}" if clean_model else brand
    else:
        display_name = clean_model if clean_model else raw_mfg

    # Chipset detection from model and raw strings
    intel_chipsets = r'\b(Z890|B860|H810|Z790|B760|H770|H710|Z690|B660|H670|H610|Z590|B560|H570|H510|Z490|B460|H470|H410|W480|Z390|Z370|B365|B360|H370|H310|Z270|B250|H270|Z170|B150|H170|H110|Z97|H97|Z87|H87|B85|H81|Z77|H77|B75|Z68|H67|H61|X79|X99|X299)(?=[MIA\s\-_]|$)'
    amd_chipsets = r'\b(X870E|X870|B850|B840|X670E|X670|B650E|B650|A620|X570S|X570|B550|A520|X470|B450|X370|B350|A320|WRX90|TRX50|WRX80|TRX40|X399)(?=[MIA\s\-_]|$)'

    chipset = ""
    full_text = f"{clean_model} {raw_mdl}"
    mi = re.search(intel_chipsets, full_text, re.IGNORECASE)
    ma = re.search(amd_chipsets, full_text, re.IGNORECASE)
    if mi:
        chipset = f"Intel {mi.group(1).upper()}"
    elif ma:
        chipset = f"AMD {ma.group(1).upper()}"

    # Form Factor detection
    form_factor = "ATX"
    if re.search(r'\bMini-?ITX\b|\b[A-Za-z0-9]+-ITX\b|\b[A-Za-z0-9]+-I\b|\b[A-Za-z0-9]{3,}I\b(?<!WIFI)', raw_mdl, re.IGNORECASE):
        form_factor = "Mini-ITX"
    elif re.search(r'\bMicro-?ATX\b|\bmATX\b|\b[A-Za-z0-9]+M\b', raw_mdl, re.IGNORECASE):
        form_factor = "Micro-ATX"
    elif re.search(r'\bE-?ATX\b|\bExtended-?ATX\b', raw_mdl, re.IGNORECASE):
        form_factor = "E-ATX"

    return {
        "raw_manufacturer": manufacturer,
        "raw_model": model,
        "display_name": display_name,
        "clean_manufacturer": brand,
        "brand": brand,
        "brand_fa": brand_fa,
        "brand_slug": brand_slug,
        "clean_model": clean_model if clean_model else raw_mdl,
        "chipset": chipset,
        "form_factor": form_factor,
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
