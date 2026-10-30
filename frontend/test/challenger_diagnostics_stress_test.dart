// frontend/test/challenger_diagnostics_stress_test.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:markazi_system_checker/controllers/hardware_test_controller.dart';
import 'package:markazi_system_checker/controllers/theme_language_controller.dart';
import 'package:markazi_system_checker/widgets/hardware_tests/keyboard_test_view.dart';
import 'package:markazi_system_checker/widgets/hardware_tests/monitor_test_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Get.reset();
    Get.put(ThemeLanguageController());
  });

  tearDown(() {
    Get.reset();
  });

  // =========================================================================
  // R1 CHALLENGE SUITE: Keyboard Mouse Decoupling, Physical Chords & Scaling
  // =========================================================================
  group('R1 Adversarial Challenge: Keyboard Mouse Decoupling', () {
    testWidgets('Rapid and multi-cluster mouse clicks on on-screen keys produce ZERO state changes or hit increments', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final ctrl = Get.put(HardwareTestController());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: KeyboardTestView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(ctrl.totalKeyHits.value, 0);
      expect(ctrl.testedKeys.isEmpty, isTrue);
      expect(ctrl.activeKeys.isEmpty, isTrue);
      expect(ctrl.lastKeyCode.value, '-');

      // Diverse sample of key labels across all clusters:
      // Main cluster: Esc, F1, F12, Tab, Caps, Q, A, Z, Space, Enter ↵, Shift ⇧
      // Nav cluster: PrtSc, Ins, Del, ▲, ◀, ▼, ▶
      // Numpad cluster: Num, /, *, -, 7, 4, 1, 0, .
      final keyLabelsToTest = [
        'Esc', 'F1', 'F5', 'F12',
        '`', '1', 'Backspace',
        'Tab', 'Q', 'W', 'E',
        'Caps', 'A', 'S', 'D', 'Enter ↵',
        'Shift ⇧', 'Z', 'X', 'C',
        'Ctrl', 'Win', 'Alt', 'Space',
        'PrtSc', 'Ins', 'Del', '▲', '◀', '▼', '▶',
        'Num', '/', '*', '-', '7', '4', '1', '0', '.',
      ];

      for (final label in keyLabelsToTest) {
        final finder = find.text(label);
        if (finder.evaluate().isNotEmpty) {
          // Rapid mouse clicks with warnIfMissed: false (since IgnorePointer intentionally swallows pointer events)
          await tester.tap(finder.first, warnIfMissed: false);
          await tester.pump(const Duration(milliseconds: 10));
          await tester.tap(finder.first, warnIfMissed: false);
          await tester.pump(const Duration(milliseconds: 10));
        }
      }

      // Assert that despite clicking across every key cluster, zero keys registered as tested
      expect(ctrl.totalKeyHits.value, 0, reason: 'Mouse clicks must never increment totalKeyHits');
      expect(ctrl.testedKeys.isEmpty, isTrue, reason: 'Mouse clicks must never populate testedKeys');
      expect(ctrl.activeKeys.isEmpty, isTrue, reason: 'Mouse clicks must never populate activeKeys');
      expect(ctrl.lastKeyCode.value, '-', reason: 'Mouse clicks must never change lastKeyCode');

      // Concurrent multi-pointer taps at various coordinates
      final gesture1 = await tester.startGesture(const Offset(300, 200));
      final gesture2 = await tester.startGesture(const Offset(600, 250));
      final gesture3 = await tester.startGesture(const Offset(900, 300));
      await tester.pump(const Duration(milliseconds: 50));
      await gesture1.up();
      await gesture2.up();
      await gesture3.up();
      await tester.pump();

      expect(ctrl.totalKeyHits.value, 0);
      expect(ctrl.testedKeys.isEmpty, isTrue);
    });

    testWidgets('Physical keyboard events handle rapid keypresses, simultaneous chords, and key releases', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final ctrl = Get.put(HardwareTestController());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: KeyboardTestView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Rapid sequential key presses
      final rapidKeys = [
        LogicalKeyboardKey.digit1,
        LogicalKeyboardKey.digit2,
        LogicalKeyboardKey.keyQ,
        LogicalKeyboardKey.keyW,
        LogicalKeyboardKey.space,
        LogicalKeyboardKey.enter,
      ];

      for (final k in rapidKeys) {
        await tester.sendKeyEvent(k);
        await tester.pump(const Duration(milliseconds: 15));
      }

      expect(ctrl.totalKeyHits.value, 6);
      expect(ctrl.testedKeys.contains('Digit1'), isTrue);
      expect(ctrl.testedKeys.contains('Digit2'), isTrue);
      expect(ctrl.testedKeys.contains('KeyQ'), isTrue);
      expect(ctrl.testedKeys.contains('KeyW'), isTrue);
      expect(ctrl.testedKeys.contains('Space'), isTrue);
      expect(ctrl.testedKeys.contains('Enter'), isTrue);
      expect(ctrl.activeKeys.isEmpty, isTrue); // All released

      // 2. Simultaneous Chords: Hold Ctrl + Shift + A
      // Press & hold Left Ctrl
      await tester.sendKeyDownEvent(
        LogicalKeyboardKey.controlLeft,
        platform: 'windows',
        physicalKey: PhysicalKeyboardKey.controlLeft,
      );
      await tester.pump();
      expect(ctrl.activeKeys.contains('ControlLeft'), isTrue);
      expect(ctrl.totalKeyHits.value, 7);

      // Press & hold Left Shift while Ctrl is held
      await tester.sendKeyDownEvent(
        LogicalKeyboardKey.shiftLeft,
        platform: 'windows',
        physicalKey: PhysicalKeyboardKey.shiftLeft,
      );
      await tester.pump();
      expect(ctrl.activeKeys.contains('ControlLeft'), isTrue);
      expect(ctrl.activeKeys.contains('ShiftLeft'), isTrue);
      expect(ctrl.totalKeyHits.value, 8);

      // Press & release KeyA while both modifiers are held
      await tester.sendKeyDownEvent(
        LogicalKeyboardKey.keyA,
        platform: 'windows',
        physicalKey: PhysicalKeyboardKey.keyA,
      );
      await tester.pump();
      expect(ctrl.activeKeys.contains('KeyA'), isTrue);
      expect(ctrl.totalKeyHits.value, 9);

      await tester.sendKeyUpEvent(
        LogicalKeyboardKey.keyA,
        platform: 'windows',
        physicalKey: PhysicalKeyboardKey.keyA,
      );
      await tester.pump();
      expect(ctrl.activeKeys.contains('KeyA'), isFalse);
      expect(ctrl.activeKeys.contains('ControlLeft'), isTrue);
      expect(ctrl.activeKeys.contains('ShiftLeft'), isTrue);

      // Release ShiftLeft
      await tester.sendKeyUpEvent(
        LogicalKeyboardKey.shiftLeft,
        platform: 'windows',
        physicalKey: PhysicalKeyboardKey.shiftLeft,
      );
      await tester.pump();
      expect(ctrl.activeKeys.contains('ShiftLeft'), isFalse);
      expect(ctrl.activeKeys.contains('ControlLeft'), isTrue);

      // Release ControlLeft
      await tester.sendKeyUpEvent(
        LogicalKeyboardKey.controlLeft,
        platform: 'windows',
        physicalKey: PhysicalKeyboardKey.controlLeft,
      );
      await tester.pump();
      expect(ctrl.activeKeys.isEmpty, isTrue);

      // Verify all chord keys are permanently in testedKeys
      expect(ctrl.testedKeys.contains('ControlLeft'), isTrue);
      expect(ctrl.testedKeys.contains('ShiftLeft'), isTrue);
      expect(ctrl.testedKeys.contains('KeyA'), isTrue);
    });

    testWidgets('Modifier discrimination cleanly separates Left and Right counterparts', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final ctrl = Get.put(HardwareTestController());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: KeyboardTestView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Test ShiftLeft vs ShiftRight
      await tester.sendKeyEvent(
        LogicalKeyboardKey.shiftLeft,
        platform: 'windows',
        physicalKey: PhysicalKeyboardKey.shiftLeft,
      );
      await tester.pump();
      expect(ctrl.testedKeys.contains('ShiftLeft'), isTrue);
      expect(ctrl.testedKeys.contains('ShiftRight'), isFalse);

      await tester.sendKeyEvent(
        LogicalKeyboardKey.shiftRight,
        platform: 'windows',
        physicalKey: PhysicalKeyboardKey.shiftRight,
      );
      await tester.pump();
      expect(ctrl.testedKeys.contains('ShiftRight'), isTrue);

      // Test ControlLeft vs ControlRight
      await tester.sendKeyEvent(
        LogicalKeyboardKey.controlLeft,
        platform: 'windows',
        physicalKey: PhysicalKeyboardKey.controlLeft,
      );
      await tester.pump();
      expect(ctrl.testedKeys.contains('ControlLeft'), isTrue);
      expect(ctrl.testedKeys.contains('ControlRight'), isFalse);

      await tester.sendKeyEvent(
        LogicalKeyboardKey.controlRight,
        platform: 'windows',
        physicalKey: PhysicalKeyboardKey.controlRight,
      );
      await tester.pump();
      expect(ctrl.testedKeys.contains('ControlRight'), isTrue);

      // Test AltLeft vs AltRight
      await tester.sendKeyEvent(
        LogicalKeyboardKey.altLeft,
        platform: 'windows',
        physicalKey: PhysicalKeyboardKey.altLeft,
      );
      await tester.pump();
      expect(ctrl.testedKeys.contains('AltLeft'), isTrue);
      expect(ctrl.testedKeys.contains('AltRight'), isFalse);

      await tester.sendKeyEvent(
        LogicalKeyboardKey.altRight,
        platform: 'windows',
        physicalKey: PhysicalKeyboardKey.altRight,
      );
      await tester.pump();
      expect(ctrl.testedKeys.contains('AltRight'), isTrue);
    });

    testWidgets('Layout scaling across extreme window sizes (2560x1440 down to 800x600) produces ZERO overflow and ZERO scrollbars', (tester) async {
      final testResolutions = [
        const Size(2560, 1440), // QHD
        const Size(1920, 1080), // FHD
        const Size(1366, 768),  // Standard Laptop
        const Size(1024, 768),  // XGA Compact
        const Size(800, 600),   // SVGA Minimal Boundary
      ];

      Get.put(HardwareTestController());

      for (final res in testResolutions) {
        tester.view.physicalSize = res;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: KeyboardTestView(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Assert zero RenderFlex overflow or layout exceptions
        expect(
          tester.takeException(),
          isNull,
          reason: 'Resolution ${res.width}x${res.height} must not throw layout exceptions',
        );

        // 2. Assert zero Scrollbar widgets inside KeyboardTestView
        final scrollbars = find.descendant(
          of: find.byType(KeyboardTestView),
          matching: find.byType(Scrollbar),
        );
        expect(
          scrollbars,
          findsNothing,
          reason: 'KeyboardTestView must not contain scrollbars at ${res.width}x${res.height}',
        );

        // 3. Assert zero Scrollable widgets inside KeyboardTestView (view fits strictly in viewport)
        final scrollables = find.descendant(
          of: find.byType(KeyboardTestView),
          matching: find.byType(Scrollable),
        );
        expect(
          scrollables,
          findsNothing,
          reason: 'KeyboardTestView must not create scrollable viewports at ${res.width}x${res.height}',
        );
      }

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });

  // =========================================================================
  // R2 CHALLENGE SUITE: Monitor Fullscreen Keyboard Navigation Edge Cases
  // =========================================================================
  group('R2 Adversarial Challenge: Monitor Fullscreen Navigation & Clean Teardown', () {
    testWidgets('Boundary transition: advances through colors 0..7 to 8 and exits fullscreen on next advance', (tester) async {
      final List<Map<String, dynamic>> channelCalls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('markazi/window'), (call) async {
        channelCalls.add({'method': call.method, 'arguments': call.arguments});
        return null;
      });

      final ctrl = Get.put(HardwareTestController());
      ctrl.setMonitorColor(0);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MonitorTestView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Launch fullscreen
      final btnFinder = find.text('شروع تست تمام‌صفحه');
      await tester.scrollUntilVisible(btnFinder, 100);
      await tester.tap(btnFinder);
      await tester.pumpAndSettle();

      expect(ctrl.isMonitorFullScreen.value, isTrue);
      expect(ctrl.monitorIndex.value, 0);

      // Advance through colors 0 to 7 with ArrowRight
      for (int i = 0; i < 7; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        expect(ctrl.monitorIndex.value, i + 1);
        expect(ctrl.isMonitorFullScreen.value, isTrue);
      }

      // Now at index 7 (Magenta). Press ArrowRight to reach index 8 (Grey 50%)
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(ctrl.monitorIndex.value, 8);
      expect(ctrl.isMonitorFullScreen.value, isTrue);
      expect(find.byKey(const ValueKey('monitor-fullscreen-color-canvas')), findsOneWidget);

      // Press ArrowRight at the final color (index 8): MUST exit fullscreen
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();

      expect(ctrl.isMonitorFullScreen.value, isFalse);
      expect(find.byKey(const ValueKey('monitor-fullscreen-color-canvas')), findsNothing);
      expect(
        channelCalls.where((c) => c['method'] == 'setFullScreen' && c['arguments'] == false).isNotEmpty,
        isTrue,
        reason: 'setFullScreen(false) must be called upon exiting fullscreen',
      );

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('markazi/window'), null);
    });

    testWidgets('Backward cycling: ArrowLeft from 0 wraps to 8 without exiting fullscreen, then ArrowUp exits', (tester) async {
      final List<Map<String, dynamic>> channelCalls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('markazi/window'), (call) async {
        channelCalls.add({'method': call.method, 'arguments': call.arguments});
        return null;
      });

      final ctrl = Get.put(HardwareTestController());
      ctrl.setMonitorColor(0);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MonitorTestView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final btnFinder = find.text('شروع تست تمام‌صفحه');
      await tester.scrollUntilVisible(btnFinder, 100);
      await tester.tap(btnFinder);
      await tester.pumpAndSettle();

      expect(ctrl.isMonitorFullScreen.value, isTrue);
      expect(ctrl.monitorIndex.value, 0);

      // Press ArrowLeft at color 0 -> wraps to last color (8)
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(ctrl.monitorIndex.value, 8);
      expect(ctrl.isMonitorFullScreen.value, isTrue);

      // Press ArrowDown from 8 -> goes to 7
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(ctrl.monitorIndex.value, 7);

      // Press ArrowUp from 7 -> goes back to 8
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(ctrl.monitorIndex.value, 8);

      // Press ArrowUp at 8 -> advancing past final color exits fullscreen
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();

      expect(ctrl.isMonitorFullScreen.value, isFalse);
      expect(find.byKey(const ValueKey('monitor-fullscreen-color-canvas')), findsNothing);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('markazi/window'), null);
    });

    testWidgets('Space bar advances color and exits past final color', (tester) async {
      final List<Map<String, dynamic>> channelCalls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('markazi/window'), (call) async {
        channelCalls.add({'method': call.method, 'arguments': call.arguments});
        return null;
      });

      final ctrl = Get.put(HardwareTestController());
      ctrl.setMonitorColor(7);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MonitorTestView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final btnFinder = find.text('شروع تست تمام‌صفحه');
      await tester.scrollUntilVisible(btnFinder, 100);
      await tester.tap(btnFinder);
      await tester.pumpAndSettle();

      expect(ctrl.monitorIndex.value, 7);

      // Press Space bar -> advances to 8
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(ctrl.monitorIndex.value, 8);
      expect(ctrl.isMonitorFullScreen.value, isTrue);

      // Press Space bar at 8 -> exits fullscreen
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(ctrl.isMonitorFullScreen.value, isFalse);
      expect(find.byKey(const ValueKey('monitor-fullscreen-color-canvas')), findsNothing);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('markazi/window'), null);
    });

    testWidgets('Escape key exits fullscreen immediately from any color without leaks', (tester) async {
      final List<Map<String, dynamic>> channelCalls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('markazi/window'), (call) async {
        channelCalls.add({'method': call.method, 'arguments': call.arguments});
        return null;
      });

      final ctrl = Get.put(HardwareTestController());

      // Test Escape at colors 0, 4, and 8
      for (final testIndex in [0, 4, 8]) {
        ctrl.setMonitorColor(testIndex);

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MonitorTestView(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final btnFinder = find.text('شروع تست تمام‌صفحه');
        await tester.scrollUntilVisible(btnFinder, 100);
        await tester.tap(btnFinder);
        await tester.pumpAndSettle();

        expect(ctrl.isMonitorFullScreen.value, isTrue);
        expect(ctrl.monitorIndex.value, testIndex);

        // Press Escape
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();

        expect(ctrl.isMonitorFullScreen.value, isFalse);
        expect(find.byKey(const ValueKey('monitor-fullscreen-color-canvas')), findsNothing);
      }

      // Check that setFullScreen(false) was called 3 times
      final falseCalls = channelCalls.where((c) => c['method'] == 'setFullScreen' && c['arguments'] == false);
      expect(falseCalls.length, 3);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('markazi/window'), null);
    });

    testWidgets('Mouse click (left tap and right click) in fullscreen advances and retreats correctly', (tester) async {
      final ctrl = Get.put(HardwareTestController());
      ctrl.setMonitorColor(0);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MonitorTestView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final btnFinder = find.text('شروع تست تمام‌صفحه');
      await tester.scrollUntilVisible(btnFinder, 100);
      await tester.tap(btnFinder);
      await tester.pumpAndSettle();

      final canvasFinder = find.byKey(const ValueKey('monitor-fullscreen-color-canvas'));
      expect(canvasFinder, findsOneWidget);

      // Left click -> advances color
      await tester.tap(canvasFinder);
      await tester.pump();
      expect(ctrl.monitorIndex.value, 1);

      await tester.tap(canvasFinder);
      await tester.pump();
      expect(ctrl.monitorIndex.value, 2);

      // Secondary click (right click) -> retreats color
      await tester.tap(canvasFinder, buttons: kSecondaryMouseButton);
      await tester.pump();
      expect(ctrl.monitorIndex.value, 1);

      // Clean exit via Esc
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(ctrl.isMonitorFullScreen.value, isFalse);
    });
  });
}
