import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../services/api_service.dart';
import '../services/winmm_audio_player.dart';

class HardwareTestController extends GetxController {
  final ApiService _api;
  final WinmmAudioPlayer _audioPlayer;

  HardwareTestController({
    ApiService? api,
    ApiService? apiService,
    WinmmAudioPlayer? audioPlayer,
  })  : _api = api ?? apiService ?? ApiService(),
        _audioPlayer = audioPlayer ??
            (Get.isRegistered<WinmmAudioPlayer>()
                ? Get.find<WinmmAudioPlayer>()
                : Get.put(WinmmAudioPlayer(), permanent: true));

  // Active view: 'hub', 'monitor', 'audio', 'mic', 'webcam', 'keyboard', 'mouse'
  final activeSubTest = 'hub'.obs;

  // Sidebar accordion expansion state
  final isAccordionExpanded = false.obs;

  void toggleAccordion() {
    isAccordionExpanded.value = !isAccordionExpanded.value;
  }

  void selectSubTest(String testId) {
    activeSubTest.value = testId;
    if (testId == 'mic') {
      fetchMicDevices();
    } else if (testId == 'webcam') {
      fetchCameraDevices();
    }
  }

  // =============================================================
  // 1. MONITOR TEST
  // =============================================================
  static const List<Map<String, dynamic>> monitorColors = [
    {'name': 'مشکی خالص (بررسی پیکسل روشن/گیرکرده)', 'hex': '#000000', 'color': 0xFF000000},
    {'name': 'سفید خالص (بررسی پیکسل خاموش/سوخته)', 'hex': '#FFFFFF', 'color': 0xFFFFFFFF},
    {'name': 'قرمز خالص (Red Sub-pixel)', 'hex': '#FF0000', 'color': 0xFFFF0000},
    {'name': 'سبز خالص (Green Sub-pixel)', 'hex': '#00FF00', 'color': 0xFF00FF00},
    {'name': 'آبی خالص (Blue Sub-pixel)', 'hex': '#0000FF', 'color': 0xFF0000FF},
    {'name': 'زرد خالص (Yellow)', 'hex': '#FFFF00', 'color': 0xFFFFFF00},
    {'name': 'فیروزه‌ای خالص (Cyan)', 'hex': '#00FFFF', 'color': 0xFF00FFFF},
    {'name': 'ارغوانی خالص (Magenta)', 'hex': '#FF00FF', 'color': 0xFFFF00FF},
    {'name': 'خاکستری ۵۰٪ (یکنواختی نور و هاله)', 'hex': '#808080', 'color': 0xFF808080},
  ];

  final monitorIndex = 0.obs;
  final isMonitorFullScreen = false.obs;

  void nextMonitorColor() {
    if (monitorIndex.value < monitorColors.length - 1) {
      monitorIndex.value++;
    } else {
      monitorIndex.value = 0;
    }
  }

  void prevMonitorColor() {
    if (monitorIndex.value > 0) {
      monitorIndex.value--;
    } else {
      monitorIndex.value = monitorColors.length - 1;
    }
  }

  void setMonitorColor(int index) {
    if (index >= 0 && index < monitorColors.length) {
      monitorIndex.value = index;
    }
  }

  void toggleMonitorFullScreen(bool value) {
    isMonitorFullScreen.value = value;
  }

  // =============================================================
  // 2. AUDIO & HEADPHONE TEST
  // =============================================================
  final audioVolume = 0.20.obs;
  final isAudioPlaying = false.obs;
  final currentAudioKind = ''.obs;
  final audioErrorMessage = ''.obs;
  Timer? _audioTimer;

  WinmmAudioPlayer get audioPlayer => _audioPlayer;

