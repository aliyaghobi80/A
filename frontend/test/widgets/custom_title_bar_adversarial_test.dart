import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:markazi_system_checker/controllers/hardware_test_controller.dart';
import 'package:markazi_system_checker/services/install_state_service.dart';
import 'package:markazi_system_checker/widgets/common/app_frame.dart';
import 'package:markazi_system_checker/widgets/common/custom_title_bar.dart';
import 'package:markazi_system_checker/widgets/hardware_tests/monitor_test_view.dart';

void main() {
  setUp(() {
    Get.reset();
  });

  tearDown(() {
    Get.reset();
  });

  group('Adversarial Close Protection Stress Tests', () {
    testWidgets('Matrix: close button NEVER closes silently when driver OR software is running', (tester) async {
      final installService = Get.put(InstallStateService());

      // Define all 4 states of (isDriverRunning, isSoftwareRunning)
      final states = [
        {'driver': true, 'software': false, 'shouldBlock': true},
        {'driver': false, 'software': true, 'shouldBlock': true},
        {'driver': true, 'software': true, 'shouldBlock': true},
        {'driver': false, 'software': false, 'shouldBlock': false},
      ];

      for (final s in states) {
        final bool driverRunning = s['driver'] as bool;
        final bool softwareRunning = s['software'] as bool;
        final bool shouldBlock = s['shouldBlock'] as bool;

        installService.isDriverRunning.value = driverRunning;
        installService.isSoftwareRunning.value = softwareRunning;

        bool closeCallbackInvoked = false;

        await tester.pumpWidget(
          GetMaterialApp(
            home: Scaffold(
              body: CustomTitleBar(
                onClose: () => closeCallbackInvoked = true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Click the close button
        await tester.tap(find.byKey(const ValueKey('window-control-close')));
        await tester.pumpAndSettle();

        if (shouldBlock) {
          // MUST NOT invoke onClose callback
          expect(closeCallbackInvoked, isFalse,
              reason: 'onClose was invoked despite driver=$driverRunning, software=$softwareRunning');

          // MUST display ExitDialog
          expect(find.byType(AlertDialog), findsOneWidget,
              reason: 'ExitDialog was NOT shown when driver=$driverRunning, software=$softwareRunning');
          expect(find.text('خروج و بستن برنامه'), findsOneWidget);

          // Technician dismisses the dialog via 'انصراف'
          await tester.tap(find.text('انصراف'));
          await tester.pumpAndSettle();

          expect(find.byType(AlertDialog), findsNothing);
          expect(closeCallbackInvoked, isFalse);
        } else {
          // When neither is running, onClose callback MUST be invoked
          expect(closeCallbackInvoked, isTrue,
              reason: 'onClose was NOT invoked when idle');
          expect(find.byType(AlertDialog), findsNothing);
        }

        // Clean up widget tree for next iteration
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
    });

    testWidgets('Rapid multiple clicks on close button under active install do not bypass protection or crash', (tester) async {
      final installService = Get.put(InstallStateService());
      installService.isDriverRunning.value = true;

      bool closeCallbackInvoked = false;

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: CustomTitleBar(
              onClose: () => closeCallbackInvoked = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // First click spawns ExitDialog modal
      await tester.tap(find.byKey(const ValueKey('window-control-close')));
      await tester.pump(const Duration(milliseconds: 20));

      // Subsequent clicks are absorbed by the modal barrier
      for (int i = 0; i < 4; i++) {
        await tester.tap(
          find.byKey(const ValueKey('window-control-close')),
          warnIfMissed: false,
        );
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pumpAndSettle();

      // onClose must NEVER be invoked
      expect(closeCallbackInvoked, isFalse);

      // Exactly one ExitDialog is displayed
      expect(find.byType(AlertDialog), findsOneWidget);

      // Dismiss dialog
      await tester.tap(find.text('انصراف'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('Dynamic reactive transition: protects mid-lifecycle as install starts and stops', (tester) async {
      final installService = Get.put(InstallStateService());
      installService.isDriverRunning.value = false;
      installService.isSoftwareRunning.value = false;

      bool closeCallbackInvoked = false;

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: CustomTitleBar(
              onClose: () => closeCallbackInvoked = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Idle state: close executes
      await tester.tap(find.byKey(const ValueKey('window-control-close')));
      await tester.pumpAndSettle();
      expect(closeCallbackInvoked, isTrue);
      expect(find.byType(AlertDialog), findsNothing);

      // Reset callback tracker
      closeCallbackInvoked = false;

      // 2. An installation starts dynamically
      installService.isSoftwareRunning.value = true;
      await tester.pumpAndSettle();

      // Close must now be blocked and prompt ExitDialog
      await tester.tap(find.byKey(const ValueKey('window-control-close')));
      await tester.pumpAndSettle();
      expect(closeCallbackInvoked, isFalse);
      expect(find.byType(AlertDialog), findsOneWidget);

      // Technician cancels exit
      await tester.tap(find.text('انصراف'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);

      // 3. Installation completes dynamically
      installService.isSoftwareRunning.value = false;
      await tester.pumpAndSettle();

      // Close must now execute directly without blocking
      await tester.tap(find.byKey(const ValueKey('window-control-close')));
      await tester.pumpAndSettle();
      expect(closeCallbackInvoked, isTrue);
      expect(find.byType(AlertDialog), findsNothing);
    });
  });

  group('Adversarial Geometry & Layout Verification Across Varied Widths', () {
    final testWidths = [1024.0, 1280.0, 1920.0, 2560.0, 3840.0];

    for (final width in testWidths) {
      testWidgets('Exact 46px button geometry, 32px bar height, and zero-gap continuity at width $width', (tester) async {
        tester.view.physicalSize = Size(width, 768);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: width,
                child: const CustomTitleBar(height: 32.0),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Root title bar container height is exactly 32.0px
        final rootFinder = find.byKey(const ValueKey('custom-title-bar-root'));
        final rootSize = tester.getSize(rootFinder);
        expect(rootSize.height, 32.0);
        expect(rootSize.width, width);

        final minFinder = find.byKey(const ValueKey('window-control-minimize'));
        final maxFinder = find.byKey(const ValueKey('window-control-maximize'));
        final closeFinder = find.byKey(const ValueKey('window-control-close'));

        final minRect = tester.getRect(minFinder);
        final maxRect = tester.getRect(maxFinder);
        final closeRect = tester.getRect(closeFinder);

        // 2. Button widths are exactly 46.0px
        expect(minRect.width, 46.0);
        expect(maxRect.width, 46.0);
        expect(closeRect.width, 46.0);

        // 3. Button height spans inner height above 1px border divider (31.0px)
        expect(minRect.height, 31.0);
        expect(maxRect.height, 31.0);
        expect(closeRect.height, 31.0);

        // 4. Verify zero gap and zero overlap between adjacent buttons
        // In Directionality LTR: [Minimize] [Maximize] [Close]
        expect(minRect.right, maxRect.left,
            reason: 'Gap or overlap detected between minimize and maximize buttons at width $width');
        expect(maxRect.right, closeRect.left,
            reason: 'Gap or overlap detected between maximize and close buttons at width $width');

        // 5. Verify close button is pinned to the right edge
        expect(closeRect.right, width,
            reason: 'Close button right edge does not align with window right bound at width $width');

        // 6. Verify maximize button is exactly at [width - 92, width - 46]
        expect(maxRect.left, width - 92.0);
        expect(maxRect.right, width - 46.0);
      });
    }
  });

  group('Adversarial Fullscreen Diagnostic & Obx Lifecycle Tests', () {
    testWidgets(
        'Entering monitor test fullscreen mode and pressing Esc completes cleanly without markNeedsBuild assertions',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final hwCtrl = Get.put(HardwareTestController());
      final List<MethodCall> channelCalls = [];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('markazi/window'),
        (call) async {
          channelCalls.add(call);
          return null;
        },
      );

      await tester.pumpWidget(
        GetMaterialApp(
          builder: (context, child) => AppFrame(child: child!),
          home: const Scaffold(
            body: MonitorTestView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Initial State: Title bar visible, not fullscreen
      expect(find.byKey(const ValueKey('custom-title-bar-root')), findsOneWidget);
      expect(hwCtrl.isMonitorFullScreen.value, isFalse);

      // 2. Launch fullscreen monitor test
      await tester.tap(find.text('شروع تست تمام‌صفحه'));
      await tester.pumpAndSettle();

      // 3. Fullscreen active: title bar completely hidden, controller updated
      expect(hwCtrl.isMonitorFullScreen.value, isTrue);
      expect(find.byKey(const ValueKey('custom-title-bar-root')), findsNothing);

      // 4. Press Esc to exit fullscreen
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      // 5. Exited: title bar restored, controller updated
      expect(hwCtrl.isMonitorFullScreen.value, isFalse);
      expect(find.byKey(const ValueKey('custom-title-bar-root')), findsOneWidget);

      // 6. Platform channel idempotency: exactly one setFullScreen(true) and one setFullScreen(false)
      final setFullScreenCalls =
          channelCalls.where((c) => c.method == 'setFullScreen').toList();
      expect(setFullScreenCalls.length, 2);
      expect(setFullScreenCalls[0].arguments, isTrue);
      expect(setFullScreenCalls[1].arguments, isFalse);
    });

    testWidgets(
        'Popping _FullScreenMonitorPage externally invokes guarded _exitFullScreen cleanup once',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final hwCtrl = Get.put(HardwareTestController());
      final List<MethodCall> channelCalls = [];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('markazi/window'),
        (call) async {
          channelCalls.add(call);
          return null;
        },
      );

      await tester.pumpWidget(
        GetMaterialApp(
          builder: (context, child) => AppFrame(child: child!),
          home: const Scaffold(
            body: MonitorTestView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('شروع تست تمام‌صفحه'));
      await tester.pumpAndSettle();
      expect(hwCtrl.isMonitorFullScreen.value, isTrue);

      // External pop without pressing Esc (e.g. Navigator.pop)
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pop();
      await tester.pumpAndSettle();

      // Must be cleaned up cleanly
      expect(hwCtrl.isMonitorFullScreen.value, isFalse);
      expect(find.byKey(const ValueKey('custom-title-bar-root')), findsOneWidget);

      final setFullScreenCalls =
          channelCalls.where((c) => c.method == 'setFullScreen').toList();
      expect(setFullScreenCalls.length, 2);
      expect(setFullScreenCalls[0].arguments, isTrue);
      expect(setFullScreenCalls[1].arguments, isFalse);
    });
  });
}
