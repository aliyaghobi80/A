// frontend/lib/widgets/hardware_tests/mic_test_view.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/hardware_test_controller.dart';
import '../../theme/app_theme.dart';

class MicTestView extends StatelessWidget {
  const MicTestView({super.key});

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

                const SizedBox(height: 16),

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
                            ? 'در حال ضبط صدا...'
                            : (isPlaying ? 'در حال بازپخش صدای ضبط‌شده شما...' : 'آزمون هوشمند لوپ‌بک میکروفون'),
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

                // Action Buttons
                Obx(() {
                  final isBusy = ctrl.isMicBusy.value;

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: isBusy ? null : () => ctrl.startMicLoopbackTest(duration: 3.0),
                        icon: const Icon(Icons.record_voice_over_rounded, size: 18),
                        label: Text(isBusy ? 'در حال اجرای آزمون...' : 'شروع ضبط و بازپخش آزمایشی (۳ ثانیه)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: isBusy ? null : () => ctrl.startMicLoopbackTest(duration: 5.0),
                        icon: const Icon(Icons.timer_outlined, size: 16),
                        label: const Text('آزمون ۵ ثانیه‌ای'),
                        style: OutlinedButton.styleFrom(
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

          const SizedBox(height: 16),

          // Evaluation Row
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ثبت نتیجه تست میکروفون',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'آیا صدای ضبط‌شده شما در بازپخش واضح، شفاف و بدون نویز یا قطعی شنیده شد؟',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    ctrl.recordResult(
                      testName: 'تست میکروفون و هدست',
                      status: 'passed',
                      details: 'ضبط و بازپخش لوپ‌بک صدا انجام شد؛ وضوح، شفافیت و حساسیت میکروفون تأیید گردید.',
                    );
                    Get.snackbar(
                      'ثبت شد',
                      'سلامت میکروفون در کارنامه ثبت شد.',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.9),
                      colorText: Colors.white,
                      duration: const Duration(seconds: 2),
                    );
                  },
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('میکروفون سالم و شفاف است (موفق)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () {
                    ctrl.recordResult(
                      testName: 'تست میکروفون و هدست',
                      status: 'failed',
                      details: 'عدم دریافت صدا، نویز شدید، صدای خفه یا ایراد در جک میکروفون گزارش شد.',
                    );
                    Get.snackbar(
                      'ثبت شد',
                      'ایراد میکروفون در کارنامه ثبت شد.',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.9),
                      colorText: Colors.white,
                      duration: const Duration(seconds: 2),
                    );
                  },
                  icon: const Icon(Icons.error_outline_rounded, size: 16),
                  label: const Text('ایراد در ورودی میکروفون'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444),
                    side: const BorderSide(color: Color(0xFFEF4444)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
