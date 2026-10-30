// frontend/test/challenger_media_diagnostics_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:markazi_system_checker/controllers/hardware_test_controller.dart';
import 'package:markazi_system_checker/services/api_service.dart';
import 'package:markazi_system_checker/services/winmm_audio_player.dart';
import 'package:markazi_system_checker/widgets/hardware_tests/mic_test_view.dart';
import 'package:markazi_system_checker/widgets/hardware_tests/webcam_test_view.dart';

class _AdversarialMockApiService extends ApiService {
  int fetchCameraCallCount = 0;
  int fetchMicCallCount = 0;
  int startLoopbackCallCount = 0;
  double lastRecordedDuration = 0.0;

  List<Map<String, dynamic>> cameraList = [
    {'name': 'HD Pro Webcam C920', 'status': 'OK', 'manufacturer': 'Logitech'},
    {'name': 'Integrated IR Camera', 'status': 'OK', 'manufacturer': 'Realtek'},
    {'name': 'OBS Virtual Camera', 'status': 'OK', 'manufacturer': 'OBS Project'},
  ];

  List<Map<String, dynamic>> micList = [
    {'name': 'Microphone (Realtek High Definition Audio)', 'status': 'OK'},
    {'name': 'Yeti Stereo Microphone (Blue Microphones)', 'status': 'OK'},
  ];