  /// Resolves the bundled audio asset path corresponding to the test parameters.
  String resolveAudioAsset({
    required String kind,
    double frequency = 440.0,
    bool sweep = false,
    bool pinkNoise = false,
  }) {
    if (kind == 'chime' || kind == 'channel_id_chime') {
      return 'assets/audio/channel_id_chime.wav';
    }
    if (pinkNoise || kind == 'pink_noise') {
      return 'assets/audio/pink_noise.wav';
    }
    if (sweep || kind == 'sweep') {
      return 'assets/audio/bass_sweep_20_120hz.wav';
    }
    if (frequency <= 45.0) {
      return 'assets/audio/bass_40hz.wav';
    }
    if (frequency <= 70.0) {
      return 'assets/audio/bass_60hz.wav';
    }
    if (frequency <= 90.0) {
      return 'assets/audio/bass_80hz.wav';
    }
    if (frequency <= 150.0) {
      return 'assets/audio/bass_100hz.wav';
    }
    if ((frequency - 1000.0).abs() < 100.0) {
      if (kind == 'left') return 'assets/audio/sine_1khz_left.wav';
      if (kind == 'right') return 'assets/audio/sine_1khz_right.wav';
      return 'assets/audio/sine_1khz_both.wav';
    }
    // Default 440 Hz standard
    if (kind == 'left') return 'assets/audio/sine_440hz_left.wav';
    if (kind == 'right') return 'assets/audio/sine_440hz_right.wav';
    return 'assets/audio/sine_440hz_both.wav';
  }

  Future<void> playAudioTone({
    required String kind,
    double frequency = 440.0,
    double duration = 2.5,
    bool sweep = false,
    bool pinkNoise = false,
    String? customAsset,
  }) async {
    await stopAudio();
    audioErrorMessage.value = '';
    isAudioPlaying.value = true;
    currentAudioKind.value = kind;

    final assetPath = customAsset ??
        resolveAudioAsset(
          kind: kind,
          frequency: frequency,
          sweep: sweep,
          pinkNoise: pinkNoise,
        );

    final channelRouting = (kind == 'left' || kind == 'right') ? kind : 'both';
    final dur = Duration(milliseconds: (duration * 1000).toInt());

    try {
      await _audioPlayer.playAsset(
        assetPath,
        volume: audioVolume.value,
        channel: channelRouting,
        duration: dur,
      );

      _audioTimer?.cancel();
      _audioTimer = Timer(dur + const Duration(milliseconds: 100), () {
        isAudioPlaying.value = false;
        currentAudioKind.value = '';
      });
    } catch (e) {
      debugPrint('[HardwareTestController] Audio playback error: $e');
      audioErrorMessage.value = 'خطا در پخش صدا: $e';
      isAudioPlaying.value = false;
      currentAudioKind.value = '';
      // Attempt backend fallback if available
      try {
        final res = await _api.playAudioTone(
          kind: channelRouting,
          frequency: frequency,
          duration: duration,
          volume: audioVolume.value,
          sweep: sweep,
        );
        if (res['status'] == 'ok') {
          audioErrorMessage.value = '';
          isAudioPlaying.value = true;
          _audioTimer?.cancel();
          _audioTimer = Timer(dur + const Duration(milliseconds: 100), () {
            isAudioPlaying.value = false;
            currentAudioKind.value = '';
          });
        }
      } catch (_) {}
    }
  }

  Future<void> stopAudio() async {
    _audioTimer?.cancel();
    isAudioPlaying.value = false;
    currentAudioKind.value = '';
    _audioPlayer.stop();
    try {
      await _api.stopAudioTone();
    } catch (_) {}
  }

  Future<void> openWindowsSoundSettings() async {
    try {
      if (Platform.isWindows) {
        await Process.run('cmd.exe', ['/c', 'start', 'ms-settings:sound']);
      }
    } catch (e) {
      audioErrorMessage.value = 'عدم دسترسی به تنظیمات صدای ویندوز: $e';
    }
  }

  // =============================================================
  // 3. MICROPHONE TEST
  // =============================================================
  final micDevices = <Map<String, dynamic>>[].obs;
  final isMicBusy = false.obs;
  final micStatusMessage = 'میکروفون را متصل کنید و دکمه تست را فشار دهید.'.obs;
  final micPhase = 'idle'.obs;
  Timer? _micPollTimer;

