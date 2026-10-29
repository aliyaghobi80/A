# backend/drivers/gpu_installers.py
"""
GPU Vendor Installation Subsystem & Display Resilience Module.

Handles discrete (dGPU) and integrated (iGPU) graphics deployment with:
1. Vendor-specific classes (NVIDIA, AMD, Intel) implementing GpuVendorInstaller.
2. Strict topological priority: iGPU before dGPU; AMD -> Intel -> NVIDIA.
3. Mandatory display-settle pause (5-8s) post-installation to survive WDDM adapter resets.
4. Adrenalin unified APU+dGPU package deduplication via HWID/source path.
"""

from abc import ABC, abstractmethod
import logging
import os
import time
from typing import Dict, Any, List, Optional, Tuple

logger = logging.getLogger(__name__)

# Default display settle duration in seconds (5-8s mandated by CONTRACT.md § 8.3)
DEFAULT_DISPLAY_SETTLE_SECONDS = 8.0


class GpuVendorInstaller(ABC):
    """Common interface for GPU vendor installation drivers."""

    @abstractmethod
    def can_handle(self, package: Dict[str, Any]) -> bool:
        """Determines if this vendor installer matches the package."""
        pass

    @abstractmethod
    def install(self, package: Dict[str, Any], timeout_seconds: int = 600) -> Dict[str, Any]:
        """
        Executes the unattended GPU installation.
        Returns Dict with keys:
          - success: bool
          - exit_code: int
          - message: str
          - reboot: bool
          - reboot_required: bool
        """
        pass

    @abstractmethod
    def get_vendor_name(self) -> str:
        """Returns vendor display name ('NVIDIA', 'AMD', 'Intel')."""
        pass


class NvidiaGpuInstaller(GpuVendorInstaller):
    """NVIDIA Graphics Driver Installer (GeForce, Quadro, RTX, GTX)."""

    def get_vendor_name(self) -> str:
        return "NVIDIA"

    def can_handle(self, package: Dict[str, Any]) -> bool:
        hwids = [str(h).upper() for h in (package.get("hardware_ids") or [])]
        if any("VEN_10DE" in h for h in hwids):
            return True

        text = " ".join([
            str(package.get("installer_file") or ""),
            str(package.get("installer_path") or ""),
            str(package.get("display_name") or ""),
            str(package.get("source_path") or ""),
            str(package.get("provider") or ""),
        ]).lower()

        keywords = ("geforce", "quadro", "whql", "nvidia", "nvs", "rtx", "gtx")
        return any(k in text for k in keywords)

    def install(self, package: Dict[str, Any], timeout_seconds: int = 600) -> Dict[str, Any]:
        from packages.manager import _run_elevated_and_wait

        installer_path = package.get("installer_path") or package.get("installer_file") or ""
        if not installer_path or not os.path.exists(installer_path):
            return {
                "success": False,
                "exit_code": -1,
                "reboot": False,
                "reboot_required": False,
                "message": f"فایل نصبی انویدیا یافت نشد: {installer_path}",
            }

        silent_args = package.get("silent_args") or ["-s", "-noreboot"]
        work_dir = os.path.dirname(installer_path)
        cmd = [installer_path] + list(silent_args)

        logger.info(f"[NVIDIA] Launching GPU installer: {installer_path} {' '.join(silent_args)}")
        exit_code = _run_elevated_and_wait(cmd, work_dir, timeout_seconds)

        # Standard exit codes: 0 (success), 3010/1641 (success + reboot), 1638 (already installed)
        success = exit_code in (0, 3010, 1641, 1638)
        reboot = exit_code in (3010, 1641)

        if success:
            msg = "درایور کارت گرافیک NVIDIA با موفقیت نصب شد."
        elif exit_code == 1618:
            msg = "Windows Installer در حال استفاده است؛ خطای 1618 رخ داد."
        elif exit_code == -2:
            msg = "زمان مجاز برای نصب گرافیک NVIDIA به پایان رسید (تایم‌اوت)."
        else:
            msg = f"نصب گرافیک NVIDIA ناموفق بود (کد خروج: {exit_code})."

        return {
            "success": success,
            "exit_code": exit_code,
            "reboot": reboot,
            "reboot_required": reboot,
            "message": msg,
        }


