# backend/drivers/package_inspector.py
"""
Intelligent Driver Package Inspector.
Recursively detects, inspects, and classifies real-world Windows driver packages:
- Type A: ZIP packages (safe extraction, deep scan of INF/EXE/MSI/Scripts)
- Type B: Extracted folders (recursive subdirectory inspection)
- Type C: Self-extracting driver EXEs (safe PE metadata inspection without execution)
- Type D: Direct INF driver trees (PnPUtil ready, hardware IDs parsed)

Supports hardware vendors: ASUS, Gigabyte, Lenovo, MSI, ASRock, Acer, Dell, HP,
Samsung, Toshiba/Dynabook, Huawei, Intel, AMD, NVIDIA, Realtek, MediaTek, Qualcomm,
Broadcom, Goodix, Synaptics, ELAN, etc.

Safety & Profiling:
- Zero guessed switches: unknown packages receive empty silent_args []
- Concurrency classification: is_barrier and is_parallel_safe conforming to CONTRACT.md
- Exclusion filter: excludes diagnostics, cleanup utilities, firmware/BIOS flashers, uninstallers
- Helper metadata parser: extracts documented metadata from .cva, InstallStep.txt, README
"""

import configparser
import hashlib
import io
import logging
import os
import re
import struct
import tempfile
import zipfile
from typing import Dict, Any, List, Optional, Tuple

logger = logging.getLogger(__name__)

# Standard Driver Categories & Metadata
DRIVER_CATEGORIES = {
    "chipset": {"en": "Chipset & Platform", "fa": "چیپست و پلتفرم", "order": 1},
    "system_mei": {"en": "Management Engine & System", "fa": "موتور مدیریت و رابط سیستم", "order": 2},
    "storage": {"en": "Storage & SATA / RAID", "fa": "کنترلر حافظه و ساتا", "order": 3},
    "lan": {"en": "Ethernet / LAN", "fa": "کارت شبکه کابلی (LAN)", "order": 4},
    "wifi": {"en": "Wi-Fi / Wireless Network", "fa": "شبکه بی‌سیم (Wi-Fi)", "order": 5},
    "bluetooth": {"en": "Bluetooth Adapter", "fa": "بلوتوث (Bluetooth)", "order": 6},
    "audio": {"en": "Audio / Sound Card", "fa": "کارت صدا و مالتی‌مدیا", "order": 7},
    "gpu": {"en": "Graphics / GPU", "fa": "کارت گرافیک (GPU)", "order": 8},
    "touchpad": {"en": "Touchpad & Input", "fa": "تاچ‌پد و حسگرها", "order": 9},
    "camera": {"en": "Camera & Imaging", "fa": "دوربین و وب‌کم", "order": 10},
    "card_reader": {"en": "Card Reader", "fa": "کارت‌خوان حافظه", "order": 11},
    "usb": {"en": "USB & Thunderbolt", "fa": "یو‌اس‌بی و تاندربولت", "order": 12},
    "other": {"en": "Other Devices", "fa": "سایر دستگاه‌ها", "order": 13},
}

KNOWN_VENDOR_NAMES = [
    "asus", "gigabyte", "lenovo", "msi", "asrock", "acer", "dell", "hp",
    "intel", "amd", "nvidia", "realtek", "mediatek", "qualcomm", "broadcom",
    "synaptics", "elan", "cirrus", "conexant", "killer", "asix",
    "samsung", "toshiba", "dynabook", "huawei", "goodix",
]

# Exclusion keywords for non-driver utilities
EXCLUDED_KEYWORDS = {
    # Diagnostics
    "supportassist", "hwdiagnostic", "diags", "pc-doctor", "pc_doctor", "pcdoctor",
    "diagnostics", "lenovodiagnostics", "dellcommandupdate",
    # Cleanup utilities
    "ddu", "amdcleanuputility", "cleaner", "remover", "cleanup", "drivercleaner",
    # Firmware / BIOS flashers
    "fwupdate", "firmwareupdate", "meupdate", "flash.bat", "flash.exe", "fpt.exe", "afudos",
    "biosflash", "bios_update", "bios-update", "insydeflash", "hpflash", "amifldrv", "afuwin",
    "firmware", "bios", "uefi", "ec firmware", "embedded controller",
    # Uninstallers
    "uninstall", "unins000", "unins001", "uninstaller",
}


def is_excluded_utility(path_or_name: str) -> bool:
    """Checks if a file or directory path matches diagnostics, cleanup, firmware/BIOS, or uninstallers."""
    if not path_or_name:
        return False
    p_lower = path_or_name.lower().replace("\\", "/")
    base_name = os.path.basename(p_lower)
    parts = {part.strip(" ._-()[]") for part in p_lower.split("/")}

    if base_name in ("flash.bat", "flash.exe", "fpt.exe", "afudos.exe", "afudos"):
        return True

    if parts.intersection(EXCLUDED_KEYWORDS):
        return True

    for kw in EXCLUDED_KEYWORDS:
        if kw in base_name or kw in p_lower:
            return True

    return False


def _safe_extract_zip(archive_path: str, destination: str) -> None:
    """Extracts zip archive safely, preventing path traversal attacks."""
    dest_abs = os.path.abspath(destination)
    with zipfile.ZipFile(archive_path, "r") as archive:
        for member in archive.infolist():
            target = os.path.abspath(os.path.join(dest_abs, member.filename))
            if os.path.commonpath([dest_abs, target]) != dest_abs:
                raise ValueError(f"Security: Malicious zip entry detected (path traversal): {member.filename}")
        archive.extractall(dest_abs)