  @override
  Future<List<Map<String, dynamic>>> fetchCameraDevices() async {
    fetchCameraCallCount++;
    return cameraList;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchMicDevices() async {
    fetchMicCallCount++;
    return micList;
  }

  @override
  Future<Map<String, dynamic>> startMicLoopback({double duration = 3.0}) async {
    startLoopbackCallCount++;
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

class _MockWinmmAudioPlayer extends WinmmAudioPlayer {
  @override
  Future<void> playAsset(String assetPath, {double volume = 1.0, String channel = 'both', Duration duration = const Duration(seconds: 2)}) async {}

  @override
  void stop() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _AdversarialMockApiService mockApi;
  late _MockWinmmAudioPlayer mockAudioPlayer;

  setUp(() {
    Get.reset();
    mockApi = _AdversarialMockApiService();
    mockAudioPlayer = _MockWinmmAudioPlayer();
    Get.put<WinmmAudioPlayer>(mockAudioPlayer, permanent: true);
  });

  tearDown(() {
    Get.reset();
  });

  // =========================================================================
  // R3 CHALLENGE: WEBCAM VIEWPORT OPTIMIZATION & INTERACTIVE CONTROLS
  // =========================================================================
  group('R3 Adversarial Challenge: Webcam Viewport Optimization', () {
    const testDimensions = <String, Size>{
      '1100x700 (Technician Minimum Track Size)': Size(1100, 700),
      '1280x720 (Standard HD 720p)': Size(1280, 720),
      '1366x768 (Common Technician Laptop)': Size(1366, 768),
      '1920x1080 (Full HD 1080p)': Size(1920, 1080),
      '950x700 (Stress Boundary)': Size(950, 700),
    };

    for (final entry in testDimensions.entries) {
      testWidgets('Viewport Boundary Stress: Layout at ${entry.key} renders with ZERO SingleChildScrollView, ZERO scrollbars, and ZERO overflow', (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        Get.put(HardwareTestController(apiService: mockApi, audioPlayer: mockAudioPlayer));

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: WebcamTestView(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Assert SingleChildScrollView is absent
        expect(find.byType(SingleChildScrollView), findsNothing, reason: 'SingleChildScrollView must be completely removed from WebcamTestView');

        // 2. Assert no vertical Scrollbar exists on the root
        expect(find.byType(Scrollbar), findsNothing, reason: 'No vertical scrollbars should be active');

        // 3. Assert zero RenderFlex overflow exceptions occurred
        expect(tester.takeException(), isNull, reason: 'RenderFlex overflow detected at dimension ${entry.key}');

        // 4. Compact header elements must exist
        expect(find.text('بازگشت به لیست تست‌ها'), findsOneWidget);
        expect(find.text('تست وب‌کم، فوکوس و تصویر زنده'), findsOneWidget);
      });
    }

    testWidgets('Interactive Elements: Resolution switching, device switching, snapshot workflow, mirror matrix flip', (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final ctrl = Get.put(HardwareTestController(apiService: mockApi, audioPlayer: mockAudioPlayer));
      await ctrl.fetchCameraDevices();

      await tester.pumpWidget(
        const GetMaterialApp(
          home: Scaffold(
            body: WebcamTestView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // --- Resolution Switching ---
      expect(find.text('1080p (1920×1080)'), findsWidgets);
      // Tap resolution dropdown
      final resDropdown = find.byType(DropdownButton<String>).last;
      await tester.tap(resDropdown);
      await tester.pumpAndSettle();

      // Select 720p
      final res720Item = find.text('720p (1280×720)').last;
      await tester.tap(res720Item);
      await tester.pumpAndSettle();
      expect(find.text('720p (1280×720)'), findsWidgets);

      // --- Camera Device Switching ---
      final devDropdown = find.byType(DropdownButton<String>).first;
      await tester.tap(devDropdown);
      await tester.pumpAndSettle();

      final logitechOption = find.text('HD Pro Webcam C920').last;
      await tester.tap(logitechOption);
      await tester.pumpAndSettle();

      // --- Snapshot Workflow ---
      expect(find.textContaining('عکس ثبت شد'), findsNothing);
      final snapshotBtn = find.text('ثبت فریم آزمایشی (Snapshot)');
      await tester.tap(snapshotBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Toast / banner shows up
      expect(find.textContaining('عکس ثبت شد'), findsOneWidget);

      // Dismiss snapshot via close icon
      final closeIcon = find.byIcon(Icons.close);
      if (closeIcon.evaluate().isNotEmpty) {
        await tester.tap(closeIcon);
        await tester.pumpAndSettle();
        expect(find.textContaining('عکس ثبت شد'), findsNothing);
      }

      // Wait for Get.snackbar to finish its display duration so it does not obscure bottom buttons
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      // --- Mirror Matrix Flip ---
      expect(find.text('حالت آینه‌ای: خاموش'), findsOneWidget);
      final mirrorBtn = find.text('فعال‌سازی آینه (Mirror)');
      await tester.tap(mirrorBtn);
      await tester.pumpAndSettle();

      expect(find.text('حالت آینه‌ای: فعال'), findsOneWidget);
      expect(find.text('غیرفعال کردن آینه'), findsOneWidget);

      // Verify Transform widget has math.pi rotation
      final transformFinder = find.byWidgetPredicate((widget) {
        if (widget is Transform) {
          final m = widget.transform;
          // Matrix4 rotationY(pi) has m[0] == -1 and m[10] == -1 approx
          return m.entry(0, 0) < -0.9;
        }
        return false;
      });
      expect(transformFinder, findsOneWidget);

      // Toggle mirror back off
      await tester.tap(find.text('غیرفعال کردن آینه'));
      await tester.pumpAndSettle();
      expect(find.text('حالت آینه‌ای: خاموش'), findsOneWidget);
    });
  });

  // =========================================================================
  // R4 CHALLENGE: MICROPHONE LIVE WAVEFORM, TIMERS & STRESS HARNESS
  // =========================================================================
  group('R4 Adversarial Challenge: Microphone Live Waveform & Lifecycle Stress', () {
    testWidgets('Idle state: Live waveform renders 24 non-zero dynamic bars on mount WITHOUT recording', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final ctrl = Get.put(HardwareTestController(apiService: mockApi, audioPlayer: mockAudioPlayer));

      // Before mounting, live monitoring is inactive
      expect(ctrl.isLiveMicMonitoring.value, isFalse);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MicTestView(),
          ),
        ),
      );
      await tester.pump();

      // Upon mounting, live monitoring immediately activates
      expect(ctrl.isLiveMicMonitoring.value, isTrue);
      expect(ctrl.micPhase.value, equals('idle'));
      expect(ctrl.isMicBusy.value, isFalse);

      // 24 waveform bars exist
      expect(ctrl.liveWaveformHeights.length, equals(24));

      // Record initial height snapshot
      final snapshot1 = List<double>.from(ctrl.liveWaveformHeights);
      for (final h in snapshot1) {
        expect(h, greaterThanOrEqualTo(5.0), reason: 'Waveform height must be at least 5.0 base');
      }

      // Advance time by 200ms to allow ambient simulation ticks
      await tester.pump(const Duration(milliseconds: 200));

      final snapshot2 = List<double>.from(ctrl.liveWaveformHeights);
      bool changed = false;
      for (int i = 0; i < 24; i++) {
        if ((snapshot1[i] - snapshot2[i]).abs() > 0.001) {
          changed = true;
          break;
        }
      }
      expect(changed, isTrue, reason: 'Live waveform heights must dynamically animate over time in idle mode');

      // Verify live audio level percentage is displayed and non-zero
      expect(find.textContaining('سطح صدای ورودی زنده:'), findsOneWidget);
      expect(ctrl.liveMicLevel.value, greaterThan(0.0));

      ctrl.stopLiveMicMonitoring();
      await tester.pump();
    });

    testWidgets('Stress Test: Rapid subtest switching (mic -> hub -> mic -> keyboard -> mic) prevents timer leaks & GetX crashes', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final ctrl = Get.put(HardwareTestController(apiService: mockApi, audioPlayer: mockAudioPlayer));

      // Build harness that switches body based on activeSubTest
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Obx(() {
              switch (ctrl.activeSubTest.value) {
                case 'mic':
                  return const MicTestView();
                case 'keyboard':
                  return const Text('KEYBOARD_VIEW');
                case 'hub':
                default:
                  return const Text('HUB_VIEW');
              }
            }),
          ),
        ),
      );
      await tester.pump();

      // Stress loop: rapidly bounce between views 15 times
      for (int cycle = 0; cycle < 15; cycle++) {
        ctrl.selectSubTest('mic');
        await tester.pump(const Duration(milliseconds: 50));
        expect(ctrl.isLiveMicMonitoring.value, isTrue);

        ctrl.selectSubTest('hub');
        await tester.pump(const Duration(milliseconds: 20));
        expect(ctrl.isLiveMicMonitoring.value, isFalse);

        ctrl.selectSubTest('mic');
        await tester.pump(const Duration(milliseconds: 50));
        expect(ctrl.isLiveMicMonitoring.value, isTrue);

        ctrl.selectSubTest('keyboard');
        await tester.pump(const Duration(milliseconds: 20));
        expect(ctrl.isLiveMicMonitoring.value, isFalse);
      }

      // Final switch back to mic
      ctrl.selectSubTest('mic');
      await tester.pump(const Duration(milliseconds: 100));

      expect(ctrl.isLiveMicMonitoring.value, isTrue);
      expect(tester.takeException(), isNull, reason: 'No crash occurred during rapid switching');

      ctrl.stopLiveMicMonitoring();
      await tester.pump();
    });

    testWidgets('Quick Tests 3s and 5s: Countdown progression, auto-stop, and state transitions', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final ctrl = Get.put(HardwareTestController(apiService: mockApi, audioPlayer: mockAudioPlayer));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MicTestView(),
          ),
        ),
      );
      await tester.pump();

