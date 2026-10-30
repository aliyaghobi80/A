import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../models/system_info.dart';
import 'api_service.dart';

/// Single source of truth for software and driver queue deployment state in Flutter.
/// Registered as a permanent singleton service via [Get.put(..., permanent: true)].
///
/// Features:
/// - Monotonic revision tracking and out-of-order stale snapshot rejection
/// - Automatic revision baseline reset on new session (startTime change)
/// - Single non-overlapping adaptive polling loop (600ms active, 4000ms idle)
/// - Network disconnection resilience without blanking queue cards
/// - Strict forward-only item state transition validation
class InstallStateService extends GetxService {
  InstallStateService({
    ApiService? apiService,
    bool? autoStartPolling,
  })  : _apiService = apiService ?? ApiService(),
        _autoStartPolling = autoStartPolling ??
            (!Platform.environment.containsKey('FLUTTER_TEST'));

  final ApiService _apiService;
  final bool _autoStartPolling;

  // ---------------------------------------------------------------------------
  // Observables
  // ---------------------------------------------------------------------------
  final Rx<DriverBatchStatus> driverStatus = DriverBatchStatus.empty().obs;
  final Rx<BatchInstallStatus> softwareStatus = BatchInstallStatus.empty().obs;
  final RxBool isDriverRunning = false.obs;
  final RxBool isSoftwareRunning = false.obs;
  final RxBool isDisconnected = false.obs;
  final RxString disconnectionMessage = ''.obs;

  static const String defaultDisconnectionMessage =
      'اتصال به سرویس قطع شد؛ در حال تلاش مجدد';

  // ---------------------------------------------------------------------------
  // Monotonic Revision Trackers & Session Baseline
  // ---------------------------------------------------------------------------
  int _latestDriverRevision = 0;
  int _latestSoftwareRevision = 0;
  double? _lastDriverStartTime;
  double? _lastSoftwareStartTime;

  int get latestDriverRevision => _latestDriverRevision;
  int get latestSoftwareRevision => _latestSoftwareRevision;

  // ---------------------------------------------------------------------------
  // Polling Loop State
  // ---------------------------------------------------------------------------
  bool _isPollingActive = false;
  bool _isLoopInFlight = false;
  bool _disposed = false;
  Completer<void>? _wakeCompleter;

  static const Duration _activeInterval = Duration(milliseconds: 600);
  static const Duration _idleInterval = Duration(milliseconds: 4000);

  // ---------------------------------------------------------------------------
  // Singleton Access
  // ---------------------------------------------------------------------------
  static InstallStateService get to => Get.find<InstallStateService>();

  static InstallStateService ensureInitialized({
    ApiService? apiService,
    bool? autoStartPolling,
  }) {
    if (Get.isRegistered<InstallStateService>()) {
      return Get.find<InstallStateService>();
    }
    return Get.put(
      InstallStateService(
        apiService: apiService,
        autoStartPolling: autoStartPolling,
      ),
      permanent: true,
    );
  }

  @override
  void onInit() {
    super.onInit();
    if (_autoStartPolling) {
      startPolling();
    }
  }

  @override
  void onClose() {
    stopPolling();
    _disposed = true;
    super.onClose();
  }

  // ---------------------------------------------------------------------------
  // Status Application & Out-of-Order Stale Rejection
  // ---------------------------------------------------------------------------

  /// Applies an incoming [DriverBatchStatus] update.
  /// Drops the frame if [status.stateRevision] is lower than the latest applied revision.
  /// Automatically resets revision tracking if a new queue session has begun.
  bool applyDriverStatus(DriverBatchStatus status) {
    if (status.startTime != null && status.startTime != _lastDriverStartTime) {
      _latestDriverRevision = 0;
      _lastDriverStartTime = status.startTime;
    } else if (!status.isRunning && status.total == 0) {
      _latestDriverRevision = 0;
      _lastDriverStartTime = null;
    }

    if (_latestDriverRevision > 0 && status.stateRevision < _latestDriverRevision) {
      debugPrint(
        '[InstallStateService] Dropped stale driver status frame: '
        'incoming ${status.stateRevision} < latest $_latestDriverRevision',
      );
      return false;
    }

    _latestDriverRevision = status.stateRevision;
    driverStatus.value = status;
    isDriverRunning.value = status.isRunning;
    isDisconnected.value = false;
    disconnectionMessage.value = '';
    return true;
  }

  /// Applies an incoming [BatchInstallStatus] update.
  /// Drops the frame if [status.stateRevision] is lower than the latest applied revision.
  /// Automatically resets revision tracking if a new queue session has begun.
  bool applySoftwareStatus(BatchInstallStatus status) {
    if (status.startTime != null && status.startTime != _lastSoftwareStartTime) {
      _latestSoftwareRevision = 0;
      _lastSoftwareStartTime = status.startTime;
    } else if (!status.isRunning && status.total == 0) {
      _latestSoftwareRevision = 0;
      _lastSoftwareStartTime = null;
    }

    if (_latestSoftwareRevision > 0 && status.stateRevision < _latestSoftwareRevision) {
      debugPrint(
        '[InstallStateService] Dropped stale software status frame: '
        'incoming ${status.stateRevision} < latest $_latestSoftwareRevision',
      );
      return false;
    }

    _latestSoftwareRevision = status.stateRevision;
    softwareStatus.value = status;
    isSoftwareRunning.value = status.isRunning;
    isDisconnected.value = false;
    disconnectionMessage.value = '';
    return true;
  }

