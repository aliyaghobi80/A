// frontend/lib/widgets/hardware_tests/mouse_test_view.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/hardware_test_controller.dart';
import '../../theme/app_theme.dart';

/// Interactive full-viewport Mouse & Scroll hardware test view.
///
/// Implements a unified interactive canvas with real-time localized ripple/splash
/// animations, centered 200x300 ergonomic 2D mouse graphic with glow effects,
/// sustained 5-button hold detection (Left, Middle, Right, Side 1 Back, Side 2 Forward),
/// cursor position indicator, double-click (<300ms) detection, and context menu suppression.
class MouseTestView extends StatefulWidget {
  const MouseTestView({super.key});

  @override
  State<MouseTestView> createState() => _MouseTestViewState();
}

class _RippleItem {
  final Offset position;
  final Color color;
  final AnimationController controller;
  final Animation<double> radiusAnim;
  final Animation<double> opacityAnim;

  _RippleItem({
    required this.position,
    required this.color,
    required this.controller,
    required this.radiusAnim,
    required this.opacityAnim,
  });
}

class _RippleRepaintNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

class _MouseTestViewState extends State<MouseTestView>
    with TickerProviderStateMixin {
  final List<_RippleItem> _ripples = [];
  final _RippleRepaintNotifier _rippleNotifier = _RippleRepaintNotifier();

  @override
  void dispose() {
    for (final r in _ripples) {
      r.controller.dispose();
    }
    _ripples.clear();
    _rippleNotifier.dispose();
    super.dispose();
  }

  void _addRipple(Offset position, Color color) {
    if (!mounted) return;

    if (_ripples.length >= 25) {
      final oldest = _ripples.removeAt(0);
      oldest.controller.dispose();
    }

    final controller = AnimationController(
      duration: const Duration(milliseconds: 550),
      vsync: this,
    );

    final radiusAnim = Tween<double>(begin: 8.0, end: 95.0).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeOutCubic),
    );

    final opacityAnim = Tween<double>(begin: 0.9, end: 0.0).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeOutQuad),
    );

    final ripple = _RippleItem(
      position: position,
      color: color,
      controller: controller,
      radiusAnim: radiusAnim,
      opacityAnim: opacityAnim,
    );

    controller.addListener(() {
      _rippleNotifier.notify();
    });

    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (_ripples.contains(ripple)) {
          _ripples.remove(ripple);
          ripple.controller.dispose();
          _rippleNotifier.notify();
        }
      }
    });

    _ripples.add(ripple);
    controller.forward();
  }

  void _handlePointerDown(
    PointerDownEvent event,
    HardwareTestController ctrl,
  ) {
    ctrl.onPointerDown(event.buttons, event.localPosition);

    // Add ripples for all active buttons
    if ((event.buttons & kPrimaryMouseButton) != 0) {
      _addRipple(event.localPosition, const Color(0xFF3B82F6));
    }
    if ((event.buttons & kSecondaryMouseButton) != 0) {
      _addRipple(event.localPosition, const Color(0xFF10B981));
    }
    if ((event.buttons & kMiddleMouseButton) != 0) {
      _addRipple(event.localPosition, const Color(0xFFF59E0B));
    }
    if ((event.buttons & kBackMouseButton) != 0) {
      _addRipple(event.localPosition, const Color(0xFF8B5CF6));
    }
    if ((event.buttons & kForwardMouseButton) != 0) {
      _addRipple(event.localPosition, const Color(0xFF06B6D4));
    }
  }

  void _handlePointerSignal(
    PointerSignalEvent event,
    HardwareTestController ctrl,
  ) {
    if (event is PointerScrollEvent) {
      final dy = event.scrollDelta.dy;
      if (dy != 0) {
        ctrl.onMouseScroll(dy);
        final currentPct = ctrl.mouseScrollPercent.value;
        final step = dy > 0 ? 5.0 : -5.0;
        ctrl.updateScrollProgress((currentPct + step).clamp(0.0, 100.0));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ctrl = Get.find<HardwareTestController>();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapDown: (_) {}, // Suppress Win32 context menu
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (e) => _handlePointerDown(e, ctrl),
        onPointerUp: (e) => ctrl.onPointerUp(e.buttons),
        onPointerMove: (e) => ctrl.onPointerMove(e.localPosition, hasButtons: e.buttons != 0),
        onPointerSignal: (e) => _handlePointerSignal(e, ctrl),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Interactive Canvas Background (Slate grid & subtle radial illumination)
            Positioned.fill(
              child: CustomPaint(
                painter: _GridBackgroundPainter(isDark: isDark),
              ),
            ),

            // 2. Click Ripple / Splash Animation Layer
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _RipplePainter(
                    ripples: _ripples,
                    repaint: _rippleNotifier,
                  ),
                ),
              ),
            ),

            // 3. Draggable Cursor Canvas Indicator
            Obx(() {
              final pos = ctrl.mousePosition.value;
              final isDragging = ctrl.isMouseDragging.value;
              if (pos == Offset.zero) return const SizedBox.shrink();
              return Positioned(
                left: pos.dx - 16,
                top: pos.dy - 16,
                child: IgnorePointer(
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDragging
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF3B82F6).withValues(alpha: 0.5),
                        width: isDragging ? 2.5 : 1.5,
                      ),
                      color: (isDragging
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF3B82F6))
                          .withValues(alpha: 0.12),
                    ),
                    child: Icon(
                      isDragging ? Icons.pan_tool_rounded : Icons.near_me_rounded,
                      size: 14,
                      color: isDragging ? const Color(0xFFEF4444) : const Color(0xFF3B82F6),
                    ),
                  ),
                ),
              );
            }),

            // 4. Centered 2D Mouse Graphic (200x300) with sustained hold & side buttons
            Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Obx(() {
                  return _buildMouse2DGraphic(ctrl, isDark);
                }),
              ),
            ),

            // 5. Floating Top HUD Bar (Navigation, 5-button stats, double-click, live action badge)
            Positioned(
              top: 16,
              left: 20,
              right: 20,
              child: _buildTopHud(context, ctrl, isDark),
            ),

            // 6. Floating Bottom HUD Bar (Guidance, Movement/Scroll stats, Reset)
            Positioned(
              bottom: 16,
              left: 20,
              right: 20,
              child: _buildBottomHud(context, ctrl, isDark),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 2D Mouse Graphic (200 x 300) with 5-Button Hold Detection
  // ===========================================================================
  Widget _buildMouse2DGraphic(HardwareTestController ctrl, bool isDark) {
    final active = ctrl.mouseActiveButton.value;
    final held = ctrl.heldMouseButtons;

    final isLeft = held.contains(1) || active == 'left';
    final isRight = held.contains(2) || active == 'right';
    final isMiddle = held.contains(4) || active == 'middle';
    final isSide1 = held.contains(8) || active == 'side1';
    final isSide2 = held.contains(16) || active == 'side2';
    final isWheelUp = active == 'wheel_up';
    final isWheelDown = active == 'wheel_down';

    return Container(
      width: 208,
      height: 300,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? const [Color(0xFF1E293B), Color(0xFF0F172A)]
              : const [Color(0xFFF1F5F9), Color(0xFFE2E8F0)],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(88),
          topRight: Radius.circular(88),
          bottomLeft: Radius.circular(72),
          bottomRight: Radius.circular(72),
        ),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
          width: 2.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.55 : 0.15),
            blurRadius: 30,
            spreadRadius: 2,
            offset: const Offset(0, 12),
          ),
          if (isLeft)
            const BoxShadow(
              color: Color(0xFF3B82F6),
              blurRadius: 30,
              spreadRadius: 2,
            ),
          if (isRight)
            const BoxShadow(
              color: Color(0xFF10B981),
              blurRadius: 30,
              spreadRadius: 2,
            ),
          if (isMiddle)
            const BoxShadow(
              color: Color(0xFFF59E0B),
              blurRadius: 30,
              spreadRadius: 2,
            ),
          if (isSide1)
            const BoxShadow(
              color: Color(0xFF8B5CF6),
              blurRadius: 25,
              spreadRadius: 2,
            ),
          if (isSide2)
            const BoxShadow(
              color: Color(0xFF06B6D4),
              blurRadius: 25,
              spreadRadius: 2,
            ),
          if (isWheelUp || isWheelDown)
            const BoxShadow(
              color: Color(0xFFEC4899),
              blurRadius: 30,
              spreadRadius: 2,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(86),
          topRight: Radius.circular(86),
          bottomLeft: Radius.circular(70),
          bottomRight: Radius.circular(70),
        ),
        child: Stack(
          children: [
            // Left Button Region
            Positioned(
              top: 0,
              left: 0,
              width: 101,
              height: 130,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  color: isLeft
                      ? const Color(0xFF3B82F6).withValues(alpha: 0.4)
                      : (isDark
                          ? const Color(0xFF1E293B).withValues(alpha: 0.6)
                          : Colors.white.withValues(alpha: 0.8)),
                  borderRadius:
                      const BorderRadius.only(topLeft: Radius.circular(86)),
                  border: Border(
                    right: BorderSide(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFCBD5E1),
                      width: 1.5,
                    ),
                    bottom: BorderSide(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFCBD5E1),
                      width: 1.5,
                    ),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 14),
                    Text(
                      'L',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                        color: isLeft
                            ? const Color(0xFF3B82F6)
                            : (isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B)),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isLeft && held.contains(1) ? 'نگه داشته شده' : 'کلیک چپ',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isLeft
                            ? const Color(0xFF3B82F6)
                            : (isDark
                                ? const Color(0xFF64748B)
                                : const Color(0xFF94A3B8)),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Right Button Region
            Positioned(
              top: 0,
              right: 0,
              width: 101,
              height: 130,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  color: isRight
                      ? const Color(0xFF10B981).withValues(alpha: 0.4)
                      : (isDark
                          ? const Color(0xFF1E293B).withValues(alpha: 0.6)
                          : Colors.white.withValues(alpha: 0.8)),
                  borderRadius:
                      const BorderRadius.only(topRight: Radius.circular(86)),
                  border: Border(
                    left: BorderSide(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFCBD5E1),
                      width: 1.5,
                    ),
                    bottom: BorderSide(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFCBD5E1),
                      width: 1.5,
                    ),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 14),
                    Text(
                      'R',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                        color: isRight
                            ? const Color(0xFF10B981)
                            : (isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B)),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isRight && held.contains(2) ? 'نگه داشته شده' : 'کلیک راست',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isRight
                            ? const Color(0xFF10B981)
                            : (isDark
                                ? const Color(0xFF64748B)
                                : const Color(0xFF94A3B8)),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Side 1 Button (Back)
            Positioned(
              top: 135,
              left: 0,
              width: 24,
              height: 38,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                decoration: BoxDecoration(
                  color: isSide1
                      ? const Color(0xFF8B5CF6)
                      : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                  border: Border.all(
                    color: isSide1
                        ? const Color(0xFF8B5CF6)
                        : (isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8)),
                  ),
                ),
                child: Center(
                  child: Text(
                    'B',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isSide1
                          ? Colors.white
                          : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                  ),
                ),
              ),
            ),

            // Side 2 Button (Forward)
            Positioned(
              top: 178,
              left: 0,
              width: 24,
              height: 38,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                decoration: BoxDecoration(
                  color: isSide2
                      ? const Color(0xFF06B6D4)
                      : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                  border: Border.all(
                    color: isSide2
                        ? const Color(0xFF06B6D4)
                        : (isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8)),
                  ),
                ),
                child: Center(
                  child: Text(
                    'F',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isSide2
                          ? Colors.white
                          : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                  ),
                ),
              ),
            ),

            // Scroll Wheel Slot & Animated Directional Indicators
            Positioned(
              top: 10,
              left: 86,
              width: 36,
              height: 108,
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    width: 1.5,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Up Directional Scroll Arrow
                    Positioned(
                      top: 3,
                      child: AnimatedSlide(
                        duration: const Duration(milliseconds: 120),
                        offset: isWheelUp ? const Offset(0, -0.25) : Offset.zero,
                        child: AnimatedScale(
                          duration: const Duration(milliseconds: 120),
                          scale: isWheelUp ? 1.35 : 1.0,
                          child: Icon(
                            isWheelUp
                                ? Icons.keyboard_double_arrow_up_rounded
                                : Icons.keyboard_arrow_up_rounded,
                            size: 16,
                            color: isWheelUp
                                ? const Color(0xFFEC4899)
                                : (isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8)),
                          ),
                        ),
                      ),
                    ),

                    // Scroll Wheel Pill
                    Positioned(
                      top: 24,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        width: 26,
                        height: 52,
                        decoration: BoxDecoration(
                          color: isMiddle
                              ? const Color(0xFFF59E0B)
                              : (isWheelUp || isWheelDown
                                  ? const Color(0xFFEC4899)
                                  : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(
                            color: (isMiddle || isWheelUp || isWheelDown)
                                ? Colors.white
                                : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(4, (_) {
                            return Container(
                              width: 14,
                              height: 2,
                              decoration: BoxDecoration(
                                color: (isMiddle || isWheelUp || isWheelDown)
                                    ? Colors.white.withValues(alpha: 0.85)
                                    : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                                borderRadius: BorderRadius.circular(1),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),

                    // Down Directional Scroll Arrow
                    Positioned(
                      bottom: 3,
                      child: AnimatedSlide(
                        duration: const Duration(milliseconds: 120),
                        offset: isWheelDown ? const Offset(0, 0.25) : Offset.zero,
                        child: AnimatedScale(
                          duration: const Duration(milliseconds: 120),
                          scale: isWheelDown ? 1.35 : 1.0,
                          child: Icon(
                            isWheelDown
                                ? Icons.keyboard_double_arrow_down_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            size: 16,
                            color: isWheelDown
                                ? const Color(0xFFEC4899)
                                : (isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Lower Body Palm Rest
            Positioned(
              top: 130,
              left: 24,
              right: 0,
              bottom: 0,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Dynamic LED Accent Light Bar
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: active.isNotEmpty || held.isNotEmpty ? 70 : 44,
                    height: 3,
                    decoration: BoxDecoration(
                      color: isLeft
                          ? const Color(0xFF3B82F6)
                          : (isRight
                              ? const Color(0xFF10B981)
                              : (isMiddle
                                  ? const Color(0xFFF59E0B)
                                  : (isSide1
                                      ? const Color(0xFF8B5CF6)
                                      : (isSide2
                                          ? const Color(0xFF06B6D4)
                                          : (isWheelUp || isWheelDown
                                              ? const Color(0xFFEC4899)
                                              : (isDark
                                                  ? const Color(0xFF334155)
                                                  : const Color(0xFFCBD5E1))))))),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Icon(
                    Icons.speed_rounded,
                    size: 20,
                    color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8),
                  ),
                  const SizedBox(height: 4),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      'MARKAZI',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.2,
                        color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'مرکزی سیستم',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
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

  // ===========================================================================
  // Floating Top HUD Bar
  // ===========================================================================
  Widget _buildTopHud(
    BuildContext context,
    HardwareTestController ctrl,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: (isDark ? const Color(0xFF1E293B) : Colors.white).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Back button
          Tooltip(
            message: 'بازگشت به لیست تست‌ها',
            child: InkWell(
              onTap: () => ctrl.selectSubTest('hub'),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9))
                      .withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    width: 1.0,
                  ),
                ),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'تست موس و اسکرول (۵ دکمه)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                ),
              ),
              Text(
                'آزمون کلیک، نگه‌داشتن، اسکرول و دوبار کلیک',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Stat chips and live action badge
          Obx(() {
            return Wrap(
              spacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildStatChip(
                  label: 'چپ',
                  count: ctrl.mouseLeftClicks.value,
                  color: const Color(0xFF3B82F6),
                  icon: Icons.mouse_rounded,
                  isDark: isDark,
                ),
                _buildStatChip(
                  label: 'راست',
                  count: ctrl.mouseRightClicks.value,
                  color: const Color(0xFF10B981),
                  icon: Icons.mouse_rounded,
                  isDark: isDark,
                ),
                _buildStatChip(
                  label: 'وسط',
                  count: ctrl.mouseMiddleClicks.value,
                  color: const Color(0xFFF59E0B),
                  icon: Icons.crop_portrait_rounded,
                  isDark: isDark,
                ),
                _buildStatChip(
                  label: 'جانبی ۱',
                  count: ctrl.mouseSide1Clicks.value,
                  color: const Color(0xFF8B5CF6),
                  icon: Icons.arrow_back_rounded,
                  isDark: isDark,
                ),
                _buildStatChip(
                  label: 'جانبی ۲',
                  count: ctrl.mouseSide2Clicks.value,
                  color: const Color(0xFF06B6D4),
                  icon: Icons.arrow_forward_rounded,
                  isDark: isDark,
                ),
                _buildStatChip(
                  label: 'دوبل',
                  count: ctrl.mouseDoubleClicks.value,
                  color: const Color(0xFF6366F1),
                  icon: Icons.touch_app_rounded,
                  isDark: isDark,
                ),
                _buildStatChip(
                  label: 'اسکرول',
                  count: ctrl.mouseWheelUp.value + ctrl.mouseWheelDown.value,
                  color: const Color(0xFFEC4899),
                  icon: Icons.swap_vert_rounded,
                  isDark: isDark,
                ),
                const SizedBox(width: 6),
                // Live action badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC))
                        .withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: (ctrl.mouseActiveButton.value.isNotEmpty ||
                                  ctrl.heldMouseButtons.isNotEmpty)
                              ? const Color(0xFF10B981)
                              : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        ctrl.lastMouseAction.value,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppTheme.darkTextSecondary
                              : AppTheme.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStatChip({
    required String label,
    required int count,
    required Color color,
    required IconData icon,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.35 : 0.25),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(width: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                  color: color,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Floating Bottom HUD Bar (Guidance, Movement/Scroll Stats & Reset)
  // ===========================================================================
  Widget _buildBottomHud(
    BuildContext context,
    HardwareTestController ctrl,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: (isDark ? const Color(0xFF1E293B) : Colors.white).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.touch_app_outlined,
            size: 18,
            color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'کلیک چپ، راست، وسط، کلیدهای جانبی (Side)، اسکرول و درگ موس را تست کنید. دوبار کلیک سریع (< 300ms) نیز ثبت می‌شود.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          // Live movement & scroll progress indicator
          Obx(() {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'حرکت: ${ctrl.mouseMoveCount.value}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'پیمایش: ${ctrl.mouseScrollPercent.value.toInt()}%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFEC4899),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(width: 12),
          // Reset Button
          OutlinedButton.icon(
            onPressed: () => ctrl.resetMouse(),
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('پاک‌سازی / Reset'),
            style: OutlinedButton.styleFrom(
              foregroundColor: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
              side: BorderSide(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                width: 1.2,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Background Canvas Painter
// =============================================================================
class _GridBackgroundPainter extends CustomPainter {
  final bool isDark;
  const _GridBackgroundPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFF334155).withValues(alpha: isDark ? 0.15 : 0.08)
      ..strokeWidth = 0.8;

    const step = 44.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Radial center illumination
    final center = Offset(size.width / 2, size.height / 2);
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.08 : 0.03),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: 260));
    canvas.drawCircle(center, 260, glowPaint);
  }

  @override
  bool shouldRepaint(covariant _GridBackgroundPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}

// =============================================================================
// Click Ripple Splash Painter
// =============================================================================
class _RipplePainter extends CustomPainter {
  final List<_RippleItem> ripples;

  _RipplePainter({
    required this.ripples,
    required Listenable repaint,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    if (ripples.isEmpty) return;

    final ringPaint = Paint()..style = PaintingStyle.stroke;
    final fillPaint = Paint()..style = PaintingStyle.fill;
    final dotPaint = Paint()..style = PaintingStyle.fill;

    for (final ripple in ripples) {
      final r = ripple.radiusAnim.value;
      final opacity = ripple.opacityAnim.value.clamp(0.0, 1.0);
      if (opacity <= 0.001) continue;

      // 1. Primary expanding outer shockwave ring
      ringPaint.color = ripple.color.withValues(alpha: opacity);
      ringPaint.strokeWidth = (2.6 * (1.0 - (r / 100.0))).clamp(1.0, 2.6);
      canvas.drawCircle(ripple.position, r, ringPaint);

      // 2. Secondary subtle inner ripple
      if (r > 16) {
        ringPaint.color = ripple.color.withValues(alpha: (opacity * 0.45).clamp(0.0, 1.0));
        ringPaint.strokeWidth = 1.2;
        canvas.drawCircle(ripple.position, r * 0.62, ringPaint);
      }

      // 3. Luminous splash glow core
      fillPaint.color = ripple.color.withValues(alpha: (opacity * 0.18).clamp(0.0, 1.0));
      canvas.drawCircle(ripple.position, r * 0.45, fillPaint);

      // 4. Exact click-point pin flash
      dotPaint.color = ripple.color.withValues(alpha: opacity);
      canvas.drawCircle(ripple.position, 3.2, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RipplePainter oldDelegate) => true;
}
