import 'package:flutter_test/flutter_test.dart';
import 'package:markazi_system_checker/controllers/driver_install_controller.dart';
import 'package:markazi_system_checker/controllers/software_controller.dart';
import 'package:markazi_system_checker/controllers/theme_language_controller.dart';
import 'package:markazi_system_checker/models/system_info.dart';
import 'package:markazi_system_checker/services/api_service.dart';
import 'package:markazi_system_checker/utils/persian_date_time.dart';

class _FakeBatchApiService extends ApiService {
  BatchInstallStatus status;
  bool fail = false;

  _FakeBatchApiService(this.status);

  @override
  Future<BatchInstallStatus> getBatchInstallStatus() async {
    if (fail) throw StateError('temporary backend outage');
    return status;
  }
}

class _FailingPackagesApiService extends ApiService {
  @override
  Future<PackagesResponse> fetchPackages({String? customDir}) async {
    throw StateError('temporary package endpoint outage');
  }
}

class _FakeDriverApiService extends ApiService {
  DriverBatchStatus status;

  _FakeDriverApiService(this.status);

  @override
  Future<DriverBatchStatus> getDriverBatchStatus() async => status;
}

void main() {
  test('seventh sidebar destination opens application settings', () {
    final controller = ThemeLanguageController();
    controller.setNavIndex(6);
    expect(controller.activeNavIndex.value, 6);
    controller.setNavIndex(7);
    expect(controller.activeNavIndex.value, 6);
  });

  test('Gregorian new year converts to Jalali new year', () {
    final value = gregorianToJalali(DateTime(2024, 3, 20));
    expect((value.year, value.month, value.day), (1403, 1, 1));
    expect(
      formatPersianDateTime(DateTime(2024, 3, 20, 9, 5)),
      contains('۱۴۰۳'),
    );
  });

  test('select all toggles the same selectable set on and off', () {
    expect(toggledSelectAll({}, {'a', 'b'}), {'a', 'b'});
    expect(toggledSelectAll({'a', 'b'}, {'a', 'b'}), isEmpty);
    expect(toggledSelectAll({'a'}, {'a', 'b'}), {'a', 'b'});
  });

  test(
    'software selection is controller-owned and toggles without page state',
    () {
      expect(toggledSoftwareSelection({}, {'app-a', 'app-b'}), {
        'app-a',
        'app-b',
      });
      expect(
        toggledSoftwareSelection({'app-a', 'app-b'}, {'app-a', 'app-b'}),
        isEmpty,
      );

      final controller = SoftwareController();
      controller.togglePackageSelection('app-a');
      expect(controller.selectedPackageIds, contains('app-a'));
      controller.toggleSelectAllPackages({'app-a', 'app-b'});
      expect(controller.selectedPackageIds, containsAll({'app-a', 'app-b'}));
    },
  );

  test(
    'software controller adopts active backend queue and preserves it on outage',
    () async {
      final api = _FakeBatchApiService(
        BatchInstallStatus.fromJson({
          'is_running': true,
          'total': 2,
          'completed': 1,
          'current_item_name': 'App B',
          'items': [
            {'id': 'app-a', 'name': 'App A', 'status': 'completed'},
            {'id': 'app-b', 'name': 'App B', 'status': 'installing'},
          ],
        }),
      );
      final controller = SoftwareController(apiService: api);

      expect(
        await controller.synchronizeBatchInstallState(startPolling: false),
        isTrue,
      );
      expect(controller.isBatchInstalling.value, isTrue);
      expect(controller.batchStatus.value.currentItemName, 'App B');

      api.fail = true;
      expect(
        await controller.synchronizeBatchInstallState(startPolling: false),
        isTrue,
      );
      expect(controller.batchStatus.value.currentItemName, 'App B');
    },
  );

  test(
    'idle refresh preserves KMS choice and queue completion clears it',
    () async {
      final api = _FakeBatchApiService(BatchInstallStatus.empty());
      final controller = SoftwareController(apiService: api);
      controller.includeActivation.value = true;

      await controller.synchronizeBatchInstallState(startPolling: false);
      expect(controller.includeActivation.value, isTrue);

      api.status = BatchInstallStatus.fromJson({
        'is_running': true,
        'include_activation': true,
        'double_speed': true,
        'total': 1,
        'items': [
          {'id': 'fixture', 'name': 'Fixture', 'status': 'installing'},
        ],
      });
      await controller.synchronizeBatchInstallState(startPolling: false);
      expect(controller.includeActivation.value, isTrue);
      expect(controller.doubleSpeed.value, isTrue);

      api.status = BatchInstallStatus.empty();
      await controller.synchronizeBatchInstallState(startPolling: false);
      expect(controller.includeActivation.value, isTrue);
      expect(controller.isBatchInstalling.value, isTrue);

      await controller.synchronizeBatchInstallState(startPolling: false);
      expect(controller.includeActivation.value, isFalse);
      expect(controller.doubleSpeed.value, isTrue);
    },
  );

  test(
    'driver controller ignores one transient empty queue snapshot',
    () async {
      final api = _FakeDriverApiService(
        DriverBatchStatus.fromJson({
          'is_running': true,
          'double_speed': true,
          'total': 2,
          'completed': 0,
          'items': [
            {
              'package_id': 'chipset',
              'display_name': 'Chipset',
              'status': 'installing',
            },
          ],
        }),
      );
      final controller = DriverInstallController(apiService: api);

      expect(await controller.synchronizeDriverBatchState(), isTrue);
      api.status = DriverBatchStatus.empty();
      expect(await controller.synchronizeDriverBatchState(), isTrue);
      expect(controller.batchStatus.value.total, 2);

      expect(await controller.synchronizeDriverBatchState(), isFalse);
    },
  );

  test(
    'failed package refresh preserves list and technician selection',
    () async {
      final controller = SoftwareController(
        apiService: _FailingPackagesApiService(),
      );
      controller.packagesResponse.value = PackagesResponse.fromJson({
        'directory_exists': true,
        'packages_directory': r'H:\PROGRAM',
        'packages': [
          {
            'id': 'vlc',
            'name': 'VLC media player',
            'filename': 'vlc.exe',
            'relative_path': 'vlc.exe',
            'version': '3.0',
            'publisher': 'VideoLAN',
            'is_valid': true,
            'status': 'Not Installed',
            'is_installed': false,
            'installed_version': '',
            'install_allowed': true,
            'has_icon': false,
          },
        ],
        'summary': {'total_packages': 1, 'valid_packages': 1},
      });
      controller.togglePackageSelection('vlc');

      await controller.fetchPackages();

      expect(controller.packages.single.id, 'vlc');
      expect(controller.selectedPackageIds, contains('vlc'));
    },
  );

  test(
    'driver queue status preserves GPU category for safe refresh timing',
    () {
      final status = DriverBatchStatus.fromJson({
        'is_running': true,
        'total': 1,
        'items': [
          {
            'display_name': 'Intel Graphics',
            'category': 'gpu',
            'status': 'installing',
          },
        ],
      });
      expect(status.items.single.category, 'gpu');
    },
  );

  test('Windows 10 and 11 Home editions use the original-home label rule', () {
    WindowsInfo windows(String edition) => WindowsInfo(
      edition: edition,
      version: '',
      build: '',
      architecture: '64-bit',
    );

    expect(windows('Windows 10 Home').isHomeEdition, isTrue);
    expect(windows('Windows 11 Home Single Language').isHomeEdition, isTrue);
    expect(windows('Windows 11 Pro').isHomeEdition, isFalse);
  });

  test('Microsoft Basic Display Adapter is detected from raw GPU name', () {
    final gpu = GpuInfo(
      name: 'Microsoft Graphics Adapter',
      rawName: 'Microsoft Basic Display Adapter',
      manufacturer: 'Microsoft',
      vramDisplay: 'Shared',
      driverVersion: 'Not available',
    );
    expect(gpu.isMicrosoftBasicDisplayAdapter, isTrue);
  });

  test('physical storage keeps mounted usage and volume mapping', () {
    final storage = StorageInfo.fromJson({
      'model': 'Test SSD',
      'type': 'SSD',
      'bus_type': 'NVMe',
      'capacity_display': '477 GB',
      'mounted_capacity_bytes': 500000000000,
      'free_bytes': 125000000000,
      'used_bytes': 375000000000,
      'percent_used': 75.0,
      'volumes': ['C:', 'D:'],
      'serial': 'TEST123',
      'health_status': 'Healthy',
    });

    expect(storage.freeBytes, 125000000000);
    expect(storage.usedBytes, 375000000000);
    expect(storage.percentUsed, 75.0);
    expect(storage.volumes, ['C:', 'D:']);
  });

  test('Office deployment is disabled for Windows 10 and 11 Home', () {
    final office = SoftwarePackage.fromJson({
      'id': 'office_2024_pro_plus',
      'name': 'Microsoft Office 2024 (Pro Plus)',
      'filename': 'Setup_Office 2024.cmd',
      'is_valid': true,
      'is_installed': false,
    });

    expect(
      officeInstallBlockedForWindows(
        office,
        WindowsInfo(
          edition: 'Windows 11 Home',
          version: '23H2',
          build: '22631',
          architecture: '64-bit',
        ),
      ),
      isTrue,
    );
    expect(
      officeInstallBlockedForWindows(
        office,
        WindowsInfo(
          edition: 'Windows 11 Enterprise',
          version: '25H2',
          build: '26200',
          architecture: '64-bit',
        ),
      ),
      isFalse,
    );
  });

  test(
    'Home Office shortcut-only queue step is presented as a prerequisite',
    () {
      final item = BatchInstallItem.fromJson({
        'id': 'step_office_shortcuts',
        'name': 'Office shortcuts',
        'filename': 'Microsoft Office',
        'orchestrator_action': 'office_shortcuts',
        'status': 'queued',
      });

      expect(item.isOrchestrator, isTrue);
      expect(item.stage, 1);
      expect(item.friendlyDescription, contains('بدون نصب Office'));
    },
  );
}