  /// Handles network drop / backend unavailability gracefully.
  /// Preserves the last valid queue states so the UI cards never reset or disappear.
  void handleNetworkFailure(Object error) {
    debugPrint('[InstallStateService] Service network drop / error: $error');
    isDisconnected.value = true;
    disconnectionMessage.value = defaultDisconnectionMessage;
  }

  // ---------------------------------------------------------------------------
  // Strict State Machine Validator
  // ---------------------------------------------------------------------------

  /// Validates item status transitions according to Contract 5.
  /// Forward-only transitions: pending -> installing -> completed/failed/skipped/interrupted.
  /// Rollback to pending is permitted exclusively for Error 1618 retry or user retry.
  static bool canTransition(
    String current,
    String target, {
    bool is1618Retry = false,
    bool isUserRetry = false,
  }) {
    if (current == target) return true;
    if (current == 'installing' && target == 'pending') {
      return is1618Retry;
    }
    if ((current == 'failed' || current == 'interrupted') && target == 'pending') {
      return isUserRetry;
    }
    const validTransitions = <String, Set<String>>{
      'pending': {'installing', 'skipped'},
      'queued': {'installing', 'skipped'},
      'installing': {'completed', 'failed', 'interrupted', 'pending'},
      'completed': {},
      'failed': {'pending'},
      'skipped': {},
      'interrupted': {'pending'},
    };
    return validTransitions[current]?.contains(target) ?? false;
  }

  // ---------------------------------------------------------------------------
  // Synchronization Methods
  // ---------------------------------------------------------------------------

  /// Explicitly queries driver status from backend and applies it.
  Future<DriverBatchStatus> synchronizeDriver() async {
    try {
      final status = await _apiService.getDriverBatchStatus();
      applyDriverStatus(status);
      return driverStatus.value;
    } catch (e) {
      handleNetworkFailure(e);
      return driverStatus.value;
    }
  }

  /// Explicitly queries software batch status from backend and applies it.
  Future<BatchInstallStatus> synchronizeSoftware() async {
    try {
      final status = await _apiService.getBatchInstallStatus();
      applySoftwareStatus(status);
      return softwareStatus.value;
    } catch (e) {
      handleNetworkFailure(e);
      return softwareStatus.value;
    }
  }

  /// Reconciles both driver and software deployment states concurrently.
  Future<void> reconcileAll() async {
    await Future.wait([
      synchronizeDriver(),
      synchronizeSoftware(),
    ]);
  }

  // ---------------------------------------------------------------------------
  // Adaptive Non-Overlapping Polling Loop
  // ---------------------------------------------------------------------------

  /// Starts the adaptive polling loop if not already running.
  void startPolling() {
    if (_isPollingActive) return;
    _isPollingActive = true;
    unawaited(_runPollingLoop());
  }

  /// Stops the adaptive polling loop.
  void stopPolling() {
    _isPollingActive = false;
    _wakeCompleter?.complete();
    _wakeCompleter = null;
  }

  /// Wakes the polling loop immediately when a new installation is launched,
  /// avoiding delay from an idle sleep cycle.
  void notifyQueueStarted() {
    if (!_isPollingActive && !_disposed) {
      startPolling();
    } else {
      _wakeCompleter?.complete();
      _wakeCompleter = null;
    }
  }

  Future<void> _runPollingLoop() async {
    if (_isLoopInFlight) return;
    _isLoopInFlight = true;
    try {
      while (_isPollingActive && !_disposed) {
        final bool isActive =
            isDriverRunning.value || isSoftwareRunning.value;
        final Duration interval =
            isActive ? _activeInterval : _idleInterval;

        final completer = Completer<void>();
        _wakeCompleter = completer;

        await Future.any<void>([
          Future.delayed(interval),
          completer.future,
        ]);
        _wakeCompleter = null;

        if (!_isPollingActive || _disposed) break;

        await _pollIteration();
      }
    } finally {
      _isLoopInFlight = false;
    }
  }

  Future<void> _pollIteration() async {
    try {
      await Future.wait([
        _pollDriverSafe(),
        _pollSoftwareSafe(),
      ]);
    } catch (e) {
      handleNetworkFailure(e);
    }
  }

  Future<void> _pollDriverSafe() async {
    try {
      final status = await _apiService.getDriverBatchStatus();
      applyDriverStatus(status);
    } catch (e) {
      handleNetworkFailure(e);
    }
  }

  Future<void> _pollSoftwareSafe() async {
    try {
      final status = await _apiService.getBatchInstallStatus();
      applySoftwareStatus(status);
    } catch (e) {
      handleNetworkFailure(e);
    }
  }
}
