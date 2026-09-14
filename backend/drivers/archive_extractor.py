# backend/drivers/archive_extractor.py
"""
Intelligent Archive Extractor for Driver Packages.
Recursively detects and unpacks compressed driver archives (.zip, .rar, .7z)
into isolated dedicated subfolders named after each archive file.
Prevents file collisions between different driver packages.
Supports:
- Python zipfile (built-in, safe path traversal check)
- WinRAR / Rar.exe (installed on system)
- 7-Zip (7z.exe)
- Windows built-in tar.exe
"""

import logging
import os
import shutil
import subprocess
import zipfile
from typing import List, Optional

from utils.powershell import get_hidden_subprocess_kwargs

logger = logging.getLogger(__name__)

SUPPORTED_ARCHIVE_EXTS = {".zip", ".rar", ".7z"}


def _find_winrar_or_rar_exe() -> Optional[str]:
    """Finds WinRAR or Rar.exe CLI binary on the host system."""
    candidates = [
        r"C:\Program Files\WinRAR\Rar.exe",
        r"C:\Program Files\WinRAR\WinRAR.exe",
        r"C:\Program Files (x86)\WinRAR\Rar.exe",
        r"C:\Program Files (x86)\WinRAR\WinRAR.exe",
        shutil.which("rar"),
        shutil.which("winrar"),
    ]
    for c in candidates:
        if c and os.path.isfile(c):
            return c
    return None


def _find_7z_exe() -> Optional[str]:
    """Finds 7-Zip executable if available."""
    candidates = [
        r"C:\Program Files\7-Zip\7z.exe",
        r"C:\Program Files (x86)\7-Zip\7z.exe",
        shutil.which("7z"),
        shutil.which("7za"),
    ]
    for c in candidates:
        if c and os.path.isfile(c):
            return c
    return None


def _find_tar_exe() -> Optional[str]:
    """Finds Windows built-in tar.exe."""
    sys_root = os.environ.get("SystemRoot", r"C:\Windows")
    cand = os.path.join(sys_root, "System32", "tar.exe")
    if os.path.isfile(cand):
        return cand
    return shutil.which("tar")


def _safe_extract_zip(archive_path: str, dest_dir: str) -> bool:
    """Extracts zip archive safely using python's zipfile, blocking path traversal."""
    try:
        dest_abs = os.path.abspath(dest_dir)
        os.makedirs(dest_abs, exist_ok=True)
        with zipfile.ZipFile(archive_path, "r") as zf:
            for member in zf.infolist():
                target = os.path.abspath(os.path.join(dest_abs, member.filename))
                if os.path.commonpath([dest_abs, target]) != dest_abs:
                    logger.warning(f"Security: Malicious zip entry detected: {member.filename}")
                    return False
            zf.extractall(dest_abs)
        return True
    except Exception as e:
        logger.warning(f"zipfile extraction failed for {archive_path}: {e}")
        return False


def _extract_with_rar(rar_bin: str, archive_path: str, dest_dir: str) -> bool:
    """Extracts using WinRAR or Rar.exe silently with full paths."""
    try:
        os.makedirs(dest_dir, exist_ok=True)
        dest_slash = os.path.abspath(dest_dir)
        if not dest_slash.endswith("\\"):
            dest_slash += "\\"

        is_gui = "winrar.exe" in rar_bin.lower()
        if is_gui:
            cmd = [rar_bin, "x", "-ibck", "-inul", "-y", archive_path, dest_slash]
        else:
            cmd = [rar_bin, "x", "-y", "-inul", archive_path, dest_slash]

        res = subprocess.run(
            cmd,
            timeout=180,
            capture_output=True,
            **get_hidden_subprocess_kwargs(),
        )
        return res.returncode in (0, 1)
    except Exception as e:
        logger.warning(f"Rar extraction failed for {archive_path}: {e}")
        return False


def _extract_with_7z(sevenz_bin: str, archive_path: str, dest_dir: str) -> bool:
    """Extracts using 7-Zip CLI silently."""
    try:
        os.makedirs(dest_dir, exist_ok=True)
        cmd = [sevenz_bin, "x", "-y", f"-o{os.path.abspath(dest_dir)}", archive_path]
        res = subprocess.run(
            cmd,
            timeout=180,
            capture_output=True,
            **get_hidden_subprocess_kwargs(),
        )
        return res.returncode == 0
    except Exception as e:
        logger.warning(f"7z extraction failed for {archive_path}: {e}")
        return False