def _compute_sha256(file_path: str, max_bytes: int = 16 * 1024 * 1024) -> str:
    """Computes SHA-256 for fingerprinting (reads up to max_bytes for speed)."""
    try:
        h = hashlib.sha256()
        with open(file_path, "rb") as f:
            chunk = f.read(65536)
            total = 0
            while chunk and total < max_bytes:
                h.update(chunk)
                total += len(chunk)
                chunk = f.read(65536)
        return h.hexdigest()
    except Exception:
        return ""


def extract_pe_metadata(exe_path: str) -> Dict[str, str]:
    """
    Extracts Windows PE Version Information without executing the file:
    FileDescription, ProductName, CompanyName, FileVersion, ProductVersion, OriginalFilename.
    """
    metadata = {
        "file_description": "",
        "product_name": "",
        "company_name": "",
        "file_version": "",
        "product_version": "",
        "original_filename": "",
    }
    if not os.path.isfile(exe_path):
        return metadata

    try:
        with open(exe_path, "rb") as f:
            head = f.read(1572864)
            f.seek(max(0, os.path.getsize(exe_path) - 524288))
            tail = f.read(524288)
            blob = head + tail

        keys = {
            "FileDescription": "file_description",
            "ProductName": "product_name",
            "CompanyName": "company_name",
            "FileVersion": "file_version",
            "ProductVersion": "product_version",
            "OriginalFilename": "original_filename",
        }

        for key, field in keys.items():
            pattern_utf16 = key.encode("utf-16le") + b"\x00\x00"
            idx = blob.find(pattern_utf16)
            if idx != -1:
                sub = blob[idx + len(pattern_utf16): idx + len(pattern_utf16) + 300]
                try:
                    text = sub.decode("utf-16le", errors="ignore").split("\x00")[0].strip()
                    if text and len(text) < 120 and text.isprintable():
                        metadata[field] = text
                except Exception:
                    pass

            if not metadata[field]:
                pattern_ascii = key.encode("ascii") + b"\x00"
                idx_a = blob.find(pattern_ascii)
                if idx_a != -1:
                    sub_a = blob[idx_a + len(pattern_ascii): idx_a + len(pattern_ascii) + 150]
                    try:
                        text_a = sub_a.decode("ascii", errors="ignore").split("\x00")[0].strip()
                        if text_a and len(text_a) < 120 and text_a.isprintable():
                            metadata[field] = text_a
                    except Exception:
                        pass
    except Exception as e:
        logger.debug(f"PE inspection failed on {exe_path}: {e}")

    return metadata


def parse_inf_file(inf_path: str) -> Dict[str, Any]:
    """
    Parses a Windows INF driver file:
    Extracts Provider, DriverVer (date and version), Class, ClassGUID,
    Manufacturer, and all Hardware IDs (PCI\\..., USB\\..., ACPI\\..., HDAUDIO\\...)
    and Compatible IDs.
    """
    res: Dict[str, Any] = {
        "inf_name": os.path.basename(inf_path),
        "inf_path": inf_path,
        "provider": "",
        "driver_date": "",
        "driver_version": "",
        "class": "",
        "class_guid": "",
        "catalog_file": "",
        "hardware_ids": [],
        "compatible_ids": [],
        "model_names": [],
    }

    if not os.path.isfile(inf_path):
        return res

    encodings = ["utf-8-sig", "utf-16", "utf-16-le", "cp1252", "latin1"]
    content = ""
    for enc in encodings:
        try:
            with open(inf_path, "r", encoding=enc, errors="strict") as f:
                content = f.read()
                if content and "[" in content and "\x00" not in content:
                    break
        except Exception:
            continue

    if not content:
        return res

    lines = [line.strip() for line in content.splitlines() if line.strip() and not line.strip().startswith(";")]
    current_section = ""
    sections: Dict[str, List[str]] = {}

    for line in lines:
        if line.startswith("[") and "]" in line:
            current_section = line.strip("[]").strip().lower()
            if current_section not in sections:
                sections[current_section] = []
        elif current_section:
            sections[current_section].append(line)

    # 1. Version Section
    version_lines = sections.get("version", [])
    for v in version_lines:
        if "=" in v:
            key, val = [p.strip() for p in v.split("=", 1)]
            k_low = key.lower()
            val_clean = val.strip('"\';')
            if k_low == "provider":
                res["provider"] = val_clean.strip("%")
            elif k_low == "driverver":
                parts = [p.strip() for p in val_clean.split(",")]
                if len(parts) >= 1:
                    res["driver_date"] = parts[0]
                if len(parts) >= 2:
                    res["driver_version"] = parts[1]
            elif k_low == "class":
                res["class"] = val_clean
            elif k_low == "classguid":
                res["class_guid"] = val_clean
            elif k_low == "catalogfile":
                res["catalog_file"] = val_clean

    # 2. Hardware IDs & Compatible IDs from Model Sections
    hw_ids = set()
    compat_ids = set()
    model_names = set()

    model_section_names = set()
    for m in sections.get("manufacturer", []):
        if "=" in m:
            _, sec_refs = m.split("=", 1)
            for ref in sec_refs.split(","):
                ref = ref.strip().lower()
                if ref:
                    model_section_names.add(ref)

    target_sections = model_section_names if model_section_names else [
        s for s in sections.keys() if any(t in s for t in ("nt", "model", "pci", "usb", "hdaudio", "acpi"))
    ]

    hw_id_pattern = re.compile(r"((?:PCI|USB|HDAUDIO|ACPI|ROOT|HID|BTH|SWD)\\[A-Za-z0-9_&.-]+)", re.IGNORECASE)

    for sec_name in target_sections:
        for line in sections.get(sec_name, []):
            if "=" in line:
                model_str, id_part = line.split("=", 1)
                model_names.add(model_str.strip(' %"'))
                tokens = [t.strip(' %"') for t in id_part.split(",") if t.strip()]
                for token in tokens:
                    matches = hw_id_pattern.findall(token)
                    for m in matches:
                        hw_ids.add(m.upper())

    if not hw_ids:
        all_matches = hw_id_pattern.findall(content)
        for m in all_matches:
            hw_ids.add(m.upper())

    strings_map: Dict[str, str] = {}
    for str_sec in [s for s in sections.keys() if "strings" in s]:
        for line in sections.get(str_sec, []):
            if "=" in line:
                k, val = line.split("=", 1)
                strings_map[k.strip().lower()] = val.strip(' "\'')

    if res["provider"].lower() in strings_map:
        res["provider"] = strings_map[res["provider"].lower()]

    clean_models = []
    for m in model_names:
        clean = strings_map.get(m.lower(), m)
        if clean and len(clean) > 2 and not clean.startswith("%"):
            clean_models.append(clean)

    res["hardware_ids"] = sorted(list(hw_ids))
    res["compatible_ids"] = sorted(list(compat_ids))
    res["model_names"] = clean_models[:8]

    return res


