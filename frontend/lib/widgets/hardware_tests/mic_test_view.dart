// frontend/lib/widgets/hardware_tests/mic_test_view.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/hardware_test_controller.dart';
import '../../theme/app_theme.dart';

class MicTestView extends StatefulWidget {
  const MicTestView({super.key});

  @override
  State<MicTestView> createState() => _MicTestViewState();
}

class _MicTestViewState extends State<MicTestView> {
  @override
  void initState() {
    super.initState();
    final ctrl = Get.find<HardwareTestController>();
    ctrl.startLiveMicMonitoring();
    if (ctrl.micDevices.isEmpty) {
      ctrl.fetchMicDevices();
    }
  }

  @override
  void dispose() {
    if (Get.isRegistered<HardwareTestController>()) {
      final ctrl = Get.find<HardwareTestController>();
      ctrl.stopLiveMicMonitoring();
    }
    super.dispose();
  }

  void _openPrivacySettings() {
    try {
      if (Platform.isWindows) {
        Process.run('cmd', ['/c', 'start', 'ms-settings:privacy-microphone']);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ctrl = Get.find<HardwareTestController>();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Top Navigation Breadcrumb
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  ctrl.stopLiveMicMonitoring();
                  ctrl.selectSubTest('hub');
                },
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: const Text('بازگشت به لیست تست‌ها'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              const SizedBox(width: 14),
              Text(
                'تست میکروفون، سنجش صدای محیط و لوپ‌بک',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => ctrl.fetchMicDevices(),
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'بازخوانی لیست دستگاه‌های صوتی',
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 2. Main Recording & Live Ambient Console
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                // Animated Mic Icon with Dynamic Status Ring
                Obx(() {
                  final isBusy = ctrl.isMicBusy.value;
                  final phase = ctrl.micPhase.value;

                  Color ringColor = const Color(0xFF10B981); // Live Ambient (Green)
                  IconData iconData = Icons.mic_rounded;

                  if (phase == 'recording') {
                    ringColor = const Color(0xFFEF4444); // Recording (Red)
                    iconData = Icons.fiber_manual_record_rounded;
                  } else if (phase == 'playing') {
                    ringColor = const Color(0xFF3B82F6); // Playback (Blue)
                    iconData = Icons.volume_up_rounded;
                  }

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: ringColor.withValues(alpha: isDark ? 0.2 : 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: ringColor,
                        width: isBusy ? 3.0 : 1.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: ringColor.withValues(alpha: isBusy ? 0.4 : 0.2),
                          blurRadius: isBusy ? 16 : 8,
                        ),
                      ],
                    ),
                    child: Icon(iconData, color: ringColor, size: 38),
                  );
                }),

                const SizedBox(height: 14),

                // Real-time Live Ambient Waveform (Reacts Immediately to Ambient Sound & Speech)
                Obx(() {
                  final heights = ctrl.liveWaveformHeights;
                  final phase = ctrl.micPhase.value;
                  final isRecording = phase == 'recording';
                  final isPlaying = phase == 'playing';

                  Color activeColor = const Color(0xFF10B981); // Emerald for ambient voice
                  if (isRecording) activeColor = const Color(0xFFEF4444);
                  if (isPlaying) activeColor = const Color(0xFF3B82F6);

                  return Container(
                    height: 54,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: activeColor.withValues(alpha: 0.6),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: List.generate(heights.length, (i) {
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2.2),
                          width: 5,
                          height: heights[i],
                          decoration: BoxDecoration(
                            color: activeColor,
                            borderRadius: BorderRadius.circular(2.5),
                          ),
                        );
                      }),
                    ),
                  );
                }),

                const SizedBox(height: 8),

                // Live Audio Level Percentage Indicator
                Obx(() {
                  final level = (ctrl.liveMicLevel.value * 100).toInt();
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.graphic_eq_rounded, size: 14, color: Color(0xFF10B981)),
                      const SizedBox(width: 6),
                      Text(
                        'سطح صدای ورودی زنده: $level٪',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                        ),
                      ),
                    ],
                  );
                }),

                const SizedBox(height: 12),

                // Status Message & Countdown Box
                Obx(() {
                  final msg = ctrl.micStatusMessage.value;
                  final countdown = ctrl.recordingCountdown.value;
                  final phase = ctrl.micPhase.value;

                  return Column(
                    children: [
                      if (countdown > 0 && phase == 'recording')
                        Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'شمارش معکوس: $countdown ثانیه باقی‌مانده...',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFEF4444),
                            ),
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          msg,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  );
                }),

                const SizedBox(height: 18),

                // Dedicated Quick Test & Manual Loopback Controls
                Obx(() {
                  final isBusy = ctrl.isMicBusy.value;
                  final phase = ctrl.micPhase.value;
                  final isManual = ctrl.isManualMode.value;
                  final hasAudio = ctrl.hasRecordedAudio.value;

                  return Column(
                    children: [
                      // Row 1: Dedicated Quick Tests (3s and 5s with Auto Loopback)
                      Wrap(
                        spacing: 12,
                        runSpacing: 10,
                        alignment: WrapAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: isBusy ? null : () => ctrl.startQuickTest(duration: 3.0),
                            icon: const Icon(Icons.flash_on_rounded, size: 18),
                            label: const Text('آزمون سریع ۳ ثانیه‌ای (خودکار)'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: isBusy ? null : () => ctrl.startQuickTest(duration: 5.0),
                            icon: const Icon(Icons.timer_outlined, size: 18),
                            label: const Text('آزمون سریع ۵ ثانیه‌ای (خودکار)'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF059669),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // Row 2: Standard Manual Recording, Playback & Windows Privacy
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          // Manual Record / Stop Button
                          if (phase == 'recording' && isManual)
                            ElevatedButton.icon(
                              onPressed: () => ctrl.stopManualRecording(),
                              icon: const Icon(Icons.stop_rounded, size: 18),
                              label: const Text('توقف ضبط دستی'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFEF4444),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              ),
                            )
                          else
                            OutlinedButton.icon(
                              onPressed: isBusy ? null : () => ctrl.startManualRecording(),
                              icon: const Icon(Icons.fiber_manual_record, size: 16, color: Color(0xFFEF4444)),
                              label: const Text('شروع ضبط دستی'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              ),
                            ),

                          // Playback Button
                          OutlinedButton.icon(
                            onPressed: (isBusy || !hasAudio) ? null : () => ctrl.playRecordedAudio(),
                            icon: const Icon(Icons.play_arrow_rounded, size: 18),
                            label: const Text('بازپخش صدای ضبط‌شده'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF3B82F6),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                          ),

                          // Reset Button
                          if (hasAudio || phase == 'completed' || phase == 'error')
                            OutlinedButton.icon(
                              onPressed: isBusy ? null : () => ctrl.resetRecording(),
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              label: const Text('بازنشانی'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),

                          // Windows Privacy Shortcut
                          OutlinedButton.icon(
                            onPressed: _openPrivacySettings,
                            icon: const Icon(Icons.security_rounded, size: 16),
                            label: const Text('دسترسی در ویندوز'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 3. Detected Audio Input Devices List
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.settings_voice_rounded, size: 18, color: Color(0xFF10B981)),
                    SizedBox(width: 8),
                    Text(
                      'دستگاه‌های صوتی ورودی شناسایی‌شده در ویندوز:',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Obx(() {
                  final list = ctrl.micDevices;
                  if (list.isEmpty) {
                    return const Text(
                      'در حال شناسایی یا ورودی پیش‌فرض ویندوز فعال است.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    );
                  }
                  return Column(
                    children: list.map((d) {
                      final name = d['name'] ?? 'Audio Input';
                      final status = d['status'] ?? 'OK';
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.circle, size: 8, color: Color(0xFF10B981)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                name,
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                status,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
