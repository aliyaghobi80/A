// frontend/test/hardware_test_controller_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:markazi_system_checker/controllers/hardware_test_controller.dart';

void main() {
  group('HardwareTestController Unit Tests', () {
    late HardwareTestController controller;

    setUp(() {
      controller = HardwareTestController();
    });

    test('initial state is correct', () {
      expect(controller.activeSubTest.value, 'hub');
      expect(controller.isAccordionExpanded.value, false);
      expect(controller.totalKeyHits.value, 0);
      expect(controller.keyHits.isEmpty, true);
      expect(controller.heldMouseButtons.isEmpty, true);
    });

    test('selectSubTest updates active view', () {
      controller.selectSubTest('monitor');
      expect(controller.activeSubTest.value, 'monitor');

      controller.selectSubTest('audio');
      expect(controller.activeSubTest.value, 'audio');

      controller.selectSubTest('keyboard');
      expect(controller.activeSubTest.value, 'keyboard');

      controller.selectSubTest('mouse');
      expect(controller.activeSubTest.value, 'mouse');

      controller.selectSubTest('webcam');
      expect(controller.activeSubTest.value, 'webcam');

      controller.selectSubTest('mic');
      expect(controller.activeSubTest.value, 'mic');
    });

    test('toggleAccordion flips accordion state', () {
      expect(controller.isAccordionExpanded.value, false);
      controller.toggleAccordion();
      expect(controller.isAccordionExpanded.value, true);
      controller.toggleAccordion();
      expect(controller.isAccordionExpanded.value, false);
    });

    test('monitor test color navigation cycles through 9 patterns', () {
      expect(HardwareTestController.monitorColors.length, 9);
      expect(controller.monitorIndex.value, 0);

      controller.nextMonitorColor();
      expect(controller.monitorIndex.value, 1);

      controller.prevMonitorColor();
      expect(controller.monitorIndex.value, 0);

      controller.prevMonitorColor();
      expect(controller.monitorIndex.value, 8); // Wraps around to last

      controller.nextMonitorColor();
      expect(controller.monitorIndex.value, 0); // Wraps back to 0
    });

    test('keyboard key hits and hit counters track accurately', () {
      expect(controller.totalKeyHits.value, 0);
      expect(controller.testedKeys.contains('KeyA'), false);

      controller.onKeyDown('KeyA', 'A');
      expect(controller.activeKeys.contains('KeyA'), true);
      expect(controller.testedKeys.contains('KeyA'), true);
      expect(controller.keyHits['KeyA'], 1);
      expect(controller.totalKeyHits.value, 1);
      expect(controller.lastKeyLabel.value, 'A');

      controller.onKeyUp('KeyA');
      expect(controller.activeKeys.contains('KeyA'), false);
      expect(controller.testedKeys.contains('KeyA'), true);

      // Second press on KeyA increments count
      controller.onKeyDown('KeyA', 'A');
      expect(controller.keyHits['KeyA'], 2);
      expect(controller.totalKeyHits.value, 2);

      controller.resetKeyboard();
      expect(controller.testedKeys.isEmpty, true);
      expect(controller.activeKeys.isEmpty, true);
      expect(controller.keyHits.isEmpty, true);
      expect(controller.totalKeyHits.value, 0);
    });

    test('mouse 5-button hold, drag, and double click detection', () {
      // 1. Left button down (bit 1)
      controller.onPointerDown(1, const Offset(100, 100));
      expect(controller.heldMouseButtons.contains(1), true);
      expect(controller.mouseLeftClicks.value, 1);

      // 2. Dragging while held
      controller.onPointerMove(const Offset(110, 110), hasButtons: true);
      expect(controller.isMouseDragging.value, true);
      expect(controller.mouseMoveCount.value, 1);

      // 3. Pointer up
      controller.onPointerUp(0);
      expect(controller.heldMouseButtons.contains(1), false);
      expect(controller.isMouseDragging.value, false);

      // 4. Side 1 (bit 8) and Side 2 (bit 16)
      controller.onPointerDown(8, const Offset(50, 50));
      expect(controller.heldMouseButtons.contains(8), true);
      expect(controller.mouseSide1Clicks.value, 1);
      controller.onPointerUp(0);

      controller.onPointerDown(16, const Offset(50, 50));
      expect(controller.heldMouseButtons.contains(16), true);
      expect(controller.mouseSide2Clicks.value, 1);
      controller.onPointerUp(0);

      // 5. Fast double click (< 300ms) on Left
      controller.onPointerDown(1, const Offset(100, 100));
      controller.onPointerUp(0);
      controller.onPointerDown(1, const Offset(100, 100));
      controller.onPointerUp(0);
      expect(controller.mouseDoubleClicks.value, 1);

      // 6. Reset
      controller.resetMouse();
      expect(controller.mouseLeftClicks.value, 0);
      expect(controller.mouseSide1Clicks.value, 0);
      expect(controller.mouseSide2Clicks.value, 0);
      expect(controller.mouseDoubleClicks.value, 0);
      expect(controller.mouseMoveCount.value, 0);
      expect(controller.heldMouseButtons.isEmpty, true);
    });
  });
}
