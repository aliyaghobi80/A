// frontend/test/hardware_test_controller_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:markazi_system_checker/controllers/hardware_test_controller.dart';
import 'package:markazi_system_checker/models/hardware_test_result.dart';

void main() {
  group('HardwareTestController & HardwareTestResult Tests', () {
    late HardwareTestController controller;

    setUp(() {
      controller = HardwareTestController();
    });

    test('initial state is correct', () {
      expect(controller.activeSubTest.value, 'hub');
      expect(controller.isAccordionExpanded.value, false);
      expect(controller.testResults.isEmpty, true);
      expect(controller.totalTestsCount, 0);
      expect(controller.passedTestsCount, 0);
      expect(controller.failedTestsCount, 0);
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

      controller.selectSubTest('report');
      expect(controller.activeSubTest.value, 'report');
    });

    test('toggleAccordion flips accordion state', () {
      expect(controller.isAccordionExpanded.value, false);
      controller.toggleAccordion();
      expect(controller.isAccordionExpanded.value, true);
      controller.toggleAccordion();
      expect(controller.isAccordionExpanded.value, false);
    });

    test('recordResult tracks passed and failed tests accurately', () {
      controller.recordResult(
        testName: 'مانیتور و صفحه نمایش',
        status: 'passed',
        details: 'بدون پیکسل سوخته',
      );

      controller.recordResult(
        testName: 'اسپیکر و هدفون',
        status: 'failed',
        details: 'کانال چپ صدا ندارد',
      );

      controller.recordResult(
        testName: 'میکروفون',
        status: 'passed',
        details: 'تست ضبط و پخش لوپ‌بک موفق',
      );

      expect(controller.totalTestsCount, 3);
      expect(controller.passedTestsCount, 2);
      expect(controller.failedTestsCount, 1);

      // Most recent result is first
      expect(controller.testResults.first.testName, 'میکروفون');
      expect(controller.testResults.first.isPassed, true);
      expect(controller.testResults.first.localizedStatus, 'موفق');

      expect(controller.testResults[1].testName, 'اسپیکر و هدفون');
      expect(controller.testResults[1].isFailed, true);
      expect(controller.testResults[1].localizedStatus, 'نیازمند بررسی');
    });

    test('getFormattedReport contains Persian branding and summary', () {
      controller.recordResult(
        testName: 'کیبورد',
        status: 'passed',
        details: 'تمام کلیدها سالم هستند',
      );

      final report = controller.getFormattedReport();
      expect(report.contains('مرکزی سیستم چکر'), true);
      expect(report.contains('کیبورد'), true);
      expect(report.contains('تأییدیه فنی کامپیوتر مرکزی'), true);
      expect(report.contains('کل تست‌ها: 1'), true);
      expect(report.contains('موفق: 1'), true);
      expect(report.contains('نیازمند بررسی: 0'), true);
    });

    test('clearResults removes all test records', () {
      controller.recordResult(
        testName: 'موس',
        status: 'passed',
        details: 'کلیک‌ها و اسکرول سالم',
      );
      expect(controller.totalTestsCount, 1);

      controller.clearResults();
      expect(controller.totalTestsCount, 0);
      expect(controller.testResults.isEmpty, true);
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

    test('mouse test counters increment properly', () {
      expect(controller.mouseLeftClicks.value, 0);
      controller.onMouseButton('left');
      expect(controller.mouseLeftClicks.value, 1);

      expect(controller.mouseRightClicks.value, 0);
      controller.onMouseButton('right');
      expect(controller.mouseRightClicks.value, 1);

      expect(controller.mouseMiddleClicks.value, 0);
      controller.onMouseButton('middle');
      expect(controller.mouseMiddleClicks.value, 1);

      controller.resetMouse();
      expect(controller.mouseLeftClicks.value, 0);
      expect(controller.mouseRightClicks.value, 0);
      expect(controller.mouseMiddleClicks.value, 0);
    });

    test('HardwareTestResult serialization round-trip', () {
      final now = DateTime(2026, 10, 28, 14, 30);
      final r1 = HardwareTestResult(
        testName: 'وب‌کم',
        status: 'passed',
        details: 'دوربین بدون نویز',
        timestamp: now,
      );

      final json = r1.toJson();
      final r2 = HardwareTestResult.fromJson(json);

      expect(r2.testName, 'وب‌کم');
      expect(r2.status, 'passed');
      expect(r2.details, 'دوربین بدون نویز');
      expect(r2.timestamp.toIso8601String(), now.toIso8601String());
    });
  });
}
