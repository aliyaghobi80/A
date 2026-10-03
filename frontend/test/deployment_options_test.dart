import 'package:flutter_test/flutter_test.dart';
import 'package:markazi_system_checker/models/system_info.dart';
import 'package:markazi_system_checker/services/backend_process_manager.dart';
import 'package:markazi_system_checker/controllers/software_controller.dart';

void main() {
  test('queue options default to sequential with activation disabled', () {
    final software = BatchInstallStatus.fromJson({'is_running': true});
    final driver = DriverBatchStatus.fromJson({'is_running': true});
    expect(software.includeActivation, isFalse);
    expect(software.doubleSpeed, isFalse);
    expect(driver.doubleSpeed, isFalse);
  });

  test('recovered queue retains options and both active items', () {
    final status = BatchInstallStatus.fromJson({
      'is_running': true,
      'double_speed': true,
      'include_activation': true,
      'items': [
        {'id': 'a', 'name': 'A', 'status': 'installing'},
        {'id': 'b', 'name': 'B', 'status': 'installing'},
      ],
    });
    expect(status.doubleSpeed, isTrue);
    expect(status.includeActivation, isTrue);
    expect(status.items.where((item) => item.status == 'installing').length, 2);
    expect(
      DriverBatchStatus.fromJson({'double_speed': true}).doubleSpeed,
      isTrue,
    );
  });

  test('widget tests never launch the real backend', () async {
    expect(await BackendProcessManager.ensureBackendRunning(), isFalse);
  });

  test('activation consent starts disabled for every controller session', () {
    expect(SoftwareController().includeActivation.value, isFalse);
  });
}
