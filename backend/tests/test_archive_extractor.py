# backend/tests/test_archive_extractor.py
"""
Comprehensive Unit Test Suite for Intelligent Driver Archive Extractor.
Tests:
- CAB archive extraction (using mock expand/tar/extrac32)
- Nested archives up to depth 3 and depth limit enforcement
- Zip-slip detection and rejection across formats
- Archive bomb protection (uncompressed size, compression ratio, file count)
- Windows long paths (\\?\\ and \\?\\UNC\\ prefixing)
- Staging isolation sandbox and directory validation
"""

import io
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
import zipfile
from unittest.mock import MagicMock, patch

BACKEND_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if BACKEND_DIR not in sys.path:
    sys.path.insert(0, BACKEND_DIR)

from drivers.archive_extractor import (
    to_long_path,
    extract_driver_archive,
    auto_unpack_driver_archives,
    _get_archive_nesting_depth,
    _safe_extract_zip,
    _extract_with_cab,
    _validate_extracted_dir,
    has_rar_extractor,
    MAX_UNCOMPRESSED_BYTES,
    MAX_COMPRESSION_RATIO,
    MAX_ARCHIVE_FILE_COUNT,
    MAX_RECURSION_DEPTH,
)


class TestArchiveExtractor(unittest.TestCase):

    def setUp(self):
        self.test_dir = tempfile.mkdtemp(prefix="test_extractor_")

    def tearDown(self):
        shutil.rmtree(self.test_dir, ignore_errors=True)

    # -------------------------------------------------------------------------
    # 1. Long Path Handling
    # -------------------------------------------------------------------------
    def test_to_long_path_short_path_unchanged(self):
        short = r"C:\Short\Path\driver.inf"
        self.assertEqual(to_long_path(short), os.path.abspath(short))

    def test_to_long_path_exceeding_240_chars_prefixed(self):
        long_segment = "a" * 250
        long_path = os.path.join(r"C:\Drivers", long_segment, "setup.exe")
        result = to_long_path(long_path)
        self.assertTrue(result.startswith(r"\\?\C:"))
        self.assertIn(long_segment, result)

    def test_to_long_path_unc_exceeding_240_chars(self):
        long_segment = "b" * 250
        unc_path = r"\\server\share\\" + long_segment + r"\driver.inf"
        result = to_long_path(unc_path)
        self.assertTrue(result.startswith(r"\\?\UNC\server\share"))

    def test_to_long_path_already_prefixed_not_double_prefixed(self):
        already = r"\\?\C:\Some\Path" + ("a" * 250)
        self.assertEqual(to_long_path(already), already)

    def test_to_long_path_empty_or_none(self):
        self.assertEqual(to_long_path(""), "")
        self.assertIsNone(to_long_path(None))

    # -------------------------------------------------------------------------
    # 2. Safe Zip Extraction & Zip-Slip Protection
    # -------------------------------------------------------------------------
    def test_safe_zip_extraction_success(self):
        zip_path = os.path.join(self.test_dir, "good.zip")
        dest_dir = os.path.join(self.test_dir, "good_extracted")

        with zipfile.ZipFile(zip_path, "w") as zf:
            zf.writestr("driver.inf", "[Version]\nSignature=$Windows NT$\n")
            zf.writestr("sub/setup.exe", b"MZdummybinary")

        ok = extract_driver_archive(zip_path, dest_dir)
        self.assertTrue(ok)
        self.assertTrue(os.path.isfile(os.path.join(dest_dir, "driver.inf")))
        self.assertTrue(os.path.isfile(os.path.join(dest_dir, "sub", "setup.exe")))

    def test_zip_slip_relative_path_traversal_rejected(self):
        zip_path = os.path.join(self.test_dir, "slip.zip")
        dest_dir = os.path.join(self.test_dir, "slip_dest")

        with zipfile.ZipFile(zip_path, "w") as zf:
            # Entry attempting path traversal
            zf.writestr("../escape.txt", "Malicious content escaping sandbox")
            zf.writestr("normal.txt", "Normal file")

        ok = extract_driver_archive(zip_path, dest_dir)
        self.assertFalse(ok)
        # Verify escape file was NOT written outside destination directory
        escaped_file = os.path.join(self.test_dir, "escape.txt")
        self.assertFalse(os.path.exists(escaped_file))

    def test_zip_slip_absolute_path_traversal_rejected(self):
        zip_path = os.path.join(self.test_dir, "slip_abs.zip")
        dest_dir = os.path.join(self.test_dir, "slip_abs_dest")

        with zipfile.ZipFile(zip_path, "w") as zf:
            # Absolute-style member filename
            zf.writestr("/windows/system32/evil.dll", "evil content")

        ok = _safe_extract_zip(zip_path, dest_dir)
        self.assertFalse(ok)

    # -------------------------------------------------------------------------
    # 3. Archive Bomb Protections (Size, Ratio, File Count)
    # -------------------------------------------------------------------------
    def test_archive_bomb_file_count_limit_rejected(self):
        zip_path = os.path.join(self.test_dir, "bomb_count.zip")
        dest_dir = os.path.join(self.test_dir, "bomb_dest")

        with zipfile.ZipFile(zip_path, "w") as zf:
            zf.writestr("test.txt", "hello")

        # Mock infolist to simulate exceeding MAX_ARCHIVE_FILE_COUNT
        fake_infolist = [MagicMock(filename=f"file_{i}.txt", file_size=10) for i in range(MAX_ARCHIVE_FILE_COUNT + 10)]

        with patch("zipfile.ZipFile.infolist", return_value=fake_infolist):
            ok = _safe_extract_zip(zip_path, dest_dir)
            self.assertFalse(ok)

    def test_archive_bomb_uncompressed_size_limit_rejected(self):
        zip_path = os.path.join(self.test_dir, "bomb_size.zip")
        dest_dir = os.path.join(self.test_dir, "bomb_dest")

        with zipfile.ZipFile(zip_path, "w") as zf:
            zf.writestr("test.txt", "hello")

        # Mock infolist where total uncompressed size exceeds MAX_UNCOMPRESSED_BYTES (10GB)
        fake_member = MagicMock(filename="giant.iso", file_size=MAX_UNCOMPRESSED_BYTES + 1024 * 1024)
        with patch("zipfile.ZipFile.infolist", return_value=[fake_member]):
            ok = _safe_extract_zip(zip_path, dest_dir)
            self.assertFalse(ok)

    def test_archive_bomb_compression_ratio_limit_rejected(self):
        zip_path = os.path.join(self.test_dir, "bomb_ratio.zip")
        dest_dir = os.path.join(self.test_dir, "bomb_dest")

        # Create a valid small zip archive
        with zipfile.ZipFile(zip_path, "w") as zf:
            zf.writestr("small.txt", "abc")

        # Mock infolist with member claiming 50,000 bytes (ratio = 500:1, exceeding 100:1)
        fake_member = MagicMock(filename="expand.bin", file_size=50000)
        with patch("zipfile.ZipFile.infolist", return_value=[fake_member]):
            ok = _safe_extract_zip(zip_path, dest_dir)
            self.assertFalse(ok)

    def test_validate_extracted_dir_detects_symlink_traversal(self):
        stage_dir = os.path.join(self.test_dir, "stage_symlink")
        os.makedirs(stage_dir, exist_ok=True)
        archive_path = os.path.join(self.test_dir, "dummy.zip")
        with open(archive_path, "wb") as f:
            f.write(b"dummy")

        file_inside = os.path.join(stage_dir, "mock_link.txt")
        with open(file_inside, "w") as f:
            f.write("link")

        outside_target = os.path.abspath(os.path.join(self.test_dir, "..", "outside_target.txt"))

        with (
            patch("drivers.archive_extractor.os.path.islink", return_value=True),
            patch("drivers.archive_extractor.os.path.realpath", return_value=outside_target),
        ):
            self.assertFalse(_validate_extracted_dir(stage_dir, archive_path))

    # -------------------------------------------------------------------------
    # 4. CAB Archive Extraction (expand.exe, extrac32.exe, tar.exe)
    # -------------------------------------------------------------------------
    def test_cab_extraction_with_expand_exe_success(self):
        cab_path = os.path.join(self.test_dir, "driver.cab")
        dest_dir = os.path.join(self.test_dir, "cab_out")
        with open(cab_path, "wb") as f:
            f.write(b"MSCFdummycabdata")

        # Mock expand.exe listing and extraction
        mock_list = MagicMock(returncode=0, stdout="Cabinet file: driver.cab\n1: driver.inf\n2: setup.dll\n")

        def fake_run(cmd, *args, **kwargs):
            if "-D" in cmd:
                return mock_list
            if "-R" in cmd:
                # cmd: [expand, -R, cab, -F:*, stage_dir]
                stage = cmd[4]
                os.makedirs(stage, exist_ok=True)
                with open(os.path.join(stage, "driver.inf"), "w") as f:
                    f.write("[Version]\nSignature=$Windows NT$\n")
                return MagicMock(returncode=0, stdout="Expanded 1 file")
            return MagicMock(returncode=1)

        with (
            patch("drivers.archive_extractor._find_expand_exe", return_value=r"C:\Windows\System32\expand.exe"),
            patch("subprocess.run", side_effect=fake_run),
        ):
            ok = extract_driver_archive(cab_path, dest_dir)
            self.assertTrue(ok)
            self.assertTrue(os.path.isfile(os.path.join(dest_dir, "driver.inf")))

    def test_cab_extraction_with_expand_exe_zipslip_detected_in_listing(self):
        cab_path = os.path.join(self.test_dir, "bad.cab")
        dest_dir = os.path.join(self.test_dir, "cab_bad_out")
        with open(cab_path, "wb") as f:
            f.write(b"MSCFbadcab")

        # Listing containing path traversal
        mock_list = MagicMock(
            returncode=0,
            stdout="Cabinet file: bad.cab\n1: ..\\evil.exe\n2: normal.inf\n",
        )

        with (
            patch("drivers.archive_extractor._find_expand_exe", return_value=r"C:\Windows\System32\expand.exe"),
            patch("subprocess.run", return_value=mock_list),
        ):
            ok = extract_driver_archive(cab_path, dest_dir)
            self.assertFalse(ok)

    def test_cab_extraction_fallback_to_extrac32(self):
        cab_path = os.path.join(self.test_dir, "driver2.cab")
        dest_dir = os.path.join(self.test_dir, "cab_out2")
        with open(cab_path, "wb") as f:
            f.write(b"MSCFcab2")

        def fake_run(cmd, *args, **kwargs):
            # extrac32 invocation: [extrac32, /Y, /E, /L, stage_dir, cab_path]
            stage = cmd[4]
            os.makedirs(stage, exist_ok=True)
            with open(os.path.join(stage, "audio.inf"), "w") as f:
                f.write("[Version]\nSignature=$Windows NT$\n")
            return MagicMock(returncode=0)

        with (
            patch("drivers.archive_extractor._find_expand_exe", return_value=None),
            patch("drivers.archive_extractor._find_extrac32_exe", return_value=r"C:\Windows\System32\extrac32.exe"),
            patch("subprocess.run", side_effect=fake_run),
        ):
            ok = extract_driver_archive(cab_path, dest_dir)
            self.assertTrue(ok)
            self.assertTrue(os.path.isfile(os.path.join(dest_dir, "audio.inf")))

    def test_cab_extraction_fallback_to_tar(self):
        cab_path = os.path.join(self.test_dir, "driver3.cab")
        dest_dir = os.path.join(self.test_dir, "cab_out3")
        with open(cab_path, "wb") as f:
            f.write(b"MSCFcab3")

        def fake_run(cmd, *args, **kwargs):
            # tar.exe invocation: [tar, -xf, cab_path, -C, stage_dir]
            stage = cmd[4]
            os.makedirs(stage, exist_ok=True)
            with open(os.path.join(stage, "net.inf"), "w") as f:
                f.write("[Version]\nSignature=$Windows NT$\n")
            return MagicMock(returncode=0)

        with (
            patch("drivers.archive_extractor._find_expand_exe", return_value=None),
            patch("drivers.archive_extractor._find_extrac32_exe", return_value=None),
            patch("drivers.archive_extractor._find_tar_exe", return_value=r"C:\Windows\System32\tar.exe"),
            patch("subprocess.run", side_effect=fake_run),
        ):
            ok = extract_driver_archive(cab_path, dest_dir)
            self.assertTrue(ok)
            self.assertTrue(os.path.isfile(os.path.join(dest_dir, "net.inf")))

    # -------------------------------------------------------------------------
    # 5. RAR and 7z Extraction (Mocked)
    # -------------------------------------------------------------------------
    def test_rar_extraction_with_mock_winrar(self):
        rar_path = os.path.join(self.test_dir, "driver.rar")
        dest_dir = os.path.join(self.test_dir, "rar_out")
        with open(rar_path, "wb") as f:
            f.write(b"Rar!dummy")

        def fake_run(cmd, *args, **kwargs):
            # cmd: [rar_bin, x, -y, -inul, archive, dest_dir]
            stage = cmd[5].rstrip("\\")
            os.makedirs(stage, exist_ok=True)
            with open(os.path.join(stage, "setup.exe"), "wb") as f:
                f.write(b"MZ")
            return MagicMock(returncode=0)

        with (
            patch("drivers.archive_extractor._find_winrar_or_rar_exe", return_value=r"C:\Program Files\WinRAR\Rar.exe"),
            patch("subprocess.run", side_effect=fake_run),
        ):
            ok = extract_driver_archive(rar_path, dest_dir)
            self.assertTrue(ok)
            self.assertTrue(os.path.isfile(os.path.join(dest_dir, "setup.exe")))

    def test_7z_extraction_with_mock_7z(self):
        sevenz_path = os.path.join(self.test_dir, "driver.7z")
        dest_dir = os.path.join(self.test_dir, "7z_out")
        with open(sevenz_path, "wb") as f:
            f.write(b"7z\xBC\xAF\x27\x1Cdummy")

        def fake_run(cmd, *args, **kwargs):
            stage = cmd[3].replace("-o", "").rstrip("\\")
            os.makedirs(stage, exist_ok=True)
            with open(os.path.join(stage, "wifi.inf"), "w") as f:
                f.write("[Version]\nSignature=$Windows NT$\n")
            return MagicMock(returncode=0)

        with (
            patch("drivers.archive_extractor._find_7z_exe", return_value=r"C:\Program Files\7-Zip\7z.exe"),
            patch("subprocess.run", side_effect=fake_run),
        ):
            ok = extract_driver_archive(sevenz_path, dest_dir)
            self.assertTrue(ok)
            self.assertTrue(os.path.isfile(os.path.join(dest_dir, "wifi.inf")))

    def test_has_rar_extractor(self):
        with patch("drivers.archive_extractor._find_winrar_or_rar_exe", return_value="Rar.exe"):
            self.assertTrue(has_rar_extractor())
        with (
            patch("drivers.archive_extractor._find_winrar_or_rar_exe", return_value=None),
            patch("drivers.archive_extractor._find_7z_exe", return_value=None),
        ):
            self.assertFalse(has_rar_extractor())

    # -------------------------------------------------------------------------
    # 6. Nested Archives & Recursion Depth Limit
    # -------------------------------------------------------------------------
    def test_nesting_depth_calculation(self):
        ext_dirs = [
            os.path.join(self.test_dir, "level0"),
            os.path.join(self.test_dir, "level0", "level1"),
            os.path.join(self.test_dir, "level0", "level1", "level2"),
        ]

        # Archive outside extracted dirs
        outside = os.path.join(self.test_dir, "other", "pkg.zip")
        self.assertEqual(_get_archive_nesting_depth(outside, ext_dirs), 0)

        # Archive inside level0
        in_level0 = os.path.join(self.test_dir, "level0", "nested1.zip")
        self.assertEqual(_get_archive_nesting_depth(in_level0, ext_dirs), 1)

        # Archive inside level1
        in_level1 = os.path.join(self.test_dir, "level0", "level1", "nested2.zip")
        self.assertEqual(_get_archive_nesting_depth(in_level1, ext_dirs), 2)

        # Archive inside level2
        in_level2 = os.path.join(self.test_dir, "level0", "level1", "level2", "nested3.zip")
        self.assertEqual(_get_archive_nesting_depth(in_level2, ext_dirs), 3)

    def test_auto_unpack_nested_archives_up_to_depth_3(self):
        root_dir = os.path.join(self.test_dir, "scan_root")
        os.makedirs(root_dir, exist_ok=True)

        # Level 0 ZIP
        l0_zip = os.path.join(root_dir, "level0.zip")
        # Build in memory level 1 ZIP
        buf1 = io.BytesIO()
        with zipfile.ZipFile(buf1, "w") as z1:
            z1.writestr("level1_file.txt", "data1")
            # In memory level 2 ZIP
            buf2 = io.BytesIO()
            with zipfile.ZipFile(buf2, "w") as z2:
                z2.writestr("level2_file.txt", "data2")
                # In memory level 3 ZIP
                buf3 = io.BytesIO()
                with zipfile.ZipFile(buf3, "w") as z3:
                    z3.writestr("level3_file.txt", "data3")
                    # In memory level 4 ZIP (exceeds max depth 3!)
                    buf4 = io.BytesIO()
                    with zipfile.ZipFile(buf4, "w") as z4:
                        z4.writestr("level4_file.txt", "data4")
                    z3.writestr("level4.zip", buf4.getvalue())
                z2.writestr("level3.zip", buf3.getvalue())
            z1.writestr("level2.zip", buf2.getvalue())

        with zipfile.ZipFile(l0_zip, "w") as z0:
            z0.writestr("level0_file.txt", "data0")
            z0.writestr("level1.zip", buf1.getvalue())

        extracted = auto_unpack_driver_archives(root_dir, max_depth=MAX_RECURSION_DEPTH)

        # Verify level0 (depth 0), level1 (depth 1), level2 (depth 2) were unpacked
        extracted_stems = [os.path.basename(p) for p in extracted]
        self.assertIn("level0", extracted_stems)
        self.assertIn("level1", extracted_stems)
        self.assertIn("level2", extracted_stems)

        # Level 3 (depth 3) is skipped because max_depth=3
        self.assertNotIn("level3", extracted_stems)
        self.assertNotIn("level4", extracted_stems)

    def test_extract_nonexistent_file_returns_false(self):
        nonexistent = os.path.join(self.test_dir, "ghost.zip")
        self.assertFalse(extract_driver_archive(nonexistent, os.path.join(self.test_dir, "out")))

    def test_auto_unpack_nonexistent_target_dir_returns_empty(self):
        self.assertEqual(auto_unpack_driver_archives(r"C:\NonExistent_Dir_xyz123"), [])


if __name__ == "__main__":
    unittest.main()
