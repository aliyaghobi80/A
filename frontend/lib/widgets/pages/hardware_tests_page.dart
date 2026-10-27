// frontend/lib/widgets/pages/hardware_tests_page.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/hardware_test_controller.dart';
import '../hardware_tests/audio_test_view.dart';
import '../hardware_tests/keyboard_test_view.dart';
import '../hardware_tests/mic_test_view.dart';
import '../hardware_tests/monitor_test_view.dart';
import '../hardware_tests/mouse_test_view.dart';
import '../hardware_tests/test_hub_view.dart';
import '../hardware_tests/test_report_view.dart';
import '../hardware_tests/webcam_test_view.dart';

class HardwareTestsPage extends StatelessWidget {
  const HardwareTestsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final HardwareTestController ctrl = Get.find<HardwareTestController>();

    return Obx(() {
      final active = ctrl.activeSubTest.value;
      switch (active) {
        case 'monitor':
          return const MonitorTestView();
        case 'audio':
          return const AudioTestView();
        case 'mic':
          return const MicTestView();
        case 'webcam':
          return const WebcamTestView();
        case 'keyboard':
          return const KeyboardTestView();
        case 'mouse':
          return const MouseTestView();
        case 'report':
          return const TestReportView();
        case 'hub':
        default:
          return const TestHubView();
      }
    });
  }
}