def classify_driver_category(
    name_hints: List[str],
    inf_class: str = "",
    hardware_ids: Optional[List[str]] = None
) -> Tuple[str, str]:
    """
    Classifies driver category based on multi-signal scoring:
    1. INF Class / ClassGuid
    2. Hardware IDs (VEN_10DE -> GPU, VEN_10EC DEV_8168 -> LAN, VID_27C6 -> Goodix touchpad/biometric)
    3. Directory / Package filename hints
    Returns (category_key, category_persian_name).
    """
    hints_text = " ".join(name_hints).lower()
    package_hint = (name_hints[0] if name_hints else "").lower().replace("-", "_")
    inf_c = inf_class.lower()
    hw_text = " ".join(hardware_ids or []).upper()

    strong_hints = (
        ("audio", ("drv_audio",)),
        ("bluetooth", ("drv_bt_", "bluetooth")),
        ("lan", ("drv_lan", "ethernet")),
        ("wifi", ("drv_wifi", "wlan", "wireless")),
        ("gpu", ("drv_vga", "graphics", "display")),
        ("storage", ("drv_rst", "vmd", "rapid_storage")),
        ("system_mei", ("drv_npu", "management_engine", "drv_mei")),
        ("audio", ("drv_ucm_realtek",)),
    )
    for category, tokens in strong_hints:
        if any(token in package_hint for token in tokens):
            return category, DRIVER_CATEGORIES[category]["fa"]

    # 1. INF Class matching
    if inf_c == "display":
        return "gpu", DRIVER_CATEGORIES["gpu"]["fa"]
    if inf_c in ("media", "audioendpoint"):
        return "audio", DRIVER_CATEGORIES["audio"]["fa"]
    if inf_c == "net":
        if any(w in hints_text for w in ("wi-fi", "wifi", "wlan", "wireless", "802.11")):
            return "wifi", DRIVER_CATEGORIES["wifi"]["fa"]
        return "lan", DRIVER_CATEGORIES["lan"]["fa"]
    if inf_c == "bluetooth":
        return "bluetooth", DRIVER_CATEGORIES["bluetooth"]["fa"]
    if inf_c in ("camera", "image"):
        return "camera", DRIVER_CATEGORIES["camera"]["fa"]
    if inf_c in ("hdc", "scsiadapter"):
        return "storage", DRIVER_CATEGORIES["storage"]["fa"]
    if inf_c in ("mouse", "keyboard", "hidclass", "biometric"):
        return "touchpad", DRIVER_CATEGORIES["touchpad"]["fa"]
    if inf_c == "system":
        if any(m in hints_text for m in ("management engine", "mei", "csme", "txei")):
            return "system_mei", DRIVER_CATEGORIES["system_mei"]["fa"]
        return "chipset", DRIVER_CATEGORIES["chipset"]["fa"]

    # 2. Hardware ID vendor/device heuristics
    if "VID_27C6" in hw_text:  # Goodix Fingerprint / Touch sensor
        return "touchpad", DRIVER_CATEGORIES["touchpad"]["fa"]
    if "VEN_10DE" in hw_text or "VEN_1002" in hw_text:  # NVIDIA or AMD Radeon
        if any(w in hints_text for w in ("vga", "graphics", "display", "geforce", "radeon")) or not any(w in hints_text for w in ("audio", "sound")):
            return "gpu", DRIVER_CATEGORIES["gpu"]["fa"]

    # 3. Keyword / Hint heuristics
    if any(w in hints_text for w in ("chipset", "infupdate", "smbus", "serialio", "serial io", "spi", "i2c", "lpss")):
        return "chipset", DRIVER_CATEGORIES["chipset"]["fa"]
    if any(w in hints_text for w in ("management engine", "mei", "csme", "heci")):
        return "system_mei", DRIVER_CATEGORIES["system_mei"]["fa"]
    if any(w in hints_text for w in ("lan", "ethernet", "gbe", "gigabit", "pcie fe", "i219", "i225", "e1d", "rt64")):
        return "lan", DRIVER_CATEGORIES["lan"]["fa"]
    if any(w in hints_text for w in ("wifi", "wi-fi", "wlan", "wireless", "802.11")):
        return "wifi", DRIVER_CATEGORIES["wifi"]["fa"]
    if any(w in hints_text for w in ("bluetooth", "bth", "bt ")):
        return "bluetooth", DRIVER_CATEGORIES["bluetooth"]["fa"]
    if any(w in hints_text for w in ("audio", "sound", "realtek audio", "smart sound", "issta", "hdaudio", "codec")):
        return "audio", DRIVER_CATEGORIES["audio"]["fa"]
    if any(w in hints_text for w in ("vga", "graphic", "display", "nvidia", "geforce", "radeon", "intel arc", "uhd graphics")):
        return "gpu", DRIVER_CATEGORIES["gpu"]["fa"]
    if any(w in hints_text for w in ("rst", "rapid storage", "ahci", "raid", "sata", "nvme", "vmd")):
        return "storage", DRIVER_CATEGORIES["storage"]["fa"]
    if any(w in hints_text for w in ("touchpad", "trackpad", "touch pad", "precision", "elan", "synaptics", "goodix", "fingerprint", "biometric")):
        return "touchpad", DRIVER_CATEGORIES["touchpad"]["fa"]
    if any(w in hints_text for w in ("camera", "webcam", "imaging")):
        return "camera", DRIVER_CATEGORIES["camera"]["fa"]
    if any(w in hints_text for w in ("cardreader", "card reader", "rtsx", "sd card")):
        return "card_reader", DRIVER_CATEGORIES["card_reader"]["fa"]
    if any(w in hints_text for w in ("thunderbolt", "tbt", "usb")):
        return "usb", DRIVER_CATEGORIES["usb"]["fa"]

    return "other", DRIVER_CATEGORIES["other"]["fa"]


