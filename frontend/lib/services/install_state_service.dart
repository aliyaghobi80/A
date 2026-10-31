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
/// - Automatic revision baseline reset on new session (startTime change) or bootId change
/// - Local Start Intent (protects auto-install running state from pre-start idle polling latency)
/// - Two-Empty-Snapshots confirmation guard (drops first transient empty frame)
/// - Single non-overlapping adaptive polling loop with immediate first poll and 3s request timeouts
/// - Network disconnection resilience: notice appears only after >= 3 consecutive errors on same endpoint
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
  String? _lastDriverBootId;
  String? _lastSoftwareBootId;

  int get latestDriverRevision => _latestDriverRevision;
  int get latestSoftwareRevision => _latestSoftwareRevision;
  String? get latestDriverBootId => _lastDriverBootId;
  String? get latestSoftwareBootId => _lastSoftwareBootId;

  // ---------------------------------------------------------------------------
  // Two-Empty-Snapshots Confirmation Guards
  // ---------------------------------------------------------------------------
  int _emptyDriverSnapshots = 0;
  int _emptySoftwareSnapshots = 0;

  // ---------------------------------------------------------------------------
  // Local Start Intent Trackers
  // ---------------------------------------------------------------------------
  bool _driverStartIntent = false;
  int _driverRevisionAtRequest = 0;
  DateTime? _driverStartIntentTime;

  bool _softwareStartIntent = false;
  int _softwareRevisionAtRequest = 0;
  DateTime? _softwareStartIntentTime;

  bool get isDriverStartIntentActive => _driverStartIntent;
  bool get isSoftwareStartIntentActive => _softwareStartIntent;

  // ---------------------------------------------------------------------------
  // Network Resilience & Error Trackers (>= 3 consecutive errors threshold)
  // ---------------------------------------------------------------------------
  int _consecutiveDriverErrors = 0;
  int _consecutiveSoftwareErrors = 0;

  int get consecutiveDriverErrors => _consecutiveDriverErrors;
  int get consecutiveSoftwareErrors => _consecutiveSoftwareErrors;

  // ---------------------------------------------------------------------------
  // Polling Loop State
  // ---------------------------------------------------------------------------
  bool _isPollingActive = false;
  bool _isLoopInFlight = false;
  bool _disposed = false;
  Completer<void>? _wakeCompleter;
  Timer? _delayTimer;

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
  // Local Start Intent Methods
  // ---------------------------------------------------------------------------

  /// Records intent to start driver queue, immediately setting running state
  /// and ignoring stale idle frames whose revision <= revisionAtRequest.
  void startDriverQueueIntent() {
    _driverStartIntent = true;
    _driverRevisionAtRequest = _latestDriverRevision;
    _driverStartIntentTime = DateTime.now();
    isDriverRunning.value = true;
    notifyQueueStarted();
  }

  /// Cancels driver start intent if queue launch failed or errored.
  void cancelDriverQueueIntent() {
    _driverStartIntent = false;
    _driverStartIntentTime = null;
    isDriverRunning.value = driverStatus.value.isRunning;
  }

  /// Records intent to start software queue, immediately setting running state
  /// and ignoring stale idle frames whose revision <= revisionAtRequest.
  void startSoftwareQueueIntent() {
    _softwareStartIntent = true;
    _softwareRevisionAtRequest = _latestSoftwareRevision;
    _softwareStartIntentTime = DateTime.now();
    isSoftwareRunning.value = true;
    notifyQueueStarted();
  }

  /// Cancels software start intent if queue launch failed or errored.
  void cancelSoftwareQueueIntent() {
    _softwareStartIntent = false;
    _softwareStartIntentTime = null;
    isSoftwareRunning.value = softwareStatus.value.isRunning;
  }

  // ---------------------------------------------------------------------------
  // Status Application & Out-of-Order Stale Rejection
  // ---------------------------------------------------------------------------

  /// Applies an incoming [DriverBatchStatus] update.
  /// Drops the frame if [status.stateRevision] is lower than the latest applied revision.
  /// Baseline resets ONLY on bootId change or startTime change, NEVER on empty frames.
  bool applyDriverStatus(DriverBatchStatus status) {
    // 1. Session & Boot ID Baseline Reset
    if (status.bootId != null && status.bootId != _lastDriverBootId) {
      _latestDriverRevision = 0;
      _lastDriverBootId = status.bootId;
      _lastDriverStartTime = status.startTime;
      _emptyDriverSnapshots = 0;
    } else if (status.startTime != null && status.startTime != _lastDriverStartTime) {
      _latestDriverRevision = 0;
      _lastDriverStartTime = status.startTime;
      _emptyDriverSnapshots = 0;
    }

    // 2. Local Start Intent Guard
    if (_driverStartIntent) {
      if (status.isRunning) {
        _driverStartIntent = false;
        _driverStartIntentTime = null;
      } else if (status.stateRevision <= _driverRevisionAtRequest) {
        if (_driverStartIntentTime != null &&
            DateTime.now().difference(_driverStartIntentTime!) < const Duration(seconds: 10)) {
          debugPrint(
            '[InstallStateService] Ignored stale idle driver frame during start intent: '
            'revision ${status.stateRevision} <= $_driverRevisionAtRequest',
          );
          return false;
        }
        _driverStartIntent = false;
        _driverStartIntentTime = null;
      } else {
        _driverStartIntent = false;
        _driverStartIntentTime = null;
      }
    }

    // 3. Monotonic Revision Check
    if (_latestDriverRevision > 0 && status.stateRevision < _latestDriverRevision) {
      debugPrint(
        '[InstallStateService] Dropped stale driver status frame: '
        'incoming ${status.stateRevision} < latest $_latestDriverRevision',
      );
      return false;
    }

    // 4. Two-Empty-Snapshots Confirmation Guard
    // When locally running, drop the first empty/idle frame; accept only after two consecutive confirmations.
    // NEVER reset monotonic baseline on empty frames!
    if (isDriverRunning.value && !status.isRunning && status.total == 0) {
      _emptyDriverSnapshots++;
      if (_emptyDriverSnapshots < 2) {
        debugPrint(
          '[InstallStateService] Ignored transient empty driver frame (1/2)',
        );
        return false;
      }
    } else {
      _emptyDriverSnapshots = 0;
    }

    _latestDriverRevision = status.stateRevision;
    driverStatus.value = status;
    isDriverRunning.value = status.isRunning || _driverStartIntent;

    _consecutiveDriverErrors = 0;
    _updateDisconnectionState();
    return true;
  }

  /// Applies an incoming [BatchInstallStatus] update.
  /// Drops the frame if [status.stateRevision] is lower than the latest applied revision.
  /// Baseline resets ONLY on bootId change or startTime change, NEVER on empty frames.
  bool applySoftwareStatus(BatchInstallStatus status) {
    // 1. Session & Boot ID Baseline Reset
    if (status.bootId != null && status.bootId != _lastSoftwareBootId) {
      _latestSoftwareRevision = 0;
      _lastSoftwareBootId = status.bootId;
      _lastSoftwareStartTime = status.startTime;
      _emptySoftwareSnapshots = 0;
    } else if (status.startTime != null && status.startTime != _lastSoftwareStartTime) {
      _latestSoftwareRevision = 0;
      _lastSoftwareStartTime = status.startTime;
      _emptySoftwareSnapshots = 0;
    }

    // 2. Local Start Intent Guard
    if (_softwareStartIntent) {
      if (status.isRunning) {
        _softwareStartIntent = false;
        _softwareStartIntentTime = null;
      } else if (status.stateRevision <= _softwareRevisionAtRequest) {
        if (_softwareStartIntentTime != null &&
            DateTime.now().difference(_softwareStartIntentTime!) < const Duration(seconds: 10)) {
          debugPrint(
            '[InstallStateService] Ignored stale idle software frame during start intent: '
            'revision ${status.stateRevision} <= $_softwareRevisionAtRequest',
          );
          return false;
        }
        _softwareStartIntent = false;
        _softwareStartIntentTime = null;
      } else {
        _softwareStartIntent = false;
        _softwareStartIntentTime = null;
      }
    }

    // 3. Monotonic Revision Check
    if (_latestSoftwareRevision > 0 && status.stateRevision < _latestSoftwareRevision) {
      debugPrint(
        '[InstallStateService] Dropped stale software status frame: '
        'incoming ${status.stateRevision} < latest $_latestSoftwareRevision',
      );
      return false;
    }

    // 4. Two-Empty-Snapshots Confirmation Guard
    if (isSoftwareRunning.value && !status.isRunning && status.total == 0) {
      _emptySoftwareSnapshots++;
      if (_emptySoftwareSnapshots < 2) {
        debugPrint(
          '[InstallStateService] Ignored transient empty software frame (1/2)',
        );
        return false;
      }
    } else {
      _emptySoftwareSnapshots = 0;
    }

    _latestSoftwareRevision = status.stateRevision;
    softwareStatus.value = status;
    isSoftwareRunning.value = status.isRunning || _softwareStartIntent;

    _consecutiveSoftwareErrors = 0;
    _updateDisconnectionState();
    return true;
  }

  // ---------------------------------------------------------------------------
  // Disconnection & Resilience Handling (>= 3 consecutive errors on same endpoint)
  // ---------------------------------------------------------------------------

  void handleDriverNetworkFailure(Object error) {
    debugPrint('[InstallStateService] Driver network failure: $error');
    _consecutiveDriverErrors++;
    _updateDisconnectionState();
  }

  void handleSoftwareNetworkFailure(Object error) {
    debugPrint('[InstallStateService] Software network failure: $error');
    _consecutiveSoftwareErrors++;
    _updateDisconnectionState();
  }

  /// Handles general network failure or external invocation.
  void handleNetworkFailure(Object error) {
    debugPrint('[InstallStateService] General network drop / error: $error');
    _consecutiveDriverErrors++;
    _consecutiveSoftwareErrors++;
    _updateDisconnectionState();
  }

  void _updateDisconnectionState() {
    if (_consecutiveDriverErrors >= 3 || _consecutiveSoftwareErrors >= 3) {
      isDisconnected.value = true;
      disconnectionMessage.value = defaultDisconnectionMessage;
    } else if (_consecutiveDriverErrors < 3 && _consecutiveSoftwareErrors < 3) {
      if (isDisconnected.value) {
        isDisconnected.value = false;
        disconnectionMessage.value = '';
      }
    }
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
      'installing': {'completed', 'failed', 'skipped', 'interrupted', 'pending'},
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
      final status = await _apiService
          .getDriverBatchStatus()
          .timeout(const Duration(seconds: 3));
      applyDriverStatus(status);
      return driverStatus.value;
    } catch (e) {
      handleDriverNetworkFailure(e);
      return driverStatus.value;
    }
  }

  /// Explicitly queries software batch status from backend and applies it.
  Future<BatchInstallStatus> synchronizeSoftware() async {
    try {
      final status = await _apiService
          .getBatchInstallStatus()
          .timeout(const Duration(seconds: 3));
      applySoftwareStatus(status);
      return softwareStatus.value;
    } catch (e) {
      handleSoftwareNetworkFailure(e);
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
    _delayTimer?.cancel();
    _delayTimer = null;
    if (_wakeCompleter != null && !_wakeCompleter!.isCompleted) {
      _wakeCompleter!.complete();
    }
    _wakeCompleter = null;
  }

  /// Wakes the polling loop immediately when a new installation is launched,
  /// avoiding delay from an idle sleep cycle.
  void notifyQueueStarted() {
    if (!_autoStartPolling) {
      return;
    }
    if (!_isPollingActive && !_disposed) {
      startPolling();
    } else {
      if (_wakeCompleter != null && !_wakeCompleter!.isCompleted) {
        _wakeCompleter!.complete();
      }
      _wakeCompleter = null;
    }
  }

  Future<void> _runPollingLoop() async {
    if (_isLoopInFlight) return;
    _isLoopInFlight = true;
    try {
      // Immediate first poll on start to eliminate startup delay
      if (_isPollingActive && !_disposed) {
        await _pollIteration();
      }

      while (_isPollingActive && !_disposed) {
        final bool isActive = isDriverRunning.value ||
            isSoftwareRunning.value ||
            _driverStartIntent ||
            _softwareStartIntent;
        final Duration interval = isActive ? _activeInterval : _idleInterval;

        final delayCompleter = Completer<void>();
        _delayTimer = Timer(interval, () {
          if (!delayCompleter.isCompleted) delayCompleter.complete();
        });
        final wakeCompleter = Completer<void>();
        _wakeCompleter = wakeCompleter;

        await Future.any<void>([
          delayCompleter.future,
          wakeCompleter.future,
        ]);
        _delayTimer?.cancel();
        _delayTimer = null;
        _wakeCompleter = null;

        if (!_isPollingActive || _disposed) break;

        await _pollIteration();
      }
    } finally {
      _isLoopInFlight = false;
    }
  }

  Future<void> _pollIteration() async {
    await Future.wait([
      _pollDriverSafe(),
      _pollSoftwareSafe(),
    ]);
  }

  Future<void> _pollDriverSafe() async {
    try {
      final status = await _apiService
          .getDriverBatchStatus()
          .timeout(const Duration(seconds: 3));
      applyDriverStatus(status);
    } catch (e) {
      handleDriverNetworkFailure(e);
    }
  }

  Future<void> _pollSoftwareSafe() async {
    try {
      final status = await _apiService
          .getBatchInstallStatus()
          .timeout(const Duration(seconds: 3));
      applySoftwareStatus(status);
    } catch (e) {
      handleSoftwareNetworkFailure(e);
    }
  }
}
