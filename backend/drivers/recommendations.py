# backend/drivers/recommendations.py
"""
Intelligent Hardware Driver Troubleshooting & Recommendation Engine
Provides offline smart assistance for technical employees at Markazi System:
- Automatically detects laptop models, motherboard brands, and dedicated GPUs
- Formulates exact official Google search queries for 1-click copying
- Suggests direct official manufacturer driver download centers (ASUS, Lenovo, HP, Dell, Gigabyte, MSI, etc.)
- Provides technician tips on driver installation order (Chipset -> Serial IO -> VGA -> Audio -> Wi-Fi -> BT).
"""

from typing import Dict, Any, List, Optional
from utils.formatters import clean_string

# Official Manufacturer Support Portals Database
MANUFACTURER_PORTALS = {
    "asus": {
        "name": "ASUS Download Center",
        "name_fa": "مرکز دانلود درایورهای ایسوس (ASUS)",
        "url": "https://www.asus.com/support/Download-Center/",
        "search_pattern": "{model} driver download official asus support",
    },
    "lenovo": {
        "name": "Lenovo PC Support",
        "name_fa": "پورتال پشتیبانی و درایورهای لنوو (Lenovo)",
        "url": "https://pcsupport.lenovo.com/",
        "search_pattern": "Lenovo {model} drivers and software download",
    },
    "hp": {
        "name": "HP Customer Support - Software and Drivers",
        "name_fa": "مرکز دانلود درایورهای اچ‌پی (HP)",
        "url": "https://support.hp.com/drivers",
        "search_pattern": "HP {model} drivers download official support",
    },
    "dell": {
        "name": "Dell Drivers & Downloads",
        "name_fa": "مرکز دانلود درایورهای دل (Dell)",
        "url": "https://www.dell.com/support/home/drivers",
        "search_pattern": "Dell {model} drivers downloads official",
    },
    "gigabyte": {
        "name": "GIGABYTE Download Center",
        "name_fa": "مرکز دانلود پشتیبانی گیگابایت (GIGABYTE)",
        "url": "https://www.gigabyte.com/Support/Consumer/Download",
        "search_pattern": "Gigabyte {model} motherboard driver download",
    },
    "msi": {
        "name": "MSI Member Center & Downloads",
        "name_fa": "مرکز دانلود درایورهای ام‌اس‌آی (MSI)",
        "url": "https://www.msi.com/support/download",
        "search_pattern": "MSI {model} driver download official support",
    },
    "asrock": {
        "name": "ASRock Support & Download",
        "name_fa": "مرکز دانلود ازراک (ASRock)",
        "url": "https://www.asrock.com/support/index.asp",
        "search_pattern": "ASRock {model} driver download official",
    },
    "acer": {
        "name": "Acer Drivers and Manuals",
        "name_fa": "مرکز دانلود ایسر (Acer)",
        "url": "https://www.acer.com/support/drivers-and-manuals",
        "search_pattern": "Acer {model} drivers download official support",
    },
    "nvidia": {
        "name": "NVIDIA Official Drivers Download",
        "name_fa": "مرکز رسمی دانلود درایورهای انویدیا (NVIDIA GeForce)",
        "url": "https://www.nvidia.com/Download/index.aspx",
        "search_pattern": "NVIDIA {model} driver download official",
    },
    "amd": {
        "name": "AMD Drivers and Support",
        "name_fa": "مرکز درایور و پشتیبانی ای‌ام‌دی (AMD Radeon / Chipset)",
        "url": "https://www.amd.com/en/support",
        "search_pattern": "AMD {model} driver official download",
    },
    "intel": {
        "name": "Intel Download Center",
        "name_fa": "مرکز دانلود و دستیار درایور اینتل (Intel)",
        "url": "https://www.intel.com/content/www/us/en/download-center/home.html",
        "search_pattern": "Intel {model} driver official download center",
    },
    "realtek": {
        "name": "Realtek High Definition Audio Codecs",
        "name_fa": "درایورهای صوتی و شبکه ریل‌تک (Realtek)",
        "url": "https://www.realtek.com/en/downloads",
        "search_pattern": "Realtek High Definition Audio driver download official",
    },
}