def _format_size(size_bytes: int) -> str:
    if size_bytes < 1024:
        return f"{size_bytes} B"
    elif size_bytes < 1024 * 1024:
        return f"{size_bytes / 1024:.1f} KB"
    elif size_bytes < 1024 * 1024 * 1024:
        return f"{size_bytes / (1024 * 1024):.1f} MB"
    else:
        return f"{size_bytes / (1024 * 1024 * 1024):.2f} GB"


def classify_concurrency_flags(
    category: str,
    install_method: str,
    silent_args: List[str],
) -> Tuple[bool, bool]:
    """
    Returns (is_barrier, is_parallel_safe) conforming to CONTRACT.md Section 3.
    """
    # 3.1 Strict Barriers (is_barrier: True, is_parallel_safe: False)
    # 1. Core Platform & Chipset
    if category in ("chipset", "system_mei", "storage"):
        return True, False

    # 2. Graphics Drivers (GPU)
    if category == "gpu":
        return True, False

    # 3. Windows Installer (MSI Packages)
    if install_method == "msiexec":
        return True, False

    # 4. PnPUtil INF Batches
    if install_method in ("pnputil", "inf_pnputil"):
        return True, False

    # 5. Vendor Batch Scripts
    if install_method == "script":
        return True, False

    # 6. Unknown or Unswitched Installers (requires GUI Autopilot)
    if not silent_args:
        return True, False

    # 3.2 Parallel-Safe Packages (is_barrier: False, is_parallel_safe: True)
    parallel_safe_categories = {
        "audio", "lan", "wifi", "bluetooth", "touchpad", "card_reader", "camera", "usb", "other"
    }
    if (
        category in parallel_safe_categories
        and install_method in ("setup_exe", "asus_setup")
        and bool(silent_args)
    ):
        return False, True

    return True, False


class DriverPackage:
    """Represents an analyzed, classified driver package ready for preview or installation."""

    def __init__(
        self,
        package_id: str,
        display_name: str,
        category: str,
        category_fa: str,
        package_type: str,  # 'zip', 'folder', 'self_extracting_exe', 'inf', 'script'
        source_path: str,
        relative_path: str,
        installer_file: str,
        install_method: str,  # 'asus_setup', 'setup_exe', 'script', 'msiexec', 'pnputil', 'self_extract'
        silent_args: List[str],
        size_bytes: int,
        fingerprint: str,
        hardware_ids: List[str],
        driver_version: str = "",
        driver_date: str = "",
        provider: str = "",
        alternative_installers: Optional[List[str]] = None,
        extraction_dir: Optional[str] = None,
        is_safe: bool = True,
        notes: str = "",
        inf_files: Optional[List[str]] = None,
        supported_windows: Optional[List[str]] = None,
        is_barrier: Optional[bool] = None,
        is_parallel_safe: Optional[bool] = None,
        resource_tag: Optional[str] = None,
        timeout_seconds: Optional[int] = None,
        requires_reboot: bool = False,
    ):
        self.package_id = package_id
        self.display_name = display_name
        self.category = category
        self.category_fa = category_fa
        self.package_type = package_type
        self.source_path = source_path
        self.relative_path = relative_path
        self.installer_file = installer_file
        self.install_method = install_method
        self.silent_args = list(silent_args) if silent_args else []
        self.size_bytes = size_bytes
        self.fingerprint = fingerprint
        self.hardware_ids = hardware_ids
        self.driver_version = driver_version
        self.driver_date = driver_date
        self.provider = provider
        self.alternative_installers = alternative_installers or []
        self.extraction_dir = extraction_dir
        self.is_safe = is_safe
        self.notes = notes
        self.inf_files = inf_files or []
        self.supported_windows = supported_windows or []

        # Concurrency flags classification (CONTRACT.md Section 3)
        if is_barrier is None or is_parallel_safe is None:
            calc_barrier, calc_parallel = classify_concurrency_flags(
                self.category, self.install_method, self.silent_args
            )
            self.is_barrier = calc_barrier if is_barrier is None else is_barrier
            self.is_parallel_safe = calc_parallel if is_parallel_safe is None else is_parallel_safe
        else:
            self.is_barrier = is_barrier
            self.is_parallel_safe = is_parallel_safe

        self.resource_tag = resource_tag if resource_tag is not None else self.category
        if timeout_seconds is not None:
            self.timeout_seconds = timeout_seconds
        else:
            if self.category == "gpu":
                self.timeout_seconds = 600
            elif self.category in ("chipset", "system_mei", "storage"):
                self.timeout_seconds = 420
            else:
                self.timeout_seconds = 300
        self.requires_reboot = requires_reboot

    def to_dict(self) -> Dict[str, Any]:
        # Determine effective installer path and method
        if self.installer_file and self.install_method not in ("pnputil", "none"):
            eff_installer_path = self.installer_file
            eff_install_method = self.install_method
        elif self.inf_files:
            eff_installer_path = self.inf_files[0]
            eff_install_method = "pnputil"
        else:
            eff_installer_path = self.installer_file
            eff_install_method = self.install_method or "setup_exe"

        eff_barrier = self.is_barrier
        eff_parallel = self.is_parallel_safe
        if eff_install_method in ("pnputil", "inf_pnputil", "msiexec", "script"):
            eff_barrier = True
            eff_parallel = False

        return {
            "package_id": self.package_id,
            "display_name": self.display_name,
            "category": self.category,
            "category_fa": self.category_fa,
            "category_order": DRIVER_CATEGORIES.get(self.category, {}).get("order", 99),
            "package_type": self.package_type,
            "source_path": self.source_path,
            "relative_path": self.relative_path,
            "installer_file": os.path.basename(self.installer_file) if self.installer_file else (os.path.basename(self.inf_files[0]) if self.inf_files else ""),
            "installer_path": eff_installer_path,
            "install_method": eff_install_method,
            "manual_installer_path": self.installer_file or (self.inf_files[0] if self.inf_files else ""),
            "manual_install_method": self.install_method if self.install_method != "none" else ("pnputil" if self.inf_files else "setup_exe"),
            "silent_args": self.silent_args,
            "is_barrier": eff_barrier,
            "is_parallel_safe": eff_parallel,
            "resource_tag": self.resource_tag,
            "timeout_seconds": self.timeout_seconds,
            "requires_reboot": self.requires_reboot,
            "size_bytes": self.size_bytes,
            "file_size_display": _format_size(self.size_bytes),
            "fingerprint": self.fingerprint,
            "hardware_ids": self.hardware_ids,
            "driver_version": self.driver_version,
            "driver_date": self.driver_date,
            "provider": self.provider,
            "alternative_installers": [os.path.basename(a) for a in self.alternative_installers],
            "is_safe": self.is_safe,
            "notes": self.notes,
            "inf_files": list(self.inf_files),
            "supported_windows": list(self.supported_windows),
        }


