// frontend/test/monitor_test_view_test.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:markazi_system_checker/controllers/driver_install_controller.dart';
import 'package:markazi_system_checker/controllers/hardware_test_controller.dart';
import 'package:markazi_system_checker/controllers/software_controller.dart';
import 'package:markazi_system_checker/controllers/system_info_controller.dart';
import 'package:markazi_system_checker/controllers/theme_language_controller.dart';
import 'package:markazi_system_checker/models/system_info.dart';
import 'package:markazi_system_checker/services/api_service.dart';
import 'package:markazi_system_checker/services/install_state_service.dart';
import 'package:markazi_system_checker/widgets/common/app_frame.dart';
import 'package:markazi_system_checker/widgets/common/custom_title_bar.dart';
import 'package:markazi_system_checker/widgets/hardware_tests/monitor_test_view.dart';
import 'package:markazi_system_checker/widgets/pages/driver_install_page.dart';
import 'package:markazi_system_checker/widgets/pages/software_install_page.dart';

class _MockFastApiService extends ApiService {
  List<String>? lastBatchPackageIds;
  bool? lastIncludeActivation;
  bool? lastDoubleSpeed;
  bool startBatchInstallCalled = false;
  bool startDriverQueueCalled = false;

  @override
  Future<Map<String, dynamic>> startBatchInstall({
    List<String>? packageIds,
    String? customDir,
    bool? includeSystemSetup,
    bool includeActivation = false,
    bool doubleSpeed = false,
  }) async {
    startBatchInstallCalled = true;
    lastBatchPackageIds = packageIds;
    lastIncludeActivation = includeActivation;
    lastDoubleSpeed = doubleSpeed;
    return {
      'success': true,
      'batch_id': 'batch_123',
      'message': 'نصب خودکار شروع شد...',
    };
  }

  @override
  Future<Map<String, dynamic>> startDriverQueueInstall({
    List<String>? packageIds,
    String? folderPath,
    bool resume = false,
    bool doubleSpeed = false,
  }) async {
    startDriverQueueCalled = true;
    return {
      'success': true,
      'queue_id': 'driver_q_123',
      'message': 'صف درایور شروع شد',
    };
  }

  @override
  Future<DriverBatchStatus> getDriverQueueStatus() async {
    return DriverBatchStatus.empty();
  }

  @override
  Future<DriverBatchStatus> getDriverBatchStatus() async {
    return DriverBatchStatus.empty();
  }