def _detect_brand_and_model(system_info: Dict[str, Any]) -> Dict[str, Any]:
    """Identifies primary device manufacturer and exact model."""
    sys_meta = system_info.get("system", {})
    mb = system_info.get("motherboard", {})
    
    sys_mfg = clean_string(sys_meta.get("manufacturer", ""))
    sys_model = clean_string(sys_meta.get("model", ""))
    mb_mfg = clean_string(mb.get("manufacturer", ""))
    mb_model = clean_string(mb.get("product", ""))

    # Determine if laptop or desktop
    is_laptop = False
    battery = system_info.get("battery", {})
    if battery.get("has_battery"):
        is_laptop = True

    # Check brand in order of specificity
    brand_key = "general"
    brand_name = "System Manufacturer"
    brand_name_fa = "سازنده سیستم"
    device_model = sys_model if (sys_model and sys_model != "Not available" and sys_model != "Default string") else mb_model

    combined_text = f"{sys_mfg} {sys_model} {mb_mfg} {mb_model}".lower()

    if "asus" in combined_text or "asustek" in combined_text:
        brand_key = "asus"
        brand_name = "ASUS"
        brand_name_fa = "ایسوس (ASUS)"
    elif "lenovo" in combined_text:
        brand_key = "lenovo"
        brand_name = "Lenovo"
        brand_name_fa = "لنوو (Lenovo)"
    elif "hp" in combined_text or "hewlett-packard" in combined_text:
        brand_key = "hp"
        brand_name = "HP"
        brand_name_fa = "اچ‌پی (HP)"
    elif "dell" in combined_text:
        brand_key = "dell"
        brand_name = "Dell"
        brand_name_fa = "دل (Dell)"
    elif "gigabyte" in combined_text:
        brand_key = "gigabyte"
        brand_name = "Gigabyte"
        brand_name_fa = "گیگابایت (Gigabyte)"
    elif "msi" in combined_text or "micro-star" in combined_text:
        brand_key = "msi"
        brand_name = "MSI"
        brand_name_fa = "ام‌اس‌آی (MSI)"
    elif "asrock" in combined_text:
        brand_key = "asrock"
        brand_name = "ASRock"
        brand_name_fa = "ازراک (ASRock)"
    elif "acer" in combined_text:
        brand_key = "acer"
        brand_name = "Acer"
        brand_name_fa = "ایسر (Acer)"

    # Clean model name
    if device_model in ["Not available", "Default string", "None", "System Product Name"]:
        device_model = mb_model if mb_model not in ["Not available", "Default string", "None"] else sys_mfg

    return {
        "brand_key": brand_key,
        "brand_name": brand_name,
        "brand_name_fa": brand_name_fa,
        "device_model": device_model,
        "is_laptop": is_laptop,
    }

def generate_driver_recommendation_for_item(
    item_name: str,
    category: str,
    device_info: Dict[str, Any]
) -> Dict[str, Any]:
    """Generates specific search query and guidance for a single driver."""
    brand_key = device_info["brand_key"]
    model = device_info["device_model"]
    portal = MANUFACTURER_PORTALS.get(brand_key, {})

    cat_lower = category.lower()
    name_lower = item_name.lower()

    if "graphics" in cat_lower or "display" in cat_lower:
        if "nvidia" in name_lower or "geforce" in name_lower or "rtx" in name_lower or "gtx" in name_lower:
            portal_info = MANUFACTURER_PORTALS["nvidia"]
            query = f"NVIDIA {item_name} driver download official"
            guide_fa = f"به سایت رسمی انویدیا مراجعه کرده و درایور کارت گرافیک {item_name} را دانلود کنید."
            guide_en = f"Visit official NVIDIA support and download the Game Ready / Studio driver for {item_name}."
            return {
                "portal_name": portal_info["name"],
                "portal_name_fa": portal_info["name_fa"],
                "portal_url": portal_info["url"],
                "search_query": query,
                "guide_fa": guide_fa,
                "guide_en": guide_en,
            }
        elif "amd" in name_lower or "radeon" in name_lower:
            portal_info = MANUFACTURER_PORTALS["amd"]
            query = f"AMD Radeon {item_name} driver download official support"
            guide_fa = f"به سایت AMD مراجعه کرده و پکیج Adrenalin Software را برای {item_name} دانلود کنید."
            guide_en = f"Visit official AMD support and download Adrenalin Software for {item_name}."
            return {
                "portal_name": portal_info["name"],
                "portal_name_fa": portal_info["name_fa"],
                "portal_url": portal_info["url"],
                "search_query": query,
                "guide_fa": guide_fa,
                "guide_en": guide_en,
            }
        elif "intel" in name_lower or "iris" in name_lower or "uhd" in name_lower or "arc" in name_lower:
            portal_info = MANUFACTURER_PORTALS["intel"]
            query = f"Intel Graphics {item_name} driver download official"
            guide_fa = f"از مرکز دانلود اینتل درایور گرافیک پردازنده {item_name} را دریافت نمایید."
            guide_en = f"Download the latest Intel Graphics driver for {item_name} from Intel Download Center."
            return {
                "portal_name": portal_info["name"],
                "portal_name_fa": portal_info["name_fa"],
                "portal_url": portal_info["url"],
                "search_query": query,
                "guide_fa": guide_fa,
                "guide_en": guide_en,
            }

    # Laptop / Motherboard Specific Drivers (Audio, Wi-Fi, Chipset, Touchpad, LAN)
    portal_name = portal.get("name", "Official Support Center")
    portal_name_fa = portal.get("name_fa", f"مرکز پشتیبانی {device_info['brand_name']}")
    portal_url = portal.get("url", f"https://www.google.com/search?q={model}+drivers")

    query = f"{device_info['brand_name']} {model} {item_name} driver download official"
    guide_fa = f"مدل «{model}» را در {portal_name_fa} جستجو کرده و درایور بخش {category} را دریافت و نصب کنید."
    guide_en = f"Search '{model}' on {portal_name} and download the driver package for {category}."

    return {
        "portal_name": portal_name,
        "portal_name_fa": portal_name_fa,
        "portal_url": portal_url,
        "search_query": query,
        "guide_fa": guide_fa,
        "guide_en": guide_en,
    }

