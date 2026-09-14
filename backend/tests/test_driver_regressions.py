import os
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
from drivers.driver_installer import _collect_driver_candidates
from drivers.package_inspector import inspect_driver_package, parse_inf_file
from drivers.queue_manager import _install_single_package, get_driver_queue_status
from drivers.deduplicator import deduplicate_driver_packages
from drivers.archive_extractor import auto_unpack_driver_archives, extract_driver_archive
from drivers.hardware_matcher import match_package_to_hardware


class DriverRegressionTests(unittest.TestCase):
    def test_opaque_downloads_are_separate_even_in_driver_named_folder(self):
        with tempfile.TemporaryDirectory() as root:
            folder = Path(root) / 'driver_laptop'
            folder.mkdir()
            expected = []
            for name in ('alksdfjasd.exe', 'alsdfklasjdf.exe', 'alksdfoiw0eifh.exe'):
                path = folder / name
                path.write_bytes(b'MZ')
                expected.append(str(path))
            self.assertCountEqual(_collect_driver_candidates(str(folder)), expected)

    def test_opaque_exe_is_unknown_not_incompatible(self):
        result = match_package_to_hardware({'install_method': 'setup_exe', 'hardware_ids': []}, [])
        self.assertEqual(result['confidence'], 'UNKNOWN')
        self.assertEqual(result['recommendation'], 'optional')

    def test_newly_extracted_nested_archive_is_scanned(self):
        import io
        with tempfile.TemporaryDirectory() as root:
            inner = io.BytesIO()
            with zipfile.ZipFile(inner, 'w') as archive:
                archive.writestr('opaque.exe', b'MZ')
            with zipfile.ZipFile(Path(root) / 'outer.zip', 'w') as archive:
                archive.writestr('inner.zip', inner.getvalue())
            auto_unpack_driver_archives(root)
            self.assertTrue((Path(root) / 'outer' / 'inner' / 'opaque.exe').exists())

    @unittest.skipUnless(os.path.isfile(r'C:\Program Files\WinRAR\Rar.exe'), 'RAR CLI unavailable')
    def test_real_rar_extracts_all_opaque_installers_without_executing_them(self):
        import subprocess
        from utils.powershell import get_hidden_subprocess_kwargs
        with tempfile.TemporaryDirectory() as root:
            source = Path(root) / 'source'
            source.mkdir()
            names = ['alksdfjasd.exe', 'alsdfklasjdf.exe', 'alksdfoiw0eifh.exe']
            for name in names:
                (source / name).write_bytes(b'MZ fixture, never execute')
            archive = Path(root) / 'drivers.rar'
            subprocess.run([r'C:\Program Files\WinRAR\Rar.exe', 'a', '-ep', '-inul',
                            str(archive), *[str(source / name) for name in names]],
                           check=True, timeout=20, **get_hidden_subprocess_kwargs())
            output = Path(root) / 'extracted'
            self.assertTrue(extract_driver_archive(str(archive), str(output)))
            self.assertCountEqual(_collect_driver_candidates(str(output)),
                                  [str(output / name) for name in names])

    def test_vendor_folder_category_overrides_aggregated_inf_class(self):
        from drivers.package_inspector import classify_driver_category
        self.assertEqual(classify_driver_category(['DRV_Audio_RTK'], 'net')[0], 'audio')
        self.assertEqual(classify_driver_category(['DRV_BT_MTK'], 'media')[0], 'bluetooth')
        self.assertEqual(classify_driver_category(['DRV_VGA_Intel'], 'net')[0], 'gpu')

    def test_windows_11_package_is_skipped_on_windows_10(self):
        package = {'supported_windows': ['11'], 'hardware_ids': ['PCI\\VEN_1234&DEV_0001'], 'category': 'gpu'}
        with patch('drivers.hardware_matcher.platform.release', return_value='10'):
            result = match_package_to_hardware(package, [])
        self.assertEqual(result['recommendation'], 'skip')
        self.assertIn('ویندوز 11', result['status_fa'])

    def test_wrong_hardware_id_is_not_promoted_by_problem_device(self):
        package = {'hardware_ids': ['PCI\\VEN_1111&DEV_0001'], 'category': 'lan'}
        hardware = [{'DeviceID': 'PCI\\VEN_2222&DEV_0002',
                     'HardwareIDs': ['PCI\\VEN_2222&DEV_0002'],
                     'PNPClass': 'Net', 'ProblemCode': 28,
                     'Name': 'Ethernet Controller'}]
        result = match_package_to_hardware(package, hardware)
        self.assertEqual(result['recommendation'], 'skip')

    def test_utf16_inf_and_service_exe_are_not_misidentified(self):
        with tempfile.TemporaryDirectory() as root:
            inf = Path(root) / 'iaStorVD.inf'
            inf.write_text('[Version]\nClass=SCSIAdapter\nDriverVer=01/01/2026,20.2.6.1025\n[Models]\nDevice=Install,PCI\\VEN_8086&DEV_1234\n', encoding='utf-16')
            (Path(root) / 'RstMwService.exe').write_bytes(b'MZ')
            self.assertEqual(parse_inf_file(str(inf))['driver_version'], '20.2.6.1025')
            package = inspect_driver_package(root, root)
            self.assertEqual(package.install_method, 'pnputil')
            self.assertEqual(package.to_dict()['installer_path'], str(inf))

    def test_uninstall_tool_is_not_a_driver(self):
        with tempfile.TemporaryDirectory() as root:
            folder = Path(root) / 'Armoury_Crate_Uninstall_Tool'
            folder.mkdir()
            (folder / 'setup.exe').write_bytes(b'MZ')
            self.assertIsNone(inspect_driver_package(str(folder), root))

    def test_zip_below_depth_two_is_extracted(self):
        with tempfile.TemporaryDirectory() as root:
            folder = Path(root) / 'board' / 'drivers' / 'win10' / 'x64'
            folder.mkdir(parents=True)
            with zipfile.ZipFile(folder / 'LAN.zip', 'w') as archive:
                archive.writestr('driver.inf', '[Version]\nClass=Net')
            self.assertIn(str(folder / 'LAN'), auto_unpack_driver_archives(root))
            self.assertTrue((folder / 'LAN' / 'driver.inf').is_file())

    def test_unsafe_zip_never_falls_back_to_external_extractor(self):
        with tempfile.TemporaryDirectory() as root:
            archive_path = Path(root) / 'bad.zip'
            with zipfile.ZipFile(archive_path, 'w') as archive:
                archive.writestr('../escape.txt', 'blocked')
            with patch('drivers.archive_extractor._extract_with_tar') as external:
                self.assertFalse(extract_driver_archive(str(archive_path), str(Path(root) / 'out')))
                external.assert_not_called()
            self.assertFalse((Path(root) / 'escape.txt').exists())

    def test_deep_package_is_discovered(self):
        with tempfile.TemporaryDirectory() as root:
            folder = Path(root) / 'board' / 'drivers' / 'win10' / 'x64' / 'LAN'
            folder.mkdir(parents=True)
            (folder / 'setup.exe').write_bytes(b'MZ')
            self.assertEqual(_collect_driver_candidates(root), [str(folder)])

    def test_all_infs_are_inspected_and_attempted_after_a_failure(self):
        with tempfile.TemporaryDirectory() as root:
            for index in range(9):
                (Path(root) / f'{index}.inf').write_text(
                    '[Version]\nClass=System\nProvider=Vendor\n'
                    f'[Models]\nDevice=Install,PCI\\VEN_1234&DEV_{index:04d}\n', encoding='utf-8')
            package = inspect_driver_package(root, root)
            self.assertEqual(len(package.inf_files), 9)
            self.assertEqual(len(package.hardware_ids), 9)
            results = [(0, 'ok')] * 9
            results[2] = (5, 'denied')
            results[8] = (3010, 'reboot required')
            with patch('drivers.queue_manager._install_inf_package', side_effect=results) as install, patch('drivers.queue_manager.record_driver_installation'), patch('drivers.queue_manager._log_driver_event'):
                result = _install_single_package(package.to_dict())
            self.assertEqual(install.call_count, 9)
            self.assertFalse(result['success'])
            self.assertTrue(result['reboot_required'])
            self.assertEqual(result['exit_code'], 5)

    def test_component_packages_with_same_hardware_survive(self):
        packages = [dict(source_path=f'C:/drivers/{name}', category='audio', hardware_ids=['PCI\\VEN_1234&DEV_1234'], display_name='Audio') for name in ('base', 'extension', 'component')]
        unique, duplicates = deduplicate_driver_packages(packages)
        self.assertEqual(len(unique), 3)
        self.assertFalse(duplicates)

    def test_queue_status_is_a_snapshot(self):
        state = get_driver_queue_status()
        state['items'].append({'status': 'corrupted'})
        self.assertNotIn({'status': 'corrupted'}, get_driver_queue_status()['items'])


if __name__ == '__main__':
    unittest.main()
