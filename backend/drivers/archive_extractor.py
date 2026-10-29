# backend/drivers/archive_extractor.py
r"""
Intelligent Archive Extractor for Driver Packages.
Recursively detects and unpacks compressed driver archives (.zip, .rar, .7z, .cab)
into isolated dedicated subfolders named after each archive file.
Prevents file collisions between different driver packages.
Supports:
- Python zipfile (built-in, safe path traversal and archive bomb checks)
- Windows built-in expand.exe / extrac32.exe / tar.exe for .cab archives
- WinRAR / Rar.exe (installed on system)
- 7-Zip (7z.exe)
- Windows built-in tar.exe

Safety controls:
- Staging isolation directory extraction (never extracts into in-place parent)
- Recursion depth enforcement (nesting depth <= 3)
- Zip-slip protection across all archive formats
- Archive bomb protection (< 10GB payload, < 100:1 ratio, < 25,000 files)
- Long path handling (\\?\ prefix for paths > 240 chars)
"""

import logging
import os
import shutil
import subprocess
import tempfile
import zipfile
from typing import List, Optional

from utils.powershell import get_hidden_subprocess_kwargs

logger = logging.getLogger(__name__)

SUPPORTED_ARCHIVE_EXTS = {".zip", ".rar", ".7z", ".cab"}

# Archive safety limits
MAX_UNCOMPRESSED_BYTES = 10 * 1024 * 1024 * 1024  # 10 GB limit
MAX_COMPRESSION_RATIO = 100.0  # 100:1 ratio limit
MAX_ARCHIVE_FILE_COUNT = 25000  # 25,000 files limit
MAX_RECURSION_DEPTH = 3


def to_long_path(path: str) -> str:
    """Prepend Windows extended-length prefix \\?\\ for paths exceeding 240 chars."""
    if not path:
        return path
    abs_path = os.path.abspath(path)
    if len(abs_path) > 240 and not abs_path.startswith("\\\\?\\"):
        if abs_path.startswith("\\\\"):
            return "\\\\?\\UNC\\" + abs_path[2:]
        return "\\\\?\\" + abs_path
    return abs_path


def _find_winrar_or_rar_exe() -> Optional[str]:
    """Finds WinRAR or Rar.exe CLI binary on the host system."""
    local_app_data = os.environ.get("LOCALAPPDATA", "")
    candidates = [
        r"C:\Program Files\WinRAR\UnRAR.exe",
        r"C:\Program Files\WinRAR\Rar.exe",
        r"C:\Program Files\WinRAR\WinRAR.exe",
        r"C:\Program Files (x86)\WinRAR\UnRAR.exe",
        r"C:\Program Files (x86)\WinRAR\Rar.exe",
        r"C:\Program Files (x86)\WinRAR\WinRAR.exe",
        os.path.join(local_app_data, "Programs", "WinRAR", "UnRAR.exe")
        if local_app_data
        else None,
        os.path.join(local_app_data, "Programs", "WinRAR", "Rar.exe")
        if local_app_data
        else None,
        os.path.join(local_app_data, "Programs", "WinRAR", "WinRAR.exe")
        if local_app_data
        else None,
        shutil.which("unrar"),
        shutil.which("rar"),
        shutil.which("winrar"),
    ]
    for c in candidates:
        if c and os.path.isfile(c):
            return c
    return None


def has_rar_extractor() -> bool:
    """Return whether a *reliable* RAR-capable extractor is available."""
    return bool(_find_winrar_or_rar_exe() or _find_7z_exe())


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


def _find_expand_exe() -> Optional[str]:
    """Finds Windows built-in expand.exe."""
    sys_root = os.environ.get("SystemRoot", r"C:\Windows")
    cand = os.path.join(sys_root, "System32", "expand.exe")
    if os.path.isfile(cand):
        return cand
    return shutil.which("expand")


def _find_extrac32_exe() -> Optional[str]:
    """Finds Windows built-in extrac32.exe."""
    sys_root = os.environ.get("SystemRoot", r"C:\Windows")
    cand = os.path.join(sys_root, "System32", "extrac32.exe")
    if os.path.isfile(cand):
        return cand
    return shutil.which("extrac32")


def _copy_tree_long_path(src_dir: str, dst_dir: str) -> None:
    """Copies all items from src_dir into dst_dir handling Windows long paths."""
    os.makedirs(to_long_path(dst_dir), exist_ok=True)
    for root, dirs, files in os.walk(src_dir):
        rel = os.path.relpath(root, src_dir)
        target_root = os.path.join(dst_dir, rel) if rel != "." else dst_dir
        os.makedirs(to_long_path(target_root), exist_ok=True)
        for f in files:
            s_file = os.path.join(root, f)
            d_file = os.path.join(target_root, f)
            shutil.copy2(to_long_path(s_file), to_long_path(d_file))


