// frontend/test/keyboard_test_view_test.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:markazi_system_checker/controllers/hardware_test_controller.dart';
import 'package:markazi_system_checker/widgets/hardware_tests/keyboard_test_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Get.reset();
  });

  tearDown(() {
    Get.reset();
  });

  group('Keyboard Diagnostics Tests (R1)', () {
    testWidgets('Clicking keyboard keycaps with mouse produces ZERO change in key state or hits', (tester) async {
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

      // Find Key A by text 'A'
      final keyFinder = find.text('A');
      expect(keyFinder, findsOneWidget);

      // 1. Mouse click on key 'A' (warnIfMissed: false because key is wrapped in IgnorePointer)
      await tester.tap(keyFinder, warnIfMissed: false);
      await tester.pump();

      // Verify mouse click was completely ignored: ZERO state changes
      expect(ctrl.totalKeyHits.value, 0);
      expect(ctrl.testedKeys.contains('KeyA'), isFalse);
      expect(ctrl.activeKeys.contains('KeyA'), isFalse);
      expect(ctrl.lastKeyCode.value, '-');

      // 2. Physical keyboard event for KeyA
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.pump();

      // Verify physical keypress registered properly
      expect(ctrl.totalKeyHits.value, 1);
      expect(ctrl.testedKeys.contains('KeyA'), isTrue);
      expect(ctrl.lastKeyLabel.value, 'A');
      expect(ctrl.lastKeyCode.value, 'KeyA');
    });

    testWidgets('Modifier keys (ShiftLeft / ShiftRight) discriminate physical key events cleanly', (tester) async {
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

      // Press Left Shift
      await tester.sendKeyEvent(
        LogicalKeyboardKey.shiftLeft,
        platform: 'windows',
        physicalKey: PhysicalKeyboardKey.shiftLeft,
      );
      await tester.pump();

      expect(ctrl.testedKeys.contains('ShiftLeft'), isTrue);
      expect(ctrl.totalKeyHits.value, 1);

      // Press Right Shift
      await tester.sendKeyEvent(
        LogicalKeyboardKey.shiftRight,
        platform: 'windows',
        physicalKey: PhysicalKeyboardKey.shiftRight,
      );
      await tester.pump();

      expect(ctrl.testedKeys.contains('ShiftRight'), isTrue);
      expect(ctrl.totalKeyHits.value, 2);
    });

    testWidgets('Reset button clears tested keys and hit counters', (tester) async {
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

      // Press Space key
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();

      expect(ctrl.testedKeys.contains('Space'), isTrue);
      expect(ctrl.totalKeyHits.value, 1);

      // Tap Reset button in floating bar or bottom bar
      final resetButtons = find.byIcon(Icons.refresh_rounded);
      expect(resetButtons, findsWidgets);
      await tester.tap(resetButtons.first);
      await tester.pump();

      expect(ctrl.testedKeys.isEmpty, isTrue);
      expect(ctrl.totalKeyHits.value, 0);
      expect(ctrl.lastKeyLabel.value, 'آماده دریافت کلید');
    });

    testWidgets('Full HD (1920x1080) viewport scales responsively with zero overflow', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      Get.put(HardwareTestController());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: KeyboardTestView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(KeyboardTestView), findsOneWidget);
    });

    testWidgets('Standard narrow viewport (1024x768) scales down with zero RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      Get.put(HardwareTestController());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: KeyboardTestView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(KeyboardTestView), findsOneWidget);
    });
  });
}
