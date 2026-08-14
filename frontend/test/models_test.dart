import 'package:flutter_test/flutter_test.dart';
import 'package:central_system_checker/models/system_info.dart';

void main() {
  test('SystemInfo.fromJson parses full schema correctly with drivers, software, and files', () {
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
        'max_clock_display': '3.30 GHz'
      },
      'motherboard': {
        'manufacturer': 'Gigabyte Technology Co., Ltd.',
        'model': 'H610M K DDR4',
        'serial': 'Not available'
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
            'part_number': 'CL15'
          }
        ]
      },
      'gpu': [
        {
          'name': 'NVIDIA GeForce RTX 3060',
          'manufacturer': 'NVIDIA',
          'vram_bytes': 12884901888,
          'vram_gb': 12.0,
          'vram_display': '12 GB VRAM',
          'driver_version': '32.0.16.1088'
        }
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
          'health_status': 'Healthy'
        }
      ],
      'windows': {
        'edition': 'Windows 11 Enterprise',
        'version': 'Version 25H2',
        'build': '26200.9168',
        'architecture': '64-bit'
      },
      'system': {
        'computer_name': 'DESKTOP-BTS6OUC',
        'manufacturer': 'Gigabyte Technology Co., Ltd.',
        'model': 'H610M K DDR4'
      },
      'bios': {
        'manufacturer': 'American Megatrends',
        'version': 'F22',
        'date': '2023-06-05'
      },
      'network': [
        {
          'name': 'Ethernet',
          'description': 'Realtek PCIe GbE Family Controller',
          'mac_address': '74-56-3C-A1-F2-22',
          'ipv4_address': '192.168.70.152',
          'status': 'Up',
          'link_speed': '1 Gbps',
          'is_connected': true
        }
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
          'instance_id': 'PCI\\VEN_10DE'
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
          'status_description': 'Bluetooth hardware is not present on this motherboard',
          'instance_id': 'Not available'
        }
      ],
      'driver_summary': {
        'healthy_count': 1,
        'total_present_count': 1,
        'all_healthy': true,
        'has_problem': false,
        'status_text': 'Ready'
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
          'install_location': 'C:\\Program Files\\Google\\Chrome\\Application',
          'required': true
        }
      ],
      'software_summary': {
        'installed_count': 1,
        'total_count': 1,
        'all_installed': true
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
          'required': true
        }
      ],
      'files_summary': {
        'present_count': 0,
        'total_count': 1,
        'all_present': false
      }
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
    expect(info.driverSummary.allHealthy, true);
    expect(info.driverSummary.statusText, 'Ready');
    expect(info.software.first.isInstalled, true);
    expect(info.filesSummary.presentCount, 0);
  });

  test('PackagesResponse.fromJson parses packages with validation and installation permissions', () {
    final mockPackagesJson = {
      'packages_directory': 'G:\\MarkaziSystem\\Packages',
      'packages': [
        {
          'id': '7zip',
          'name': '7-Zip',
          'version': '24.09',
          'publisher': 'Igor Pavlov',
          'detection_id': '7zip',
          'package_folder': '7Zip',
          'installer_file': 'installer.bat',
          'silent_arguments': '/S',
          'is_valid': true,
          'validation_error': null,
          'status': 'Not Installed',
          'is_installed': false,
          'installed_version': 'Not available',
          'install_allowed': true,
          'has_icon': false,
          'icon_url': null,
          'package_path': 'G:\\MarkaziSystem\\Packages\\7Zip'
        },
        {
          'id': 'invalid_tool',
          'name': 'Invalid Tool',
          'version': '1.0',
          'publisher': 'Unknown',
          'package_folder': 'InvalidSample',
          'installer_file': 'missing.exe',
          'is_valid': false,
          'validation_error': 'Installer file missing',
          'status': 'Unknown',
          'is_installed': false,
          'install_allowed': false,
          'has_icon': false,
          'icon_url': null
        }
      ],
      'summary': {
        'total_packages': 2,
        'valid_packages': 1,
        'installed_packages': 0,
        'available_to_install': 1
      }
    };

    final resp = PackagesResponse.fromJson(mockPackagesJson);
    expect(resp.packages.length, 2);
    expect(resp.packages.first.installAllowed, true);
    expect(resp.packages[1].isValid, false);
    expect(resp.summary.availableToInstall, 1);
  });
}
