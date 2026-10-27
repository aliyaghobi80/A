// frontend/lib/widgets/hardware_tests/mouse_test_view.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/hardware_test_controller.dart';
import '../../theme/app_theme.dart';

class MouseTestView extends StatefulWidget {
  const MouseTestView({super.key});

  @override
  State<MouseTestView> createState() => _MouseTestViewState();
}

class _MouseTestViewState extends State<MouseTestView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScrollChanged);
  }

  void _onScrollChanged() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    final current = _scrollController.offset;
    final pct = max > 0 ? (current / max * 100).clamp(0.0, 100.0) : 0.0;
    Get.find<HardwareTestController>().updateScrollProgress(pct);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
                'تست موس، دکمه‌ها و چرخ اسکرول',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                ),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () => ctrl.resetMouse(),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('شروع از ابتدا'),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 4 Counter Stat Cards (Left, Right, Middle, Wheel)
          Obx(() {
            return Row(
              children: [
                _buildCountCard('کلیک چپ (Left)', '${ctrl.mouseLeftClicks.value}', const Color(0xFF3B82F6), isDark),
                const SizedBox(width: 12),
                _buildCountCard('کلیک راست (Right)', '${ctrl.mouseRightClicks.value}', const Color(0xFF10B981), isDark),
                const SizedBox(width: 12),
                _buildCountCard('کلیک وسط (Wheel)', '${ctrl.mouseMiddleClicks.value}', const Color(0xFFF59E0B), isDark),
                const SizedBox(width: 12),
                _buildCountCard('اسکرول چرخ (Scroll)', '${ctrl.mouseWheelUp.value + ctrl.mouseWheelDown.value}', const Color(0xFFEC4899), isDark),
              ],
            );
          }),

          const SizedBox(height: 16),

          // Interactive Testing Workspace: 2D Mouse Illustration + Real Scroll Area
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. 2D Visual Mouse Box
              Expanded(
                flex: 4,
                child: Container(
                  height: 340,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'شبیه‌ساز ۲ بعدی دکمه‌های موس',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                          Obx(() {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.2 : 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                ctrl.lastMouseAction.value,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF3B82F6),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // Interactive Mouse Body Target
                      Expanded(
                        child: Center(
                          child: Listener(
                            behavior: HitTestBehavior.opaque,
                            onPointerDown: (e) {
                              if (e.buttons & kPrimaryMouseButton != 0) {
                                ctrl.onMouseButton('left');
                              }
                              if (e.buttons & kSecondaryMouseButton != 0) {
                                ctrl.onMouseButton('right');
                              }
                              if (e.buttons & kMiddleMouseButton != 0) {
                                ctrl.onMouseButton('middle');
                              }
                            },
                            onPointerSignal: (e) {
                              if (e is PointerScrollEvent) {
                                ctrl.onMouseScroll(e.scrollDelta.dy);
                              }
                            },
                            child: Obx(() {
                              final active = ctrl.mouseActiveButton.value;
                              return _buildMouse2DGraphic(active, isDark);
                            }),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'روی کادر فوق کلیک چپ، راست یا دکمه وسط را بزنید.',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 16),

              // 2. Real Scrollable Workspace for Testing Scroll Wheel
              Expanded(
                flex: 5,
                child: Container(
                  height: 340,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'تست چرخ اسکرول (متن آزمایشی مرکزی)',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                          Obx(() {
                            return Text(
                              'موقعیت: ${ctrl.mouseScrollPercent.value.toInt()}%',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'monospace',
                                color: Color(0xFFEC4899),
                              ),
                            );
                          }),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Progress Bar
                      Obx(() {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: ctrl.mouseScrollPercent.value / 100.0,
                            minHeight: 5,
                            backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            valueColor: const AlwaysStoppedAnimation(Color(0xFFEC4899)),
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                      // Scrollable Text View
                      Expanded(
                        child: Listener(
                          onPointerDown: (e) {
                            if (e.buttons & kPrimaryMouseButton != 0) ctrl.onMouseButton('left');
                            if (e.buttons & kSecondaryMouseButton != 0) ctrl.onMouseButton('right');
                            if (e.buttons & kMiddleMouseButton != 0) ctrl.onMouseButton('middle');
                          },
                          onPointerSignal: (e) {
                            if (e is PointerScrollEvent) ctrl.onMouseScroll(e.scrollDelta.dy);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: ListView.builder(
                              controller: _scrollController,
                              itemCount: 40,
                              itemBuilder: (ctx, i) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 3),
                                  child: Text(
                                    'سطر ${(i + 1).toString().padLeft(2, '0')} — کامپیوتر مرکزی · تست روان بودن حرکت چرخ اسکرول موس',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'چرخ موس را روی متن بالا بچرخانید؛ متن باید روان و بدون پرش حرکت کند.',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ],
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
                        'ثبت نتیجه تست موس',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'آیا کلیک چپ، راست، کلیک وسط و حرکت چرخ اسکرول به‌درستی کار می‌کنند؟',
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
                    final left = ctrl.mouseLeftClicks.value;
                    final right = ctrl.mouseRightClicks.value;
                    final mid = ctrl.mouseMiddleClicks.value;
                    final wheel = ctrl.mouseWheelUp.value + ctrl.mouseWheelDown.value;
                    ctrl.recordResult(
                      testName: 'تست موس و اسکرول',
                      status: 'passed',
                      details: 'کلیک چپ ($left)، راست ($right)، وسط ($mid) و اسکرول ($wheel) آزمایش و تأیید شد.',
                    );
                    Get.snackbar(
                      'ثبت شد',
                      'سلامت موس در کارنامه ثبت شد.',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.9),
                      colorText: Colors.white,
                      duration: const Duration(seconds: 2),
                    );
                  },
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('موس و اسکرول سالم است (موفق)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () {
                    ctrl.recordResult(
                      testName: 'تست موس و اسکرول',
                      status: 'failed',
                      details: 'دابل کلیک ناخواسته، کار نکردن یکی از دکمه‌ها یا هرز بودن چرخ اسکرول گزارش شد.',
                    );
                    Get.snackbar(
                      'ثبت شد',
                      'ایراد موس در کارنامه ثبت شد.',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.9),
                      colorText: Colors.white,
                      duration: const Duration(seconds: 2),
                    );
                  },
                  icon: const Icon(Icons.error_outline_rounded, size: 16),
                  label: const Text('ایراد در عملکرد موس'),
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

  Widget _buildCountCard(String label, String value, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: color,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMouse2DGraphic(String active, bool isDark) {
    final isLeft = active == 'left';
    final isRight = active == 'right';
    final isMiddle = active == 'middle';
    final isWheelUp = active == 'wheel_up';
    final isWheelDown = active == 'wheel_down';

    return Container(
      width: 140,
      height: 220,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(60),
          topRight: Radius.circular(60),
          bottomLeft: Radius.circular(50),
          bottomRight: Radius.circular(50),
        ),
        border: Border.all(
          color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8),
          width: 2.5,
        ),
      ),
      child: Stack(
        children: [
          // Left Button Region
          Positioned(
            top: 0,
            left: 0,
            right: 70,
            height: 95,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                color: isLeft ? const Color(0xFF3B82F6) : Colors.transparent,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(58)),
                border: Border(
                  right: BorderSide(
                    color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8),
                    width: 1.5,
                  ),
                  bottom: BorderSide(
                    color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8),
                    width: 1.5,
                  ),
                ),
              ),
              child: Center(
                child: Text(
                  'L',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: isLeft ? Colors.white : (isDark ? Colors.grey : Colors.black54),
                  ),
                ),
              ),
            ),
          ),

          // Right Button Region
          Positioned(
            top: 0,
            right: 0,
            left: 70,
            height: 95,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                color: isRight ? const Color(0xFF10B981) : Colors.transparent,
                borderRadius: const BorderRadius.only(topRight: Radius.circular(58)),
                border: Border(
                  left: BorderSide(
                    color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8),
                    width: 1.5,
                  ),
                  bottom: BorderSide(
                    color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8),
                    width: 1.5,
                  ),
                ),
              ),
              child: Center(
                child: Text(
                  'R',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: isRight ? Colors.white : (isDark ? Colors.grey : Colors.black54),
                  ),
                ),
              ),
            ),
          ),

          // Middle Scroll Wheel in Center
          Positioned(
            top: 25,
            left: 58,
            width: 24,
            height: 48,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                color: isMiddle
                    ? const Color(0xFFF59E0B)
                    : (isWheelUp || isWheelDown
                        ? const Color(0xFFEC4899)
                        : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.white70 : Colors.black87,
                  width: 1.5,
                ),
                boxShadow: isMiddle || isWheelUp || isWheelDown
                    ? [
                        BoxShadow(
                          color: (isMiddle ? const Color(0xFFF59E0B) : const Color(0xFFEC4899)).withValues(alpha: 0.5),
                          blurRadius: 8,
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Icon(
                  isWheelUp
                      ? Icons.arrow_upward_rounded
                      : (isWheelDown ? Icons.arrow_downward_rounded : Icons.unfold_more_rounded),
                  size: 14,
                  color: isMiddle || isWheelUp || isWheelDown ? Colors.white : Colors.grey,
                ),
              ),
            ),
          ),

          // Lower Body Palm Rest
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'Markazi',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8),
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