      // --- 3s Quick Test ---
      final quick3Btn = find.text('آزمون سریع ۳ ثانیه‌ای (خودکار)');
      await tester.tap(quick3Btn);
      await tester.pump();

      expect(ctrl.isMicBusy.value, isTrue);
      expect(ctrl.micPhase.value, equals('recording'));
      expect(ctrl.recordingCountdown.value, equals(3));
      expect(find.textContaining('شمارش معکوس: 3 ثانیه باقی‌مانده...'), findsOneWidget);

      // Advance 1 second
      await tester.pump(const Duration(seconds: 1));
      expect(ctrl.recordingCountdown.value, equals(2));

      // Advance 2 more seconds
      await tester.pump(const Duration(seconds: 2));
      expect(ctrl.recordingCountdown.value, equals(0));

      // Advance poll timer
      await tester.pump(const Duration(milliseconds: 400));
      expect(ctrl.isMicBusy.value, isFalse);
      expect(ctrl.hasRecordedAudio.value, isTrue);

      // --- 5s Quick Test ---
      final quick5Btn = find.text('آزمون سریع ۵ ثانیه‌ای (خودکار)');
      await tester.tap(quick5Btn);
      await tester.pump();

      expect(ctrl.isMicBusy.value, isTrue);
      expect(ctrl.micPhase.value, equals('recording'));
      expect(ctrl.recordingCountdown.value, equals(5));

