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

class _AdversarialMockApiService extends ApiService {
  DriverBatchStatus? mockDriverStatus;
  BatchInstallStatus? mockSoftwareStatus;
  int driverStartCallCount = 0;
  int softwareStartCallCount = 0;

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
    driverStartCallCount++;
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
    softwareStartCallCount++;
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

Widget buildTestWidget(Widget child, {Locale locale = const Locale('fa')}) {
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

  late _AdversarialMockApiService mockApi;
  late InstallStateService installService;

  setUp(() {
    Get.reset();
    mockApi = _AdversarialMockApiService();
    installService = InstallStateService(
      apiService: mockApi,
      autoStartPolling: false,
    );
    Get.put<InstallStateService>(installService, permanent: true);
    Get.put(ThemeLanguageController());
    Get.put(SystemInfoController());
    Get.put(SoftwareController(apiService: mockApi));
    Get.put(DriverInstallController(apiService: mockApi));
    Get.put(ActivationController());
    Get.put(QcController());
  });

  tearDown(() {
    installService.stopPolling();
    Get.reset();
  });

  group('Adversarial Challenge 1: State Monotonicity & Invariants Stress Harness', () {
    test('1.1 Out-of-order revision chaotic stream rejects all regressions without state corruption', () {
      // Feed revisions in chaotic order: 10 -> 8 -> 9 -> 12 -> 11 -> 15 -> 14 -> 15
      final rev10 = DriverBatchStatus(stateRevision: 10, isRunning: true, total: 5, completed: 1, startTime: 100.0);
      expect(installService.applyDriverStatus(rev10), isTrue);
      expect(installService.latestDriverRevision, 10);
      expect(installService.driverStatus.value.completed, 1);

      // Stale regression 8
      final rev8 = DriverBatchStatus(stateRevision: 8, isRunning: true, total: 5, completed: 0, startTime: 100.0);
      expect(installService.applyDriverStatus(rev8), isFalse, reason: 'Revision 8 < 10 must be rejected');
      expect(installService.latestDriverRevision, 10);
      expect(installService.driverStatus.value.completed, 1);

      // Stale regression 9
      final rev9 = DriverBatchStatus(stateRevision: 9, isRunning: true, total: 5, completed: 0, startTime: 100.0);
      expect(installService.applyDriverStatus(rev9), isFalse, reason: 'Revision 9 < 10 must be rejected');
      expect(installService.latestDriverRevision, 10);

      // Monotonic advance 12
      final rev12 = DriverBatchStatus(stateRevision: 12, isRunning: true, total: 5, completed: 2, startTime: 100.0);
      expect(installService.applyDriverStatus(rev12), isTrue);
      expect(installService.latestDriverRevision, 12);
      expect(installService.driverStatus.value.completed, 2);

      // Stale regression 11
      final rev11 = DriverBatchStatus(stateRevision: 11, isRunning: true, total: 5, completed: 1, startTime: 100.0);
      expect(installService.applyDriverStatus(rev11), isFalse, reason: 'Revision 11 < 12 must be rejected');
      expect(installService.latestDriverRevision, 12);
      expect(installService.driverStatus.value.completed, 2);

      // Monotonic advance 15
      final rev15 = DriverBatchStatus(stateRevision: 15, isRunning: true, total: 5, completed: 3, startTime: 100.0);
      expect(installService.applyDriverStatus(rev15), isTrue);
      expect(installService.latestDriverRevision, 15);
      expect(installService.driverStatus.value.completed, 3);

      // Stale regression 14
      final rev14 = DriverBatchStatus(stateRevision: 14, isRunning: true, total: 5, completed: 2, startTime: 100.0);
      expect(installService.applyDriverStatus(rev14), isFalse, reason: 'Revision 14 < 15 must be rejected');
      expect(installService.latestDriverRevision, 15);

      // Identical revision 15 is accepted (idempotent status update)
      final rev15b = DriverBatchStatus(stateRevision: 15, isRunning: true, total: 5, completed: 3, startTime: 100.0);
      expect(installService.applyDriverStatus(rev15b), isTrue);
      expect(installService.latestDriverRevision, 15);
    });

    test('1.2 Empty frames NEVER reset monotonic baseline revision', () {
      final activeFrame = DriverBatchStatus(
        stateRevision: 42,
        isRunning: true,
        total: 4,
        completed: 4,
        startTime: 200.0,
      );
      expect(installService.applyDriverStatus(activeFrame), isTrue);
      expect(installService.latestDriverRevision, 42);

      // First empty frame while running is dropped by two-empty-snapshots guard
      final empty1 = DriverBatchStatus(stateRevision: 43, isRunning: false, total: 0, completed: 0, startTime: 200.0);
      expect(installService.applyDriverStatus(empty1), isFalse);
      expect(installService.latestDriverRevision, 42, reason: 'Baseline preserved on dropped transient empty');

      // Second consecutive empty frame confirms idle
      final empty2 = DriverBatchStatus(stateRevision: 44, isRunning: false, total: 0, completed: 0, startTime: 200.0);
      expect(installService.applyDriverStatus(empty2), isTrue);
      expect(installService.latestDriverRevision, 44, reason: 'Baseline advanced to 44, NEVER zeroed to 0!');

      // Critical assertion: an old revision (e.g. 30) arriving later MUST be rejected, proving baseline is NOT 0
      final lateStale = DriverBatchStatus(stateRevision: 30, isRunning: true, total: 1, completed: 0, startTime: 200.0);
      expect(installService.applyDriverStatus(lateStale), isFalse,
          reason: 'Monotonic baseline was preserved; frame with revision 30 < 44 must be rejected');
    });

    test('1.3 Baseline resets ONLY on boot_id change or startTime change', () {
      // Initial session
      final initFrame = DriverBatchStatus(
        stateRevision: 99,
        isRunning: true,
        total: 2,
        completed: 1,
        bootId: 'boot_uuid_original',
        startTime: 500.0,
      );
      expect(installService.applyDriverStatus(initFrame), isTrue);
      expect(installService.latestDriverRevision, 99);
      expect(installService.latestDriverBootId, 'boot_uuid_original');

      // 1. Same bootId, same startTime -> lower revision is rejected
      final staleInSession = DriverBatchStatus(
        stateRevision: 5,
        isRunning: true,
        total: 1,
        bootId: 'boot_uuid_original',
        startTime: 500.0,
      );
      expect(installService.applyDriverStatus(staleInSession), isFalse);

      // 2. Different bootId (backend crash/restart) -> baseline resets to 0, accepts revision 1!
      final restartedFrame = DriverBatchStatus(
        stateRevision: 1,
        isRunning: true,
        total: 1,
        bootId: 'boot_uuid_restarted',
        startTime: 600.0,
      );
      expect(installService.applyDriverStatus(restartedFrame), isTrue,
          reason: 'Boot ID change MUST reset baseline and accept revision 1');
      expect(installService.latestDriverRevision, 1);
      expect(installService.latestDriverBootId, 'boot_uuid_restarted');

      // 3. Same bootId, but new deployment session (different startTime) -> baseline resets to 0!
      final advanceFrame = DriverBatchStatus(
        stateRevision: 50,
        isRunning: false,
        total: 1,
        completed: 1,
        bootId: 'boot_uuid_restarted',
        startTime: 600.0,
      );
      expect(installService.applyDriverStatus(advanceFrame), isTrue);
      expect(installService.latestDriverRevision, 50);

      final newSessionFrame = DriverBatchStatus(
        stateRevision: 1,
        isRunning: true,
        total: 3,
        bootId: 'boot_uuid_restarted',
        startTime: 999.0, // Different startTime
      );
      expect(installService.applyDriverStatus(newSessionFrame), isTrue,
          reason: 'StartTime change MUST reset baseline and accept revision 1 for new session');
      expect(installService.latestDriverRevision, 1);
    });

    test('1.4 Two-Empty-Snapshots guard protects both Driver and Software queues', () {
      // Software queue running
      final swRunning = BatchInstallStatus(
        stateRevision: 10,
        isRunning: true,
        total: 2,
        completed: 1,
        startTime: 100.0,
        items: [
          BatchInstallItem(id: 'app1', name: 'App 1', status: 'completed'),
          BatchInstallItem(id: 'app2', name: 'App 2', status: 'installing'),
        ],
      );
      installService.applySoftwareStatus(swRunning);
      expect(installService.isSoftwareRunning.value, isTrue);

      // Empty snapshot 1 arrives while running
      final swEmpty1 = BatchInstallStatus(
        stateRevision: 11,
        isRunning: false,
        total: 0,
        completed: 0,
        startTime: 100.0,
      );
      final accepted1 = installService.applySoftwareStatus(swEmpty1);
      expect(accepted1, isFalse, reason: 'First empty frame during running must be dropped');
      expect(installService.isSoftwareRunning.value, isTrue, reason: 'Running state preserved');
      expect(installService.softwareStatus.value.total, 2, reason: 'Items preserved');

      // Empty snapshot 2 confirms idle
      final swEmpty2 = BatchInstallStatus(
        stateRevision: 12,
        isRunning: false,
        total: 0,
        completed: 0,
        startTime: 100.0,
      );
      final accepted2 = installService.applySoftwareStatus(swEmpty2);
      expect(accepted2, isTrue, reason: 'Second empty frame confirms idle transition');
      expect(installService.isSoftwareRunning.value, isFalse);
    });

    test('1.5 Network resilience: no hopping contamination and instant dismissal on success', () {
      expect(installService.isDisconnected.value, isFalse);

      // Fail driver endpoint twice (count = 2)
      installService.handleDriverNetworkFailure(Exception('Driver fail 1'));
      installService.handleDriverNetworkFailure(Exception('Driver fail 2'));
      expect(installService.consecutiveDriverErrors, 2);
      expect(installService.isDisconnected.value, isFalse, reason: '2 errors < 3 threshold');

      // Fail software endpoint twice (count = 2)
      installService.handleSoftwareNetworkFailure(Exception('Software fail 1'));
      installService.handleSoftwareNetworkFailure(Exception('Software fail 2'));
      expect(installService.consecutiveSoftwareErrors, 2);
      expect(installService.isDisconnected.value, isFalse,
          reason: 'Neither endpoint reached 3 errors; no hopping contamination');

      // 3rd failure on driver endpoint triggers disconnection
      installService.handleDriverNetworkFailure(Exception('Driver fail 3'));
      expect(installService.consecutiveDriverErrors, 3);
      expect(installService.isDisconnected.value, isTrue);
      expect(installService.disconnectionMessage.value, InstallStateService.defaultDisconnectionMessage);

      // Single successful driver frame clears driver count and dismisses banner
      // Software count remains 2 (independent), but since driver is 0 and software is 2 (< 3), banner hides!
      installService.applyDriverStatus(DriverBatchStatus(stateRevision: 1, isRunning: false, total: 0));
      expect(installService.consecutiveDriverErrors, 0);
      expect(installService.consecutiveSoftwareErrors, 2);
      expect(installService.isDisconnected.value, isFalse,
          reason: 'Banner dismissed because neither endpoint is >= 3');
    });

    test('1.6 Strict State Machine Validator enforces terminal immutability & Error 1618 retry', () {
      // Valid forward transitions
      expect(InstallStateService.canTransition('pending', 'installing'), isTrue);
      expect(InstallStateService.canTransition('installing', 'completed'), isTrue);
      expect(InstallStateService.canTransition('installing', 'failed'), isTrue);
      expect(InstallStateService.canTransition('installing', 'skipped'), isTrue);
      expect(InstallStateService.canTransition('installing', 'interrupted'), isTrue);

      // Forbidden backward transitions
      expect(InstallStateService.canTransition('installing', 'pending'), isFalse);
      expect(InstallStateService.canTransition('completed', 'installing'), isFalse);
      expect(InstallStateService.canTransition('completed', 'pending'), isFalse);
      expect(InstallStateService.canTransition('completed', 'failed'), isFalse);
      expect(InstallStateService.canTransition('skipped', 'installing'), isFalse);
      expect(InstallStateService.canTransition('skipped', 'pending'), isFalse);

      // Error 1618 retry allows rollback exclusively to pending
      expect(InstallStateService.canTransition('installing', 'pending', is1618Retry: true), isTrue);
      expect(InstallStateService.canTransition('completed', 'pending', is1618Retry: true), isFalse);

      // User retry allows rollback exclusively from failed or interrupted to pending
      expect(InstallStateService.canTransition('failed', 'pending', isUserRetry: true), isTrue);
      expect(InstallStateService.canTransition('interrupted', 'pending', isUserRetry: true), isTrue);
      expect(InstallStateService.canTransition('completed', 'pending', isUserRetry: true), isFalse);
    });
  });

  group('Adversarial Challenge 2: Live Item UI & Multi-Item Transition Harness', () {
    testWidgets('2.1 Multi-driver queue: button stability and sequential green checkmark transitions (#10B981)', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final ctrl = Get.find<DriverInstallController>();

      final pkg1 = IntelligentDriverPackage(
        packageId: 'drv_chipset',
        displayName: 'Intel Chipset Device Software',
        category: 'chipset',
        categoryFa: 'چیپست',
        packageType: 'folder',
        sourcePath: 'C:\\Drivers\\Chipset',
        relativePath: 'Chipset',
        installerFile: 'SetupChipset.exe',
        installMethod: 'direct_exe',
        fingerprint: 'fp_chipset',
        match: DriverHardwareMatch(
          isMatched: true,
          confidence: 'HIGH',
          status: 'needs_install',
          statusFa: 'نیاز به نصب',
          statusEn: 'Needs Install',
          matchedDeviceName: 'Intel Chipset',
          matchedDeviceId: 'PCI\\VEN_8086&DEV_A000',
          installedVersion: '',
          packageVersion: '10.1.18',
          recommendation: 'install',
          reasons: ['Hardware match'],
        ),
      );

      final pkg2 = IntelligentDriverPackage(
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

      final pkg3 = IntelligentDriverPackage(
        packageId: 'drv_audio',
        displayName: 'Realtek High Definition Audio',
        category: 'audio',
        categoryFa: 'کارت صدا',
        packageType: 'folder',
        sourcePath: 'C:\\Drivers\\Audio',
        relativePath: 'Audio',
        installerFile: 'SetupAudio.exe',
        installMethod: 'direct_exe',
        fingerprint: 'fp_audio',
        match: DriverHardwareMatch(
          isMatched: true,
          confidence: 'HIGH',
          status: 'needs_install',
          statusFa: 'نیاز به نصب',
          statusEn: 'Needs Install',
          matchedDeviceName: 'Realtek Audio',
          matchedDeviceId: 'HDAUDIO\\FUNC_01&VEN_10EC',
          installedVersion: '',
          packageVersion: '6.0.9000',
          recommendation: 'install',
          reasons: ['Hardware match'],
        ),
      );

      ctrl.scanResult.value = DriverScanResult(
        success: true,
        message: 'Scan OK',
        driverDirectory: 'C:\\Drivers',
        totalPackages: 3,
        packages: [pkg1, pkg2, pkg3],
      );
      ctrl.selectedPackageIds.addAll(['drv_chipset', 'drv_lan', 'drv_audio']);

      await tester.pumpWidget(buildTestWidget(const DriverInstallPage()));
      await tester.pump();

      final autoInstallBtn = find.byKey(const ValueKey('driver-auto-install-button'));
      expect(autoInstallBtn, findsOneWidget);
      expect(find.text('نصب خودکار همه (3)'), findsOneWidget);

      // 1. Click auto install
      await tester.tap(autoInstallBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verifying stable running state on button
      expect(ctrl.isBatchRunning.value, isTrue);
      expect(find.text('در حال نصب (0/3)'), findsOneWidget);

      // Stale idle frame arrives during HTTP latency -> Local start intent MUST ignore it!
      final stalePreStart = DriverBatchStatus(stateRevision: 0, isRunning: false, total: 0, completed: 0);
      installService.applyDriverStatus(stalePreStart);
      await tester.pump();

      expect(ctrl.isBatchRunning.value, isTrue, reason: 'Start intent must prevent button flicker');
      expect(find.text('در حال نصب (0/3)'), findsOneWidget);

      // 2. Stage A: drv_chipset is installing (item 1/3)
      installService.applyDriverStatus(DriverBatchStatus(
        stateRevision: 10,
        isRunning: true,
        total: 3,
        completed: 0,
        items: [
          DriverInstallItem(packageId: 'drv_chipset', displayName: 'Intel Chipset Device Software', status: 'installing'),
          DriverInstallItem(packageId: 'drv_lan', displayName: 'Realtek Gigabit Ethernet', status: 'pending'),
          DriverInstallItem(packageId: 'drv_audio', displayName: 'Realtek High Definition Audio', status: 'pending'),
        ],
      ));
      await tester.pump();

      expect(find.text('در حال نصب (0/3)'), findsOneWidget);
      final chipsetCard = find.byKey(const ValueKey('driver-package-drv_chipset'));
      final lanCard = find.byKey(const ValueKey('driver-package-drv_lan'));
      final audioCard = find.byKey(const ValueKey('driver-package-drv_audio'));

      expect(find.descendant(of: chipsetCard, matching: find.byKey(const ValueKey('driver-installing-spinner'))), findsOneWidget);
      expect(find.descendant(of: chipsetCard, matching: find.byKey(const ValueKey('driver-completed-checkmark'))), findsNothing);
      expect(find.descendant(of: lanCard, matching: find.byKey(const ValueKey('driver-pending-icon'))), findsOneWidget);
      expect(find.descendant(of: audioCard, matching: find.byKey(const ValueKey('driver-pending-icon'))), findsOneWidget);

      // 3. Stage B: drv_chipset completes! drv_lan starts installing (item 2/3)
      installService.applyDriverStatus(DriverBatchStatus(
        stateRevision: 11,
        isRunning: true,
        total: 3,
        completed: 1,
        items: [
          DriverInstallItem(packageId: 'drv_chipset', displayName: 'Intel Chipset Device Software', status: 'completed'),
          DriverInstallItem(packageId: 'drv_lan', displayName: 'Realtek Gigabit Ethernet', status: 'installing'),
          DriverInstallItem(packageId: 'drv_audio', displayName: 'Realtek High Definition Audio', status: 'pending'),
        ],
      ));
      await tester.pump();

      // Button updates to (1/3) stably
      expect(find.text('در حال نصب (1/3)'), findsOneWidget);

      // Chipset card MUST immediately display the green checkmark
      final chipsetCheckmark = find.descendant(of: chipsetCard, matching: find.byKey(const ValueKey('driver-completed-checkmark')));
      expect(chipsetCheckmark, findsOneWidget, reason: 'Completed chipset item MUST immediately display green checkmark');
      final icon1 = tester.widget<Icon>(chipsetCheckmark);
      expect(icon1.icon, Icons.check_circle_rounded);
      expect(icon1.color, const Color(0xFF10B981));

      // LAN card shows installing spinner
      expect(find.descendant(of: lanCard, matching: find.byKey(const ValueKey('driver-installing-spinner'))), findsOneWidget);

      // 4. Stage C: drv_lan completes! drv_audio starts installing (item 3/3)
      installService.applyDriverStatus(DriverBatchStatus(
        stateRevision: 12,
        isRunning: true,
        total: 3,
        completed: 2,
        items: [
          DriverInstallItem(packageId: 'drv_chipset', displayName: 'Intel Chipset Device Software', status: 'completed'),
          DriverInstallItem(packageId: 'drv_lan', displayName: 'Realtek Gigabit Ethernet', status: 'completed'),
          DriverInstallItem(packageId: 'drv_audio', displayName: 'Realtek High Definition Audio', status: 'installing'),
        ],
      ));
      await tester.pump();

      expect(find.text('در حال نصب (2/3)'), findsOneWidget);

      // Chipset & LAN both show green checkmark
      expect(find.descendant(of: chipsetCard, matching: find.byKey(const ValueKey('driver-completed-checkmark'))), findsOneWidget);
      final lanCheckmark = find.descendant(of: lanCard, matching: find.byKey(const ValueKey('driver-completed-checkmark')));
      expect(lanCheckmark, findsOneWidget, reason: 'Completed LAN item MUST immediately display green checkmark');
      final icon2 = tester.widget<Icon>(lanCheckmark);
      expect(icon2.icon, Icons.check_circle_rounded);
      expect(icon2.color, const Color(0xFF10B981));

      // Audio card shows spinner
      expect(find.descendant(of: audioCard, matching: find.byKey(const ValueKey('driver-installing-spinner'))), findsOneWidget);

      // 5. Stage D: drv_audio completes! Entire queue done!
      installService.applyDriverStatus(DriverBatchStatus(
        stateRevision: 13,
        isRunning: false,
        total: 3,
        completed: 3,
        items: [
          DriverInstallItem(packageId: 'drv_chipset', displayName: 'Intel Chipset Device Software', status: 'completed'),
          DriverInstallItem(packageId: 'drv_lan', displayName: 'Realtek Gigabit Ethernet', status: 'completed'),
          DriverInstallItem(packageId: 'drv_audio', displayName: 'Realtek High Definition Audio', status: 'completed'),
        ],
      ));
      await tester.pump();

      // All 3 cards display green checkmark
      expect(find.byKey(const ValueKey('driver-completed-checkmark')), findsNWidgets(3));
      expect(ctrl.isBatchRunning.value, isFalse);
    });
  });
}
