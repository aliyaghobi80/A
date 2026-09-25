import 'package:get/get.dart';
import '../services/backend_process_manager.dart';

enum StartupStatus { connecting, ready, failed }

typedef StartupProgressReporter = void Function(double value, String message);
typedef StartupProgressConnector =
    Future<bool> Function(StartupProgressReporter report);

/// Startup failures are visible states, never an endless loading animation.
class StartupController extends GetxController {
  StartupController({
    Future<bool> Function()? connect,
    this.connectWithProgress,
  }) : _connect = connect ?? BackendProcessManager.ensureBackendRunning;

  final Future<bool> Function() _connect;
  final StartupProgressConnector? connectWithProgress;
  final status = StartupStatus.connecting.obs;
  final progress = 0.05.obs;
  final message = 'در حال راه‌اندازی سرویس برنامه…'.obs;
  bool _inFlight = false;

  Future<void> connect() async {
    if (_inFlight || isClosed) return;
    _inFlight = true;
    status.value = StartupStatus.connecting;
    progress.value = 0.05;
    message.value = 'در حال راه‌اندازی سرویس برنامه…';
    try {
      void report(double value, String text) {
        if (isClosed) return;
        progress.value = value.clamp(0.0, 1.0).toDouble();
        message.value = text;
      }

      final ready = await (connectWithProgress?.call(report) ?? _connect())
          .timeout(const Duration(seconds: 90));
      if (!isClosed) {
        status.value = ready ? StartupStatus.ready : StartupStatus.failed;
        progress.value = ready ? 1.0 : progress.value;
        message.value = ready ? 'برنامه آماده است' : 'سرویس برنامه آماده نشد';
      }
    } catch (_) {
      if (!isClosed) {
        status.value = StartupStatus.failed;
        message.value = 'راه‌اندازی کامل نشد؛ دوباره تلاش کنید';
      }
    } finally {
      _inFlight = false;
    }
  }
}
