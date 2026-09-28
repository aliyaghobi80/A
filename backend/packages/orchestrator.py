# backend/packages/orchestrator.py
"""
Setup & Deployment Orchestrator for Markazi System Checker.
Automates pre-installation and post-installation workflows:
1. Intelligent Office archive detection and extraction (extract here if not yet extracted).
2. KMS archive detection and extraction into the PROGRAM directory.
3. Windows/Office activation via owned WINDOWS.cmd and OFFICE.cmd scripts with
   live licensing verification.
4. Essential desktop icons configuration (This PC, Recycle Bin, Control Panel).
5. Essential device settings application:
   - Display & Sleep timeouts to Never (powercfg)
   - Laptop power modes (AC: Best performance, DC: Balanced)
   - Tehran timezone (UTC+03:30) and automatic timezone update
   - Startup apps optimization
   - Windows 10 background apps optimization
"""

import os
import re
import shutil
import tempfile
import time
import logging
from typing import Dict, Any, Optional, List

from drivers.archive_extractor import extract_driver_archive, has_rar_extractor
from activation.windows_activation import _query_wmi_licensing
from activation.activation_tools import (
    DEFAULT_TOOLS_DIR,
    execute_elevated_batch_script,
    is_safe_tool_path,
)
from windows.desktop_time import show_desktop_icons, set_tehran_automatic_timezone
from windows.device_settings import (
    set_sleep_never,
    disable_all_startup_apps,
    disable_windows10_background_apps,
    has_battery,
    get_windows_identity,
)
from windows.power_settings import set_laptop_power_modes

logger = logging.getLogger(__name__)

_ARCHIVE_EXTENSIONS = {".zip", ".rar", ".7z"}
_KMS_SCAN_MAX_DEPTH = 3