def _parse_helper_metadata(root_dir: str) -> Dict[str, Any]:
    """
    Parses helper documentation files (.cva, InstallStep.txt, README) in root_dir
    to discover metadata (title, version) and documented entry points without executing scripts.
    """
    result: Dict[str, Any] = {
        "title": "",
        "version": "",
        "entrypoint": None,
        "silent_args": [],
        "method": None,
    }
    if not os.path.isdir(root_dir):
        return result

    try:
        entries = os.listdir(root_dir)
    except Exception:
        return result

    # 1. Parse HP .cva files
    cva_files = [os.path.join(root_dir, e) for e in entries if e.lower().endswith(".cva")]
    for cva in cva_files:
        try:
            with open(cva, "r", encoding="utf-8", errors="ignore") as f:
                cva_text = f.read()
            for line in cva_text.splitlines():
                line_str = line.strip()
                if "=" in line_str:
                    k, v = [x.strip() for x in line_str.split("=", 1)]
                    k_low = k.lower()
                    val = v.strip(' "\'')
                    if k_low in ("software title", "title") and not result["title"]:
                        result["title"] = val
                    elif k_low == "version" and not result["version"]:
                        result["version"] = val
                    elif k_low in ("silentinstall", "install") and not result["entrypoint"]:
                        tokens = [t.strip(' "\'') for t in val.split() if t.strip(' "\'')]
                        if tokens:
                            candidate_file = tokens[0]
                            full_cand = os.path.join(root_dir, candidate_file)
                            if os.path.isfile(full_cand) and not is_excluded_utility(full_cand):
                                result["entrypoint"] = full_cand
                                ext = os.path.splitext(candidate_file)[1].lower()
                                if ext == ".exe":
                                    result["method"] = "setup_exe"
                                elif ext in (".cmd", ".bat"):
                                    result["method"] = "script"
                                elif ext == ".msi":
                                    result["method"] = "msiexec"
                                result["silent_args"] = [t for t in tokens[1:] if t.startswith(("-", "/"))]
        except Exception as e:
            logger.debug(f"Error reading .cva file {cva}: {e}")

    # 2. Parse ASUS InstallStep.txt
    installstep_files = [
        os.path.join(root_dir, e) for e in entries
        if e.lower() in ("installstep.txt", "install_step.txt", "installstep.bat.txt")
    ]
    for step_file in installstep_files:
        try:
            with open(step_file, "r", encoding="utf-8", errors="ignore") as f:
                step_text = f.read()
            for line in step_text.splitlines():
                line_str = line.strip()
                tokens = [t.strip(' "\';') for t in line_str.split() if t.strip(' "\';')]
                for token in tokens:
                    cand_name = os.path.basename(token)
                    if cand_name.lower().endswith((".exe", ".bat", ".cmd")):
                        full_cand = os.path.join(root_dir, cand_name)
                        if os.path.isfile(full_cand) and not is_excluded_utility(full_cand) and not result["entrypoint"]:
                            result["entrypoint"] = full_cand
                            cand_low = cand_name.lower()
                            if "asussetup" in cand_low:
                                result["method"] = "asus_setup"
                                result["silent_args"] = ["-s", "-norestart"]
                            elif cand_low.endswith(".exe"):
                                result["method"] = "setup_exe"
                                switches = [t for t in tokens if t.startswith(("-", "/"))]
                                result["silent_args"] = switches if switches else get_driver_exe_silent_args(full_cand)
                            elif cand_low.endswith((".bat", ".cmd")):
                                result["method"] = "script"
                                result["silent_args"] = [t for t in tokens if t.startswith(("-", "/"))]
                            break
        except Exception as e:
            logger.debug(f"Error reading InstallStep file {step_file}: {e}")

    # 3. Parse README files
    if not result["entrypoint"]:
        readme_files = [
            os.path.join(root_dir, e) for e in entries
            if any(e.lower().startswith(p) for p in ("readme", "read_me", "install.txt"))
        ]
        for rm in readme_files:
            try:
                with open(rm, "r", encoding="utf-8", errors="ignore") as f:
                    rm_text = f.read()
                for line in rm_text.splitlines():
                    tokens = [t.strip(' "\';') for t in line.strip().split() if t.strip(' "\';')]
                    for token in tokens:
                        cand_name = os.path.basename(token)
                        if cand_name.lower().endswith((".exe", ".bat", ".cmd")):
                            full_cand = os.path.join(root_dir, cand_name)
                            if os.path.isfile(full_cand) and not is_excluded_utility(full_cand) and not result["entrypoint"]:
                                result["entrypoint"] = full_cand
                                ext = os.path.splitext(cand_name)[1].lower()
                                if ext == ".exe":
                                    result["method"] = "setup_exe"
                                    switches = [t for t in tokens if t.startswith(("-", "/"))]
                                    result["silent_args"] = switches if switches else get_driver_exe_silent_args(full_cand)
                                elif ext in (".bat", ".cmd"):
                                    result["method"] = "script"
                                    result["silent_args"] = [t for t in tokens if t.startswith(("-", "/"))]
                                break
                    if result["entrypoint"]:
                        break
            except Exception as e:
                logger.debug(f"Error reading readme file {rm}: {e}")

    return result