def _validate_extracted_dir(stage_dir: str, archive_path: str) -> bool:
    """
    Validates staging directory for zip-slip, payload size, file count, and compression ratio.
    """
    stage_abs = os.path.abspath(stage_dir)
    file_count = 0
    total_uncompressed = 0
    archive_size = os.path.getsize(archive_path) if os.path.isfile(archive_path) else 0

    for root, dirs, files in os.walk(stage_abs):
        for name in files:
            file_count += 1
            if file_count > MAX_ARCHIVE_FILE_COUNT:
                logger.warning(
                    f"Security: Archive bomb detected: file count {file_count} exceeds limit {MAX_ARCHIVE_FILE_COUNT}"
                )
                return False

            fp = os.path.join(root, name)
            try:
                fp_abs = os.path.abspath(fp)
                if os.path.commonpath([stage_abs, fp_abs]) != stage_abs:
                    logger.warning(
                        f"Security: Malicious archive entry detected outside staging directory: {name}"
                    )
                    return False
                if os.path.islink(fp) or (hasattr(os, "isjunction") and os.path.isjunction(fp)):
                    link_target = os.path.abspath(os.path.realpath(fp))
                    if os.path.commonpath([stage_abs, link_target]) != stage_abs:
                        logger.warning(f"Security: Malicious symlink/junction detected: {name}")
                        return False
                total_uncompressed += os.path.getsize(fp)
            except Exception as e:
                logger.warning(f"Error inspecting extracted file {fp}: {e}")
                return False

            if total_uncompressed > MAX_UNCOMPRESSED_BYTES:
                logger.warning(
                    f"Security: Archive bomb detected: uncompressed size {total_uncompressed} exceeds limit"
                )
                return False

    if archive_size > 0 and (total_uncompressed / archive_size) > MAX_COMPRESSION_RATIO:
        logger.warning(
            f"Security: Archive bomb detected: compression ratio {total_uncompressed / archive_size:.1f} exceeds limit"
        )
        return False

    return True


def _safe_extract_zip(archive_path: str, dest_dir: str) -> bool:
    """Extracts zip archive safely using python's zipfile, blocking path traversal and bombs."""
    try:
        dest_abs = os.path.abspath(dest_dir)
        os.makedirs(to_long_path(dest_abs), exist_ok=True)
        archive_size = os.path.getsize(archive_path) if os.path.isfile(archive_path) else 0

        with zipfile.ZipFile(archive_path, "r") as zf:
            infolist = zf.infolist()
            if len(infolist) > MAX_ARCHIVE_FILE_COUNT:
                logger.warning(
                    f"Security: Archive bomb detected: zip contains {len(infolist)} files (limit: {MAX_ARCHIVE_FILE_COUNT})"
                )
                return False

            total_uncompressed = sum(member.file_size for member in infolist)
            if total_uncompressed > MAX_UNCOMPRESSED_BYTES:
                logger.warning(
                    f"Security: Archive bomb detected: zip payload {total_uncompressed} exceeds limit {MAX_UNCOMPRESSED_BYTES}"
                )
                return False

            if archive_size > 0 and (total_uncompressed / archive_size) > MAX_COMPRESSION_RATIO:
                logger.warning(
                    f"Security: Archive bomb detected: compression ratio {total_uncompressed / archive_size:.1f} exceeds limit"
                )
                return False

            for member in infolist:
                target = os.path.abspath(os.path.join(dest_abs, member.filename))
                if os.path.commonpath([dest_abs, target]) != dest_abs:
                    logger.warning(f"Security: Malicious zip entry detected: {member.filename}")
                    return False

            # Extract into dedicated staging isolation directory first
            with tempfile.TemporaryDirectory(prefix="_markazi_zip_stage_") as stage_dir:
                zf.extractall(to_long_path(stage_dir))
                if not _validate_extracted_dir(stage_dir, archive_path):
                    return False
                _copy_tree_long_path(stage_dir, dest_abs)

        return True
    except Exception as e:
        logger.warning(f"zipfile extraction failed for {archive_path}: {e}")
        return False