class AmdGpuInstaller(GpuVendorInstaller):
    """AMD Radeon / Adrenalin Graphics Driver Installer (APU + dGPU)."""

    def get_vendor_name(self) -> str:
        return "AMD"

    def can_handle(self, package: Dict[str, Any]) -> bool:
        hwids = [str(h).upper() for h in (package.get("hardware_ids") or [])]
        if any("VEN_1002" in h for h in hwids):
            return True

        text = " ".join([
            str(package.get("installer_file") or ""),
            str(package.get("installer_path") or ""),
            str(package.get("display_name") or ""),
            str(package.get("source_path") or ""),
            str(package.get("provider") or ""),
        ]).lower()

        keywords = ("adrenalin", "radeon", "amd-software", "amd", "advanced micro devices")
        return any(k in text for k in keywords)

    def install(self, package: Dict[str, Any], timeout_seconds: int = 600) -> Dict[str, Any]:
        from packages.manager import _run_elevated_and_wait

        installer_path = package.get("installer_path") or package.get("installer_file") or ""
        if not installer_path or not os.path.exists(installer_path):
            return {
                "success": False,
                "exit_code": -1,
                "reboot": False,
                "reboot_required": False,
                "message": f"فایل نصبی AMD یافت نشد: {installer_path}",
            }

        silent_args = package.get("silent_args") or ["-INSTALL", "-OUTPUT", "screen", "-NORESTART"]
        work_dir = os.path.dirname(installer_path)
        cmd = [installer_path] + list(silent_args)

        logger.info(f"[AMD] Launching GPU installer: {installer_path} {' '.join(silent_args)}")
        exit_code = _run_elevated_and_wait(cmd, work_dir, timeout_seconds)

        success = exit_code in (0, 3010, 1641, 1638)
        reboot = exit_code in (3010, 1641)

        if success:
            msg = "درایور کارت گرافیک AMD Radeon با موفقیت نصب شد."
        elif exit_code == 1618:
            msg = "Windows Installer در حال استفاده است؛ خطای 1618 رخ داد."
        elif exit_code == -2:
            msg = "زمان مجاز برای نصب گرافیک AMD به پایان رسید (تایم‌اوت)."
        else:
            msg = f"نصب گرافیک AMD ناموفق بود (کد خروج: {exit_code})."

        return {
            "success": success,
            "exit_code": exit_code,
            "reboot": reboot,
            "reboot_required": reboot,
            "message": msg,
        }


class IntelGpuInstaller(GpuVendorInstaller):
    """Intel Graphics Driver Installer (Arc, Iris Xe, UHD, HD Graphics)."""

    def get_vendor_name(self) -> str:
        return "Intel"

    def can_handle(self, package: Dict[str, Any]) -> bool:
        hwids = [str(h).upper() for h in (package.get("hardware_ids") or [])]
        # Check Intel display controller class or VEN_8086 with display keywords
        if any("VEN_8086" in h for h in hwids):
            # Verify it's a display controller or graphics package
            cat = str(package.get("category") or "").lower()
            if cat in ("gpu", "display"):
                return True

        text = " ".join([
            str(package.get("installer_file") or ""),
            str(package.get("installer_path") or ""),
            str(package.get("display_name") or ""),
            str(package.get("source_path") or ""),
            str(package.get("provider") or ""),
        ]).lower()

        keywords = ("installer.exe", "igxpin.exe", "gfx_win", "intel arc", "iris", "uhd graphics", "hd graphics")
        return any(k in text for k in keywords)

    def install(self, package: Dict[str, Any], timeout_seconds: int = 480) -> Dict[str, Any]:
        from packages.manager import _run_elevated_and_wait

        installer_path = package.get("installer_path") or package.get("installer_file") or ""
        if not installer_path or not os.path.exists(installer_path):
            return {
                "success": False,
                "exit_code": -1,
                "reboot": False,
                "reboot_required": False,
                "message": f"فایل نصبی اینتل یافت نشد: {installer_path}",
            }

        # Select modern vs legacy switch per CONTRACT.md § 8.2
        filename = os.path.basename(installer_path).lower()
        if package.get("silent_args"):
            silent_args = package["silent_args"]
        elif filename == "installer.exe" or "arc" in installer_path.lower():
            silent_args = ["--overwrite", "-s"]
        else:
            silent_args = ["-s", "-norestart"]

        work_dir = os.path.dirname(installer_path)
        cmd = [installer_path] + list(silent_args)

        logger.info(f"[Intel] Launching GPU installer: {installer_path} {' '.join(silent_args)}")
        exit_code = _run_elevated_and_wait(cmd, work_dir, timeout_seconds)

        success = exit_code in (0, 3010, 1641, 1638)
        reboot = exit_code in (3010, 1641)

        if success:
            msg = "درایور کارت گرافیک Intel با موفقیت نصب شد."
        elif exit_code == 1618:
            msg = "Windows Installer در حال استفاده است؛ خطای 1618 رخ داد."
        elif exit_code == -2:
            msg = "زمان مجاز برای نصب گرافیک Intel به پایان رسید (تایم‌اوت)."
        else:
            msg = f"نصب گرافیک Intel ناموفق بود (کد خروج: {exit_code})."

        return {
            "success": success,
            "exit_code": exit_code,
            "reboot": reboot,
            "reboot_required": reboot,
            "message": msg,
        }


