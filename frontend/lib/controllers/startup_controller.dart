import 'package:get/get.dart';
import '../services/backend_process_manager.dart';

enum StartupStatus { connecting, ready, failed }

/// Startup failures are visible states, never an endless loading animation.
class StartupController extends GetxController {
  StartupController({Future<bool> Function()? connect})
    : _connect = connect ?? BackendProcessManager.ensureBackendRunning;

  final Future<bool> Function() _connect;
  final status = StartupStatus.connecting.obs;
  bool _inFlight = false;

  Future<void> connect() async {
    if (_inFlight || isClosed) return;
    _inFlight = true;
    status.value = StartupStatus.connecting;
    try {
      final ready = await _connect().timeout(const Duration(seconds: 45));
      if (!isClosed) {
        status.value = ready ? StartupStatus.ready : StartupStatus.failed;
      }
    } catch (_) {
      if (!isClosed) status.value = StartupStatus.failed;
    } finally {
      _inFlight = false;
    }
  }
}