def get_driver_exe_silent_args(file_path: str) -> List[str]:
    """
    Returns vendor-specific silent switches for driver executables
    (ASUS, Gigabyte, MSI, Lenovo, HP, Dell, Samsung, Toshiba/Dynabook, Huawei, Goodix, NVIDIA, AMD, Intel, Realtek).
    Returns empty list [] for unknown packages (no guessed switches!).
    """
    name_l = os.path.basename(file_path).lower()
    path_l = os.path.abspath(file_path).lower().replace("\\", "/")

    if "dpinst" in name_l:
        return ["/q", "/se", "/sa", "/sw"]
    elif any(t in name_l for t in ("nvidia", "geforce", "quadro")) or name_l.endswith("-international-dch-whql.exe") or "-whql" in name_l:
        return ["-s", "-noreboot"]
    elif any(t in name_l for t in ("amd", "radeon", "ati", "adrenalin")):
        return ["-INSTALL", "-OUTPUT", "screen", "-NORESTART"]
    elif any(t in name_l for t in ("asussetup", "asus")):
        return ["-s", "-norestart"]
    elif (
        "gfx_win" in path_l
        or "igfx" in path_l
        or ("intel" in path_l and any(t in path_l for t in ("graphic", "display", "vga")))
    ):
        return ["--overwrite", "-s"]
    elif any(t in name_l for t in ("setuprst", "setupchipset", "igxpin")):
        return ["-s", "-norestart"]
    elif re.match(r"^sp\d{4,7}\.exe$", name_l):  # HP SoftPaq
        return ["/s", "-s"]
    elif re.match(r"^[a-z0-9]+us\d+\.exe$", name_l) or "lenovo" in name_l:  # Lenovo SoftPaq
        return ["/VERYSILENT", "/NORESTART", "/SUPPRESSMSGBOXES"]
    elif "dell" in name_l or "win64" in name_l:  # Dell DUP
        return ["/s"]
    # Samsung vendor profile
    elif "samsung" in name_l or "samsung" in path_l:
        return ["/s", "/norestart"]
    # Toshiba / Dynabook vendor profile
    elif any(t in name_l or t in path_l for t in ("toshiba", "dynabook")):
        return ["/s", "/norestart"]
    # Huawei vendor profile
    elif "huawei" in name_l or "huawei" in path_l:
        return ["/s", "/norestart"]
    # Goodix component profile
    elif "goodix" in name_l or "goodix" in path_l:
        return ["/s", "/norestart"]
    elif any(t in name_l or t in path_l for t in ("intel", "realtek", "audio", "lan", "wlan", "wifi", "bluetooth", "touchpad", "chipset")):
        return ["/s", "/norestart"]

    # Zero guessed switches for unknown packages
    return []


