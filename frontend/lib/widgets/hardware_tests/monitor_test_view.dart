// frontend/lib/widgets/hardware_tests/monitor_test_view.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../controllers/hardware_test_controller.dart';
import '../../theme/app_theme.dart';

class MonitorTestView extends StatefulWidget {
  const MonitorTestView({super.key});

  @override
  State<MonitorTestView> createState() => _MonitorTestViewState();
}

class _MonitorTestViewState extends State<MonitorTestView> {
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _openFullScreen(BuildContext context, HardwareTestController ctrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => _FullScreenMonitorPage(ctrl: ctrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ctrl = Get.find<HardwareTestController>();

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
              event.logicalKey == LogicalKeyboardKey.space) {
            ctrl.nextMonitorColor();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            ctrl.prevMonitorColor();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyF) {
            _openFullScreen(context, ctrl);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: SingleChildScrollView(
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
                  'تست مانیتور و پیکسل‌های نمایشگر',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => _openFullScreen(context, ctrl),
                  icon: const Icon(Icons.fullscreen_rounded, size: 18),
                  label: const Text('شروع تست تمام‌صفحه (F)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Color Display Stage Container
            Obx(() {
              final idx = ctrl.monitorIndex.value;
              final currentColorData = HardwareTestController.monitorColors[idx];
              final colorVal = Color(currentColorData['color'] as int);
              final isLight = colorVal.computeLuminance() > 0.5;

              return Container(
                width: double.infinity,
                height: 280,
                decoration: BoxDecoration(
                  color: colorVal,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: (isLight ? Colors.black : Colors.white).withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          currentColorData['name'] as String,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: isLight ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 12,
                      left: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${idx + 1} / ${HardwareTestController.monitorColors.length} · ${currentColorData['hex']}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 16),

            // Palette Swatches & Navigation Controls
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'انتخاب الگوی رنگ:',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      OutlinedButton(
                        onPressed: () => ctrl.prevMonitorColor(),
                        child: const Text('→ رنگ قبلی'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () => ctrl.nextMonitorColor(),
                        child: const Text('رنگ بعدی ←'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Swatches
                  Obx(() {
                    final currentIdx = ctrl.monitorIndex.value;
                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: List.generate(
                        HardwareTestController.monitorColors.length,
                        (i) {
                          final item = HardwareTestController.monitorColors[i];
                          final c = Color(item['color'] as int);
                          final isSelected = currentIdx == i;

                          return InkWell(
                            onTap: () => ctrl.setMonitorColor(i),
                            borderRadius: BorderRadius.circular(8),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: c,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF3B82F6) : Colors.grey.withValues(alpha: 0.4),
                                  width: isSelected ? 3.5 : 1.2,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFF3B82F6).withValues(alpha: 0.5),
                                          blurRadius: 8,
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                          );
                        },
                      ),
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
                          'ثبت نتیجه تست مانیتور',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'آیا در رنگ‌های مشکی، سفید یا RGB نقطه‌ی خاموش، پیکسل گیرکرده یا هاله مشاهده شد؟',
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
                        testName: 'تست مانیتور و پیکسل',
                        status: 'passed',
                        details: '۹ رنگ اصلی بررسی شد؛ پنل سالم و بدون پیکسل سوخته تأیید گردید.',
                      );
                      Get.snackbar(
                        'ثبت شد',
                        'سلامت مانیتور در کارنامه ثبت شد.',
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.9),
                        colorText: Colors.white,
                        duration: const Duration(seconds: 2),
                      );
                    },
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('پنل سالم است (موفق)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: () {
                      ctrl.recordResult(
                        testName: 'تست مانیتور و پیکسل',
                        status: 'failed',
                        details: 'پیکسل معیوب، هاله یا لکه غیرعادی در نمایشگر مشاهده شد.',
                      );
                      Get.snackbar(
                        'ثبت شد',
                        'ایراد مانیتور جهت بررسی در کارنامه ثبت شد.',
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.9),
                        colorText: Colors.white,
                        duration: const Duration(seconds: 2),
                      );
                    },
                    icon: const Icon(Icons.error_outline_rounded, size: 16),
                    label: const Text('ایراد مشاهده شد'),
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
      ),
    );
  }
}

class _FullScreenMonitorPage extends StatelessWidget {
  final HardwareTestController ctrl;

  const _FullScreenMonitorPage({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.escape) {
              Navigator.of(context).pop();
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
                event.logicalKey == LogicalKeyboardKey.space) {
              ctrl.nextMonitorColor();
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
              ctrl.prevMonitorColor();
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onTap: () => ctrl.nextMonitorColor(),
          onDoubleTap: () => Navigator.of(context).pop(),
          child: Obx(() {
            final idx = ctrl.monitorIndex.value;
            final item = HardwareTestController.monitorColors[idx];
            final c = Color(item['color'] as int);

            return Container(
              color: c,
              width: double.infinity,
              height: double.infinity,
              child: Stack(
                children: [
                  Positioned(
                    top: 14,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${item['name']} (${item['hex']}) · ${idx + 1}/9',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 14,
                    right: 16,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      tooltip: 'خروج از تمام‌صفحه (ESC)',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 14,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'کلیک یا Space: رنگ بعدی | ESC: خروج',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}