def _extract_with_cab(archive_path: str, dest_dir: str) -> bool:
    """Extracts Windows CAB archive safely using expand.exe, extrac32.exe, or tar.exe."""
    dest_abs = os.path.abspath(dest_dir)
    os.makedirs(to_long_path(dest_abs), exist_ok=True)

    with tempfile.TemporaryDirectory(prefix="_markazi_cab_stage_") as stage_dir:
        success = False

        # 1. Try expand.exe (Windows built-in)
        expand_bin = _find_expand_exe()
        if expand_bin:
            try:
                # Pre-check listing with -D for zip-slip entries
                list_res = subprocess.run(
                    [expand_bin, "-D", to_long_path(archive_path)],
                    timeout=30,
                    capture_output=True,
                    text=True,
                    **get_hidden_subprocess_kwargs(),
                )
                if list_res.returncode == 0:
                    for line in list_res.stdout.splitlines():
                        if ":" in line and not line.strip().endswith(":") and "files total" not in line.lower():
                            entry = line.rsplit(":", 1)[1].strip()
                            if ".." in entry or entry.startswith(("\\", "/")) or (len(entry) > 1 and entry[1] == ":"):
                                logger.warning(f"Security: Malicious cab entry detected: {entry}")
                                return False

                cmd = [expand_bin, "-R", to_long_path(archive_path), "-F:*", to_long_path(stage_dir)]
                res = subprocess.run(
                    cmd,
                    timeout=180,
                    capture_output=True,
                    **get_hidden_subprocess_kwargs(),
                )
                if res.returncode == 0:
                    success = True
            except Exception as e:
                logger.warning(f"expand.exe extraction failed for {archive_path}: {e}")

        # 2. Try extrac32.exe if expand.exe failed or was unavailable
        if not success:
            extrac32_bin = _find_extrac32_exe()
            if extrac32_bin:
                try:
                    cmd = [extrac32_bin, "/Y", "/E", f"/L", to_long_path(stage_dir), to_long_path(archive_path)]
                    res = subprocess.run(
                        cmd,
                        timeout=180,
                        capture_output=True,
                        **get_hidden_subprocess_kwargs(),
                    )
                    if res.returncode == 0:
                        success = True
                except Exception as e:
                    logger.warning(f"extrac32.exe extraction failed for {archive_path}: {e}")

        # 3. Try tar.exe fallback if available
        if not success:
            tar_bin = _find_tar_exe()
            if tar_bin:
                try:
                    cmd = [tar_bin, "-xf", to_long_path(archive_path), "-C", to_long_path(stage_dir)]
                    res = subprocess.run(
                        cmd,
                        timeout=180,
                        capture_output=True,
                        **get_hidden_subprocess_kwargs(),
                    )
                    if res.returncode == 0:
                        success = True
                except Exception as e:
                    logger.warning(f"tar.exe cab extraction failed for {archive_path}: {e}")

        if success:
            if not _validate_extracted_dir(stage_dir, archive_path):
                return False
            _copy_tree_long_path(stage_dir, dest_abs)
            return True

    return False


def _extract_with_rar(rar_bin: str, archive_path: str, dest_dir: str) -> bool:
    """Extracts using WinRAR or Rar.exe silently via staging isolation sandbox."""
    try:
        dest_abs = os.path.abspath(dest_dir)
        os.makedirs(to_long_path(dest_abs), exist_ok=True)
        with tempfile.TemporaryDirectory(prefix="_markazi_rar_stage_") as stage_dir:
            dest_slash = os.path.abspath(stage_dir)
            if not dest_slash.endswith("\\"):
                dest_slash += "\\"

            is_gui = "winrar.exe" in os.path.basename(rar_bin).lower()
            if is_gui:
                cmd = [rar_bin, "x", "-ibck", "-inul", "-y", to_long_path(archive_path), to_long_path(dest_slash)]
            else:
                cmd = [rar_bin, "x", "-y", "-inul", to_long_path(archive_path), to_long_path(dest_slash)]

            res = subprocess.run(
                cmd,
                timeout=180,
                capture_output=True,
                **get_hidden_subprocess_kwargs(),
            )
            if res.returncode in (0, 1):
                if not _validate_extracted_dir(stage_dir, archive_path):
                    return False
                _copy_tree_long_path(stage_dir, dest_abs)
                return True
        return False
    except Exception as e:
        logger.warning(f"Rar extraction failed for {archive_path}: {e}")
        return False


def _extract_with_7z(sevenz_bin: str, archive_path: str, dest_dir: str) -> bool:
    """Extracts using 7-Zip CLI silently via staging isolation sandbox."""
    try:
        dest_abs = os.path.abspath(dest_dir)
        os.makedirs(to_long_path(dest_abs), exist_ok=True)
        with tempfile.TemporaryDirectory(prefix="_markazi_7z_stage_") as stage_dir:
            cmd = [sevenz_bin, "x", "-y", f"-o{to_long_path(stage_dir)}", to_long_path(archive_path)]
            res = subprocess.run(
                cmd,
                timeout=180,
                capture_output=True,
                **get_hidden_subprocess_kwargs(),
            )
            if res.returncode == 0:
                if not _validate_extracted_dir(stage_dir, archive_path):
                    return False
                _copy_tree_long_path(stage_dir, dest_abs)
                return True
        return False
    except Exception as e:
        logger.warning(f"7z extraction failed for {archive_path}: {e}")
        return False


