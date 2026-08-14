import 'package:flutter_test/flutter_test.dart';
import 'package:central_system_checker/models/system_info.dart';

void main() {
  test('SystemInfo.fromJson parses full schema correctly with fallbacks', () {
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
      ]
    };

    final info = SystemInfo.fromJson(mockJson);

    expect(info.status, 'success');
    expect(info.cpu.name, '12th Gen Intel Core i3-12100F');
    expect(info.cpu.coresThreadsDisplay, '4 Cores / 8 Threads');
    expect(info.motherboard.model, 'H610M K DDR4');
    expect(info.ram.totalGb, 16.0);
    expect(info.ram.modules.length, 1);
    expect(info.gpu.first.name, 'NVIDIA GeForce RTX 3060');
    expect(info.gpu.first.vramDisplay, '12 GB VRAM');
    expect(info.storage.first.model, 'Samsung SSD 870 EVO 500GB');
    expect(info.windows.edition, 'Windows 11 Enterprise');
    expect(info.system.computerName, 'DESKTOP-BTS6OUC');
    expect(info.bios.version, 'F22');
    expect(info.network.first.isConnected, true);
  });
}