def get_gpu_installer(package: Dict[str, Any]) -> Optional[GpuVendorInstaller]:
    """Factory function returning the matching GpuVendorInstaller instance."""
    installers = [
        AmdGpuInstaller(),
        IntelGpuInstaller(),
        NvidiaGpuInstaller(),
    ]
    for inst in installers:
        if inst.can_handle(package):
            return inst
    return None


def execute_gpu_settle_delay(seconds: float = DEFAULT_DISPLAY_SETTLE_SECONDS) -> None:
    """
    Mandatory display settle delay after GPU installation (CONTRACT.md § 8.3).
    Allows Windows Display Driver Model (WDDM) to complete adapter re-initialization.
    """
    delay = max(0.0, float(seconds))
    if delay > 0:
        logger.info(f"[GPU] Waiting {delay}s for display adapter settle...")
        time.sleep(delay)


def is_igpu_package(package: Dict[str, Any]) -> bool:
    """Returns True if package represents an integrated processor graphics (iGPU/APU)."""
    if package.get("gpu_type") == "igpu" or package.get("is_igpu") is True or package.get("is_integrated") is True:
        return True

    text = " ".join([
        str(package.get("display_name") or ""),
        str(package.get("source_path") or ""),
        str(package.get("installer_file") or ""),
        " ".join(package.get("hardware_ids") or []),
    ]).lower()

    # NVIDIA is never an iGPU
    if "nvidia" in text or "geforce" in text or "quadro" in text or "ven_10de" in text:
        return False

    # Intel Arc is dGPU
    if "arc" in text:
        return False

    # UHD, Iris, APU, Vega integrated
    if any(k in text for k in ("uhd", "iris", "apu", "integrated", "vega 7", "vega 8", "radeon(tm) graphics")):
        return True

    # Category order 4 is iGPU, 5 is dGPU in CONTRACT.md
    if package.get("category_order") == 4:
        return True

    # By default, Intel is predominantly iGPU on technician laptops unless Arc
    if "intel" in text or "ven_8086" in text:
        return True

    return False


def gpu_priority_key(package: Dict[str, Any]) -> Tuple[int, int, str]:
    """
    Calculates sorting key for GPU packages according to CONTRACT.md § 8.3:
    1. iGPU before dGPU (0 for iGPU, 1 for dGPU).
    2. Vendor priority: AMD (0) -> Intel (1) -> NVIDIA (2) -> Other (3).
    3. Alphabetical tie-breaker.
    """
    is_dgpu = 0 if is_igpu_package(package) else 1

    # Vendor order
    text = " ".join([
        str(package.get("display_name") or ""),
        str(package.get("source_path") or ""),
        str(package.get("provider") or ""),
        " ".join(package.get("hardware_ids") or []),
    ]).lower()

    if "amd" in text or "radeon" in text or "ven_1002" in text:
        vendor_order = 0
    elif "intel" in text or "ven_8086" in text:
        vendor_order = 1
    elif "nvidia" in text or "geforce" in text or "ven_10de" in text:
        vendor_order = 2
    else:
        vendor_order = 3

    return (is_dgpu, vendor_order, str(package.get("display_name") or ""))


def deduplicate_gpu_packages(packages: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """
    Deduplicates unified AMD Adrenalin / APU+dGPU packages.
    If multiple GPU items point to the exact same installer or sharing identical HWIDs,
    retains only one to execute and maps to both devices.
    """
    seen_paths = set()
    seen_hwids = set()
    result = []

    for pkg in packages:
        cat = str(pkg.get("category") or "").lower()
        if cat != "gpu":
            result.append(pkg)
            continue

        installer_path = str(pkg.get("installer_path") or pkg.get("source_path") or "").lower()
        hwids = frozenset(str(h).upper() for h in (pkg.get("hardware_ids") or []))

        # Check path collision
        if installer_path and installer_path in seen_paths:
            logger.info(f"[GPU Deduplication] Skipping duplicate GPU package path: {installer_path}")
            continue

        # Check HWID exact match collision
        if hwids and hwids in seen_hwids:
            logger.info(f"[GPU Deduplication] Skipping duplicate GPU package with matching HWIDs: {hwids}")
            continue

        if installer_path:
            seen_paths.add(installer_path)
        if hwids:
            seen_hwids.add(hwids)

        result.append(pkg)

    return result
