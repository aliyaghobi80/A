// frontend/lib/controllers/hardware_test_controller.dart
import 'dart:async';
import 'package:get/get.dart';
import '../models/hardware_test_result.dart';
import '../services/api_service.dart';

class HardwareTestController extends GetxController {
  final ApiService _api = ApiService();

  // Active view: 'hub', 'monitor', 'audio', 'mic', 'webcam', 'keyboard', 'mouse', 'report'
  final activeSubTest = 'hub'.obs;

  // Sidebar accordion expansion state
  final isAccordionExpanded = false.obs;

  // Test Results Log
  final testResults = <HardwareTestResult>[].obs;

  int get totalTestsCount => testResults.length;
  int get passedTestsCount => testResults.where((r) => r.isPassed).length;
  int get failedTestsCount => testResults.where((r) => r.isFailed).length;

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

  void recordResult({
    required String testName,
    required String status,
    required String details,
  }) {
    final result = HardwareTestResult(
      testName: testName,
      status: status,
      details: details,
      timestamp: DateTime.now(),
    );
    testResults.insert(0, result);
  }

  void clearResults() {
    testResults.clear();
  }

  String getFormattedReport() {
    final now = DateTime.now();
    final dateStr = '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final buf = StringBuffer();
    buf.writeln('مرکزی سیستم چکر — گزارش جامع آزمون سلامت قطعات و لوازم جانبی');
    buf.writeln('زمان ثبت گزارش: $dateStr');
    buf.writeln('خلاصه عملکرد: کل تست‌ها: $totalTestsCount | موفق: $passedTestsCount | نیازمند بررسی: $failedTestsCount');
    buf.writeln('------------------------------------------------------------');
    if (testResults.isEmpty) {
      buf.writeln('هنوز تستی در این نشست ثبت نشده است.');
    } else {
      for (int i = 0; i < testResults.length; i++) {
        final r = testResults[i];
        buf.writeln('${i + 1}. [${r.localizedStatus}] ${r.testName} — ${r.details}');
      }
    }
    buf.writeln('------------------------------------------------------------');
    buf.writeln('تأییدیه فنی کامپیوتر مرکزی');
    return buf.toString();
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
  final audioVolume = 0.18.obs;
  final isAudioPlaying = false.obs;
  final currentAudioKind = ''.obs;
  Timer? _audioTimer;

  Future<void> playAudioTone({
    required String kind,
    double frequency = 440.0,
    double duration = 2.4,
    bool sweep = false,
  }) async {
    stopAudio();
    isAudioPlaying.value = true;
    currentAudioKind.value = kind;

    await _api.playAudioTone(
      kind: kind,
      frequency: frequency,
      duration: duration,
      volume: audioVolume.value,
      sweep: sweep,
    );

    _audioTimer?.cancel();
    _audioTimer = Timer(Duration(milliseconds: (duration * 1000).toInt() + 150), () {
      isAudioPlaying.value = false;
      currentAudioKind.value = '';
    });
  }

  Future<void> stopAudio() async {
    _audioTimer?.cancel();
    isAudioPlaying.value = false;
    currentAudioKind.value = '';
    await _api.stopAudioTone();
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
  final lastKeyLabel = 'آماده دریافت کلید'.obs;
  final lastKeyCode = '-'.obs;

  void onKeyDown(String code, String label) {
    activeKeys.add(code);
    testedKeys.add(code);
    lastKeyLabel.value = label.isNotEmpty ? label : code;
    lastKeyCode.value = code;
  }

  void onKeyUp(String code) {
    activeKeys.remove(code);
  }

  void resetKeyboard() {
    testedKeys.clear();
    activeKeys.clear();
    lastKeyLabel.value = 'آماده دریافت کلید';
    lastKeyCode.value = '-';
  }

  // =============================================================
  // 6. MOUSE TEST
  // =============================================================
  final mouseLeftClicks = 0.obs;
  final mouseRightClicks = 0.obs;
  final mouseMiddleClicks = 0.obs;
  final mouseWheelUp = 0.obs;
  final mouseWheelDown = 0.obs;
  final lastMouseAction = 'آماده آزمون کلیک و اسکرول'.obs;
  final mouseActiveButton = ''.obs; // 'left', 'right', 'middle'
  final mouseScrollPercent = 0.0.obs;
  Timer? _mouseResetTimer;

  void onMouseButton(String button) {
    if (button == 'left') {
      mouseLeftClicks.value++;
      lastMouseAction.value = 'کلیک چپ فشرده شد';
    } else if (button == 'right') {
      mouseRightClicks.value++;
      lastMouseAction.value = 'کلیک راست فشرده شد';
    } else if (button == 'middle') {
      mouseMiddleClicks.value++;
      lastMouseAction.value = 'کلیک وسط (چرخ) فشرده شد';
    }
    mouseActiveButton.value = button;
    _mouseResetTimer?.cancel();
    _mouseResetTimer = Timer(const Duration(milliseconds: 300), () {
      mouseActiveButton.value = '';
    });
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
    mouseWheelUp.value = 0;
    mouseWheelDown.value = 0;
    lastMouseAction.value = 'آماده آزمون کلیک و اسکرول';
    mouseActiveButton.value = '';
    mouseScrollPercent.value = 0.0;
  }

  @override
  void onClose() {
    _audioTimer?.cancel();
    _micPollTimer?.cancel();
    _mouseResetTimer?.cancel();
    super.onClose();
  }
}