def _extract_with_tar(tar_bin: str, archive_path: str, dest_dir: str) -> bool:
    """Extracts using Windows built-in tar.exe."""
    try:
        os.makedirs(dest_dir, exist_ok=True)
        cmd = [tar_bin, "-xf", os.path.abspath(archive_path), "-C", os.path.abspath(dest_dir)]
        res = subprocess.run(
            cmd,
            timeout=180,
            capture_output=True,
            **get_hidden_subprocess_kwargs(),
        )
        return res.returncode == 0
    except Exception as e:
        logger.warning(f"tar extraction failed for {archive_path}: {e}")
        return False


def extract_driver_archive(archive_path: str, dest_dir: str) -> bool:
    """
    Extracts a driver archive (.zip, .rar, .7z) into dest_dir using the best available tool.
    Returns True if extraction succeeded and created files.
    """
    if not os.path.isfile(archive_path):
        return False

    ext = os.path.splitext(archive_path)[1].lower()
    os.makedirs(dest_dir, exist_ok=True)

    success = False

    if ext == ".zip":
        # 1. Try python zipfile
        success = _safe_extract_zip(archive_path, dest_dir)
        # A failed security/CRC check must not be bypassed by another extractor.

    elif ext == ".rar":
        # WinRAR / Rar.exe
        rar_bin = _find_winrar_or_rar_exe()
        if rar_bin:
            success = _extract_with_rar(rar_bin, archive_path, dest_dir)
        else:
            sevenz_bin = _find_7z_exe()
            if sevenz_bin:
                success = _extract_with_7z(sevenz_bin, archive_path, dest_dir)
            else:
                tar_bin = _find_tar_exe()
                if tar_bin:
                    success = _extract_with_tar(tar_bin, archive_path, dest_dir)

    elif ext == ".7z":
        # 7-Zip or WinRAR
        sevenz_bin = _find_7z_exe()
        if sevenz_bin:
            success = _extract_with_7z(sevenz_bin, archive_path, dest_dir)
        else:
            rar_bin = _find_winrar_or_rar_exe()
            if rar_bin:
                success = _extract_with_rar(rar_bin, archive_path, dest_dir)
            else:
                tar_bin = _find_tar_exe()
                if tar_bin:
                    success = _extract_with_tar(tar_bin, archive_path, dest_dir)

    if success and os.path.isdir(dest_dir):
        try:
            return bool(os.listdir(dest_dir))
        except Exception:
            return True

    return success


def auto_unpack_driver_archives(target_dir: str) -> List[str]:
    """
    Recursively scans target_dir for compressed driver archives (.zip, .rar, .7z)
    at any directory depth, without following filesystem links.
    For each archive, creates a dedicated subfolder named after the archive file,
    and extracts all contents into it so driver files never mix together.
    Returns list of paths of all extracted driver directories.
    """
    if not os.path.isdir(target_dir):
        return []

    extracted_dirs: List[str] = []
    ignored_names = {"backend", "_internal", "build", "dist", "node_modules", ".git", "temp", "tmp", "logs", "__pycache__"}

    try:
        for root, dirs, files in os.walk(target_dir):
            dirs[:] = [d for d in dirs if d.lower() not in ignored_names
                       and not d.startswith(".")
                       and not os.path.islink(os.path.join(root, d))
                       and not os.path.isjunction(os.path.join(root, d))]

            for f in files:
                ext = os.path.splitext(f)[1].lower()
                if ext in SUPPORTED_ARCHIVE_EXTS:
                    archive_path = os.path.join(root, f)
                    archive_stem = os.path.splitext(f)[0].strip()
                    if not archive_stem:
                        continue

                    # Dedicated folder named after the archive file
                    dest_folder = os.path.join(root, archive_stem)

                    # Check if destination folder already exists and is non-empty
                    already_extracted = False
                    if os.path.isdir(dest_folder):
                        try:
                            contents = os.listdir(dest_folder)
                            if contents:
                                already_extracted = True
                                if dest_folder not in extracted_dirs:
                                    extracted_dirs.append(dest_folder)
                        except Exception:
                            pass

                    if not already_extracted:
                        logger.info(f"[ArchiveExtractor] Unpacking driver archive: {archive_path} -> {dest_folder}")
                        ok = extract_driver_archive(archive_path, dest_folder)
                        if ok and os.path.isdir(dest_folder):
                            logger.info(f"[ArchiveExtractor] Successfully extracted: {dest_folder}")
                            if dest_folder not in extracted_dirs:
                                extracted_dirs.append(dest_folder)
                        else:
                            logger.warning(f"[ArchiveExtractor] Failed to extract archive: {archive_path}")
                    # os.walk captured dirs before extraction. Include new
                    # directories so nested ZIP/RAR/7z archives are visited too.
                    if os.path.isdir(dest_folder) and archive_stem not in dirs:
                        dirs.append(archive_stem)

    except Exception as e:
        logger.error(f"[ArchiveExtractor] Error during archive scan in {target_dir}: {e}")

    return extracted_dirs