def _resolve_installer_entrypoint(root_dir: str) -> tuple[str, str, List[str], List[str]]:
    """
    Finds the best installer entrypoint inside a directory or extracted archive:
    Returns (installer_file, method, silent_args, alternative_files).
    """
    candidates_exe = []
    candidates_msi = []
    candidates_inf = []
    candidates_script = []

    for r, _, files in os.walk(root_dir):
        for f in files:
            full = os.path.join(r, f)
            # Skip excluded utilities
            if is_excluded_utility(full):
                continue
            ext = os.path.splitext(f)[1].lower()
            if ext == ".exe":
                candidates_exe.append(full)
            elif ext == ".msi":
                candidates_msi.append(full)
            elif ext == ".inf":
                candidates_inf.append(full)
            elif ext in (".cmd", ".bat"):
                candidates_script.append(full)

    # 1. ASUS Setup (AsusSetup.exe) - High priority for ASUS laptops and motherboards
    for exe in candidates_exe:
        if os.path.basename(exe).lower() == "asussetup.exe":
            alts = [c for c in candidates_exe if c != exe]
            return exe, "asus_setup", ["-s", "-norestart"], alts

    # 2. Check helper metadata (.cva, InstallStep.txt, README)
    helper_meta = _parse_helper_metadata(root_dir)
    if helper_meta.get("entrypoint") and os.path.isfile(helper_meta["entrypoint"]):
        ep = helper_meta["entrypoint"]
        if not is_excluded_utility(ep):
            method = helper_meta.get("method") or "setup_exe"
            args = helper_meta.get("silent_args") or get_driver_exe_silent_args(ep)
            alts = [c for c in candidates_exe if c != ep]
            return ep, method, args, alts

    # 3. Recognized standard vendor setups (Gigabyte, MSI, Intel, Realtek, Samsung, Huawei)
    known_setups = (
        "setup.exe", "installer.exe", "setuprst.exe", "setupchipset.exe",
        "igxpin.exe", "dpinst.exe", "dpinst64.exe", "install.exe",
        "install_win10.exe", "install_win11.exe", "setup_win10.exe", "setup_win11.exe"
    )
    for exe in candidates_exe:
        if os.path.basename(exe).lower() in known_setups:
            alts = [c for c in candidates_exe if c != exe]
            args = get_driver_exe_silent_args(exe)
            return exe, "setup_exe", args, alts

    # 4. Trusted vendor scripts (SilentInstall.cmd, install.bat, etc.)
    trusted_scripts = (
        "silentinstall.cmd", "silentinstall.bat", "install.cmd", "install.bat",
        "setup.cmd", "setup.bat", "installstep.bat", "silent.bat", "silent.cmd"
    )
    for scr in candidates_script:
        if os.path.basename(scr).lower() in trusted_scripts:
            return scr, "script", [], [c for c in candidates_script if c != scr]

    # 5. Standalone OEM vendor driver packages (NVIDIA, AMD, Intel, Lenovo, HP, Dell)
    for exe in candidates_exe:
        exe_low = os.path.basename(exe).lower()
        if (
            "-whql" in exe_low
            or "geforce" in exe_low
            or "adrenalin" in exe_low
            or exe_low.startswith("amd-software")
            or exe_low.startswith("gfx_win")
            or re.match(r"^sp\d{4,7}\.exe$", exe_low)
            or re.match(r"^[a-z0-9]+us\d+\.exe$", exe_low)
        ):
            alts = [c for c in candidates_exe if c != exe]
            return exe, "setup_exe", get_driver_exe_silent_args(exe), alts

    # 6. Prefer the complete INF tree unless a known OEM wrapper was selected
    if candidates_inf:
        return candidates_inf[0], "pnputil", [], candidates_inf[1:] + candidates_exe

    # 7. Any root or shallow EXE
    if candidates_exe:
        candidates_exe.sort(key=lambda p: len(os.path.relpath(p, root_dir).replace("\\", "/").split("/")))
        primary = candidates_exe[0]
        rel_parts = os.path.relpath(primary, root_dir).replace("\\", "/").split("/")
        if len(rel_parts) <= 2 or not candidates_inf:
            return primary, "setup_exe", get_driver_exe_silent_args(primary), candidates_exe[1:]

    # 8. MSI packages
    if candidates_msi:
        return candidates_msi[0], "msiexec", ["/qn", "/norestart", "REBOOT=ReallySuppress"], candidates_msi[1:]

    return "", "none", [], []


