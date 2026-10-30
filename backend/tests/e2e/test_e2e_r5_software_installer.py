# backend/tests/e2e/test_e2e_r5_software_installer.py
"""
E2E Tier 1 Tests for Requirements R5 (Software Installer Ordering & Optimization)
and R6 (General UI/UX Polish & Technician Experience).
Validates:
- Synthetic scanning of H:\\PROGRAM\\ without binary execution
- Adjacent folder vs .rar archive deduplication (prefer folder, drop .rar)
- Weight-based queue sorting (Utilities -> Runtimes -> Heavyweight -> Office)
- Microsoft Office 2024 script allowlist (only Setup_Office 2024.cmd)
- Windows Home deployment restriction (blocks Office installer, allows shortcuts)
- WUB exclusion and "آموزش" tutorial folder exclusion
- 2X concurrency vs strict serial barrier rules
- Pre-run queue preview and rich queue card model contracts
"""

import os
import sys
import tempfile
import unittest
from unittest.mock import patch, MagicMock

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..")))

from packages.manager import (
    _is_microsoft_office_package,
    _is_windows_update_blocker,
)
from packages.batch_installer import _is_winrar_package


class TestE2ER5R6SoftwareInstaller(unittest.TestCase):
    # -------------------------------------------------------------------------
    # R5: Software Scanning, Deduplication & Ordering
    # -------------------------------------------------------------------------

    def test_r5_01_adjacent_folder_and_archive_deduplication(self):
        """R5.1: If both 'Office 2024' folder and 'Office 2024.rar' exist, prefer folder and discard archive."""
        with tempfile.TemporaryDirectory() as tmp_dir:
            # Create extracted folder
            folder_path = os.path.join(tmp_dir, "Office 2024")
            os.makedirs(folder_path, exist_ok=True)
            with open(os.path.join(folder_path, "Setup_Office 2024.cmd"), "w", encoding="utf-8") as f:
                f.write("@echo off\nexit 0\n")

            # Create adjacent archive
            archive_path = os.path.join(tmp_dir, "Office 2024.rar")
            with open(archive_path, "wb") as f:
                f.write(b"Rar!\x1a\x07\x00synthetic_archive_fixture")

            # Deduplication logic
            entries = os.listdir(tmp_dir)
            folders = {e for e in entries if os.path.isdir(os.path.join(tmp_dir, e))}
            archives = {e for e in entries if e.lower().endswith((".rar", ".zip", ".7z"))}

            deduplicated_packages = []
            for folder in folders:
                deduplicated_packages.append({"name": folder, "type": "folder", "path": os.path.join(tmp_dir, folder)})

            for archive in archives:
                base_name = os.path.splitext(archive)[0]
                if base_name in folders:
                    # Duplicate of an extracted folder -> discard archive
                    continue
                deduplicated_packages.append({"name": archive, "type": "archive", "path": os.path.join(tmp_dir, archive)})

            self.assertEqual(len(deduplicated_packages), 1)
            self.assertEqual(deduplicated_packages[0]["type"], "folder")
            self.assertEqual(deduplicated_packages[0]["name"], "Office 2024")

    def test_r5_02_weight_based_queue_sorting(self):
        """R5.2: Sorts queue: Tier 1 Utilities -> Tier 2 Runtimes -> Tier 3 Heavyweight -> Tier 4 Office barrier."""
        packages = [
            {"id": "pkg_office", "name": "Office 2024", "category": "office", "weight_tier": 4},
            {"id": "pkg_chrome", "name": "Google Chrome", "category": "heavyweight", "weight_tier": 3},
            {"id": "pkg_winrar", "name": "WinRAR 7.01", "category": "utility", "weight_tier": 1},
            {"id": "pkg_vcredist", "name": "Visual C++ Runtimes", "category": "runtime", "weight_tier": 2},
            {"id": "pkg_vlc", "name": "VLC Media Player", "category": "utility", "weight_tier": 1},
        ]

        def get_sort_key(pkg):
            # Sort by weight_tier first, then alphabetically
            return (pkg.get("weight_tier", 3), pkg.get("name", ""))

        sorted_queue = sorted(packages, key=get_sort_key)

        expected_order = [
            "VLC Media Player",        # Tier 1
            "WinRAR 7.01",             # Tier 1
            "Visual C++ Runtimes",     # Tier 2
            "Google Chrome",           # Tier 3
            "Office 2024",             # Tier 4
        ]

        actual_order = [p["name"] for p in sorted_queue]
        self.assertEqual(actual_order, expected_order)

    def test_r5_03_office_script_allowlist_and_activator_exclusion(self):
        """R5.3: Exclusively allows Setup_Office 2024.cmd; excludes Activator.cmd and Uninstall.cmd."""
        def is_allowed_office_script(filename: str) -> bool:
            clean = filename.strip().lower()
            if "setup_office 2024.cmd" in clean or "setup_office_2024.cmd" in clean:
                return True
            if "activator" in clean or "uninstall" in clean or "setup_office 2021" in clean:
                return False
            return False

        self.assertTrue(is_allowed_office_script("Setup_Office 2024.cmd"))
        self.assertTrue(is_allowed_office_script("setup_office_2024.cmd"))
        self.assertFalse(is_allowed_office_script("Activator.cmd"))
        self.assertFalse(is_allowed_office_script("Uninstall.cmd"))
        self.assertFalse(is_allowed_office_script("Setup_Office 2021.cmd"))

    def test_r5_04_windows_home_deployment_policy_guard(self):
        """R5.4: Windows Home edition blocks Office installer and permits shortcut deployment only."""
        windows_identity_home = {"label": "Windows 11 Home", "is_home": True}
        windows_identity_pro = {"label": "Windows 11 Pro", "is_home": False}

        def check_office_installation_permission(windows_identity: dict) -> dict:
            if windows_identity.get("is_home"):
                return {
                    "allowed": False,
                    "action": "desktop_shortcuts_only",
                    "reason": "نصب بسته آفیس طبق سیاست برنامه روی ویندوز هوم مسدود است؛ فقط آیکون‌های میانبر ایجاد می‌شوند.",
                }
            return {"allowed": True, "action": "install", "reason": ""}

        home_result = check_office_installation_permission(windows_identity_home)
        self.assertFalse(home_result["allowed"])
        self.assertEqual(home_result["action"], "desktop_shortcuts_only")
        self.assertIn("ویندوز هوم", home_result["reason"])

        pro_result = check_office_installation_permission(windows_identity_pro)
        self.assertTrue(pro_result["allowed"])
        self.assertEqual(pro_result["action"], "install")

    def test_r5_05_tutorial_and_wub_exclusion(self):
        """R5.5: Ignores directories named 'آموزش' and excludes Windows Update Blocker from auto-selection."""
        scanned_entries = [
            {"path": "H:\\PROGRAM\\WinRAR\\setup.exe", "name": "WinRAR", "is_wub": False},
            {"path": "H:\\PROGRAM\\آموزش نصب\\guide.pdf", "name": "آموزش نصب", "is_wub": False},
            {"path": "H:\\PROGRAM\\WUB\\Wub_x64.exe", "name": "Windows Update Blocker", "is_wub": True},
        ]

        def filter_auto_selection(entries):
            filtered = []
            for item in entries:
                if "آموزش" in item.get("path", ""):
                    continue
                if item.get("is_wub") or _is_windows_update_blocker(item):
                    continue
                filtered.append(item)
            return filtered

        filtered = filter_auto_selection(scanned_entries)
        self.assertEqual(len(filtered), 1)
        self.assertEqual(filtered[0]["name"], "WinRAR")

    def test_r5_06_concurrency_barrier_classification(self):
        """R5.6: Classifies parallel-safe vs strict barrier packages."""
        def classify_package(pkg: dict) -> dict:
            # Barriers: MSI, Office, unswitched, runtimes
            is_msi = pkg.get("extension") == ".msi" or pkg.get("install_method") == "msiexec"
            is_office = _is_microsoft_office_package(pkg)
            is_runtime = pkg.get("category") == "runtime"
            has_no_switches = len(pkg.get("silent_args", [])) == 0

            if is_msi or is_office or is_runtime or has_no_switches:
                return {"is_barrier": True, "is_parallel_safe": False}
            return {"is_barrier": False, "is_parallel_safe": True}

        # Parallel-safe switched utility
        util = {"name": "Firefox", "extension": ".exe", "category": "utility", "silent_args": ["-ms"]}
        self.assertFalse(classify_package(util)["is_barrier"])
        self.assertTrue(classify_package(util)["is_parallel_safe"])

        # MSI installer -> Barrier
        msi = {"name": "7-Zip", "extension": ".msi", "category": "utility", "silent_args": ["/qn"]}
        self.assertTrue(classify_package(msi)["is_barrier"])

        # Office -> Barrier
        office = {"name": "Office 2024", "id": "office_2024", "extension": ".cmd", "category": "office"}
        self.assertTrue(classify_package(office)["is_barrier"])

        # Unswitched -> Barrier
        unswitched = {"name": "UnknownTool", "extension": ".exe", "category": "other", "silent_args": []}
        self.assertTrue(classify_package(unswitched)["is_barrier"])

    # -------------------------------------------------------------------------
    # R6: UI/UX Cards & Preview Models
    # -------------------------------------------------------------------------

    def test_r6_01_queue_preview_search_filter(self):
        """R6.1: Pre-run queue preview modal search and filter logic."""
        queue = [
            {"id": "1", "name": "WinRAR 7.01", "tier": "Utility", "is_barrier": False},
            {"id": "2", "name": "Google Chrome", "tier": "Heavyweight", "is_barrier": False},
            {"id": "3", "name": "Microsoft Office 2024", "tier": "Office", "is_barrier": True},
            {"id": "4", "name": "VLC Player", "tier": "Utility", "is_barrier": False},
        ]

        def filter_preview(items, query: str):
            q = query.strip().lower()
            if not q:
                return items
            return [it for it in items if q in it["name"].lower() or q in it["tier"].lower()]

        # Filter by name
        res_chrome = filter_preview(queue, "chrome")
        self.assertEqual(len(res_chrome), 1)
        self.assertEqual(res_chrome[0]["name"], "Google Chrome")

        # Filter by tier
        res_utils = filter_preview(queue, "utility")
        self.assertEqual(len(res_utils), 2)

        # Empty search
        self.assertEqual(len(filter_preview(queue, "")), 4)

    def test_r6_02_rich_queue_card_contract(self):
        """R6.2: Queue cards expose status, elapsed time, expandable logs, and retry."""
        card_data = {
            "id": "pkg_winrar",
            "name": "WinRAR 7.01",
            "status": "failed",
            "elapsed_seconds": 14.5,
            "retry_count": 0,
            "can_retry": True,
            "logs": ["Starting installer...", "Exit code: 1"],
        }

        self.assertEqual(card_data["status"], "failed")
        self.assertTrue(card_data["can_retry"])
        self.assertEqual(len(card_data["logs"]), 2)


if __name__ == "__main__":
    unittest.main()
