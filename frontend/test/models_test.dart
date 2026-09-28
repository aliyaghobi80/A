import 'package:flutter_test/flutter_test.dart';
import 'package:markazi_system_checker/models/system_info.dart';

void main() {
  test(
    'System device title prefers exact product model over Windows hostname',
    () {
      final system = SystemMetaInfo.fromJson({
        'computer_name': 'DESKTOP-H4S6RIG',
        'manufacturer': 'ASUSTeK COMPUTER INC.',
        'model': 'ASUS All-in-One',
        'display_name': 'ASUS All-in-One P440VA',
        'model_code': 'P440VA',
        'sku': 'ASUS_AIO_P440VA',
      });

      expect(system.deviceDisplayName, 'ASUS All-in-One P440VA');
    },
  );

  test('System device title falls back to manufacturer and model', () {
    final system = SystemMetaInfo(
      computerName: 'DESKTOP-TEST',
      manufacturer: 'Lenovo',
      model: 'V15 G3 IAP',
    );

    expect(system.deviceDisplayName, 'Lenovo V15 G3 IAP');
  });

  test('Windows Update Blocker package is recognized case-insensitively', () {
    final package = SoftwarePackage(
      id: 'tools/wub',
      name: 'WINDOWS update BLOCKER',
      filename: 'Wub_x64.exe',
      relativePath: 'Tools/Wub_x64.exe',
      version: '1.8',
      publisher: 'Sordum',
      isValid: true,
      status: 'Ready to Run',
      isInstalled: true,
      installedVersion: '1.8',
      installAllowed: false,
      hasIcon: false,
      isPortableTool: true,
      canOpenTool: true,
    );
    expect(package.isWindowsUpdateBlocker, isTrue);
  });

  test('Windows Update state and Microsoft Office identity are parsed', () {
    final wub = SoftwarePackage.fromJson({
      'id': 'wub',
      'name': 'Windows Update Blocker',
      'filename': 'Wub_x64.exe',
      'relative_path': 'Tools/Wub_x64.exe',
      'publisher': 'Sordum',
      'is_valid': true,
      'status': 'Ready to Run',
      'is_installed': true,
      'installed_version': '1.8',
      'install_allowed': false,
      'has_icon': false,
      'windows_update_blocked': true,
      'windows_update_state_known': true,
    });
    final office = SoftwarePackage.fromJson({
      'id': 'office_2024_pro_plus',
      'name': 'Microsoft Office 2024 (Pro Plus)',
      'filename': 'Setup_Office 2024.cmd',
      'relative_path': 'Office/Setup_Office 2024.cmd',
      'publisher': 'Microsoft Corporation',
      'installer_type': 'office_cmd',
      'is_valid': true,
      'status': 'Installed',
      'is_installed': true,
      'installed_version': '2024',
      'install_allowed': true,
      'has_icon': false,
    });
    expect(wub.windowsUpdateBlocked, isTrue);
    expect(wub.windowsUpdateStateKnown, isTrue);
    expect(office.isMicrosoftOfficePackage, isTrue);
  });

  test(
    'SystemInfo.fromJson parses full schema correctly with drivers, software, and files',
    () {
      final mockJson = {
        'status': 'success',
        'timestamp': '2026-08-14T06:35:00',
        'scan_duration_ms': 120.5,
        'cpu': {
          'name': '12th Gen Intel Core i3-12100F',
          'manufacturer': 'Intel',
          'cores': 4,
          'threads': 8,
          'max_clock_mhz': 3300,
          'max_clock_display': '3.30 GHz',
        },
        'motherboard': {
          'manufacturer': 'Gigabyte Technology Co., Ltd.',
          'model': 'H610M K DDR4',
          'serial': 'Not available',
        },
        'ram': {
          'total_gb': 16.0,
          'total_display': '16 GB',
          'module_count': 2,
          'module_summary': '8 GB + 8 GB',
          'speed_mhz': 2133,
          'speed_display': '2133 MHz',
          'modules': [
            {
              'slot': 'Controller0-ChannelA-DIMM0',
              'capacity_gb': 8.0,
              'capacity_display': '8 GB',
              'speed_mhz': 2133,
              'speed_display': '2133 MHz',
              'type': 'DDR4',
              'manufacturer': 'Golden Empire',
              'part_number': 'CL15',
            },
          ],
        },
        'gpu': [
          {
            'name': 'NVIDIA GeForce RTX 3060',
            'manufacturer': 'NVIDIA',
            'vram_bytes': 12884901888,
            'vram_gb': 12.0,
            'vram_display': '12 GB VRAM',
            'driver_version': '32.0.16.1088',
          },
        ],
        'storage': [
          {
            'model': 'Samsung SSD 870 EVO 500GB',
            'type': 'SSD',
            'bus_type': 'SATA',
            'capacity_bytes': 500107862016,
            'capacity_gb': 465.76,
            'capacity_display': '466 GB',
            'serial': 'S5Y1NJ0NC40889T',
            'health_status': 'Healthy',
          },
        ],
        'windows': {
          'edition': 'Windows 11 Enterprise',
          'version': 'Version 25H2',
          'build': '26200.9168',
          'architecture': '64-bit',
        },
        'system': {
          'computer_name': 'DESKTOP-BTS6OUC',
          'manufacturer': 'Gigabyte Technology Co., Ltd.',
          'model': 'H610M K DDR4',
        },
        'bios': {
          'manufacturer': 'American Megatrends',
          'version': 'F22',
          'date': '2023-06-05',
        },
        'network': [
          {
            'name': 'Ethernet',
            'description': 'Realtek PCIe GbE Family Controller',
            'mac_address': '74-56-3C-A1-F2-22',
            'ipv4_address': '192.168.70.152',
            'status': 'Up',
            'link_speed': '1 Gbps',
            'is_connected': true,
          },
        ],
        'drivers': [
          {
            'id': 'graphics',
            'name': 'Graphics / GPU',
            'display_name': 'Graphics / GPU',
            'device_name': 'NVIDIA GeForce RTX 3060',
            'category': 'Display',
            'status': 'OK',
            'is_healthy': true,
            'is_present': true,
            'problem_code': 0,
            'status_description': 'Device is working properly',
            'instance_id': 'PCI\\VEN_10DE',
          },
          {
            'id': 'bluetooth',
            'name': 'Bluetooth Adapter',
            'display_name': 'Bluetooth Adapter',
            'device_name': 'Not present',
            'category': 'Bluetooth',
            'status': 'Not Present',
            'is_healthy': true,
            'is_present': false,
            'problem_code': 0,
            'status_description':
                'Bluetooth hardware is not present on this motherboard',
            'instance_id': 'Not available',
          },
        ],
        'driver_summary': {
          'healthy_count': 1,
          'total_present_count': 1,
          'allHealthy': true,
          'has_problem': false,
          'status_text': 'Ready',
        },
        'software': [
          {
            'id': 'chrome',
            'name': 'Google Chrome',
            'display_name': 'Google Chrome',
            'status': 'Installed',
            'is_installed': true,
            'version': '151.0.7922.138',
            'product_name': 'Google Chrome',
            'detection_source': 'Registry (HKLM_32)',
            'install_location':
                'C:\\Program Files\\Google\\Chrome\\Application',
            'required': true,
          },
        ],
        'software_summary': {
          'installed_count': 1,
          'total_count': 1,
          'all_installed': true,
        },
        'required_files': [
          {
            'id': 'training_folder',
            'name': 'Training Folder',
            'display_name': 'Training Folder',
            'path': 'C:\\CompanyFiles\\Training',
            'type': 'folder',
            'status': 'Missing',
            'exists': false,
            'required': true,
          },
        ],
        'files_summary': {
          'present_count': 0,
          'total_count': 1,
          'all_present': false,
        },
      };

      final info = SystemInfo.fromJson(mockJson);

      expect(info.status, 'success');
      expect(info.cpu.name, '12th Gen Intel Core i3-12100F');
      expect(info.motherboard.model, 'H610M K DDR4');
      expect(info.ram.totalGb, 16.0);
      expect(info.gpu.first.name, 'NVIDIA GeForce RTX 3060');
      expect(info.drivers.length, 2);
      expect(info.drivers.first.isHealthy, true);
      expect(info.drivers[1].isPresent, false);
      expect(info.driverSummary.statusText, 'Ready');
      expect(info.software.first.isInstalled, true);
      expect(info.filesSummary.presentCount, 0);
    },
  );

  test(
    'PackagesResponse.fromJson parses recursive exe packages and icons correctly',
    () {
      final mockPackagesJson = {
        'directory_exists': true,
        'packages_directory': 'G:\\MarkaziSystem\\Packages',
        'packages': [
          {
            'id': '7zip',
            'name': '7-Zip',
            'filename': '7Zip.EXE',
            'relative_path': 'Utilities/7Zip.EXE',
            'full_path': 'G:\\MarkaziSystem\\Packages\\Utilities\\7Zip.EXE',
            'version': '24.09',
            'publisher': 'Igor Pavlov',
            'file_size_display': '564.0 KB',
            'is_valid': true,
            'status': 'Not Installed',
            'is_installed': false,
            'installed_version': 'Not available',
            'install_allowed': true,
            'has_icon': true,
            'icon_base64': 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUg==',
          },
          {
            'id': 'winrar',
            'name': 'WinRAR',
            'filename': 'winrar-x64.exe',
            'relative_path': 'WinRAR/winrar-x64.exe',
            'full_path': 'G:\\MarkaziSystem\\Packages\\WinRAR\\winrar-x64.exe',
            'version': '7.13.0',
            'publisher': 'win.rar GmbH',
            'file_size_display': '3.4 MB',
            'is_valid': true,
            'status': 'Installed',
            'is_installed': true,
            'installed_version': '7.13.0',
            'install_allowed': false,
            'has_icon': false,
          },
        ],
        'summary': {
          'total_packages': 2,
          'valid_packages': 2,
          'installed_packages': 1,
          'available_to_install': 1,
        },
      };

      final resp = PackagesResponse.fromJson(mockPackagesJson);
      expect(resp.directoryExists, true);
      expect(resp.packages.length, 2);
      expect(resp.packages.first.filename, '7Zip.EXE');
      expect(resp.packages.first.relativePath, 'Utilities/7Zip.EXE');
      expect(resp.packages.first.fileSizeDisplay, '564.0 KB');
      expect(resp.packages.first.installAllowed, true);
      expect(resp.packages.first.hasIcon, true);
      expect(resp.packages[1].isInstalled, true);
      expect(resp.packages[1].installAllowed, false);
      expect(resp.summary.availableToInstall, 1);
    },
  );

  test(
    'SoftwarePackage parses portable tools correctly with isPortable and open action',
    () {
      final wubJson = {
        'id': 'wub_x64',
        'name': 'Windows Update Blocker',
        'filename': 'Wub_x64.exe',
        'relative_path': 'Tools/Wub_x64.exe',
        'full_path': r'C:\Packages\Tools\Wub_x64.exe',
        'version': '1.8',
        'publisher': 'Sordum.org',
        'is_valid': true,
        'status': 'Ready to Run',
        'is_installed': true,
        'is_portable_tool': true,
        'can_open_tool': true,
        'install_allowed': false,
        'has_icon': true,
        'installed_exe_path': r'C:\Packages\Tools\Wub_x64.exe',
      };

      final pkg = SoftwarePackage.fromJson(wubJson);
      expect(pkg.isPortable, true);
      expect(pkg.isPortableTool, true);
      expect(pkg.canOpenTool, true);
      expect(pkg.installAllowed, false);
      expect(pkg.installPathTooltip.contains('ابزار پرتابل'), true);
    },
  );

  test(
    'WindowsActivationInfo & OfficeActivationInfo parse correctly from json',
    () {
      final winJson = {
        'status': 'Licensed',
        'activated': true,
        'channel': 'Retail',
        'partial_key': '8HV2C',
        'description': 'Windows(R) Operating System, RETAIL channel',
        'expiration': null,
        'is_permanent': true,
        'tool_available': true,
        'tool_path': 'Tools\\WindowsActivation\\activate.cmd',
      };

      final winInfo = WindowsActivationInfo.fromJson(winJson);
      expect(winInfo.statusText, 'Licensed');
      expect(winInfo.activated, true);
      expect(winInfo.channel, 'Retail');
      expect(winInfo.partialKey, '8HV2C');
      expect(winInfo.isPermanent, true);
      expect(winInfo.toolAvailable, true);

      final officeJson = {
        'installed': true,
        'product': 'Microsoft Office Professional Plus 2024',
        'version': '16.0.20228.20158',
        'architecture': '64-bit',
        'install_type': 'Click-to-Run',
        'status': 'Licensed',
        'status_text': 'Licensed',
        'activated': true,
        'channel': 'Retail',
        'partial_key': '88KC6',
        'expiration': null,
        'tool_available': true,
        'tool_path': 'Tools\\OfficeActivation\\activate.cmd',
      };

      final officeInfo = OfficeActivationInfo.fromJson(officeJson);
      expect(officeInfo.installed, true);
      expect(officeInfo.product, 'Microsoft Office Professional Plus 2024');
      expect(officeInfo.architecture, '64-bit');
      expect(officeInfo.installType, 'Click-to-Run');
      expect(officeInfo.statusText, 'Licensed');
      expect(officeInfo.activated, true);
      expect(officeInfo.partialKey, '88KC6');
      expect(officeInfo.toolAvailable, true);

      final resultJson = {
        'success': true,
        'cancelled': false,
        'message': 'Windows activation tool launched successfully',
        'exit_code': 0,
        'output': 'Activation OK',
      };

      final actResult = ActivationResult.fromJson(resultJson);
      expect(actResult.success, true);
      expect(actResult.cancelled, false);
      expect(
        actResult.message,
        'Windows activation tool launched successfully',
      );
      expect(actResult.exitCode, 0);
    },
  );

  test(
    'IntelligentDriverPackage & DriverScanResult parse correctly from json',
    () {
      final mockScanJson = {
        'success': true,
        'message': '2 packages discovered',
        'driver_directory': 'C:\\Drivers',
        'total_packages': 2,
        'summary': {
          'total': 2,
          'matching': 1,
          'needs_install': 1,
          'update_available': 0,
          'up_to_date': 0,
          'not_applicable': 1,
          'duplicates': 0,
        },
        'removable_sources': [
          {
            'drive_letter': 'E:',
            'volume_name': 'FlashDrive',
            'driver_path': 'E:\\Drivers',
            'display_name': 'FlashDrive (E:) - Drivers',
          },
        ],
        'packages': [
          {
            'package_id': 'drv_pkg_abc123',
            'display_name': 'Realtek PCIe GbE Family Controller',
            'category': 'lan',
            'category_fa': 'کارت شبکه کابلی (LAN)',
            'category_order': 4,
            'package_type': 'folder',
            'source_path': 'C:\\Drivers\\ASUS_LAN',
            'relative_path': 'ASUS_LAN',
            'installer_file': 'ASUSSetup.exe',
            'install_method': 'asus_setup',
            'file_size_display': '15.4 MB',
            'size_bytes': 16148070,
            'fingerprint': 'abc123456789',
            'hardware_ids': ['PCI\\VEN_10EC&DEV_8168'],
            'driver_version': '11.18.0.0',
            'driver_date': '03/15/2024',
            'provider': 'Realtek',
            'alternative_installers': ['setup.exe'],
            'is_duplicate': false,
            'match': {
              'is_matched': true,
              'confidence': 'HIGH',
              'status': 'needs_install',
              'status_fa': 'نیاز فوری به نصب درایور',
              'status_en': 'Driver Missing (Code 28)',
              'matched_device_name': 'Ethernet Controller',
              'matched_device_id': 'PCI\\VEN_10EC&DEV_8168',
              'installed_version': '',
              'package_version': '11.18.0.0',
              'recommendation': 'recommended',
              'reasons': ['دستگاه دارای خطای کد ۲۸ در ویندوز است.'],
            },
          },
        ],
      };

      final scanResult = DriverScanResult.fromJson(mockScanJson);
      expect(scanResult.success, true);
      expect(scanResult.totalPackages, 2);
      expect(scanResult.packages.length, 1);
      expect(scanResult.removableSources.length, 1);
      expect(scanResult.removableSources.first.driveLetter, 'E:');

      final pkg = scanResult.packages.first;
      expect(pkg.packageId, 'drv_pkg_abc123');
      expect(pkg.displayName, 'Realtek PCIe GbE Family Controller');
      expect(pkg.category, 'lan');
      expect(pkg.installMethod, 'asus_setup');
      expect(pkg.installerFile, 'ASUSSetup.exe');
      expect(pkg.alternativeInstallers, ['setup.exe']);

      final match = pkg.match;
      expect(match, isNotNull);
      expect(match!.isMatched, true);
      expect(match.confidence, 'HIGH');
      expect(match.status, 'needs_install');
      expect(match.recommendation, 'recommended');
    },
  );

  test(
    'MotherboardInfo handles brand detection, fallback colors, and display names',
    () {
      final mbGigabyte = MotherboardInfo.fromJson({
        'manufacturer': 'Gigabyte Technology Co., Ltd.',
        'model': 'H610M K DDR4',
        'serial': 'SN123456',
      });
      expect(mbGigabyte.effectiveBrand, 'GIGABYTE');
      expect(mbGigabyte.effectiveBrandFa, 'گیگابایت');
      expect(mbGigabyte.effectiveChipset, 'Intel H610');
      expect(mbGigabyte.effectiveFormFactor, 'Micro-ATX');
      expect(mbGigabyte.fullDisplayName, 'GIGABYTE H610M K DDR4');
      expect(mbGigabyte.brandColor.toARGB32(), 0xFFF97316);

      final mbAsus = MotherboardInfo.fromJson({
        'manufacturer': 'ASUSTeK COMPUTER INC.',
        'model': 'ROG STRIX B650-A GAMING WIFI',
        'serial': 'SN998877',
      });
      expect(mbAsus.effectiveBrand, 'ASUS');
      expect(mbAsus.effectiveBrandFa, 'ایسوس');
      expect(mbAsus.effectiveChipset, 'AMD B650');
      expect(mbAsus.fullDisplayName, 'ASUS ROG STRIX B650-A GAMING WIFI');
      expect(mbAsus.brandColor.toARGB32(), 0xFF0072C6);

      final mbMsi = MotherboardInfo.fromJson({
        'manufacturer': 'Micro-Star International Co., Ltd.',
        'model': 'MAG B760 TOMAHAWK WIFI',
        'serial': 'SN554433',
      });
      expect(mbMsi.effectiveBrand, 'MSI');
      expect(mbMsi.effectiveBrandFa, 'ام‌اس‌آی');
      expect(mbMsi.effectiveChipset, 'Intel B760');
      expect(mbMsi.fullDisplayName, 'MSI MAG B760 TOMAHAWK WIFI');
      expect(mbMsi.brandColor.toARGB32(), 0xFFEF4444);

      final mbAsrock = MotherboardInfo.fromJson({
        'manufacturer': 'ASRock',
        'model': 'B550M Pro4',
        'serial': 'SN112233',
      });
      expect(mbAsrock.effectiveBrand, 'ASRock');
      expect(mbAsrock.effectiveBrandFa, 'ازراک');
      expect(mbAsrock.effectiveChipset, 'AMD B550');
      expect(mbAsrock.effectiveFormFactor, 'Micro-ATX');
      expect(mbAsrock.fullDisplayName, 'ASRock B550M Pro4');
      expect(mbAsrock.brandColor.toARGB32(), 0xFF0EA5E9);
    },
  );

  test(
    'UsbDriveInfo.fromJson parses USB flash drive details and calculates percent properly',
    () {
      final usb = UsbDriveInfo.fromJson({
        'drive_letter': 'H:',
        'volume_name': 'aliyaghobi',
        'file_system': 'NTFS',
        'vendor': 'SanDisk',
        'product': 'Cruzer Blade',
        'serial': '2004432432075A52F543',
        'total_bytes': 31481360384,
        'free_bytes': 10957152256,
        'used_bytes': 20524208128,
        'total_gb': 29.32,
        'free_gb': 10.2,
        'used_gb': 19.11,
        'percent_used': 65.2,
        'is_removable': true,
      });

      expect(usb.driveLetter, 'H:');
      expect(usb.volumeName, 'aliyaghobi');
      expect(usb.fileSystem, 'NTFS');
      expect(usb.vendor, 'SanDisk');
      expect(usb.product, 'Cruzer Blade');
      expect(usb.totalGb, 29.32);
      expect(usb.freeGb, 10.2);
      expect(usb.usedGb, 19.11);
      expect(usb.percentUsed, 65.2);
      expect(usb.isRemovable, true);
      expect(usb.displayName, 'SanDisk Cruzer Blade (aliyaghobi)');
    },
  );
}
