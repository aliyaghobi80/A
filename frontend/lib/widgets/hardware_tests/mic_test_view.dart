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

class _MicTestViewState extends State<MicTestView>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _openPrivacySettings() {
    try {
      Process.run('cmd', ['/c', 'start', 'ms-settings:privacy-microphone']);
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
          // Top Navigation Breadcrumb
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => ctrl.selectSubTest('hub'),
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: const Text('بازگشت به لیست تست‌ها'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              const SizedBox(width: 14),
              Text(
                'تست میکروفون و سنجش ورودی هدست',
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

          // Main Recording & Loopback Interactive Console
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
                // Animated Mic Icon with Status Ring
                Obx(() {
                  final isBusy = ctrl.isMicBusy.value;
                  final phase = ctrl.micPhase.value;

                  Color ringColor = const Color(0xFF10B981);
                  IconData iconData = Icons.mic_rounded;
                  if (phase == 'recording') {
                    ringColor = const Color(0xFFEF4444);
                    iconData = Icons.fiber_manual_record_rounded;
                  } else if (phase == 'playing') {
                    ringColor = const Color(0xFF3B82F6);
                    iconData = Icons.volume_up_rounded;
                  }

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: ringColor.withValues(alpha: isDark ? 0.2 : 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: ringColor,
                        width: isBusy ? 3.0 : 1.5,
                      ),
                      boxShadow: isBusy
                          ? [
                              BoxShadow(
                                color: ringColor.withValues(alpha: 0.35),
                                blurRadius: 16,
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(iconData, color: ringColor, size: 40),
                  );
                }),

                const SizedBox(height: 14),

                // Real-time Waveform / Amplitude Level Meter
                Obx(() {
                  final phase = ctrl.micPhase.value;
                  final isRecording = phase == 'recording';
                  final isPlaying = phase == 'playing';
                  final isActive = isRecording || isPlaying;

                  return Container(
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isActive
                            ? (isRecording ? const Color(0xFFEF4444) : const Color(0xFF3B82F6))
                            : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                    ),
                    child: AnimatedBuilder(
                      animation: _animController,
                      builder: (context, _) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: List.generate(24, (i) {
                            double barHeight = 6.0;
                            if (isActive) {
                              final offset = (i * 0.12);
                              final animVal = (_animController.value + offset) % 1.0;
                              barHeight = 6.0 + 26.0 * (0.3 + 0.7 * (animVal > 0.5 ? 1.0 - animVal : animVal) * 2);
                            }
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              width: 5,
                              height: barHeight,
                              decoration: BoxDecoration(
                                color: isActive
                                    ? (isRecording ? const Color(0xFFEF4444) : const Color(0xFF3B82F6))
                                    : (isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8)),
                                borderRadius: BorderRadius.circular(2.5),
                              ),
                            );
                          }),
                        );
                      },
                    ),
                  );
                }),

                const SizedBox(height: 14),

                // Status Message Box
                Obx(() {
                  final msg = ctrl.micStatusMessage.value;
                  final phase = ctrl.micPhase.value;
                  final isRecording = phase == 'recording';
                  final isPlaying = phase == 'playing';

                  return Column(
                    children: [
                      Text(
                        isRecording
                            ? 'در حال ضبط صدا (میکروفون فعال)...'
                            : (isPlaying
                                ? 'در حال بازپخش صدای ضبط‌شده شما در خروجی...'
                                : 'آزمون لوپ‌بک صدا (ضبط و بازپخش مستقیم)'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
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

                const SizedBox(height: 20),

                // Loopback Controls (Record, Re-record, Stop)
                Obx(() {
                  final isBusy = ctrl.isMicBusy.value;
                  final phase = ctrl.micPhase.value;

                  return Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: isBusy ? null : () => ctrl.startMicLoopbackTest(duration: 3.0),
                        icon: const Icon(Icons.mic_rounded, size: 18),
                        label: Text(phase == 'completed'
                            ? 'ضبط مجدد (۳ ثانیه)'
                            : (isBusy ? 'در حال پردازش...' : 'شروع ضبط آزمایشی (۳ ثانیه)')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: isBusy ? null : () => ctrl.startMicLoopbackTest(duration: 5.0),
                        icon: const Icon(Icons.timer_outlined, size: 16),
                        label: const Text('آزمون ۵ ثانیه‌ای'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _openPrivacySettings,
                        icon: const Icon(Icons.security_rounded, size: 16),
                        label: const Text('دسترسی میکروفون در ویندوز'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF3B82F6),
                          side: const BorderSide(color: Color(0xFF3B82F6)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Detected Audio Devices List
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