  Future<void> fetchMicDevices() async {
    final list = await _api.fetchMicDevices();
    micDevices.assignAll(list);
  }

  Future<void> startMicLoopbackTest({double duration = 3.0}) async {
    if (isMicBusy.value) return;
    isMicBusy.value = true;
    micPhase.value = 'recording';
    micStatusMessage.value = 'در حال ضبط صدا (${duration.toInt()} ثانیه)... با صدای عادی صحبت کنید';

    final res = await _api.startMicLoopback(duration: duration);
    if (res['status'] == 'error') {
      isMicBusy.value = false;
      micPhase.value = 'error';
      micStatusMessage.value = res['message'] ?? 'خطا در دسترسی به میکروفون';
      return;
    }

    _micPollTimer?.cancel();
    _micPollTimer = Timer.periodic(const Duration(milliseconds: 400), (timer) async {
      final status = await _api.fetchMicLoopbackStatus();
      micPhase.value = status['phase'] ?? 'idle';
      micStatusMessage.value = status['message'] ?? '';
      if (status['is_busy'] == false && micPhase.value != 'recording') {
        isMicBusy.value = false;
        timer.cancel();
      }
    });
  }

  // =============================================================
  // 4. WEBCAM TEST
  // =============================================================
  final cameraDevices = <Map<String, dynamic>>[].obs;
  final cameraStatusMessage = ''.obs;

  Future<void> fetchCameraDevices() async {
    final list = await _api.fetchCameraDevices();
    cameraDevices.assignAll(list);
  }

  Future<void> launchCameraApp() async {
    final res = await _api.launchCameraApp();
    cameraStatusMessage.value = res['message'] ?? '';
  }

  // =============================================================
  // 5. KEYBOARD TEST
  // =============================================================
  final testedKeys = <String>{}.obs;
  final activeKeys = <String>{}.obs;
  final keyHits = <String, int>{}.obs;
  final totalKeyHits = 0.obs;
  final lastKeyLabel = 'آماده دریافت کلید'.obs;
  final lastKeyCode = '-'.obs;

  void onKeyDown(String code, String label) {
    activeKeys.add(code);
    testedKeys.add(code);
    keyHits[code] = (keyHits[code] ?? 0) + 1;
    totalKeyHits.value++;
    lastKeyLabel.value = label.isNotEmpty ? label : code;
    lastKeyCode.value = code;
  }

  void onKeyUp(String code) {
    activeKeys.remove(code);
  }

  void resetKeyboard() {
    testedKeys.clear();
    activeKeys.clear();
    keyHits.clear();
    totalKeyHits.value = 0;
    lastKeyLabel.value = 'آماده دریافت کلید';
    lastKeyCode.value = '-';
  }

  // =============================================================
  // 6. MOUSE TEST
  // =============================================================
  final mouseLeftClicks = 0.obs;
  final mouseRightClicks = 0.obs;
  final mouseMiddleClicks = 0.obs;
  final mouseSide1Clicks = 0.obs;
  final mouseSide2Clicks = 0.obs;
  final mouseDoubleClicks = 0.obs;
  final mouseWheelUp = 0.obs;
  final mouseWheelDown = 0.obs;
  final mouseMoveCount = 0.obs;
  final heldMouseButtons = <int>{}.obs;
  final mousePosition = const Offset(0, 0).obs;
  final isMouseDragging = false.obs;
  final lastMouseAction = 'آماده آزمون کلیک و اسکرول'.obs;
  final mouseActiveButton = ''.obs; // 'left', 'right', 'middle', 'side1', 'side2'
  final mouseScrollPercent = 0.0.obs;

  DateTime? _lastClickTime;
  int? _lastClickButton;
  Timer? _mouseResetTimer;

  void onPointerDown(int buttons, Offset position) {
    mousePosition.value = position;
    for (final bit in [1, 2, 4, 8, 16]) {
      if ((buttons & bit) != 0) {
        heldMouseButtons.add(bit);
        _handleSingleButtonPress(bit);
      }
    }
  }

