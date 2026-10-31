import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:markazi_system_checker/controllers/activation_controller.dart';
import 'package:markazi_system_checker/controllers/driver_install_controller.dart';
import 'package:markazi_system_checker/controllers/qc_controller.dart';
import 'package:markazi_system_checker/controllers/software_controller.dart';
import 'package:markazi_system_checker/controllers/system_info_controller.dart';
import 'package:markazi_system_checker/controllers/theme_language_controller.dart';
import 'package:markazi_system_checker/l10n/app_localizations.dart';
import 'package:markazi_system_checker/models/system_info.dart';
import 'package:markazi_system_checker/services/api_service.dart';
import 'package:markazi_system_checker/services/install_state_service.dart';
import 'package:markazi_system_checker/widgets/pages/driver_install_page.dart';
import 'package:markazi_system_checker/widgets/pages/software_install_page.dart';

class _MockLiveUiApiService extends ApiService {
  DriverBatchStatus? mockDriverStatus;
  BatchInstallStatus? mockSoftwareStatus;

  @override
  Future<DriverBatchStatus> getDriverBatchStatus() async {
    return mockDriverStatus ?? DriverBatchStatus.empty();
  }

  @override
  Future<BatchInstallStatus> getBatchInstallStatus() async {
    return mockSoftwareStatus ?? BatchInstallStatus.empty();
  }

  @override
  Future<Map<String, dynamic>> getDriverDirectoryConfig() async {
    return {
      'configured_path': 'C:\\Drivers',
      'resolved_path': 'C:\\Drivers',
      'removable_sources': [],
    };
  }

  @override
  Future<Map<String, dynamic>> startDriverQueueInstall({
    List<String>? packageIds,
    String? folderPath,
    bool resume = false,
    bool doubleSpeed = false,
  }) async {
    return {
      'success': true,
      'message': 'Driver queue started',
      'total': packageIds?.length ?? 0,
      'status': {
        'state_revision': 1,
        'is_running': true,
        'total': packageIds?.length ?? 0,
        'completed': 0,
      },
    };
  }

  @override
  Future<Map<String, dynamic>> startBatchInstall({
    List<String>? packageIds,
    String? customDir,
    bool? includeSystemSetup,
    bool includeActivation = false,
    bool doubleSpeed = false,
  }) async {
    return {
      'success': true,
      'message': 'Software batch started',
      'total': packageIds?.length ?? 0,
      'status': {
        'state_revision': 1,
        'is_running': true,
        'total': packageIds?.length ?? 0,
        'completed': 0,
      },
    };
  }
}

