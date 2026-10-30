// frontend/test/fast_auto_install_adversarial_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:markazi_system_checker/controllers/driver_install_controller.dart';
import 'package:markazi_system_checker/controllers/software_controller.dart';
import 'package:markazi_system_checker/controllers/system_info_controller.dart';
import 'package:markazi_system_checker/models/system_info.dart';
import 'package:markazi_system_checker/services/api_service.dart';
import 'package:markazi_system_checker/services/install_state_service.dart';

class _MockAutoInstallApiService extends ApiService {
  List<String>? capturedBatchPackageIds;
  List<String>? capturedDriverPackageIds;
  bool startBatchCalled = false;
  bool startDriverBatchCalled = false;

  @override
  Future<Map<String, dynamic>> startBatchInstall({
    List<String>? packageIds,
    String? customDir,
    bool? includeSystemSetup,
    bool includeActivation = false,
    bool doubleSpeed = false,
  }) async {
    startBatchCalled = true;
    capturedBatchPackageIds = packageIds != null ? List.from(packageIds) : null;
    return {'status': 'started', 'total': packageIds?.length ?? 0};
  }

  @override
  Future<DriverBatchStatus> getDriverBatchStatus() async {
    return DriverBatchStatus.empty();
  }

  @override
  Future<BatchInstallStatus> getBatchInstallStatus() async {
    return BatchInstallStatus.empty();
  }

  @override
  Future<Map<String, dynamic>> startDriverQueueInstall({
    List<String>? packageIds,
    String? folderPath,
    bool resume = false,
    bool doubleSpeed = false,
  }) async {
    startDriverBatchCalled = true;
    capturedDriverPackageIds = packageIds != null ? List.from(packageIds) : null;
    return {
      'success': true,
      'message': 'Driver queue started',
      'total': packageIds?.length ?? 0,
      'status': {'is_running': true, 'total': packageIds?.length ?? 0},
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Get.reset();
  });

  tearDown(() {
    if (Get.isRegistered<SoftwareController>()) {
      Get.find<SoftwareController>().onClose();
    }
    if (Get.isRegistered<DriverInstallController>()) {
      Get.find<DriverInstallController>().onClose();
    }
    if (Get.isRegistered<SystemInfoController>()) {
      Get.find<SystemInfoController>().onClose();
    }
    if (Get.isRegistered<InstallStateService>()) {
      InstallStateService.to.stopPolling();
    }
    Get.reset();
  });

