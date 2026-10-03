import 'package:flutter_test/flutter_test.dart';
import 'package:markazi_system_checker/models/system_info.dart';
import 'package:markazi_system_checker/services/backend_process_manager.dart';
import 'package:markazi_system_checker/controllers/software_controller.dart';
import 'package:markazi_system_checker/controllers/driver_install_controller.dart';

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

  test('software select-all toggles 5000 visible IDs synchronously', () {
    final ids = {for (var index = 0; index < 5000; index++) 'app-$index'};
    final stopwatch = Stopwatch()..start();
    final selected = toggledSoftwareSelection({}, ids);
    final cleared = toggledSoftwareSelection(selected, ids);
    stopwatch.stop();
    expect(selected, hasLength(5000));
    expect(cleared, isEmpty);
    expect(stopwatch.elapsedMilliseconds, lessThan(500));
  });

  test('driver select-all uses controller state and toggles immediately', () {
    final controller = DriverInstallController();
    controller.scanResult.value = DriverScanResult.fromJson({
      'success': true,
      'packages': [
        for (var index = 0; index < 1000; index++)
          {
            'package_id': 'driver-$index',
            'display_name': 'Driver $index',
            'category': 'other',
            'category_fa': 'سایر',
            'package_type': 'folder',
            'source_path': 'fixture-$index',
            'relative_path': 'fixture-$index',
            'installer_file': 'setup-$index.exe',
            'install_method': 'setup_exe',
            'fingerprint': 'hash-$index',
          },
      ],
    });
    final stopwatch = Stopwatch()..start();
    controller.toggleSelectAllPackages();
    expect(controller.areAllInstallableSelected, isTrue);
    expect(controller.triStateSelectionValue, isTrue);
    controller.toggleSelectAllPackages();
    stopwatch.stop();
    expect(controller.selectedPackageIds, isEmpty);
    expect(controller.triStateSelectionValue, isFalse);
    expect(stopwatch.elapsedMilliseconds, lessThan(500));
  });
}