      // Advance 5 seconds
      await tester.pump(const Duration(seconds: 5));
      expect(ctrl.recordingCountdown.value, equals(0));

      await tester.pump(const Duration(milliseconds: 400));
      expect(ctrl.isMicBusy.value, isFalse);
      expect(ctrl.hasRecordedAudio.value, isTrue);

      ctrl.stopLiveMicMonitoring();
      await tester.pump();
    });

    testWidgets('Manual Recording State Machine: Idle -> Recording -> Completed -> Playing -> Reset', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final ctrl = Get.put(HardwareTestController(apiService: mockApi, audioPlayer: mockAudioPlayer));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MicTestView(),
          ),
        ),
      );
      await tester.pump();

      expect(ctrl.micPhase.value, equals('idle'));
      expect(ctrl.hasRecordedAudio.value, isFalse);

      // 1. Start Manual Recording
      final startBtn = find.text('شروع ضبط دستی');
      await tester.tap(startBtn);
      await tester.pump();

      expect(ctrl.isManualMode.value, isTrue);
      expect(ctrl.micPhase.value, equals('recording'));
      expect(ctrl.isMicBusy.value, isTrue);

      // Elapse 3 seconds
      await tester.pump(const Duration(seconds: 3));
      expect(ctrl.elapsedManualSeconds.value, equals(3));

      // 2. Stop Manual Recording
      final stopBtn = find.text('توقف ضبط دستی');
      await tester.tap(stopBtn);
      await tester.pump();

      expect(ctrl.isMicBusy.value, isFalse);
      expect(ctrl.micPhase.value, equals('completed'));
      expect(ctrl.hasRecordedAudio.value, isTrue);
      expect(find.textContaining('ضبط به پایان رسید (3 ثانیه)'), findsOneWidget);

      // 3. Play Recorded Audio
      final playBtn = find.text('بازپخش صدای ضبط‌شده');
      await tester.tap(playBtn);
      await tester.pump();

      expect(ctrl.micPhase.value, equals('playing'));
      expect(ctrl.isMicBusy.value, isTrue);

      // Complete playback
      await tester.pump(const Duration(seconds: 3));
      expect(ctrl.micPhase.value, equals('completed'));
      expect(ctrl.isMicBusy.value, isFalse);

      // 4. Reset
      final resetBtn = find.text('بازنشانی');
      await tester.tap(resetBtn);
      await tester.pump();

      expect(ctrl.micPhase.value, equals('idle'));
      expect(ctrl.hasRecordedAudio.value, isFalse);
      expect(ctrl.isMicBusy.value, isFalse);

      ctrl.stopLiveMicMonitoring();
      await tester.pump();
    });

    testWidgets('Edge Case: Multiple calls to startLiveMicMonitoring do not spawn duplicate timers', (tester) async {
      final ctrl = Get.put(HardwareTestController(apiService: mockApi, audioPlayer: mockAudioPlayer));

      // Call startLiveMicMonitoring 5 times in succession
      ctrl.startLiveMicMonitoring();
      ctrl.startLiveMicMonitoring();
      ctrl.startLiveMicMonitoring();
      ctrl.startLiveMicMonitoring();
      ctrl.startLiveMicMonitoring();

      expect(ctrl.isLiveMicMonitoring.value, isTrue);

      // Stop once
      ctrl.stopLiveMicMonitoring();
      expect(ctrl.isLiveMicMonitoring.value, isFalse);
    });
  });
}