  group('Fast Auto-Installation Queue Empirical Challenge (R5)', () {
    testWidgets('Driver controller bypassConfirmation=true launches immediately without dialog', (tester) async {
      final mockApi = _MockAutoInstallApiService();
      final driverCtrl = Get.put(DriverInstallController(apiService: mockApi));

      driverCtrl.scanResult.value = DriverScanResult.fromJson({
        'success': true,
        'packages': [
          {
            'package_id': 'drv_lan',
            'display_name': 'Realtek PCIe GbE LAN',
            'category': 'lan',
            'category_fa': 'شبکه کابلی',
            'package_type': 'folder',
            'source_path': 'C:\\drivers\\lan',
            'relative_path': 'lan',
            'installer_file': 'Setup.exe',
            'install_method': 'setup_exe',
            'fingerprint': 'lan_hash',
          },
          {
            'package_id': 'drv_audio',
            'display_name': 'Realtek High Definition Audio',
            'category': 'audio',
            'category_fa': 'صدا',
            'package_type': 'folder',
            'source_path': 'C:\\drivers\\audio',
            'relative_path': 'audio',
            'installer_file': 'Setup.exe',
            'install_method': 'setup_exe',
            'fingerprint': 'audio_hash',
          },
        ],
      });

      driverCtrl.selectedPackageIds.assignAll(['drv_lan', 'drv_audio']);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => driverCtrl.installSelectedDrivers(context, bypassConfirmation: true),
                child: const Text('Fast Install'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Fast Install'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Zero AlertDialogs must be present
      expect(find.byType(AlertDialog), findsNothing);
      // Backend driver installation must have been initiated
      expect(mockApi.startDriverBatchCalled, isTrue);
      expect(mockApi.capturedDriverPackageIds, containsAll(['drv_lan', 'drv_audio']));

      driverCtrl.onClose();
      if (Get.isRegistered<InstallStateService>()) {
        InstallStateService.to.stopPolling();
      }
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('Driver controller bypassConfirmation=false presents confirmation modal', (tester) async {
      final mockApi = _MockAutoInstallApiService();
      final driverCtrl = Get.put(DriverInstallController(apiService: mockApi));

      driverCtrl.scanResult.value = DriverScanResult.fromJson({
        'success': true,
        'packages': [
          {
            'package_id': 'drv_wifi',
            'display_name': 'Intel Wi-Fi 6 AX201',
            'category': 'wifi',
            'category_fa': 'شبکه بی‌سیم',
            'package_type': 'folder',
            'source_path': 'C:\\drivers\\wifi',
            'relative_path': 'wifi',
            'installer_file': 'Setup.exe',
            'install_method': 'setup_exe',
            'fingerprint': 'wifi_hash',
          },
        ],
      });

      driverCtrl.selectedPackageIds.assignAll(['drv_wifi']);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => driverCtrl.installSelectedDrivers(context, bypassConfirmation: false),
                child: const Text('Prompt Install'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Prompt Install'));
      await tester.pump();

      // AlertDialog MUST be displayed
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('تأیید نصب درایورهای انتخاب‌شده'), findsOneWidget);
      expect(mockApi.startDriverBatchCalled, isFalse);

      // Confirm dialog
      await tester.tap(find.text('شروع صف نصب (1)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(mockApi.startDriverBatchCalled, isTrue);

      driverCtrl.onClose();
      if (Get.isRegistered<InstallStateService>()) {
        InstallStateService.to.stopPolling();
      }
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('Driver empty selection shows warning snackbar and never starts install', (tester) async {
      final mockApi = _MockAutoInstallApiService();
      final driverCtrl = Get.put(DriverInstallController(apiService: mockApi));
      driverCtrl.selectedPackageIds.clear();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => driverCtrl.installSelectedDrivers(context, bypassConfirmation: true),
                child: const Text('Install Empty'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Install Empty'));
      await tester.pump();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('لطفاً حداقل یک بسته درایور را انتخاب کنید.'), findsOneWidget);
      expect(mockApi.startDriverBatchCalled, isFalse);

      driverCtrl.onClose();
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('Software controller bypassConfirmation=true launches immediately without dialog', (tester) async {
      final mockApi = _MockAutoInstallApiService();
      final swCtrl = Get.put(SoftwareController(apiService: mockApi));

      swCtrl.packages.assignAll([
        SoftwarePackage.fromJson({
          'id': 'pkg_winrar',
          'name': 'WinRAR',
          'is_valid': true,
          'is_installed': false,
          'is_duplicate': false,
          'category': 'utility',
          'weight_tier': 1,
        }),
        SoftwarePackage.fromJson({
          'id': 'pkg_chrome',
          'name': 'Google Chrome',
          'is_valid': true,
          'is_installed': false,
          'is_duplicate': false,
          'category': 'heavyweight',
          'weight_tier': 3,
        }),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => swCtrl.startAutoInstallAll(
                  context,
                  targetPackageIds: ['pkg_winrar', 'pkg_chrome'],
                  bypassConfirmation: true,
                ),
                child: const Text('Fast SW Install'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Fast SW Install'));
      await tester.pumpAndSettle();

      // Zero AlertDialogs must be present
      expect(find.byType(AlertDialog), findsNothing);
      expect(mockApi.startBatchCalled, isTrue);
      expect(mockApi.capturedBatchPackageIds, equals(['pkg_winrar', 'pkg_chrome']));

      swCtrl.onClose();
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('Software controller bypassConfirmation=false presents confirmation dialog', (tester) async {
      final mockApi = _MockAutoInstallApiService();
      final swCtrl = Get.put(SoftwareController(apiService: mockApi));

      swCtrl.packages.assignAll([
        SoftwarePackage.fromJson({
          'id': 'pkg_vlc',
          'name': 'VLC Media Player',
          'is_valid': true,
          'is_installed': false,
          'is_duplicate': false,
          'category': 'utility',
          'weight_tier': 1,
        }),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => swCtrl.startAutoInstallAll(
                  context,
                  targetPackageIds: ['pkg_vlc'],
                  bypassConfirmation: false,
                ),
                child: const Text('Prompt SW Install'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Prompt SW Install'));
      await tester.pump();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('نصب خودکار نرم‌افزارها'), findsOneWidget);
      expect(mockApi.startBatchCalled, isFalse);

      await tester.tap(find.text('شروع نصب خودکار'));
      await tester.pumpAndSettle();

      expect(mockApi.startBatchCalled, isTrue);
      expect(mockApi.capturedBatchPackageIds, equals(['pkg_vlc']));

      swCtrl.onClose();
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('Software controller strictly enforces Windows Home Office blocking invariant', (tester) async {
      final mockApi = _MockAutoInstallApiService();
      final swCtrl = Get.put(SoftwareController(apiService: mockApi));

      // Simulate Windows Home Edition in SystemInfoController
      final sysInfoCtrl = Get.put(SystemInfoController());
      sysInfoCtrl.systemInfo.value = SystemInfo.fromJson({
        'windows': {
          'edition': 'Windows 11 Home',
          'caption': 'Windows 11 Home Single Language',
          'version': '10.0.22631',
          'build_number': '22631',
        },
      });

      final officePkg = SoftwarePackage.fromJson({
        'id': 'pkg_office',
        'name': 'Microsoft Office 2024',
        'is_valid': true,
        'is_installed': false,
        'is_duplicate': false,
        'category': 'office',
        'weight_tier': 4,
        'installer_path': 'C:\\soft\\Setup_Office 2024.cmd',
      });

      final utilPkg = SoftwarePackage.fromJson({
        'id': 'pkg_7zip',
        'name': '7-Zip',
        'is_valid': true,
        'is_installed': false,
        'is_duplicate': false,
        'category': 'utility',
        'weight_tier': 1,
      });

      swCtrl.packages.assignAll([officePkg, utilPkg]);

      // Direct method verification
      expect(swCtrl.isOfficeBlockedOnHome(officePkg), isTrue);
      expect(swCtrl.isOfficeBlockedOnHome(utilPkg), isFalse);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => swCtrl.startAutoInstallAll(
                  context,
                  bypassConfirmation: true,
                ),
                child: const Text('Auto Install Home'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Auto Install Home'));
      await tester.pumpAndSettle();

      // Invariant: Office must be strictly EXCLUDED from batch installation on Windows Home
      expect(mockApi.startBatchCalled, isTrue);
      expect(mockApi.capturedBatchPackageIds, equals(['pkg_7zip']));
      expect(mockApi.capturedBatchPackageIds, isNot(contains('pkg_office')));

      sysInfoCtrl.onClose();
      swCtrl.onClose();
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
