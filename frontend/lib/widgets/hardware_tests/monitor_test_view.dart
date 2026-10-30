// frontend/lib/widgets/hardware_tests/monitor_test_view.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../controllers/hardware_test_controller.dart';
import '../../theme/app_theme.dart';

const _windowChannel = MethodChannel('markazi/window');

class MonitorTestView extends StatelessWidget {
  const MonitorTestView({super.key});

  void _openFullScreen(BuildContext context, HardwareTestController ctrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullScreenMonitorPage(ctrl: ctrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ctrl = Get.find<HardwareTestController>();

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 600;

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Back button row ──
              Wrap(
                spacing: 14,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => ctrl.selectSubTest('hub'),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                    label: const Text('بازگشت به لیست تست‌ها'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                    ),
                  ),
                  Text(
                    'تست مانیتور و پیکسل‌های نمایشگر',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark
                          ? AppTheme.darkTextPrimary
                          : AppTheme.lightTextPrimary,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ── Large color preview ──
              Obx(() {
                final idx = ctrl.monitorIndex.value;
                final currentColorData =
                    HardwareTestController.monitorColors[idx];
                final colorVal = Color(currentColorData['color'] as int);
                final isLight = colorVal.computeLuminance() > 0.5;

                return GestureDetector(
                  onTap: () => ctrl.nextMonitorColor(),
                  child: Container(
                    width: double.infinity,
                    constraints: BoxConstraints(
                      minHeight: narrow ? 200 : 320,
                    ),
                    decoration: BoxDecoration(
                      color: colorVal,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF475569)
                            : const Color(0xFFCBD5E1),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withValues(alpha: isDark ? 0.3 : 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color:
                                  (isLight ? Colors.black : Colors.white)
                                      .withValues(alpha: 0.85),
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
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Directionality(
                              textDirection: TextDirection.ltr,
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
                        ),
                      ],
                    ),
                  ),
                );
              }),

              const SizedBox(height: 16),

              // ── Color swatches ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'انتخاب الگوی رنگ:',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    Obx(() {
                      final currentIdx = ctrl.monitorIndex.value;
                      return Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: List.generate(
                          HardwareTestController.monitorColors.length,
                          (i) {
                            final item =
                                HardwareTestController.monitorColors[i];
                            final c = Color(item['color'] as int);
                            final isSelected = currentIdx == i;

                            return Tooltip(
                              message: item['name'] as String,
                              child: InkWell(
                                onTap: () => ctrl.setMonitorColor(i),
                                borderRadius: BorderRadius.circular(8),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: c,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xFF3B82F6)
                                          : Colors.grey.withValues(alpha: 0.4),
                                      width: isSelected ? 3.5 : 1.2,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: const Color(0xFF3B82F6)
                                                  .withValues(alpha: 0.5),
                                              blurRadius: 8,
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: isSelected
                                      ? Center(
                                          child: Icon(
                                            Icons.check_rounded,
                                            size: 20,
                                            color:
                                                c.computeLuminance() > 0.5
                                                    ? Colors.black
                                                    : Colors.white,
                                          ),
                                        )
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

              // ── Start Full Screen Test button ──
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () => _openFullScreen(context, ctrl),
                  icon: const Icon(Icons.fullscreen_rounded, size: 22),
                  label: const Text(
                    'شروع تست تمام‌صفحه',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Full-screen monitor page — pure static solid color, zero animations, zero
// gradients, zero overlays. Mouse cursor hidden during test.
// ESC exits and restores window geometry.
// ArrowRight / ArrowUp / Space / Left click -> Next color.
// ArrowLeft / ArrowDown / Right click -> Prev color.
// ─────────────────────────────────────────────────────────────────────────────
class _FullScreenMonitorPage extends StatefulWidget {
  final HardwareTestController ctrl;

  const _FullScreenMonitorPage({required this.ctrl});

  @override
  State<_FullScreenMonitorPage> createState() => _FullScreenMonitorPageState();
}

class _FullScreenMonitorPageState extends State<_FullScreenMonitorPage> {
  late final FocusNode _focusNode;
  bool _isFullScreenActive = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _enterFullScreen();
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _exitFullScreen();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _enterFullScreen() async {
    if (_isFullScreenActive) return;
    _isFullScreenActive = true;
    widget.ctrl.toggleMonitorFullScreen(true);
    try {
      await _windowChannel.invokeMethod('setFullScreen', true);
    } catch (_) {
      try {
        const MethodChannel('window_manager').invokeMethod('setFullScreen', true);
      } catch (_) {}
    }
  }

  Future<void> _exitFullScreen() async {
    if (!_isFullScreenActive) return;
    _isFullScreenActive = false;
    widget.ctrl.toggleMonitorFullScreen(false);
    try {
      await _windowChannel.invokeMethod('setFullScreen', false);
    } catch (_) {
      try {
        const MethodChannel('window_manager').invokeMethod('setFullScreen', false);
      } catch (_) {}
    }
  }

  void _close() {
    _exitFullScreen();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _advanceColorOrExit() {
    if (widget.ctrl.monitorIndex.value < HardwareTestController.monitorColors.length - 1) {
      widget.ctrl.nextMonitorColor();
    } else {
      _close();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, _) {
          _exitFullScreen();
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.none,
          child: Focus(
            focusNode: _focusNode,
            autofocus: true,
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent) {
                if (event.logicalKey == LogicalKeyboardKey.escape) {
                  _close();
                  return KeyEventResult.handled;
                } else if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
                    event.logicalKey == LogicalKeyboardKey.arrowUp ||
                    event.logicalKey == LogicalKeyboardKey.space) {
                  _advanceColorOrExit();
                  return KeyEventResult.handled;
                } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
                    event.logicalKey == LogicalKeyboardKey.arrowDown) {
                  widget.ctrl.prevMonitorColor();
                  return KeyEventResult.handled;
                }
              }
              return KeyEventResult.ignored;
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => widget.ctrl.nextMonitorColor(),
              onSecondaryTap: () => widget.ctrl.prevMonitorColor(),
              child: Obx(() {
                final idx = widget.ctrl.monitorIndex.value;
                final item = HardwareTestController.monitorColors[idx];
                final c = Color(item['color'] as int);

                // Pure static solid color: zero animation, zero gradients, zero overlays
                return Container(
                  key: const ValueKey('monitor-fullscreen-color-canvas'),
                  color: c,
                  width: double.infinity,
                  height: double.infinity,
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