def generate_system_driver_recommendations(
    system_info: Dict[str, Any],
    driver_items: List[Dict[str, Any]]
) -> Dict[str, Any]:
    """
    Generates a high-level troubleshooting guide and recommendations overview
    for Markazi System technical staff.
    """
    device_info = _detect_brand_and_model(system_info)
    brand_name = device_info["brand_name"]
    brand_name_fa = device_info["brand_name_fa"]
    model = device_info["device_model"]
    portal = MANUFACTURER_PORTALS.get(device_info["brand_key"], MANUFACTURER_PORTALS.get("asus"))

    # Missing & Problem Drivers
    missing_items = [d for d in driver_items if not d.get("is_healthy") or d.get("problem_code", 0) != 0]

    # Google 1-click Search Query
    if device_info["is_laptop"]:
        main_search_query = f"{brand_name} {model} official drivers support download"
        device_type_fa = f"لپ‌تاپ {brand_name_fa} مدل {model}"
    else:
        main_search_query = f"{brand_name} {model} motherboard driver official support download"
        device_type_fa = f"مادربرد {brand_name_fa} مدل {model}"

    # Professional Installation Workflow Steps for Techs
    installation_order_fa = [
        "۱. درایور چیپست و اینترفیس سیستم (Chipset & Intel Serial IO / AMD SMBus)",
        "۲. درایور کارت گرافیک اصلی و کمکی (VGA / Display Driver)",
        "۳. درایور کارت شبکه بی‌سیم و بلوتوث (Wireless LAN & Bluetooth)",
        "۴. درایور کارت صدا (Realtek High Definition Audio)",
        "۵. درایور تاچ‌پد، پورت‌ها و سایر حسگرها (Touchpad / HID / Camera)",
    ]

    installation_order_en = [
        "1. Chipset & Core System Interfaces (Chipset, Serial IO, MEI)",
        "2. Display & Graphics Drivers (Intel / AMD / NVIDIA)",
        "3. Network Drivers (Wireless LAN & Bluetooth)",
        "4. High Definition Audio Driver (Realtek / Cirrus)",
        "5. Input & Auxiliary Devices (Touchpad, Card Reader, Camera)",
    ]

    tips_fa = (
        f"راهنمای فنی کامپیوتر مرکزی: برای {device_type_fa}، ابتدا عبارت جستجوی زیر را در سایت سازنده وارد کنید. "
        "همیشه درایورهای رسمی نسخه ۶۴ بیتی ویندوز ۱۱/۱۰ را دانلود کرده و طبق ترتیب استاندارد نصب نمایید."
    )

    return {
        "brand": brand_name,
        "brand_fa": brand_name_fa,
        "model": model,
        "device_type_fa": device_type_fa,
        "is_laptop": device_info["is_laptop"],
        "portal_name": portal["name"],
        "portal_name_fa": portal["name_fa"],
        "portal_url": portal["url"],
        "main_search_query": main_search_query,
        "missing_count": len(missing_items),
        "has_missing": len(missing_items) > 0,
        "installation_order_fa": installation_order_fa,
        "installation_order_en": installation_order_en,
        "tech_tips_fa": tips_fa,
    }