  void onPointerUp(int remainingButtons) {
    heldMouseButtons.removeWhere((bit) => (remainingButtons & bit) == 0);
    if (heldMouseButtons.isEmpty) {
      isMouseDragging.value = false;
    }
  }

  void onPointerMove(Offset position, {bool hasButtons = false}) {
    mousePosition.value = position;
    mouseMoveCount.value++;
    if (hasButtons && heldMouseButtons.isNotEmpty) {
      isMouseDragging.value = true;
      lastMouseAction.value = 'در حال درگ موس (Drag)';
    }
  }

  void _handleSingleButtonPress(int bit) {
    final now = DateTime.now();
    if (_lastClickButton == bit &&
        _lastClickTime != null &&
        now.difference(_lastClickTime!) < const Duration(milliseconds: 300)) {
      mouseDoubleClicks.value++;
      lastMouseAction.value = 'دوبار کلیک سریع (< 300ms)';
    } else {
      if (bit == 1) {
        mouseLeftClicks.value++;
        lastMouseAction.value = 'کلیک چپ (Left)';
        mouseActiveButton.value = 'left';
      } else if (bit == 2) {
        mouseRightClicks.value++;
        lastMouseAction.value = 'کلیک راست (Right)';
        mouseActiveButton.value = 'right';
      } else if (bit == 4) {
        mouseMiddleClicks.value++;
        lastMouseAction.value = 'کلیک چرخ وسط (Middle)';
        mouseActiveButton.value = 'middle';
      } else if (bit == 8) {
        mouseSide1Clicks.value++;
        lastMouseAction.value = 'کلیک دکمه جانبی ۱ (Back)';
        mouseActiveButton.value = 'side1';
      } else if (bit == 16) {
        mouseSide2Clicks.value++;
        lastMouseAction.value = 'کلیک دکمه جانبی ۲ (Forward)';
        mouseActiveButton.value = 'side2';
      }
    }
    _lastClickTime = now;
    _lastClickButton = bit;

    _mouseResetTimer?.cancel();
    _mouseResetTimer = Timer(const Duration(milliseconds: 300), () {
      mouseActiveButton.value = '';
    });
  }

  void onMouseButton(String button) {
    if (button == 'left') {
      _handleSingleButtonPress(1);
    } else if (button == 'right') {
      _handleSingleButtonPress(2);
    } else if (button == 'middle') {
      _handleSingleButtonPress(4);
    }
  }

  void onMouseScroll(double deltaY) {
    if (deltaY < 0) {
      mouseWheelUp.value++;
      lastMouseAction.value = 'اسکرول به بالا ↑';
      mouseActiveButton.value = 'wheel_up';
    } else if (deltaY > 0) {
      mouseWheelDown.value++;
      lastMouseAction.value = 'اسکرول به پایین ↓';
      mouseActiveButton.value = 'wheel_down';
    }
    _mouseResetTimer?.cancel();
    _mouseResetTimer = Timer(const Duration(milliseconds: 250), () {
      mouseActiveButton.value = '';
    });
  }

  void updateScrollProgress(double percent) {
    mouseScrollPercent.value = percent.clamp(0.0, 100.0);
  }

  void resetMouse() {
    mouseLeftClicks.value = 0;
    mouseRightClicks.value = 0;
    mouseMiddleClicks.value = 0;
    mouseSide1Clicks.value = 0;
    mouseSide2Clicks.value = 0;
    mouseDoubleClicks.value = 0;
    mouseWheelUp.value = 0;
    mouseWheelDown.value = 0;
    mouseMoveCount.value = 0;
    heldMouseButtons.clear();
    isMouseDragging.value = false;
    lastMouseAction.value = 'آماده آزمون کلیک و اسکرول';
    mouseActiveButton.value = '';
    mouseScrollPercent.value = 0.0;
    _lastClickTime = null;
    _lastClickButton = null;
  }

  @override
  void onClose() {
    _audioTimer?.cancel();
    _audioPlayer.stop();
    _micPollTimer?.cancel();
    _mouseResetTimer?.cancel();
    super.onClose();
  }
}