def inspect_driver_package(entry_path: str, driver_root: str) -> Optional[DriverPackage]:
    """
    Inspects a candidate file or directory in the driver directory and returns a DriverPackage.
    Guarantees zero arbitrary execution during inspection.
    Excludes diagnostics, cleanup utilities, firmware/BIOS flashers, and uninstallers.
    """
    if not os.path.exists(entry_path):
        return None

    rel_path = os.path.relpath(entry_path, driver_root)
    base_name = os.path.basename(entry_path)
    parent_folder = os.path.basename(os.path.dirname(entry_path))

    # Exclusion filter: diagnostics, cleanup, firmware/BIOS, uninstallers
    if is_excluded_utility(rel_path) or is_excluded_utility(entry_path) or is_excluded_utility(base_name):
        logger.info("Excluded removal/diagnostic/firmware utility from driver installation: %s", rel_path)
        return None

    version_hint = rel_path.lower().replace("-", "_")
    supported_windows = []
    if re.search(r"(?:^|_)w(?:in)?11(?:_|$)", version_hint):
        supported_windows.append("11")
    if re.search(r"(?:^|_)w(?:in)?10(?:_|$)", version_hint):
        supported_windows.append("10")

    # Determine Package Type
    if os.path.isfile(entry_path):
        ext = os.path.splitext(entry_path)[1].lower()
        if ext == ".zip":
            package_type = "zip"
        elif ext == ".exe":
            package_type = "self_extracting_exe"
        elif ext == ".inf":
            package_type = "inf"
        elif ext == ".msi":
            package_type = "msi"
        elif ext in (".cmd", ".bat"):
            trusted_scripts = {
                "silentinstall.cmd", "silentinstall.bat", "install.cmd",
                "install.bat", "setup.cmd", "setup.bat", "installstep.bat",
                "installpackage.bat", "silent.bat", "silent.cmd",
            }
            if base_name.lower() not in trusted_scripts:
                return None
            package_type = "script"
        else:
            return None
    elif os.path.isdir(entry_path):
        package_type = "folder"
    else:
        return None

    extracted_temp_dir: Optional[str] = None
    target_scan_dir = entry_path

    if package_type == "zip":
        try:
            temp_dir = tempfile.mkdtemp(prefix="markazi_inspect_zip_")
            _safe_extract_zip(entry_path, temp_dir)
            extracted_temp_dir = temp_dir
            target_scan_dir = temp_dir
        except Exception as e:
            logger.warning(f"Failed to safely inspect zip package {entry_path}: {e}")
            return None

    # Gather INF files and metadata
    all_infs = []
    if os.path.isdir(target_scan_dir):
        for r, _, files in os.walk(target_scan_dir):
            for f in files:
                if f.lower().endswith(".inf"):
                    all_infs.append(os.path.join(r, f))
    elif package_type == "inf":
        all_infs = [entry_path]

    inf_data_list = []
    for inf_f in sorted(all_infs):
        inf_data_list.append(parse_inf_file(inf_f))

    # Aggregate Hardware IDs & INF metadata
    combined_hw_ids = set()
    driver_version = ""
    driver_date = ""
    provider = ""
    inf_class = ""
    model_names = []

    for idata in inf_data_list:
        combined_hw_ids.update(idata["hardware_ids"])
        if not driver_version and idata["driver_version"]:
            driver_version = idata["driver_version"]
        if not driver_date and idata["driver_date"]:
            driver_date = idata["driver_date"]
        if not provider and idata["provider"]:
            provider = idata["provider"]
        if not inf_class and idata["class"]:
            inf_class = idata["class"]
        model_names.extend(idata["model_names"])

    # Determine installer file & method
    if package_type in ("folder", "zip"):
        installer_file, install_method, silent_args, alts = _resolve_installer_entrypoint(target_scan_dir)
    elif package_type == "self_extracting_exe":
        installer_file = entry_path
        install_method = "setup_exe"
        silent_args = get_driver_exe_silent_args(entry_path)
        alts = []
    elif package_type == "inf":
        installer_file = entry_path
        install_method = "pnputil"
        silent_args = []
        alts = []
    elif package_type == "script":
        installer_file = entry_path
        install_method = "script"
        silent_args = []
        alts = []
    else:  # msi
        installer_file = entry_path
        install_method = "msiexec"
        silent_args = ["/qn", "/norestart", "REBOOT=ReallySuppress"]
        alts = []

    # Final check on resolved installer file
    if installer_file and is_excluded_utility(installer_file):
        logger.info("Excluded removal/diagnostic/firmware utility installer: %s", installer_file)
        return None

    # Helper metadata from .cva / InstallStep.txt / README
    helper_meta = _parse_helper_metadata(target_scan_dir) if os.path.isdir(target_scan_dir) else {}
    if not driver_version and helper_meta.get("version"):
        driver_version = helper_meta["version"]

    # PE Metadata extraction for EXEs
    pe_meta = {}
    if installer_file and installer_file.lower().endswith(".exe") and os.path.isfile(installer_file):
        pe_meta = extract_pe_metadata(installer_file)
        if not driver_version and pe_meta.get("file_version"):
            driver_version = pe_meta["file_version"]
        if not provider and pe_meta.get("company_name"):
            provider = pe_meta["company_name"]

    # Classify category
    name_hints = [base_name]
    if os.path.isfile(entry_path):
        name_hints.append(parent_folder)
    name_hints.extend([pe_meta.get("file_description", ""), pe_meta.get("product_name", "")])
    if helper_meta.get("title"):
        name_hints.append(helper_meta["title"])
    name_hints.extend(model_names[:3])
    category_key, category_fa = classify_driver_category(name_hints, inf_class, list(combined_hw_ids))

    # Smart Driver Display Name
    display_name = ""
    if helper_meta.get("title") and len(helper_meta["title"]) > 4:
        display_name = helper_meta["title"]
    elif pe_meta.get("product_name") and len(pe_meta["product_name"]) > 4:
        display_name = pe_meta["product_name"]
    elif pe_meta.get("file_description") and len(pe_meta["file_description"]) > 4:
        display_name = pe_meta["file_description"]
    elif model_names:
        display_name = f"{provider} {model_names[0]}".strip()
    elif package_type == "folder":
        clean_folder = base_name.replace("_", " ").replace("-", " ").title()
        display_name = f"{clean_folder} Driver"
    elif package_type == "zip":
        clean_zip = os.path.splitext(base_name)[0].replace("_", " ").replace("-", " ").title()
        display_name = f"{clean_zip} Driver"
    else:
        display_name = os.path.splitext(base_name)[0]

    # Calculate size and fingerprint
    size_bytes = 0
    if os.path.isfile(entry_path):
        size_bytes = os.path.getsize(entry_path)
    elif os.path.isdir(entry_path):
        for r, _, files in os.walk(entry_path):
            for f in files:
                try:
                    size_bytes += os.path.getsize(os.path.join(r, f))
                except Exception:
                    pass

    # Fingerprint
    fp_source = f"{rel_path}|{category_key}|{driver_version}|{','.join(sorted(list(combined_hw_ids))[:10])}"
    fingerprint = hashlib.sha256(fp_source.encode("utf-8")).hexdigest()[:16]
    package_id = f"drv_pkg_{fingerprint}"

    return DriverPackage(
        package_id=package_id,
        display_name=display_name.strip(),
        category=category_key,
        category_fa=category_fa,
        package_type=package_type,
        source_path=entry_path,
        relative_path=rel_path,
        installer_file=installer_file,
        install_method=install_method,
        silent_args=silent_args,
        size_bytes=size_bytes,
        fingerprint=fingerprint,
        hardware_ids=sorted(list(combined_hw_ids)),
        driver_version=driver_version,
        driver_date=driver_date,
        provider=provider,
        alternative_installers=alts,
        extraction_dir=extracted_temp_dir,
        inf_files=sorted(all_infs),
        supported_windows=supported_windows,
    )