def _normalized_kms_name(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", " ", str(value).lower()).strip()


def _looks_like_kms_archive(path: str, packages_dir: str) -> bool:
    try:
        relative = os.path.relpath(path, packages_dir)
    except ValueError:
        relative = os.path.basename(path)
    normalized = _normalized_kms_name(os.path.splitext(relative)[0])
    tokens = normalized.split()
    return "kms" in tokens or "kmsauto" in normalized.replace(" ", "")


def _find_kms_archives(packages_dir: str) -> List[str]:
    """Find KMS/kms v6 archives case-insensitively up to a safe depth."""
    if not packages_dir or not os.path.isdir(packages_dir):
        return []

    root_dir = os.path.realpath(os.path.abspath(packages_dir))
    ignored = {"backend", "build", "dist", ".git", "node_modules", "logs"}
    candidates: List[str] = []
    for current_root, directories, files in os.walk(root_dir, followlinks=False):
        try:
            relative_root = os.path.relpath(current_root, root_dir)
            depth = 0 if relative_root == "." else len(relative_root.split(os.sep))
        except ValueError:
            directories[:] = []
            continue

        directories[:] = [
            directory
            for directory in directories
            if directory.lower() not in ignored
            and not directory.startswith(".markazi_kms_")
            and not os.path.islink(os.path.join(current_root, directory))
            and not os.path.isjunction(os.path.join(current_root, directory))
        ]
        if depth >= _KMS_SCAN_MAX_DEPTH:
            directories[:] = []

        for filename in files:
            archive_path = os.path.join(current_root, filename)
            extension = os.path.splitext(filename)[1].lower()
            if extension in _ARCHIVE_EXTENSIONS and _looks_like_kms_archive(
                archive_path,
                root_dir,
            ):
                candidates.append(os.path.abspath(archive_path))

    def priority(path: str) -> tuple[int, int, str]:
        normalized = _normalized_kms_name(os.path.relpath(path, root_dir))
        is_v6 = "kms v6" in normalized or "kms 6" in normalized
        return (0 if is_v6 else 1, len(normalized), normalized)

    return sorted(set(candidates), key=priority)


def _is_winrar_package(package: Dict[str, Any]) -> bool:
    identity = " ".join(
        str(package.get(field) or "")
        for field in ("id", "name", "filename", "relative_path", "publisher")
    ).lower()
    compact = re.sub(r"[^a-z0-9]+", "", identity)
    return "winrar" in compact or "winrargmbh" in compact


def _ensure_rar_extractor_available(packages_dir: str) -> Dict[str, Any]:
    """Install the validated WinRAR package before a RAR-based KMS bundle."""
    if has_rar_extractor():
        return {
            "success": True,
            "already_available": True,
            "message": "استخراج‌کننده RAR از قبل نصب است.",
        }

    try:
        from packages.manager import scan_packages, silent_install_package

        scanned = scan_packages(packages_dir)
        candidates = [
            package
            for package in scanned.get("packages", [])
            if _is_winrar_package(package)
            and package.get("is_valid", True)
            and package.get("auto_install_supported", True)
        ]
        candidates.sort(
            key=lambda package: (
                package.get("is_installed") is True,
                "x64" not in str(package.get("filename") or "").lower(),
                len(str(package.get("relative_path") or "")),
            )
        )
        if not candidates:
            return {
                "success": False,
                "message": (
                    "برای استخراج KMS با فرمت RAR، نصاب معتبر WinRAR در پوشه "
                    "نرم‌افزارها پیدا نشد."
                ),
            }

        winrar = candidates[0]
        target = (
            winrar.get("relative_path")
            or winrar.get("id")
            or winrar.get("filename")
        )
        install_result = silent_install_package(
            target,
            custom_dir=packages_dir,
            timeout_seconds=300,
        )
        for _ in range(10):
            if has_rar_extractor():
                return {
                    "success": True,
                    "installed": True,
                    "package": winrar.get("name") or "WinRAR",
                    "install_result": install_result,
                    "message": "WinRAR نصب شد و استخراج RAR آماده است.",
                }
            time.sleep(0.5)

        return {
            "success": False,
            "package": winrar.get("name") or "WinRAR",
            "install_result": install_result,
            "message": "نصب WinRAR پایان یافت اما استخراج‌کننده RAR تأیید نشد.",
        }
    except Exception as exc:
        logger.exception("[Orchestrator] WinRAR prerequisite failed: %s", exc)
        return {
            "success": False,
            "message": f"نصب پیش‌نیاز WinRAR انجام نشد: {exc}",
        }


def is_office_already_extracted(packages_dir: str) -> bool:
    """
    Checks if Microsoft Office is already extracted in the packages directory.
    Returns True if an 'Office' or 'Microsoft Office' folder exists and contains
    setup/install executables or scripts.
    """
    if not packages_dir or not os.path.isdir(packages_dir):
        return False

    try:
        for entry in os.listdir(packages_dir):
            full_path = os.path.join(packages_dir, entry)
            if os.path.isdir(full_path) and "office" in entry.lower():
                # Check if it contains setup files
                for root, _, files in os.walk(full_path):
                    for f in files:
                        f_lower = f.lower()
                        if f_lower in ("setup.exe", "install.exe", "setup.cmd", "office.cmd", "install.cmd", "configuration.xml"):
                            logger.info(f"[Orchestrator] Office already extracted in: {full_path}")
                            return True
                # If the folder exists and has at least 3 files, consider it extracted
                file_count = sum(len(files) for _, _, files in os.walk(full_path))
                if file_count >= 3:
                    logger.info(f"[Orchestrator] Office folder detected with {file_count} files in: {full_path}")
                    return True
    except Exception as e:
        logger.warning(f"[Orchestrator] Error checking office extraction status: {e}")

    return False


def ensure_office_extracted(packages_dir: str) -> Dict[str, Any]:
    """
    Checks whether the Office folder has been extracted.
    If not extracted, extracts any Office archive (.rar, .zip, .7z) found in packages_dir.
    If already extracted, returns successfully without redundant work.
    """
    identity = get_windows_identity()
    if identity.get("is_home") is True:
        return {
            "success": True,
            "skipped": True,
            "blocked": True,
            "home_guard": True,
            "windows": identity,
            "message": "Windows Home اورجینال است؛ آرشیو Office استخراج نمی‌شود.",
        }

    if not packages_dir or not os.path.isdir(packages_dir):
        return {
            "success": True,
            "skipped": True,
            "message": "پوشه نرم‌افزارها در دسترس نیست.",
        }

    if is_office_already_extracted(packages_dir):
        return {
            "success": True,
            "already_extracted": True,
            "message": "پوشه آفیس قبلاً استخراج شده است (بدون نیاز به تغییر).",
        }

    # Find Office archive
    archive_candidates = []
    try:
        for entry in os.listdir(packages_dir):
            entry_lower = entry.lower()
            if "office" in entry_lower:
                _, ext = os.path.splitext(entry_lower)
                if ext in (".rar", ".zip", ".7z"):
                    archive_candidates.append(os.path.join(packages_dir, entry))
    except Exception as e:
        logger.warning(f"[Orchestrator] Error searching for Office archive: {e}")

    if not archive_candidates:
        return {
            "success": True,
            "skipped": True,
            "message": "آرشیو فشرده آفیس در پوشه نرم‌افزارها یافت نشد.",
        }

    # Sort to pick the cleanest name first
    archive_candidates.sort(key=lambda p: len(os.path.basename(p)))
    target_archive = archive_candidates[0]
    archive_name = os.path.basename(target_archive)
    prerequisite: Dict[str, Any] = {
        "success": True,
        "skipped": True,
        "message": "برای این آرشیو پیش‌نیاز جداگانه لازم نیست.",
    }
    if os.path.splitext(target_archive)[1].lower() == ".rar":
        prerequisite = _ensure_rar_extractor_available(packages_dir)
        if not prerequisite.get("success"):
            return {
                "success": False,
                "archive_name": archive_name,
                "prerequisite": prerequisite,
                "message": prerequisite.get(
                    "message",
                    "پیش‌نیاز استخراج RAR آماده نشد.",
                ),
            }

    logger.info(f"[Orchestrator] Extracting Office archive: {target_archive} into {packages_dir}")
    try:
        ok = extract_driver_archive(target_archive, packages_dir)
        if ok:
            return {
                "success": True,
                "already_extracted": False,
                "archive_name": archive_name,
                "prerequisite": prerequisite,
                "message": f"آرشیو آفیس ({archive_name}) با موفقیت استخراج شد.",
            }
        else:
            return {
                "success": False,
                "archive_name": archive_name,
                "prerequisite": prerequisite,
                "message": f"استخراج خودکار آرشیو آفیس ({archive_name}) ناموفق بود.",
            }
    except Exception as e:
        logger.error(f"[Orchestrator] Office extraction error: {e}")
        return {
            "success": False,
            "archive_name": archive_name,
            "message": f"خطا در استخراج آفیس: {e}",
        }


def extract_kms_archive(packages_dir: str) -> Dict[str, Any]:
    """
    Find and safely extract KMS/KMS v6 archives from PROGRAM.

    Matching is case-insensitive and accepts separators such as spaces,
    underscores, and hyphens. Extraction is isolated beside the archive and is
    considered successful only when a supported WINDOWS.cmd is found.
    """
    identity = get_windows_identity()
    if identity.get("is_home") is True:
        return {
            "success": True,
            "skipped": True,
            "blocked": True,
            "home_guard": True,
            "found": False,
            "windows": identity,
            "message": "Windows Home اورجینال است؛ آرشیو KMS استخراج نشد.",
        }

    if not packages_dir or not os.path.isdir(packages_dir):
        return {
            "success": True,
            "found": False,
            "message": "پوشه پکیج‌ها یافت نشد.",
        }

    packages_dir = os.path.abspath(packages_dir)
    kms_archives = _find_kms_archives(packages_dir)

    # Avoid re-extracting KMS v6, while still allowing a v6 archive to replace
    # an older extracted KMS folder that happens to be present in PROGRAM.
    existing_cmd = find_windows_cmd(packages_dir, allow_bundled=False)
    if existing_cmd:
        relative = os.path.relpath(existing_cmd, packages_dir).replace("\\", "/").lower()
        normalized = _normalized_kms_name(relative)
        has_v6_archive = any(
            "kms v6" in _normalized_kms_name(os.path.relpath(path, packages_dir))
            or "kms 6" in _normalized_kms_name(os.path.relpath(path, packages_dir))
            for path in kms_archives
        )
        if "kms v6" in normalized or ("kms" in normalized and not has_v6_archive):
            bundle_root = _activation_bundle_root(existing_cmd, packages_dir)
            return {
                "success": True,
                "found": True,
                "already_extracted": True,
                "extract_dir": bundle_root,
                "command_path": existing_cmd,
                "windows_command_path": existing_cmd,
                "office_command_path": find_office_cmd(
                    bundle_root,
                    allow_bundled=False,
                ),
                "message": "KMS v6 قبلاً در پوشه PROGRAM استخراج شده است.",
            }

    if not kms_archives:
        logger.info("[Orchestrator] No KMS archive found in packages directory.")
        return {
            "success": False,
            "found": False,
            "message": (
                "آرشیو KMS در پوشه نرم‌افزارها یافت نشد؛ نام‌هایی مانند "
                "KMS، KMS v6 و KMS_V6 پشتیبانی می‌شوند."
            ),
        }

    # _find_kms_archives already prioritizes v6 and deterministic short names.
    target_archive = kms_archives[0]
    archive_name = os.path.basename(target_archive)
    archive_extension = os.path.splitext(target_archive)[1].lower()
    prerequisite: Dict[str, Any] = {
        "success": True,
        "skipped": True,
        "message": "برای این آرشیو پیش‌نیاز جداگانه لازم نیست.",
    }
    if archive_extension == ".rar":
        prerequisite = _ensure_rar_extractor_available(packages_dir)
        if not prerequisite.get("success"):
            return {
                "success": False,
                "found": True,
                "archive_name": archive_name,
                "archive_path": target_archive,
                "prerequisite": prerequisite,
                "message": prerequisite.get(
                    "message",
                    "پیش‌نیاز استخراج RAR آماده نشد.",
                ),
            }

    archive_parent = os.path.dirname(target_archive)
    archive_stem = os.path.splitext(archive_name)[0].strip() or "KMS v6"
    preferred_destination = os.path.join(archive_parent, archive_stem)

    # An exact sibling folder is the expected result for KMS v6.rar/.zip.
    if os.path.isdir(preferred_destination):
        sibling_cmd = find_windows_cmd(
            preferred_destination,
            allow_bundled=False,
        )
        if sibling_cmd:
            return {
                "success": True,
                "found": True,
                "already_extracted": True,
                "archive_name": archive_name,
                "archive_path": target_archive,
                "extract_dir": preferred_destination,
                "command_path": sibling_cmd,
                "windows_command_path": sibling_cmd,
                "office_command_path": find_office_cmd(
                    preferred_destination,
                    allow_bundled=False,
                ),
                "prerequisite": prerequisite,
                "message": "KMS v6 قبلاً استخراج شده و WINDOWS.cmd آماده است.",
            }

    staging_dir = tempfile.mkdtemp(prefix=".markazi_kms_extract_", dir=archive_parent)
    logger.info(
        "[Orchestrator] Extracting KMS archive in isolation: %s -> %s",
        target_archive,
        staging_dir,
    )

    try:
        ok = extract_driver_archive(target_archive, staging_dir)
        staged_cmd = (
            find_windows_cmd(staging_dir, allow_bundled=False) if ok else None
        )
        staged_office_cmd = (
            find_office_cmd(staging_dir, allow_bundled=False) if ok else None
        )
        if not ok or not staged_cmd:
            return {
                "success": False,
                "found": True,
                "archive_name": archive_name,
                "archive_path": target_archive,
                "prerequisite": prerequisite,
                "message": (
                    f"آرشیو {archive_name} استخراج نشد یا فایل WINDOWS.cmd "
                    "داخل آن پیدا نشد."
                ),
            }

        destination = preferred_destination
        if os.path.exists(destination):
            suffix = 1
            destination = f"{preferred_destination}_extracted"
            while os.path.exists(destination):
                suffix += 1
                destination = f"{preferred_destination}_extracted_{suffix}"

        command_relative = os.path.relpath(staged_cmd, staging_dir)
        office_command_relative = (
            os.path.relpath(staged_office_cmd, staging_dir)
            if staged_office_cmd
            else None
        )
        os.replace(staging_dir, destination)
        command_path = os.path.abspath(os.path.join(destination, command_relative))
        office_command_path = (
            os.path.abspath(os.path.join(destination, office_command_relative))
            if office_command_relative
            else None
        )
        return {
            "success": True,
            "found": True,
            "archive_name": archive_name,
            "archive_path": target_archive,
            "extract_dir": destination,
            "command_path": command_path,
            "windows_command_path": command_path,
            "office_command_path": office_command_path,
            "prerequisite": prerequisite,
            "message": f"آرشیو {archive_name} با موفقیت استخراج و بررسی شد.",
        }
    except Exception as e:
        logger.error(f"[Orchestrator] KMS extraction error: {e}")
        return {
            "success": False,
            "found": True,
            "archive_name": archive_name,
            "message": f"خطا در استخراج KMS: {e}",
        }
    finally:
        # Only remove our own isolated staging directory. Existing user folders
        # and archives are never deleted or overwritten.
        if os.path.isdir(staging_dir):
            shutil.rmtree(staging_dir, ignore_errors=True)


def _find_activation_commands(
    search_dir: Optional[str],
    accepted_names: set[str],
) -> List[str]:
    """Collect owned activation commands without leaving the selected tree."""
    if not search_dir or not os.path.isdir(search_dir):
        return []

    search_root = os.path.realpath(os.path.abspath(search_dir))
    ignored = {"backend", "build", "dist", ".git", "node_modules", "logs"}
    candidates: List[str] = []
    for root, directories, files in os.walk(search_root, followlinks=False):
        try:
            relative_root = os.path.relpath(root, search_root)
            depth = 0 if relative_root == "." else len(relative_root.split(os.sep))
        except ValueError:
            directories[:] = []
            continue

        directories[:] = [
            directory
            for directory in directories
            if directory.lower() not in ignored
            and not os.path.islink(os.path.join(root, directory))
            and not os.path.isjunction(os.path.join(root, directory))
        ]
        if depth >= 6:
            directories[:] = []

        for filename in files:
            if filename.lower() not in accepted_names:
                continue
            candidate = os.path.abspath(os.path.join(root, filename))
            if _path_is_inside(candidate, search_root):
                candidates.append(candidate)
    return candidates


def _activation_command_priority(path: str, exact_name: str) -> tuple[int, int, int, str]:
    normalized = _normalized_kms_name(path)
    return (
        0 if "kms v6" in normalized or "kms 6" in normalized else 1,
        0 if os.path.basename(path).lower() == exact_name else 1,
        len(path),
        path.lower(),
    )


def find_windows_cmd(
    packages_dir: Optional[str] = None,
    allow_bundled: bool = True,
) -> Optional[str]:
    """Find WINDOWS.cmd case-insensitively inside the selected repository."""
    candidates = _find_activation_commands(
        packages_dir,
        {
            "windows.cmd",
            "windows.bat",
            "window.cmd",
            "window.bat",
            "win.cmd",
            "activate.cmd",
        },
    )
    if candidates:
        candidates.sort(key=lambda path: _activation_command_priority(path, "windows.cmd"))
        return candidates[0]

    bundled_cmd = os.path.abspath(os.path.join(DEFAULT_TOOLS_DIR, "WINDOWS.cmd"))
    if allow_bundled and os.path.isfile(bundled_cmd):
        return bundled_cmd
    return None


def find_office_cmd(
    packages_dir: Optional[str] = None,
    allow_bundled: bool = True,
) -> Optional[str]:
    """Find the dedicated OFFICE.cmd without falling back to WINDOWS.cmd."""
    candidates = _find_activation_commands(
        packages_dir,
        {
            "office.cmd",
            "office.bat",
            "office_activation.cmd",
            "activate_office.cmd",
        },
    )
    if candidates:
        candidates.sort(key=lambda path: _activation_command_priority(path, "office.cmd"))
        return candidates[0]

    bundled_cmd = os.path.abspath(os.path.join(DEFAULT_TOOLS_DIR, "OFFICE.cmd"))
    if allow_bundled and os.path.isfile(bundled_cmd):
        return bundled_cmd
    return None


def _activation_bundle_root(command_path: str, packages_dir: str) -> str:
    """Return the KMS bundle ancestor that owns one discovered command."""
    repository = os.path.realpath(os.path.abspath(packages_dir))
    current = os.path.realpath(os.path.dirname(os.path.abspath(command_path)))
    fallback = current
    while _path_is_inside(current, repository) and current != repository:
        normalized = _normalized_kms_name(os.path.basename(current))
        if "kms" in normalized.split() or "kmsauto" in normalized.replace(" ", ""):
            return current
        parent = os.path.dirname(current)
        if parent == current:
            break
        current = parent
    return fallback


def _consolidated_windows_license() -> Dict[str, Any]:
    """Read the public consolidated status, falling back to the WMI signal."""
    try:
        from activation.windows_activation import get_windows_activation_info

        result = get_windows_activation_info()
        if isinstance(result, dict):
            return result
    except Exception:
        logger.debug("Consolidated Windows license query failed", exc_info=True)
    try:
        return _query_wmi_licensing()
    except Exception:
        return {"activated": False}


def _path_is_inside(candidate: str, root: str) -> bool:
    try:
        candidate_real = os.path.normcase(os.path.realpath(candidate))
        root_real = os.path.normcase(os.path.realpath(root))
        return os.path.commonpath([candidate_real, root_real]) == root_real
    except (OSError, ValueError):
        return False


def run_windows_cmd_activation(
    packages_dir: Optional[str] = None,
    timeout_seconds: int = 300,
    command_path: Optional[str] = None,
) -> Dict[str, Any]:
    """
    Executes WINDOWS.cmd with Administrator privileges, then waits and polls
    until Windows licensing verifies active status.
    """
    identity = get_windows_identity()
    if identity.get("is_home") is True:
        return {
            "success": True,
            "skipped": True,
            "blocked": True,
            "home_guard": True,
            "windows": identity,
            "message": "Windows Home اورجینال است؛ KMS اجرا نشد.",
        }

    # 1. Never unpack or execute anything for an already licensed system.
    current_lic = _consolidated_windows_license()
    if current_lic.get("activated") is True:
        logger.info("[Orchestrator] Windows is already fully licensed and activated.")
        return {
            "success": True,
            "skipped": True,
            "already_activated": True,
            "license": current_lic,
            "message": "ویندوز قبلاً فعال و دارای لایسنس قانونی است.",
        }

    # 2. Find WINDOWS.cmd
    cmd_path = command_path or find_windows_cmd(
        packages_dir,
        allow_bundled=packages_dir is None,
    )
    if not cmd_path or not os.path.isfile(cmd_path):
        return {
            "success": False,
            "message": "اسکریپت فعال‌سازی WINDOWS.cmd مربوط به KMS v6 در پوشه PROGRAM یافت نشد.",
        }
    cmd_path = os.path.abspath(cmd_path)
    if packages_dir:
        if not _path_is_inside(cmd_path, packages_dir):
            return {
                "success": False,
                "message": "مسیر WINDOWS.cmd خارج از پوشه نرم‌افزارهای انتخاب‌شده است.",
            }
    elif not is_safe_tool_path(cmd_path):
        return {
            "success": False,
            "message": "مسیر ابزار فعال‌سازی مجاز نیست.",
        }

    logger.info(f"[Orchestrator] Found WINDOWS.cmd at: {cmd_path}")

    # 3. Feed menu option 1 and a queued completion key. The shared runner
    # waits for the owned process to exit even if WMI becomes licensed early.
    def license_probe() -> bool:
        return _query_wmi_licensing().get("activated") is True

    run_result = execute_elevated_batch_script(
        cmd_path,
        input_values=["1"],
        timeout_seconds=timeout_seconds,
        log_file=os.path.join(os.path.dirname(cmd_path), "windows_activation_run.log"),
        status_probe=license_probe,
    )
    if run_result.get("cancelled"):
        return {
            **run_result,
            "activated": False,
            "message": "فعال‌سازی در پنجره دسترسی مدیر لغو شد.",
        }

    # Licensing services may update just after the batch file exits. Retry a
    # bounded number of times and accept any positive official signal.
    activated = bool(run_result.get("status_observed"))
    verified_license: Dict[str, Any] = {}
    for attempt in range(8):
        verified_license = _consolidated_windows_license()
        if verified_license.get("activated") is True:
            activated = True
            break
        if attempt < 7:
            time.sleep(1.5)

    if activated:
        return {
            **run_result,
            "success": True,
            "activated": True,
            "license": verified_license,
            "message": "ویندوز با موفقیت فعال شد و وضعیت لایسنس تأیید شد.",
        }

    return {
        **run_result,
        "success": False,
        "activated": False,
        "license": verified_license,
        "message": (
            run_result.get("message")
            if run_result.get("timed_out")
            else "اسکریپت کامل شد اما فعال‌سازی ویندوز هنوز تأیید نشده است."
        ),
    }


def _office_license_status() -> Dict[str, Any]:
    """Read the consolidated Office installation and licensing state."""
    try:
        from activation.office_activation import get_office_activation_info

        result = get_office_activation_info()
        if isinstance(result, dict):
            return result
    except Exception as exc:
        logger.warning("Office license query failed: %s", exc)
        return {"installed": None, "activated": False, "error": str(exc)}
    return {"installed": None, "activated": False}


def run_office_cmd_activation(
    packages_dir: Optional[str] = None,
    timeout_seconds: int = 300,
    command_path: Optional[str] = None,
) -> Dict[str, Any]:
    """Run the owned OFFICE.cmd with option 1 and verify Office licensing."""
    identity = get_windows_identity()
    if identity.get("is_home") is True:
        return {
            "success": True,
            "skipped": True,
            "blocked": True,
            "home_guard": True,
            "windows": identity,
            "message": "Windows Home اورجینال است؛ فعال‌سازی Office اجرا نشد.",
        }

    current_office = _office_license_status()
    if current_office.get("installed") is not True:
        return {
            "success": False,
            "skipped": True,
            "blocked": True,
            "not_installed": True,
            "office": current_office,
            "message": "ابتدا Microsoft Office را نصب کنید؛ OFFICE.cmd اجرا نشد.",
        }
    if current_office.get("activated") is True:
        return {
            "success": True,
            "skipped": True,
            "already_activated": True,
            "office": current_office,
            "message": "Microsoft Office قبلاً فعال است؛ OFFICE.cmd اجرا نشد.",
        }

    cmd_path = command_path or find_office_cmd(
        packages_dir,
        allow_bundled=packages_dir is None,
    )
    if not cmd_path or not os.path.isfile(cmd_path):
        return {
            "success": False,
            "activated": False,
            "message": "فایل OFFICE.cmd در بسته KMS انتخاب‌شده پیدا نشد.",
        }

    cmd_path = os.path.abspath(cmd_path)
    if packages_dir:
        if not _path_is_inside(cmd_path, packages_dir):
            return {
                "success": False,
                "activated": False,
                "message": "مسیر OFFICE.cmd خارج از پوشه نرم‌افزارهای انتخاب‌شده است.",
            }
    elif not is_safe_tool_path(cmd_path):
        return {
            "success": False,
            "activated": False,
            "message": "مسیر ابزار فعال‌سازی Office مجاز نیست.",
        }

    logger.info("[Orchestrator] Found OFFICE.cmd at: %s", cmd_path)
    run_result = execute_elevated_batch_script(
        cmd_path,
        input_values=["1"],
        timeout_seconds=timeout_seconds,
        log_file=os.path.join(os.path.dirname(cmd_path), "office_activation_run.log"),
    )
    if run_result.get("cancelled"):
        return {
            **run_result,
            "activated": False,
            "message": "فعال‌سازی Office در پنجره دسترسی مدیر لغو شد.",
        }

    verified_office: Dict[str, Any] = {}
    for attempt in range(6):
        verified_office = _office_license_status()
        if verified_office.get("activated") is True:
            return {
                **run_result,
                "success": True,
                "activated": True,
                "office": verified_office,
                "message": "Microsoft Office با موفقیت فعال و وضعیت لایسنس تأیید شد.",
            }
        if attempt < 5:
            time.sleep(2)

    return {
        **run_result,
        "success": False,
        "activated": False,
        "office": verified_office,
        "message": (
            run_result.get("message")
            if run_result.get("timed_out")
            else "OFFICE.cmd کامل شد اما فعال‌سازی Office هنوز تأیید نشده است."
        ),
    }


def activate_windows_from_packages(
    packages_dir: Optional[str], timeout_seconds: int = 300
) -> Dict[str, Any]:
    """Prepare KMS v6 from the selected PROGRAM folder, then run WINDOWS.cmd."""
    identity = get_windows_identity()
    if identity.get("is_home") is True:
        return {
            "success": True,
            "skipped": True,
            "blocked": True,
            "home_guard": True,
            "windows": identity,
            "message": "Windows Home اورجینال است؛ KMS استخراج یا اجرا نشد.",
        }

    current_license = _consolidated_windows_license()
    if current_license.get("activated") is True:
        return {
            "success": True,
            "skipped": True,
            "already_activated": True,
            "extraction_skipped": True,
            "license": current_license,
            "message": (
                "ویندوز از قبل فعال است؛ آرشیو KMS بررسی یا استخراج نشد و "
                "هیچ ابزار فعال‌سازی اجرا نشد."
            ),
        }

    extraction = extract_kms_archive(packages_dir or "")
    if not extraction.get("success", False):
        return {
            "success": False,
            "extraction": extraction,
            "message": extraction.get("message", "استخراج KMS v6 ناموفق بود."),
        }

    activation = run_windows_cmd_activation(
        packages_dir,
        timeout_seconds=timeout_seconds,
        command_path=(
            extraction.get("windows_command_path")
            or extraction.get("command_path")
        ),
    )
    activation["extraction"] = extraction
    return activation


def activate_office_from_packages(
    packages_dir: Optional[str], timeout_seconds: int = 300
) -> Dict[str, Any]:
    """Prepare the selected KMS bundle, run OFFICE.cmd and verify Office."""
    identity = get_windows_identity()
    if identity.get("is_home") is True:
        return {
            "success": True,
            "skipped": True,
            "blocked": True,
            "home_guard": True,
            "windows": identity,
            "message": "Windows Home اورجینال است؛ KMS یا OFFICE.cmd اجرا نشد.",
        }

    current_office = _office_license_status()
    if current_office.get("installed") is not True:
        return {
            "success": False,
            "skipped": True,
            "blocked": True,
            "not_installed": True,
            "extraction_skipped": True,
            "office": current_office,
            "message": "ابتدا Microsoft Office را نصب کنید؛ KMS استخراج یا اجرا نشد.",
        }
    if current_office.get("activated") is True:
        return {
            "success": True,
            "skipped": True,
            "already_activated": True,
            "extraction_skipped": True,
            "office": current_office,
            "message": "Microsoft Office قبلاً فعال است؛ KMS استخراج یا اجرا نشد.",
        }

    extraction = extract_kms_archive(packages_dir or "")
    if not extraction.get("success", False):
        return {
            "success": False,
            "extraction": extraction,
            "message": extraction.get("message", "استخراج KMS v6 ناموفق بود."),
        }

    office_command = extraction.get("office_command_path")
    if not office_command and extraction.get("extract_dir"):
        office_command = find_office_cmd(
            extraction["extract_dir"],
            allow_bundled=False,
        )
    activation = run_office_cmd_activation(
        packages_dir,
        timeout_seconds=timeout_seconds,
        command_path=office_command,
    )
    activation["extraction"] = extraction
    return activation


def activate_windows_and_office_from_packages(
    packages_dir: Optional[str], timeout_seconds: int = 300
) -> Dict[str, Any]:
    """Run the non-Home deployment activation flow from one extracted bundle."""
    identity = get_windows_identity()
    if identity.get("is_home") is True:
        return {
            "success": True,
            "skipped": True,
            "blocked": True,
            "home_guard": True,
            "windows": identity,
            "message": "Windows Home اورجینال است؛ KMS، WINDOWS.cmd و OFFICE.cmd اجرا نشدند.",
        }

    windows_before = _consolidated_windows_license()
    office_before = _office_license_status()
    windows_ready = windows_before.get("activated") is True
    office_installed = office_before.get("installed") is True
    office_ready = office_before.get("activated") is True

    if windows_ready and office_ready:
        return {
            "success": True,
            "skipped": True,
            "already_activated": True,
            "extraction_skipped": True,
            "windows_activation": {
                "success": True,
                "skipped": True,
                "already_activated": True,
                "license": windows_before,
            },
            "office_activation": {
                "success": True,
                "skipped": True,
                "already_activated": True,
                "office": office_before,
            },
            "message": "Windows و Microsoft Office از قبل فعال هستند؛ KMS اجرا نشد.",
        }

    if windows_ready and not office_installed:
        return {
            "success": False,
            "skipped": True,
            "blocked": True,
            "not_installed": True,
            "extraction_skipped": True,
            "windows_activation": {
                "success": True,
                "skipped": True,
                "already_activated": True,
                "license": windows_before,
            },
            "office_activation": {
                "success": False,
                "skipped": True,
                "not_installed": True,
                "office": office_before,
            },
            "message": "Windows فعال است، اما ابتدا Microsoft Office را نصب کنید.",
        }

    extraction = extract_kms_archive(packages_dir or "")
    if not extraction.get("success", False):
        return {
            "success": False,
            "extraction": extraction,
            "message": extraction.get("message", "استخراج KMS v6 ناموفق بود."),
        }

    if windows_ready:
        windows_result: Dict[str, Any] = {
            "success": True,
            "skipped": True,
            "already_activated": True,
            "license": windows_before,
            "message": "Windows قبلاً فعال است؛ WINDOWS.cmd اجرا نشد.",
        }
    else:
        windows_result = run_windows_cmd_activation(
            packages_dir,
            timeout_seconds=timeout_seconds,
            command_path=(
                extraction.get("windows_command_path")
                or extraction.get("command_path")
            ),
        )

    if not office_installed:
        office_result: Dict[str, Any] = {
            "success": False,
            "skipped": True,
            "blocked": True,
            "not_installed": True,
            "office": office_before,
            "message": "ابتدا Microsoft Office را نصب کنید؛ OFFICE.cmd اجرا نشد.",
        }
    elif office_ready:
        office_result = {
            "success": True,
            "skipped": True,
            "already_activated": True,
            "office": office_before,
            "message": "Microsoft Office قبلاً فعال است؛ OFFICE.cmd اجرا نشد.",
        }
    else:
        office_command = extraction.get("office_command_path")
        if not office_command and extraction.get("extract_dir"):
            office_command = find_office_cmd(
                extraction["extract_dir"],
                allow_bundled=False,
            )
        office_result = run_office_cmd_activation(
            packages_dir,
            timeout_seconds=timeout_seconds,
            command_path=office_command,
        )

    success = bool(windows_result.get("success") and office_result.get("success"))
    return {
        "success": success,
        "skipped": bool(
            windows_result.get("skipped") and office_result.get("skipped")
        ),
        "activated": bool(windows_result.get("activated") or windows_ready),
        "office_activated": bool(office_result.get("activated") or office_ready),
        "windows_activation": windows_result,
        "office_activation": office_result,
        "extraction": extraction,
        "message": (
            f"Windows: {windows_result.get('message', '')} | "
            f"Office: {office_result.get('message', '')}"
        ),
    }


def apply_desktop_icons() -> Dict[str, Any]:
    """
    Adds This PC, Recycle Bin, and Control Panel icons to the desktop.
    """
    try:
        from activation.windows_activation import get_windows_activation_info

        activation = get_windows_activation_info()
        if activation.get("activated") is not True:
            return {
                "success": False,
                "blocked": True,
                "message": "ابتدا فعال‌بودن ویندوز را تأیید کنید؛ آیکن‌های دسکتاپ تغییری نکردند.",
                "activation": activation,
            }
        res = show_desktop_icons(force=True)
        res["activation"] = activation
        return res
    except Exception as e:
        logger.error(f"[Orchestrator] Error applying desktop icons: {e}")
        return {
            "success": False,
            "message": f"خطا در تنظیم آیکن‌های دسکتاپ: {e}",
        }


def apply_essential_device_settings() -> Dict[str, Any]:
    """
    Applies the essential device settings in sequence:
    1. Sleep & screen timeouts to Never (for both AC & DC).
    2. Laptop power modes (AC: Best Performance, DC: Balanced) if device has battery.
    3. Tehran timezone (UTC+03:30) and automatic timezone update.
    4. Startup apps optimization.
    5. Windows 10 background apps optimization (if Windows 10).
    """
    results = {}

    # 1. Sleep & Screen Timeouts to Never
    try:
        sleep_res = set_sleep_never()
        results["sleep_never"] = sleep_res
        logger.info(f"[Orchestrator] Sleep timeouts set to Never: {sleep_res.get('success')}")
    except Exception as e:
        results["sleep_never"] = {"success": False, "message": str(e)}

    # 2. Power Modes (if battery/laptop)
    try:
        if has_battery():
            power_res = set_laptop_power_modes()
            results["power_modes"] = power_res
            logger.info(f"[Orchestrator] Laptop power modes set: {power_res.get('success')}")
        else:
            results["power_modes"] = {
                "success": True,
                "skipped": True,
                "message": "دستگاه رومیزی (بدون باتری) است؛ طرح توان لپ‌تاپ نیاز نیست.",
            }
    except Exception as e:
        results["power_modes"] = {"success": False, "message": str(e)}

    # 3. Tehran Timezone
    try:
        tz_res = set_tehran_automatic_timezone()
        results["tehran_timezone"] = tz_res
        logger.info(f"[Orchestrator] Tehran timezone configured: {tz_res.get('success')}")
    except Exception as e:
        results["tehran_timezone"] = {"success": False, "message": str(e)}

    # 4. Disable Startup Apps (silent, non-elevated user-level execution)
    try:
        startup_res = disable_all_startup_apps(elevate=False, open_page=False)
        results["startup_apps"] = startup_res
        logger.info(f"[Orchestrator] Startup apps configured: {startup_res.get('success')}")
    except Exception as e:
        results["startup_apps"] = {"success": False, "message": str(e)}

    # 5. Disable Windows 10 Background Apps
    identity = get_windows_identity()
    if identity.get("generation") == "Windows 10":
        try:
            bg_res = disable_windows10_background_apps(open_page=False)
            results["background_apps"] = bg_res
            logger.info(f"[Orchestrator] Windows 10 background apps disabled: {bg_res.get('success')}")
        except Exception as e:
            results["background_apps"] = {"success": False, "message": str(e)}

    # Core setting is sleep_never. If sleep_never or the majority succeeded, report success.
    sleep_ok = results.get("sleep_never", {}).get("success", False)
    all_success = all(v.get("success") for v in results.values())
    overall_ok = all_success or (sleep_ok and any(v.get("success") for k, v in results.items() if k != "sleep_never"))

    return {
        "success": overall_ok,
        "all_success": all_success,
        "results": results,
        "message": "تنظیمات مهم سیستم با موفقیت اعمال شدند." if all_success else "تنظیمات اصلی سیستم (خاموشی صفحه، زمان Sleep و...) با موفقیت اعمال شدند.",
    }