  @override
  Future<BatchInstallStatus> getBatchInstallStatus() async {
    return BatchInstallStatus.empty();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Get.reset();
    Get.put(ThemeLanguageController());
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

  group('Monitor Diagnostics Fullscreen (R3)', () {
    testWidgets('Entering fullscreen invokes method channel setFullScreen(true) and hides cursor', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final List<Map<String, dynamic>> channelCalls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('markazi/window'), (call) async {
        channelCalls.add({'method': call.method, 'arguments': call.arguments});
        return null;
      });

      final ctrl = Get.put(HardwareTestController());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MonitorTestView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find and scroll until start fullscreen button is visible
      final btnFinder = find.text('شروع تست تمام‌صفحه');
      await tester.scrollUntilVisible(btnFinder, 100);
      await tester.pumpAndSettle();

      // Click "شروع تست تمام‌صفحه"
      await tester.tap(btnFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // MethodChannel was called with setFullScreen(true)
      expect(channelCalls.any((c) => c['method'] == 'setFullScreen' && c['arguments'] == true), isTrue);
      expect(ctrl.isMonitorFullScreen.value, isTrue);

      // MouseRegion has cursor: SystemMouseCursors.none
      final mouseRegionFinder = find.byType(MouseRegion);
      expect(mouseRegionFinder, findsWidgets);
      final hasHiddenCursor = tester.widgetList<MouseRegion>(mouseRegionFinder)
          .any((mr) => mr.cursor == SystemMouseCursors.none);
      expect(hasHiddenCursor, isTrue);

      // Pure solid color canvas is displayed without overlays or text
      expect(find.byKey(const ValueKey('monitor-fullscreen-color-canvas')), findsOneWidget);
      final canvasContainer = tester.widget<Container>(find.byKey(const ValueKey('monitor-fullscreen-color-canvas')));
      expect(canvasContainer.color, const Color(0xFF000000)); // First color is black

      // Clean up
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('markazi/window'), null);
    });

    testWidgets('Arrow keys and Esc key navigate colors and exit fullscreen cleanly', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final List<Map<String, dynamic>> channelCalls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('markazi/window'), (call) async {
        channelCalls.add({'method': call.method, 'arguments': call.arguments});
        return null;
      });

      final ctrl = Get.put(HardwareTestController());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MonitorTestView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll and enter fullscreen
      final btnFinder = find.text('شروع تست تمام‌صفحه');
      await tester.scrollUntilVisible(btnFinder, 100);
      await tester.pumpAndSettle();

      await tester.tap(btnFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(ctrl.monitorIndex.value, 0);

      // Press ArrowRight to advance color
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(ctrl.monitorIndex.value, 1);

      // Press ArrowUp to advance color
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(ctrl.monitorIndex.value, 2);

      // Press ArrowLeft to go back
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(ctrl.monitorIndex.value, 1);

      // Press ArrowDown to go back
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(ctrl.monitorIndex.value, 0);

      // Press Esc to exit fullscreen
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      // Fullscreen exited and setFullScreen(false) called
      expect(ctrl.isMonitorFullScreen.value, isFalse);
      expect(channelCalls.any((c) => c['method'] == 'setFullScreen' && c['arguments'] == false), isTrue);
      expect(find.byKey(const ValueKey('monitor-fullscreen-color-canvas')), findsNothing);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('markazi/window'), null);
    });

    testWidgets('AppFrame observes HardwareTestController.isMonitorFullScreen reactively', (tester) async {
      final ctrl = Get.put(HardwareTestController());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppFrame(
              child: const Text('Inner Page'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially title bar is visible
      expect(find.byKey(const ValueKey('app-frame-titlebar')), findsOneWidget);
      expect(find.byType(CustomTitleBar), findsOneWidget);

      // Toggle fullscreen on
      ctrl.toggleMonitorFullScreen(true);
      await tester.pump();

      // Title bar is hidden
      expect(find.byKey(const ValueKey('app-frame-titlebar')), findsNothing);
      expect(find.byType(CustomTitleBar), findsNothing);

      // Toggle fullscreen off
      ctrl.toggleMonitorFullScreen(false);
      await tester.pump();

      // Title bar is restored
      expect(find.byKey(const ValueKey('app-frame-titlebar')), findsOneWidget);
      expect(find.byType(CustomTitleBar), findsOneWidget);
    });
  });

  group('Fast Auto-Installation Queue Trigger (R5)', () {
    testWidgets('Driver auto-install triggers immediately without modal dialog', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockApi = _MockFastApiService();
      Get.put(SystemInfoController());
      final driverCtrl = Get.put(DriverInstallController(apiService: mockApi));

      // Inject scanned packages and select one
      driverCtrl.scanResult.value = DriverScanResult.fromJson({
        'success': true,
        'message': 'OK',
        'driver_directory': 'C:\\Drivers',
        'packages': [
          {
            'package_id': 'lan_intel_1',
            'display_name': 'Intel Gigabit LAN',
            'category': 'lan',
            'category_fa': 'شبکه کابلی',
            'package_type': 'exe',
            'source_path': 'C:\\Drivers\\LAN',
            'relative_path': 'LAN',
            'installer_file': 'setup.exe',
            'install_method': 'exe',
            'fingerprint': 'fp_lan_intel',
          },
        ],
      });
      driverCtrl.selectedPackageIds.add('lan_intel_1');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DriverInstallPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the auto-install button by key
      final btnFinder = find.byKey(const ValueKey('driver-auto-install-button'));
      expect(btnFinder, findsOneWidget);

      // Tap the auto install button
      await tester.tap(btnFinder);
      await tester.pump();

      // Verify that no preview dialog (QueuePreviewModal / AlertDialog) is open
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('پیش‌نمایش صف نصب درایورها'), findsNothing);
      expect(mockApi.startDriverQueueCalled, isTrue);

      driverCtrl.onClose();
      if (Get.isRegistered<InstallStateService>()) {
        InstallStateService.to.stopPolling();
      }
      if (Get.isRegistered<SystemInfoController>()) {
        Get.find<SystemInfoController>().onClose();
      }
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('Software auto-install triggers immediately without modal dialog', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockApi = _MockFastApiService();
      Get.put(SystemInfoController());
      final swCtrl = Get.put(SoftwareController(apiService: mockApi));

      // Inject packages
      swCtrl.packages.assignAll([
        SoftwarePackage.fromJson({
          'id': 'winrar_test',
          'name': 'WinRAR 7.00',
          'is_installed': false,
          'is_valid': true,
          'is_duplicate': false,
        }),
      ]);
      swCtrl.selectedPackageIds.add('winrar_test');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SoftwareInstallPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the auto install button by key
      final btnFinder = find.byKey(const ValueKey('software-auto-install-button'));
      expect(btnFinder, findsOneWidget);

      await tester.tap(btnFinder);
      await tester.pump();

      // Verify that no preview dialog (QueuePreviewModal / AlertDialog) is open
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('پیش‌نمایش صف نصب'), findsNothing);
      expect(mockApi.startBatchInstallCalled, isTrue);
      expect(mockApi.lastBatchPackageIds, contains('winrar_test'));

      swCtrl.onClose();
      if (Get.isRegistered<InstallStateService>()) {
        InstallStateService.to.stopPolling();
      }
      if (Get.isRegistered<SystemInfoController>()) {
        Get.find<SystemInfoController>().onClose();
      }
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
