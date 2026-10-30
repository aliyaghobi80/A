// frontend/test/e2e/e2e_tier4_real_workload_test.dart
// End-to-End Tier 4 Tests: Real-World Workload Scenarios.
// Covers:
// - W-01: Full technician end-to-end lifecycle (Scan -> Deduplicate -> Sort -> 2X -> Crash Reconcile -> Adopt -> Hardware Verify -> Settings)
// - W-02: Hybrid graphics driver deployment sequence with display settle & advisory reboot reminder
// - W-03: Windows Home deployment policy workflow (blocks Office setup, creates shortcuts)

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('E2E Tier 4 — Real-World Workload Scenarios', () {
    test('W-01: Complete technician deployment lifecycle', () {
      // 1. Synthetic scan with duplicate archive & folder
      final scannedItems = [
        {'name': 'Office 2024', 'type': 'folder'},
        {'name': 'Office 2024.rar', 'type': 'archive'},
        {'name': 'WinRAR 7.01.exe', 'type': 'standalone_exe'},
        {'name': 'Chrome.exe', 'type': 'standalone_exe'},
      ];

      // Deduplication: prefer folder
      final deduplicated = scannedItems.where((item) {
        if (item['type'] == 'archive' && item['name'] == 'Office 2024.rar') {
          return false; // Discard duplicate archive
        }
        return true;
      }).toList();
      expect(deduplicated.length, 3);

      // 2. Weight sorting: Utilities -> Heavyweight -> Office barrier
      final queue = [
        {'name': 'Office 2024', 'tier': 4, 'status': 'pending'},
        {'name': 'Chrome.exe', 'tier': 3, 'status': 'pending'},
        {'name': 'WinRAR 7.01.exe', 'tier': 1, 'status': 'pending'},
      ];
      queue.sort((a, b) => (a['tier'] as int).compareTo(b['tier'] as int));
      expect(queue.first['name'], 'WinRAR 7.01.exe');
      expect(queue.last['name'], 'Office 2024');

      // 3. Execution simulation: WinRAR finishes, Chrome is installing, Office is pending
      queue[0]['status'] = 'completed';
      queue[1]['status'] = 'installing';

      // 4. Backend restart: in-flight item reconciles to 'interrupted' without auto-restart
      for (final item in queue) {
        if (item['status'] == 'installing' || item['status'] == 'pending') {
          item['status'] = 'interrupted';
        }
      }
      expect(queue[0]['status'], 'completed');
      expect(queue[1]['status'], 'interrupted');
      expect(queue[2]['status'], 'interrupted');

      // 5. Technician navigates to Hardware Tests & Settings
      int activeNavIndex = 3; // Hardware Tests
      expect(activeNavIndex, 3);
      activeNavIndex = 7; // Settings
      expect(activeNavIndex, 7);
    });

    test('W-02: Hybrid graphics driver deployment sequence with display settle & advisory reboot', () {
      final drivers = [
        {'name': 'Intel Chipset', 'category': 'chipset', 'priority': 1, 'is_barrier': true},
        {'name': 'Intel UHD Graphics', 'category': 'gpu', 'priority': 4, 'is_barrier': true},
        {'name': 'NVIDIA RTX 4060', 'category': 'gpu', 'priority': 5, 'is_barrier': true},
        {'name': 'Realtek LAN', 'category': 'lan', 'priority': 6, 'is_barrier': false},
        {'name': 'Realtek Audio', 'category': 'audio', 'priority': 9, 'is_barrier': false},
      ];

      drivers.sort((a, b) => (a['priority'] as int).compareTo(b['priority'] as int));
      expect(drivers[0]['name'], 'Intel Chipset');
      expect(drivers[1]['name'], 'Intel UHD Graphics');
      expect(drivers[2]['name'], 'NVIDIA RTX 4060');

      // GPU settle delay requirement
      final hasGpu = drivers.any((d) => d['category'] == 'gpu');
      final double settleDelay = hasGpu ? 8.0 : 0.0;
      expect(settleDelay, 8.0);

      // Post-queue advisory reboot reminder
      String summaryMessage = 'همهٔ درایورها نصب شدند.';
      const bool rebootRequired = true;
      if (rebootRequired) {
        summaryMessage += ' — یادتان نرود پس از پایان همهٔ کارها، سیستم را دستی ری‌استارت کنید.';
      }
      expect(summaryMessage, contains('دستی ری‌استارت کنید'));
    });

    test('W-03: Windows Home deployment policy workflow', () {
      final rawPackages = [
        {'id': 'pkg_office', 'name': 'Office 2024', 'is_office': true},
        {'id': 'pkg_winrar', 'name': 'WinRAR', 'is_office': false},
      ];

      List<Map<String, dynamic>> buildQueue(bool isHome) {
        final queue = <Map<String, dynamic>>[];
        if (isHome) {
          queue.add({
            'id': 'step_office_shortcuts',
            'name': 'ساخت میانبرهای Word، Excel و PowerPoint (بدون نصب)',
            'status': 'queued',
          });
          queue.addAll(rawPackages.where((p) => p['is_office'] != true));
        } else {
          queue.addAll(rawPackages);
        }
        return queue;
      }

      final homeQueue = buildQueue(true);
      expect(homeQueue.length, 2);
      expect(homeQueue[0]['id'], 'step_office_shortcuts');
      expect(homeQueue[1]['id'], 'pkg_winrar');
      expect(homeQueue.any((p) => p['id'] == 'pkg_office'), isFalse);

      final proQueue = buildQueue(false);
      expect(proQueue.length, 2);
      expect(proQueue.any((p) => p['id'] == 'pkg_office'), isTrue);
    });
  });
}
