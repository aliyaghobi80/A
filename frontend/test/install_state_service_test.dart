import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:markazi_system_checker/controllers/driver_install_controller.dart';
import 'package:markazi_system_checker/models/system_info.dart';
import 'package:markazi_system_checker/services/api_service.dart';
import 'package:markazi_system_checker/services/install_state_service.dart';

class _MockStateApiService extends ApiService {
  DriverBatchStatus? nextDriverStatus;
  BatchInstallStatus? nextSoftwareStatus;
  Object? driverError;
  Object? softwareError;
  int driverPollCount = 0;
  int softwarePollCount = 0;

  @override
  Future<DriverBatchStatus> getDriverBatchStatus() async {
    driverPollCount++;
    if (driverError != null) {
      throw driverError!;
    }
    return nextDriverStatus ?? DriverBatchStatus.empty();
  }

  @override
  Future<BatchInstallStatus> getBatchInstallStatus() async {
    softwarePollCount++;
    if (softwareError != null) {
      throw softwareError!;
    }
    return nextSoftwareStatus ?? BatchInstallStatus.empty();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockStateApiService mockApi;
  late InstallStateService service;

  setUp(() {
    Get.reset();
    mockApi = _MockStateApiService();
    service = InstallStateService(
      apiService: mockApi,
      autoStartPolling: false,
    );
    Get.put<InstallStateService>(service, permanent: true);
  });

  tearDown(() {
    service.stopPolling();
    Get.reset();
  });

  group('InstallStateService Architecture & Invariant Tests (Task 2 / R3)', () {
    test('1. Monotonic frame acceptance drops stale revision frames and preserves state', () {
      final initialFrame = DriverBatchStatus(
        stateRevision: 10,
        isRunning: true,
        total: 3,
        completed: 1,
        startTime: 1000.0,
        items: [
          DriverInstallItem(filename: 'chipset.exe', status: 'completed'),
          DriverInstallItem(filename: 'lan.exe', status: 'installing'),
          DriverInstallItem(filename: 'wifi.exe', status: 'pending'),
        ],
      );

      final accepted = service.applyDriverStatus(initialFrame);
      expect(accepted, isTrue);
      expect(service.latestDriverRevision, 10);
      expect(service.driverStatus.value.completed, 1);
      expect(service.isDriverRunning.value, isTrue);

      // Incoming stale frame with revision 8 (e.g. from an out-of-order in-flight poll)
      final staleFrame = DriverBatchStatus(
        stateRevision: 8,
        isRunning: true,
        total: 3,
        completed: 0,
        startTime: 1000.0,
        items: [
          DriverInstallItem(filename: 'chipset.exe', status: 'installing'),
          DriverInstallItem(filename: 'lan.exe', status: 'pending'),
          DriverInstallItem(filename: 'wifi.exe', status: 'pending'),
        ],
      );

      final staleAccepted = service.applyDriverStatus(staleFrame);
      expect(staleAccepted, isFalse, reason: 'Stale frame with lower revision must be rejected');
      expect(service.latestDriverRevision, 10, reason: 'Revision baseline must remain at latest accepted');
      expect(service.driverStatus.value.completed, 1, reason: 'State must not be reverted to older completed count');

      // Valid newer frame with revision 11
      final newerFrame = DriverBatchStatus(
        stateRevision: 11,
        isRunning: true,
        total: 3,
        completed: 2,
        startTime: 1000.0,
        items: [
          DriverInstallItem(filename: 'chipset.exe', status: 'completed'),
          DriverInstallItem(filename: 'lan.exe', status: 'completed'),
          DriverInstallItem(filename: 'wifi.exe', status: 'installing'),
        ],
      );

      final newerAccepted = service.applyDriverStatus(newerFrame);
      expect(newerAccepted, isTrue);
      expect(service.latestDriverRevision, 11);
      expect(service.driverStatus.value.completed, 2);
    });

    test('2. Local Start Intent ignores pre-start idle frames and avoids UI flickering', () {
      // System is initially idle with revision 3
      final idleFrame = DriverBatchStatus(
        stateRevision: 3,
        isRunning: false,
        total: 0,
        completed: 0,
      );
      service.applyDriverStatus(idleFrame);
      expect(service.isDriverRunning.value, isFalse);
      expect(service.latestDriverRevision, 3);

      // User initiates auto-install: controller signals start intent
      service.startDriverQueueIntent();
      expect(service.isDriverRunning.value, isTrue, reason: 'Start intent must immediately assert running state');
      expect(service.isDriverStartIntentActive, isTrue);

      // A pre-start idle frame with stateRevision <= 3 arrives during HTTP launch latency
      final preStartIdleFrame = DriverBatchStatus(
        stateRevision: 3,
        isRunning: false,
        total: 0,
        completed: 0,
      );

      final preStartAccepted = service.applyDriverStatus(preStartIdleFrame);
      expect(preStartAccepted, isFalse, reason: 'Pre-start idle frame must be ignored during start intent');
      expect(service.isDriverRunning.value, isTrue, reason: 'Running state must not flicker back to false');

      // Backend launches queue and returns running frame with revision 4
      final queueStartedFrame = DriverBatchStatus(
        stateRevision: 4,
        isRunning: true,
        total: 2,
        completed: 0,
        startTime: 2000.0,
        items: [
          DriverInstallItem(filename: 'drv1.exe', status: 'installing'),
          DriverInstallItem(filename: 'drv2.exe', status: 'pending'),
        ],
      );

      final startedAccepted = service.applyDriverStatus(queueStartedFrame);
      expect(startedAccepted, isTrue);
      expect(service.isDriverRunning.value, isTrue);
      expect(service.isDriverStartIntentActive, isFalse, reason: 'Start intent clears once running frame is confirmed');
      expect(service.driverStatus.value.total, 2);
    });

    test('3. Two-Empty-Snapshots confirmation guard ignores single transient empty frame and never zeroes baseline', () {
      final runningFrame = DriverBatchStatus(
        stateRevision: 5,
        isRunning: true,
        total: 2,
        completed: 1,
        startTime: 3000.0,
        items: [
          DriverInstallItem(filename: 'audio.exe', status: 'completed'),
          DriverInstallItem(filename: 'lan.exe', status: 'installing'),
        ],
      );
      service.applyDriverStatus(runningFrame);
      expect(service.isDriverRunning.value, isTrue);
      expect(service.latestDriverRevision, 5);

      // First transient empty frame arriving while queue is known to be running (e.g. backend worker race)
      final emptyFrame1 = DriverBatchStatus(
        stateRevision: 6,
        isRunning: false,
        total: 0,
        completed: 0,
        items: const [],
      );

      final accepted1 = service.applyDriverStatus(emptyFrame1);
      expect(accepted1, isFalse, reason: 'First empty frame during running must be dropped');
      expect(service.isDriverRunning.value, isTrue, reason: 'Queue must remain running on transient empty frame');
      expect(service.driverStatus.value.total, 2, reason: 'Queue items must not be wiped out');
      expect(service.latestDriverRevision, 5, reason: 'Baseline revision must NEVER reset to 0 on empty frame');

      // Second consecutive empty frame confirms true queue idle state
      final emptyFrame2 = DriverBatchStatus(
        stateRevision: 7,
        isRunning: false,
        total: 0,
        completed: 0,
        items: const [],
      );

      final accepted2 = service.applyDriverStatus(emptyFrame2);
      expect(accepted2, isTrue, reason: 'Second consecutive empty frame must be accepted');
      expect(service.isDriverRunning.value, isFalse);
      expect(service.latestDriverRevision, 7, reason: 'Revision baseline advances monotonically');
    });

    test('4. Network resilience: disconnection banner requires >= 3 consecutive errors on same endpoint and clears on success', () {
      expect(service.isDisconnected.value, isFalse);
      expect(service.consecutiveDriverErrors, 0);

      // Error 1 on driver endpoint
      service.handleDriverNetworkFailure(Exception('Connection timed out'));
      expect(service.consecutiveDriverErrors, 1);
      expect(service.isDisconnected.value, isFalse, reason: '1 error must not trigger disconnection notice');

      // Error 2 on driver endpoint
      service.handleDriverNetworkFailure(Exception('Connection reset'));
      expect(service.consecutiveDriverErrors, 2);
      expect(service.isDisconnected.value, isFalse, reason: '2 errors must not trigger disconnection notice');

      // Error 3 on driver endpoint -> triggers threshold
      service.handleDriverNetworkFailure(Exception('No route to host'));
      expect(service.consecutiveDriverErrors, 3);
      expect(service.isDisconnected.value, isTrue, reason: '>= 3 consecutive errors on same endpoint triggers notice');
      expect(service.disconnectionMessage.value, InstallStateService.defaultDisconnectionMessage);

      // A single successful status frame restores connectivity immediately
      final recoveryFrame = DriverBatchStatus(
        stateRevision: 1,
        isRunning: false,
        total: 0,
      );
      service.applyDriverStatus(recoveryFrame);
      expect(service.consecutiveDriverErrors, 0);
      expect(service.isDisconnected.value, isFalse, reason: 'Success resets error count and hides banner');
      expect(service.disconnectionMessage.value, '');
    });

    test('5. Backend restart with new boot_id resets revision baseline cleanly', () {
      final session1Frame = DriverBatchStatus(
        stateRevision: 50,
        isRunning: true,
        total: 4,
        completed: 2,
        bootId: 'boot_session_alpha',
        startTime: 5000.0,
      );
      service.applyDriverStatus(session1Frame);
      expect(service.latestDriverRevision, 50);
      expect(service.latestDriverBootId, 'boot_session_alpha');

      // Backend restarts, generating bootId 'boot_session_beta' and resetting stateRevision to 1
      final session2Frame = DriverBatchStatus(
        stateRevision: 1,
        isRunning: true,
        total: 1,
        completed: 0,
        bootId: 'boot_session_beta',
        startTime: 6000.0,
        items: [
          DriverInstallItem(filename: 'first_after_reboot.exe', status: 'installing'),
        ],
      );

      final accepted = service.applyDriverStatus(session2Frame);
      expect(accepted, isTrue, reason: 'New boot_id resets baseline and accepts revision 1 from new backend process');
      expect(service.latestDriverRevision, 1);
      expect(service.latestDriverBootId, 'boot_session_beta');
      expect(service.driverStatus.value.total, 1);
    });

    test('6. Session start (startTime change) resets revision baseline', () {
      final firstRun = BatchInstallStatus(
        stateRevision: 30,
        isRunning: false,
        total: 5,
        completed: 5,
        startTime: 7000.0,
      );
      service.applySoftwareStatus(firstRun);
      expect(service.latestSoftwareRevision, 30);

      // New queue launched with startTime 8000.0 and initial revision 1
      final secondRun = BatchInstallStatus(
        stateRevision: 1,
        isRunning: true,
        total: 2,
        completed: 0,
        startTime: 8000.0,
      );

      final accepted = service.applySoftwareStatus(secondRun);
      expect(accepted, isTrue, reason: 'New startTime resets baseline and accepts revision 1');
      expect(service.latestSoftwareRevision, 1);
      expect(service.isSoftwareRunning.value, isTrue);
    });

    test('7. Page exit/re-entry adopts active queue state from InstallStateService without state loss', () async {
      // Simulate active background queue in service
      final backgroundStatus = DriverBatchStatus(
        stateRevision: 15,
        isRunning: true,
        total: 4,
        completed: 2,
        startTime: 9000.0,
        items: [
          DriverInstallItem(packageId: 'p1', displayName: 'Chipset', status: 'completed'),
          DriverInstallItem(packageId: 'p2', displayName: 'Audio', status: 'completed'),
          DriverInstallItem(packageId: 'p3', displayName: 'LAN', status: 'installing'),
          DriverInstallItem(packageId: 'p4', displayName: 'WLAN', status: 'pending'),
        ],
      );
      service.applyDriverStatus(backgroundStatus);

      // Create DriverInstallController (page enter)
      final ctrl1 = DriverInstallController(apiService: mockApi);
      expect(ctrl1.isBatchInstalling.value, isTrue);
      expect(ctrl1.batchStatus.value.completed, 2);
      expect(ctrl1.batchStatus.value.total, 4);

      // User navigates away: ctrl1 is closed
      ctrl1.onClose();

      // Background installation advances to completed = 3
      final backgroundStatus2 = DriverBatchStatus(
        stateRevision: 16,
        isRunning: true,
        total: 4,
        completed: 3,
        startTime: 9000.0,
        items: [
          DriverInstallItem(packageId: 'p1', displayName: 'Chipset', status: 'completed'),
          DriverInstallItem(packageId: 'p2', displayName: 'Audio', status: 'completed'),
          DriverInstallItem(packageId: 'p3', displayName: 'LAN', status: 'completed'),
          DriverInstallItem(packageId: 'p4', displayName: 'WLAN', status: 'installing'),
        ],
      );
      service.applyDriverStatus(backgroundStatus2);

      // User navigates back: ctrl2 is instantiated
      final ctrl2 = DriverInstallController(apiService: mockApi);
      expect(ctrl2.isBatchInstalling.value, isTrue);
      expect(ctrl2.batchStatus.value.completed, 3, reason: 'New controller immediately consumes live service state');
      expect(ctrl2.batchStatus.value.items[2].status, 'completed');

      ctrl2.onClose();
    });

    test('8. 2X mode concurrent items tracking exposes activeItems correctly', () {
      final dualActiveStatus = DriverBatchStatus(
        stateRevision: 20,
        isRunning: true,
        doubleSpeed: true,
        total: 4,
        completed: 1,
        activeWorkers: 2,
        activeItems: [
          DriverActiveItem(packageId: 'p_lan', displayName: 'Gigabit LAN', workerId: 1, status: 'installing'),
          DriverActiveItem(packageId: 'p_wifi', displayName: 'Wi-Fi 6', workerId: 2, status: 'installing'),
        ],
        items: [
          DriverInstallItem(packageId: 'p_chip', displayName: 'Chipset', status: 'completed'),
          DriverInstallItem(packageId: 'p_lan', displayName: 'Gigabit LAN', workerId: 1, status: 'installing'),
          DriverInstallItem(packageId: 'p_wifi', displayName: 'Wi-Fi 6', workerId: 2, status: 'installing'),
          DriverInstallItem(packageId: 'p_audio', displayName: 'Audio', status: 'pending'),
        ],
      );

      service.applyDriverStatus(dualActiveStatus);
      expect(service.driverStatus.value.doubleSpeed, isTrue);
      expect(service.driverStatus.value.effectiveActiveItems.length, 2);
      expect(service.driverStatus.value.effectiveActiveItems[0].displayName, 'Gigabit LAN');
      expect(service.driverStatus.value.effectiveActiveItems[1].displayName, 'Wi-Fi 6');
    });

    test('9. Strict state machine validator enforces forward transitions, 1618 retry, and terminal invariance', () {
      // Forward transitions:
      expect(InstallStateService.canTransition('pending', 'installing'), isTrue);
      expect(InstallStateService.canTransition('queued', 'installing'), isTrue);
      expect(InstallStateService.canTransition('installing', 'completed'), isTrue);
      expect(InstallStateService.canTransition('installing', 'failed'), isTrue);
      expect(InstallStateService.canTransition('installing', 'skipped'), isTrue);
      expect(InstallStateService.canTransition('installing', 'interrupted'), isTrue);

      // Illegal backward transition:
      expect(InstallStateService.canTransition('installing', 'pending'), isFalse,
          reason: 'Rollback to pending without 1618 flag is strictly disallowed');

      // Error 1618 exception:
      expect(
        InstallStateService.canTransition('installing', 'pending', is1618Retry: true),
        isTrue,
        reason: 'Error 1618 retry allows rollback to pending',
      );

      // User retry exception for failed or interrupted tasks:
      expect(
        InstallStateService.canTransition('failed', 'pending', isUserRetry: true),
        isTrue,
      );
      expect(
        InstallStateService.canTransition('interrupted', 'pending', isUserRetry: true),
        isTrue,
      );

      // Terminal invariance: once completed or skipped, cannot transition
      expect(InstallStateService.canTransition('completed', 'installing'), isFalse);
      expect(InstallStateService.canTransition('completed', 'pending'), isFalse);
      expect(InstallStateService.canTransition('skipped', 'installing'), isFalse);
    });
  });
}