def _extract_with_tar(tar_bin: str, archive_path: str, dest_dir: str) -> bool:
    """Extracts using Windows built-in tar.exe via staging isolation sandbox."""
    try:
        dest_abs = os.path.abspath(dest_dir)
        os.makedirs(to_long_path(dest_abs), exist_ok=True)
        with tempfile.TemporaryDirectory(prefix="_markazi_tar_stage_") as stage_dir:
            cmd = [tar_bin, "-xf", to_long_path(archive_path), "-C", to_long_path(stage_dir)]
            res = subprocess.run(
                cmd,
                timeout=180,
                capture_output=True,
                **get_hidden_subprocess_kwargs(),
            )
            if res.returncode == 0:
                if not _validate_extracted_dir(stage_dir, archive_path):
                    return False
                _copy_tree_long_path(stage_dir, dest_abs)
                return True
        return False
    except Exception as e:
        logger.warning(f"tar extraction failed for {archive_path}: {e}")
        return False


def extract_driver_archive(archive_path: str, dest_dir: str) -> bool:
    """
    Extracts a driver archive (.zip, .rar, .7z, .cab) into dest_dir using the best available tool.
    Extracts via dedicated staging isolation sandbox with zip-slip and bomb defenses.
    Returns True if extraction succeeded and created valid files.
    """
    if not os.path.isfile(archive_path):
        return False

    ext = os.path.splitext(archive_path)[1].lower()
    os.makedirs(to_long_path(dest_dir), exist_ok=True)

    success = False

    if ext == ".zip":
        # 1. Try python zipfile with path traversal and bomb checks
        success = _safe_extract_zip(archive_path, dest_dir)
        # A failed security/CRC check must not be bypassed by another extractor.

    elif ext == ".cab":
        # Windows CAB extraction via expand.exe / extrac32.exe / tar.exe
        success = _extract_with_cab(archive_path, dest_dir)

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


def _get_archive_nesting_depth(archive_path: str, extracted_dirs: List[str]) -> int:
    """
    Calculates how many levels of archive extraction this archive is nested within.
    Direct files in the target directory tree have depth 0.
    """
    abs_path = os.path.normcase(os.path.abspath(archive_path))
    depth = 0
    for ed in sorted(extracted_dirs, key=len):
        ed_abs = os.path.normcase(os.path.abspath(ed))
        try:
            if os.path.commonpath([ed_abs, abs_path]) == ed_abs and ed_abs != abs_path:
                depth += 1
        except Exception:
            pass
    return depth


def auto_unpack_driver_archives(
    target_dir: str,
    staging_dir: Optional[str] = None,
    max_depth: int = MAX_RECURSION_DEPTH,
) -> List[str]:
    """
    Recursively scans target_dir for compressed driver archives (.zip, .rar, .7z, .cab)
    enforcing archive nesting recursion depth <= 3, without following filesystem links.
    For each archive, unpacks into a dedicated isolated subfolder named after the archive
    (or inside staging_dir if provided), preventing file collisions.
    Returns list of paths of all extracted driver directories.
    """
    if not os.path.isdir(target_dir):
        return []

    extracted_dirs: List[str] = []
    ignored_names = {
        "backend", "_internal", "build", "dist", "node_modules", ".git", "temp", "tmp", "logs", "__pycache__"
    }

    try:
        for root, dirs, files in os.walk(target_dir):
            dirs[:] = [
                d for d in dirs
                if d.lower() not in ignored_names
                and not d.startswith(".")
                and not os.path.islink(os.path.join(root, d))
                and not (hasattr(os, "isjunction") and os.path.isjunction(os.path.join(root, d)))
            ]

            for f in files:
                ext = os.path.splitext(f)[1].lower()
                if ext in SUPPORTED_ARCHIVE_EXTS:
                    archive_path = os.path.join(root, f)
                    archive_stem = os.path.splitext(f)[0].strip()
                    if not archive_stem:
                        continue

                    nesting_depth = _get_archive_nesting_depth(archive_path, extracted_dirs)
                    if nesting_depth >= max_depth:
                        logger.warning(
                            f"[ArchiveExtractor] Skipping archive {archive_path}: "
                            f"nesting depth {nesting_depth} reached max recursion depth {max_depth}"
                        )
                        continue

                    # Dedicated folder named after the archive file (isolation directory)
                    if staging_dir:
                        dest_folder = os.path.join(staging_dir, archive_stem)
                    else:
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

                    # Include new directories so nested archives up to max_depth are visited
                    if nesting_depth + 1 < max_depth and os.path.isdir(dest_folder) and archive_stem not in dirs:
                        dirs.append(archive_stem)

    except Exception as e:
        logger.error(f"[ArchiveExtractor] Error during archive scan in {target_dir}: {e}")

    return extracted_dirs
