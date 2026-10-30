// frontend/test/mic_test_view_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:markazi_system_checker/controllers/hardware_test_controller.dart';
import 'package:markazi_system_checker/services/api_service.dart';
import 'package:markazi_system_checker/widgets/hardware_tests/mic_test_view.dart';

class _MockMicApiService extends ApiService {
  bool fetchMicCalled = false;
  double lastRecordedDuration = 0.0;
  List<Map<String, dynamic>> mockMics = [
    {'name': 'Microphone Array (Realtek Audio)', 'status': 'OK', 'manufacturer': 'Realtek'},
  ];

  @override
  Future<List<Map<String, dynamic>>> fetchMicDevices() async {
    fetchMicCalled = true;
    return mockMics;
  }

  @override
  Future<Map<String, dynamic>> startMicLoopback({double duration = 3.0}) async {
    lastRecordedDuration = duration;
    return {'status': 'started', 'duration': duration};
  }

  @override
  Future<Map<String, dynamic>> fetchMicLoopbackStatus() async {
    return {
      'is_busy': false,
      'phase': 'idle',
      'message': 'آماده بررسی',
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Get.reset();
  });

  tearDown(() {
    Get.reset();
  });

  group('Microphone Test & Live Ambient Monitoring (R4)', () {
    testWidgets('Mounts MicTestView and verifies automatic live ambient monitoring & waveform heights', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockApi = _MockMicApiService();
      final ctrl = Get.put(HardwareTestController(apiService: mockApi));

      expect(ctrl.isLiveMicMonitoring.value, isFalse);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MicTestView(),
          ),
        ),
      );
      await tester.pump();

      // Upon mount, live monitoring should automatically activate
      expect(ctrl.isLiveMicMonitoring.value, isTrue);
      expect(ctrl.liveWaveformHeights.length, equals(24));
      expect(find.text('تست میکروفون، سنجش صدای محیط و لوپ‌بک'), findsOneWidget);
      expect(find.textContaining('سطح صدای ورودی زنده:'), findsOneWidget);

      // Advance periodic timer for live waveform simulation
      await tester.pump(const Duration(milliseconds: 100));
      expect(ctrl.liveWaveformHeights.any((h) => h > 4.0), isTrue);

      // Unmount by pumping a replacement widget
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
      await tester.pump();

      // On dispose, live monitoring should be stopped
      expect(ctrl.isLiveMicMonitoring.value, isFalse);
    });

    testWidgets('Quick Test buttons (3s and 5s) trigger startQuickTest with specified durations', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockApi = _MockMicApiService();
      final ctrl = Get.put(HardwareTestController(apiService: mockApi));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MicTestView(),
          ),
        ),
      );
      await tester.pump();

      // 1. Trigger 3s Quick Test
      final quick3Btn = find.text('آزمون سریع ۳ ثانیه‌ای (خودکار)');
      expect(quick3Btn, findsOneWidget);
      await tester.tap(quick3Btn);
      await tester.pump();

      expect(mockApi.lastRecordedDuration, equals(3.0));
      expect(ctrl.isMicBusy.value, isTrue);
      expect(ctrl.micPhase.value, equals('recording'));

      // Clean up controller timers
      ctrl.resetRecording();
      await tester.pump();

      // 2. Trigger 5s Quick Test
      final quick5Btn = find.text('آزمون سریع ۵ ثانیه‌ای (خودکار)');
      expect(quick5Btn, findsOneWidget);
      await tester.tap(quick5Btn);
      await tester.pump();

      expect(mockApi.lastRecordedDuration, equals(5.0));
      expect(ctrl.isMicBusy.value, isTrue);

      ctrl.resetRecording();
      ctrl.stopLiveMicMonitoring();
      await tester.pump();
    });

    testWidgets('Manual recording lifecycle: start, stop, playback, and reset', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockApi = _MockMicApiService();
      final ctrl = Get.put(HardwareTestController(apiService: mockApi));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MicTestView(),
          ),
        ),
      );
      await tester.pump();

      // 1. Start Manual Recording
      final startManualBtn = find.text('شروع ضبط دستی');
      expect(startManualBtn, findsOneWidget);
      await tester.tap(startManualBtn);
      await tester.pump();

      expect(ctrl.isManualMode.value, isTrue);
      expect(ctrl.micPhase.value, equals('recording'));
      expect(ctrl.isMicBusy.value, isTrue);

      // Advance 1 second
      await tester.pump(const Duration(seconds: 1));
      expect(ctrl.elapsedManualSeconds.value, greaterThanOrEqualTo(1));

      // 2. Stop Manual Recording
      final stopManualBtn = find.text('توقف ضبط دستی');
      expect(stopManualBtn, findsOneWidget);
      await tester.tap(stopManualBtn);
      await tester.pump();

      expect(ctrl.hasRecordedAudio.value, isTrue);
      expect(ctrl.micPhase.value, equals('completed'));

      // 3. Play Recorded Audio
      final playBtn = find.text('بازپخش صدای ضبط‌شده');
      expect(playBtn, findsOneWidget);
      await tester.tap(playBtn);
      await tester.pump();

      expect(ctrl.micPhase.value, equals('playing'));

      // Advance past 3-second playback timer
      await tester.pump(const Duration(seconds: 3));
      expect(ctrl.micPhase.value, equals('completed'));

      // 4. Reset Recording
      final resetBtn = find.text('بازنشانی');
      expect(resetBtn, findsOneWidget);
      await tester.tap(resetBtn);
      await tester.pump();

      expect(ctrl.hasRecordedAudio.value, isFalse);
      expect(ctrl.micPhase.value, equals('idle'));

      ctrl.stopLiveMicMonitoring();
      await tester.pump();
    });

    testWidgets('Renders detected microphone devices from controller', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockApi = _MockMicApiService();
      final ctrl = Get.put(HardwareTestController(apiService: mockApi));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MicTestView(),
          ),
        ),
      );
      // Pump to trigger initState and resolve fetchMicDevices future
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Devices list populated
      expect(find.text('Microphone Array (Realtek Audio)'), findsOneWidget);
      expect(find.text('OK'), findsOneWidget);
      expect(find.text('دستگاه‌های صوتی ورودی شناسایی‌شده در ویندوز:'), findsOneWidget);

      ctrl.stopLiveMicMonitoring();
      await tester.pump();
    });
  });
}