Widget buildTestableWidget(Widget child, {Locale locale = const Locale('fa')}) {
  return GetMaterialApp(
    key: ValueKey(locale.languageCode),
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(body: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockLiveUiApiService mockApi;
  late InstallStateService installService;
  late DriverInstallController driverCtrl;
  late SoftwareController softwareCtrl;

  setUp(() {
    Get.reset();
    mockApi = _MockLiveUiApiService();
    installService = InstallStateService(
      apiService: mockApi,
      autoStartPolling: false,
    );
    Get.put<InstallStateService>(installService, permanent: true);
    Get.put(ThemeLanguageController());
    Get.put(SystemInfoController());
    softwareCtrl = Get.put(SoftwareController(apiService: mockApi));
    driverCtrl = Get.put(DriverInstallController(apiService: mockApi));
    Get.put(ActivationController());
    Get.put(QcController());
  });

  tearDown(() {
    installService.stopPolling();
    Get.reset();
  });

  group('Live Item UI & Auto-Install Stability Widget Tests (Task 2 / R3)', () {
    testWidgets('1. Auto-install button running state stability & local start intent', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final pkg1 = IntelligentDriverPackage(
        packageId: 'drv_lan',
        displayName: 'Realtek Gigabit Ethernet',
        category: 'lan',
        categoryFa: 'شبکه کابلی',
        packageType: 'folder',
        sourcePath: 'C:\\Drivers\\LAN',
        relativePath: 'LAN',
        installerFile: 'setup.exe',
        installMethod: 'direct_exe',
        fingerprint: 'fp_lan',
        match: DriverHardwareMatch(
          isMatched: true,
          confidence: 'HIGH',
          status: 'needs_install',
          statusFa: 'نیاز به نصب',
          statusEn: 'Needs Install',
          matchedDeviceName: 'Realtek PCIe GbE',
          matchedDeviceId: 'PCI\\VEN_10EC&DEV_8168',
          installedVersion: '',
          packageVersion: '10.050',
          recommendation: 'install',
          reasons: ['Hardware match'],
        ),
      );

      final pkg2 = IntelligentDriverPackage(
        packageId: 'drv_wifi',
        displayName: 'Intel Wi-Fi 6 AX201',
        category: 'wifi',
        categoryFa: 'شبکه بی‌سیم',
        packageType: 'folder',
        sourcePath: 'C:\\Drivers\\WIFI',
        relativePath: 'WIFI',
        installerFile: 'setup.exe',
        installMethod: 'direct_exe',
        fingerprint: 'fp_wifi',
        match: DriverHardwareMatch(
          isMatched: true,
          confidence: 'HIGH',
          status: 'needs_install',
          statusFa: 'نیاز به نصب',
          statusEn: 'Needs Install',
          matchedDeviceName: 'Intel Wi-Fi 6',
          matchedDeviceId: 'PCI\\VEN_8086&DEV_06F0',
          installedVersion: '',
          packageVersion: '22.40',
          recommendation: 'install',
          reasons: ['Hardware match'],
        ),
      );

      driverCtrl.scanResult.value = DriverScanResult(
        success: true,
        message: 'Scan OK',
        driverDirectory: 'C:\\Drivers',
        totalPackages: 2,
        packages: [pkg1, pkg2],
      );
      driverCtrl.selectedPackageIds.addAll(['drv_lan', 'drv_wifi']);

      await tester.pumpWidget(buildTestableWidget(const DriverInstallPage()));
      await tester.pump();

      final autoInstallBtn = find.byKey(const ValueKey('driver-auto-install-button'));
      expect(autoInstallBtn, findsOneWidget);
      expect(find.text('نصب خودکار همه (2)'), findsOneWidget);

      // User clicks "نصب خودکار"
      await tester.tap(autoInstallBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify immediate transition to running state
      expect(driverCtrl.isBatchRunning.value, isTrue);
      expect(find.text('در حال نصب (0/2)'), findsOneWidget);
      expect(find.byKey(const ValueKey('driver-auto-install-button')), findsOneWidget);

      // Adversarial test: backend returns an idle snapshot before bumping revision
      final staleIdleFrame = DriverBatchStatus(
        stateRevision: 0,
        isRunning: false,
        total: 0,
        completed: 0,
      );
      installService.applyDriverStatus(staleIdleFrame);
      await tester.pump();

      // Verify that local start intent prevents flickering back to idle
      expect(driverCtrl.isBatchRunning.value, isTrue,
          reason: 'Start intent must keep button in running state during pre-start latency');
      expect(find.text('در حال نصب (0/2)'), findsOneWidget);

      // Backend advances to active execution (revision 1)
      final runningFrame = DriverBatchStatus(
        stateRevision: 1,
        isRunning: true,
        total: 2,
        completed: 1,
        items: [
          DriverInstallItem(packageId: 'drv_lan', displayName: 'Realtek Gigabit Ethernet', status: 'completed'),
          DriverInstallItem(packageId: 'drv_wifi', displayName: 'Intel Wi-Fi 6 AX201', status: 'installing'),
        ],
      );
      installService.applyDriverStatus(runningFrame);
      await tester.pump();

      // Verify running state display updates
      expect(find.text('در حال نصب (1/2)'), findsOneWidget);

      // Queue completes (revision 2)
      final completedFrame = DriverBatchStatus(
        stateRevision: 2,
        isRunning: false,
        total: 2,
        completed: 2,
        items: [
          DriverInstallItem(packageId: 'drv_lan', displayName: 'Realtek Gigabit Ethernet', status: 'completed'),
          DriverInstallItem(packageId: 'drv_wifi', displayName: 'Intel Wi-Fi 6 AX201', status: 'completed'),
        ],
      );
      installService.applyDriverStatus(completedFrame);
      await tester.pump();

      // Verify queue finished cleanly
      expect(driverCtrl.isBatchRunning.value, isFalse);
    });

    testWidgets('2. Per-driver completion checkmark transitions immediately from spinner to green checkmark', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final pkgLan = IntelligentDriverPackage(
        packageId: 'drv_lan',
        displayName: 'Realtek Gigabit Ethernet',
        category: 'lan',
        categoryFa: 'شبکه کابلی',
        packageType: 'folder',
        sourcePath: 'C:\\Drivers\\LAN',
        relativePath: 'LAN',
        installerFile: 'setup.exe',
        installMethod: 'direct_exe',
        fingerprint: 'fp_lan',
        match: DriverHardwareMatch(
          isMatched: true,
          confidence: 'HIGH',
          status: 'needs_install',
          statusFa: 'نیاز به نصب',
          statusEn: 'Needs Install',
          matchedDeviceName: 'Realtek PCIe GbE',
          matchedDeviceId: 'PCI\\VEN_10EC&DEV_8168',
          installedVersion: '',
          packageVersion: '10.050',
          recommendation: 'install',
          reasons: ['Hardware match'],
        ),
      );

      final pkgWifi = IntelligentDriverPackage(
        packageId: 'drv_wifi',
        displayName: 'Intel Wi-Fi 6 AX201',
        category: 'wifi',
        categoryFa: 'شبکه بی‌سیم',
        packageType: 'folder',
        sourcePath: 'C:\\Drivers\\WIFI',
        relativePath: 'WIFI',
        installerFile: 'install.exe',
        installMethod: 'direct_exe',
        fingerprint: 'fp_wifi',
        match: DriverHardwareMatch(
          isMatched: true,
          confidence: 'HIGH',
          status: 'needs_install',
          statusFa: 'نیاز به نصب',
          statusEn: 'Needs Install',
          matchedDeviceName: 'Intel Wi-Fi 6',
          matchedDeviceId: 'PCI\\VEN_8086&DEV_06F0',
          installedVersion: '',
          packageVersion: '22.40',
          recommendation: 'install',
          reasons: ['Hardware match'],
        ),
      );

      driverCtrl.scanResult.value = DriverScanResult(
        success: true,
        message: 'Scan OK',
        driverDirectory: 'C:\\Drivers',
        totalPackages: 2,
        packages: [pkgLan, pkgWifi],
      );
      driverCtrl.selectedPackageIds.addAll(['drv_lan', 'drv_wifi']);

      await tester.pumpWidget(buildTestableWidget(const DriverInstallPage()));
      await tester.pump();

      final lanCardFinder = find.byKey(const ValueKey('driver-package-drv_lan'));
      final wifiCardFinder = find.byKey(const ValueKey('driver-package-drv_wifi'));
      expect(lanCardFinder, findsOneWidget);
      expect(wifiCardFinder, findsOneWidget);

      // Phase A: drv_lan is installing, drv_wifi is pending
      installService.applyDriverStatus(DriverBatchStatus(
        stateRevision: 10,
        isRunning: true,
        total: 2,
        completed: 0,
        items: [
          DriverInstallItem(packageId: 'drv_lan', displayName: 'Realtek Gigabit Ethernet', status: 'installing'),
          DriverInstallItem(packageId: 'drv_wifi', displayName: 'Intel Wi-Fi 6 AX201', status: 'pending'),
        ],
      ));
      await tester.pump();

      // Verify drv_lan card shows installing spinner and NOT the checkmark
      expect(
        find.descendant(of: lanCardFinder, matching: find.byKey(const ValueKey('driver-installing-spinner'))),
        findsOneWidget,
      );
      expect(
        find.descendant(of: lanCardFinder, matching: find.byKey(const ValueKey('driver-completed-checkmark'))),
        findsNothing,
      );

      // Verify drv_wifi card shows pending schedule icon
      expect(
        find.descendant(of: wifiCardFinder, matching: find.byKey(const ValueKey('driver-pending-icon'))),
        findsOneWidget,
      );

      // Phase B: drv_lan completes! drv_wifi starts installing
      installService.applyDriverStatus(DriverBatchStatus(
        stateRevision: 11,
        isRunning: true,
        total: 2,
        completed: 1,
        items: [
          DriverInstallItem(packageId: 'drv_lan', displayName: 'Realtek Gigabit Ethernet', status: 'completed'),
          DriverInstallItem(packageId: 'drv_wifi', displayName: 'Intel Wi-Fi 6 AX201', status: 'installing'),
        ],
      ));
      await tester.pump();

      // VERIFICATION: drv_lan card MUST immediately display the green checkmark
      final checkmarkFinder = find.descendant(
        of: lanCardFinder,
        matching: find.byKey(const ValueKey('driver-completed-checkmark')),
      );
      expect(checkmarkFinder, findsOneWidget,
          reason: 'Completed driver must immediately display green checkmark instead of loading spinner');

      final iconWidget = tester.widget<Icon>(checkmarkFinder);
      expect(iconWidget.color, const Color(0xFF10B981),
          reason: 'Checkmark must use the official green status color');

      // Verify drv_wifi is now installing (shows spinner)
      expect(
        find.descendant(of: wifiCardFinder, matching: find.byKey(const ValueKey('driver-installing-spinner'))),
        findsOneWidget,
      );

      // Verify in-memory package status was updated in DriverInstallController
      final updatedPkgLan = driverCtrl.scanResult.value.packages.firstWhere((p) => p.packageId == 'drv_lan');
      expect(updatedPkgLan.match?.status, 'up_to_date',
          reason: 'DriverInstallController must update in-memory package match to up_to_date');

      // Phase C: drv_wifi also completes
      installService.applyDriverStatus(DriverBatchStatus(
        stateRevision: 12,
        isRunning: false,
        total: 2,
        completed: 2,
        items: [
          DriverInstallItem(packageId: 'drv_lan', displayName: 'Realtek Gigabit Ethernet', status: 'completed'),
          DriverInstallItem(packageId: 'drv_wifi', displayName: 'Intel Wi-Fi 6 AX201', status: 'completed'),
        ],
      ));
      await tester.pump();

      // Both cards show green checkmark
      expect(find.byKey(const ValueKey('driver-completed-checkmark')), findsNWidgets(2));
    });

    testWidgets('3. Package-to-item matching succeeds across packageId, displayName, and normalized installerFile', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final pkg = IntelligentDriverPackage(
        packageId: 'drv_touchpad',
        displayName: 'Synaptics Pointing Device',
        category: 'touchpad',
        categoryFa: 'تاچ‌پد',
        packageType: 'folder',
        sourcePath: 'C:\\Drivers\\Touchpad',
        relativePath: 'Touchpad',
        installerFile: 'bin\\setup.exe',
        installMethod: 'direct_exe',
        fingerprint: 'fp_tp',
      );

      driverCtrl.scanResult.value = DriverScanResult(
        success: true,
        message: 'Scan OK',
        driverDirectory: 'C:\\Drivers',
        totalPackages: 1,
        packages: [pkg],
      );

      await tester.pumpWidget(buildTestableWidget(const DriverInstallPage()));
      await tester.pump();

      final cardFinder = find.byKey(const ValueKey('driver-package-drv_touchpad'));
      expect(cardFinder, findsOneWidget);

      // Match via installerFile filename fallback when packageId and displayName are omitted
      installService.applyDriverStatus(DriverBatchStatus(
        stateRevision: 15,
        isRunning: true,
        total: 1,
        completed: 1,
        items: [
          DriverInstallItem(
            filename: 'setup.exe',
            installerFile: 'setup.exe',
            status: 'completed',
          ),
        ],
      ));
      await tester.pump();

      // Card correctly matched item and rendered green checkmark
      expect(
        find.descendant(of: cardFinder, matching: find.byKey(const ValueKey('driver-completed-checkmark'))),
        findsOneWidget,
      );
    });

    testWidgets('4. Software auto-install button running state stability & local start intent', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final pkgWinrar = SoftwarePackage(
        id: 'pkg_winrar',
        name: 'WinRAR',
        filename: 'WinRAR.exe',
        relativePath: 'WinRAR.exe',
        version: '7.01',
        publisher: 'RARLab',
        isValid: true,
        status: 'ready',
        isInstalled: false,
        installedVersion: '',
        installAllowed: true,
        hasIcon: false,
        autoInstallSupported: true,
        fileSizeDisplay: '5 MB',
      );

      softwareCtrl.packagesResponse.value = PackagesResponse(
        packagesDirectory: 'C:\\Soft',
        packages: [pkgWinrar],
        summary: PackageSummary(
          totalPackages: 1,
          validPackages: 1,
          installedPackages: 0,
          availableToInstall: 1,
        ),
      );
      softwareCtrl.selectedPackageIds.add('pkg_winrar');

      await tester.pumpWidget(buildTestableWidget(const SoftwareInstallPage()));
      await tester.pump();

      final autoInstallBtn = find.byKey(const ValueKey('software-auto-install-button'));
      expect(autoInstallBtn, findsOneWidget);
      expect(find.text('نصب خودکار (1)'), findsOneWidget);

      // Tap software auto install
      await tester.tap(autoInstallBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Immediate transition to running state
      expect(softwareCtrl.isBatchInstalling.value, isTrue);
      expect(find.text('در حال نصب (0/1)'), findsOneWidget);

      // Idle frame during pre-start latency is ignored by start intent
      installService.applySoftwareStatus(BatchInstallStatus(
        stateRevision: 0,
        isRunning: false,
        total: 0,
        completed: 0,
      ));
      await tester.pump();

      expect(softwareCtrl.isBatchInstalling.value, isTrue);
      expect(find.text('در حال نصب (0/1)'), findsOneWidget);

      // Backend acknowledges running state
      installService.applySoftwareStatus(BatchInstallStatus(
        stateRevision: 2,
        isRunning: true,
        total: 1,
        completed: 0,
        items: [
          BatchInstallItem(id: 'pkg_winrar', name: 'WinRAR', status: 'installing'),
        ],
      ));
      await tester.pump();

      expect(find.text('در حال نصب (0/1)'), findsOneWidget);

      // Software completes
      installService.applySoftwareStatus(BatchInstallStatus(
        stateRevision: 3,
        isRunning: false,
        total: 1,
        completed: 1,
        items: [
          BatchInstallItem(id: 'pkg_winrar', name: 'WinRAR', status: 'completed'),
        ],
      ));
      await tester.pump();

      expect(softwareCtrl.isBatchInstalling.value, isFalse);
    });

    testWidgets('5. Network resilience notice appears only after >= 3 consecutive errors and clears on success', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableWidget(const DriverInstallPage()));
      await tester.pump();

      final noticeFinder = find.byKey(const ValueKey('disconnection-notice-banner'));

      // Error 1: notice should NOT appear
      installService.handleDriverNetworkFailure(Exception('Network error 1'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(noticeFinder, findsNothing);

      // Error 2: notice should still NOT appear
      installService.handleDriverNetworkFailure(Exception('Network error 2'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(noticeFinder, findsNothing);

      // Error 3: notice MUST appear
      installService.handleDriverNetworkFailure(Exception('Network error 3'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(noticeFinder, findsOneWidget);
      expect(find.text('اتصال به سرویس قطع شد؛ در حال تلاش مجدد'), findsOneWidget);

      // Recovery: single successful frame clears the notice
      installService.applyDriverStatus(DriverBatchStatus(
        stateRevision: 1,
        isRunning: false,
        total: 0,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(noticeFinder, findsNothing,
          reason: 'Successful frame must immediately dismiss disconnection banner');
    });
  });
}
