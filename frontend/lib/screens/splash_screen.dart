import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/system_info_controller.dart';
import '../controllers/startup_controller.dart';
import '../main.dart';
import '../services/backend_process_manager.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.connect, this.onReady});

  final Future<bool> Function()? connect;
  final VoidCallback? onReady;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entrance;
  late final AnimationController _rgb;
  late final StartupController _startup;
  late final Worker _statusWorker;
  bool _navigated = false;
  bool? _reducedMotion;

  @override
  void initState() {
    super.initState();
    _startup = StartupController(
      connect: widget.connect,
      connectWithProgress: widget.connect == null ? _prepareApplication : null,
    );
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..forward();
    _rgb = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _statusWorker = ever(_startup.status, (_) => _navigateIfReady());
    unawaited(_startup.connect());
  }

  Future<bool> _prepareApplication(StartupProgressReporter report) async {
    report(0.12, 'در حال راه‌اندازی سرویس برنامه…');
    final backendReady = await BackendProcessManager.ensureBackendRunning();
    if (!backendReady) return false;
    report(0.48, 'سرویس آماده شد؛ در حال خواندن مشخصات دستگاه…');
    if (!Get.isRegistered<SystemInfoController>()) return true;
    final ready = await Get.find<SystemInfoController>().prepareInitialData(
      report: report,
    );
    if (ready) report(0.92, 'در حال آماده‌سازی رابط کاربری…');
    return ready;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (_reducedMotion == reduced) return;
    _reducedMotion = reduced;
    if (reduced) {
      _rgb.stop();
    } else {
      _rgb.repeat();
    }
  }

  void _navigateIfReady() {
    if (_startup.status.value == StartupStatus.ready) _continue();
  }

  void _continue() {
    if (!mounted || _navigated) return;
    _navigated = true;
    if (widget.onReady != null) {
      widget.onReady!();
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const DashboardScreen()),
    );
  }

  @override
  void dispose() {
    _statusWorker.dispose();
    _startup.onDelete();
    _entrance.dispose();
    _rgb.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      backgroundColor: dark ? const Color(0xFF050816) : const Color(0xFFF5F7FF),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.16),
            radius: 1.05,
            colors: dark
                ? const [Color(0xFF121A3C), Color(0xFF050816)]
                : const [Color(0xFFFFFFFF), Color(0xFFEEF2FF)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final shortest = math.min(
                constraints.maxWidth,
                constraints.maxHeight,
              );
              final logoSize = (shortest * 0.38).clamp(190.0, 284.0);
              final dropDistance = math.min(
                constraints.maxHeight * 0.52,
                360.0,
              );

              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_entrance, _rgb]),
                      builder: (context, _) {
                        final progress = reducedMotion ? 1.0 : _entrance.value;
                        final rgbProgress = reducedMotion ? 0.18 : _rgb.value;
                        final landing = Curves.easeOutBack.transform(
                          (progress / 0.34).clamp(0.0, 1.0),
                        );
                        final logoOpacity = Curves.easeOut.transform(
                          (progress / 0.16).clamp(0.0, 1.0),
                        );
                        final englishPhase = Curves.easeOutCubic.transform(
                          ((progress - 0.64) / 0.17).clamp(0.0, 1.0),
                        );
                        final loaderPhase = Curves.easeOutCubic.transform(
                          ((progress - 0.73) / 0.16).clamp(0.0, 1.0),
                        );

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Opacity(
                              opacity: logoOpacity,
                              child: Transform.translate(
                                key: const ValueKey('splash-logo-drop'),
                                offset: Offset(
                                  0,
                                  -(1 - landing) * dropDistance,
                                ),
                                child: Transform.scale(
                                  scale: 0.88 + (landing * 0.12),
                                  child: _CoverLogo(
                                    size: logoSize,
                                    glowPhase: rgbProgress,
                                    dark: dark,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 28),
                            Semantics(
                              label: 'مرکزی سیستم چکر',
                              excludeSemantics: true,
                              child: Directionality(
                                textDirection: TextDirection.rtl,
                                child: Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: 10,
                                  runSpacing: 6,
                                  children: List.generate(3, (index) {
                                    final phase = Curves.easeOutBack.transform(
                                      ((progress - 0.35 - index * 0.095) / 0.2)
                                          .clamp(0.0, 1.0),
                                    );
                                    return Opacity(
                                      opacity: phase.clamp(0.0, 1.0),
                                      child: Transform.translate(
                                        offset: Offset(0, (1 - phase) * 22),
                                        child: Transform.scale(
                                          scale: 0.86 + phase * 0.14,
                                          child: Text(
                                            ['مرکزی', 'سیستم', 'چکر'][index],
                                            style: theme
                                                .textTheme
                                                .headlineMedium
                                                ?.copyWith(
                                                  color: colors.onSurface,
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: -0.6,
                                                ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Opacity(
                              opacity: englishPhase,
                              child: Transform.translate(
                                offset: Offset(0, (1 - englishPhase) * 12),
                                child: Text(
                                  'Markazi System Checker',
                                  textDirection: TextDirection.ltr,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: colors.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 28),
                            Opacity(
                              opacity: loaderPhase,
                              child: Transform.scale(
                                scaleX: 0.72 + loaderPhase * 0.28,
                                child: Obx(
                                  () => Semantics(
                                    label: _startup.message.value,
                                    value:
                                        '${(_startup.progress.value * 100).round()} درصد',
                                    child: RepaintBoundary(
                                      child: CustomPaint(
                                        key: const ValueKey(
                                          'splash-rgb-loader',
                                        ),
                                        size: const Size(236, 24),
                                        painter: _RgbLoadingPainter(
                                          phase: rgbProgress,
                                          progress: _startup.progress.value,
                                          trackColor: colors.onSurface
                                              .withValues(
                                                alpha: dark ? 0.14 : 0.09,
                                              ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 22),
                            _StartupStatus(
                              startup: _startup,
                              onContinue: _continue,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CoverLogo extends StatelessWidget {
  const _CoverLogo({
    required this.size,
    required this.glowPhase,
    required this.dark,
  });

  final double size;
  final double glowPhase;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final hue = glowPhase * 360;
    final glow = HSVColor.fromAHSV(0.32, hue, 0.82, 1).toColor();
    final cornerRadius = BorderRadius.circular(size * 0.16);
    return Semantics(
      image: true,
      label: 'لوگوی کامپیوتر مرکزی',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: cornerRadius,
          boxShadow: [
            BoxShadow(color: glow, blurRadius: 34, spreadRadius: dark ? 1 : -2),
          ],
        ),
        child: ClipRRect(
          key: const ValueKey('splash-logo-rounded-cover'),
          borderRadius: cornerRadius,
          child: Transform.scale(
            // The source PNG has baked-in black margins. Cropping into its blue
            // field produces a true cover treatment without altering the logo.
            scale: 1.36,
            child: Image.asset(
              'assets/logo/camputermarkazi.png',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              excludeFromSemantics: true,
              errorBuilder: (_, _, _) => ColoredBox(
                color: const Color(0xFF071735),
                child: Icon(
                  Icons.computer_rounded,
                  size: size * 0.52,
                  color: const Color(0xFF38BDF8),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RgbLoadingPainter extends CustomPainter {
  const _RgbLoadingPainter({
    required this.phase,
    required this.progress,
    required this.trackColor,
  });

  final double phase;
  final double progress;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final bar = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 9, size.width, 6),
      const Radius.circular(99),
    );
    canvas.drawRRect(bar, Paint()..color = trackColor);

    final colors = List<Color>.generate(7, (index) {
      final hue = (phase * 360 + index * 60) % 360;
      return HSVColor.fromAHSV(1, hue, 0.82, 1).toColor();
    });
    final activeRect = Rect.fromLTWH(
      0,
      9,
      size.width * progress.clamp(0.0, 1.0),
      6,
    );
    final activeBar = RRect.fromRectAndRadius(
      activeRect,
      const Radius.circular(99),
    );
    final shader = LinearGradient(colors: colors).createShader(bar.outerRect);
    canvas.drawRRect(
      activeBar,
      Paint()
        ..shader = shader
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawRRect(activeBar, Paint()..shader = shader);

    final scannerX = (size.width + 44) * phase - 22;
    final scanner = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(scannerX, 12), width: 44, height: 4),
      const Radius.circular(99),
    );
    canvas.save();
    canvas.clipRRect(activeBar);
    canvas.drawRRect(
      scanner,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.7)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RgbLoadingPainter oldDelegate) {
    return oldDelegate.phase != phase ||
        oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor;
  }
}

class _StartupStatus extends StatelessWidget {
  const _StartupStatus({required this.startup, required this.onContinue});

  final StartupController startup;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final status = startup.status.value;
      if (status == StartupStatus.failed) {
        return Column(
          children: [
            const Icon(Icons.error_outline_rounded),
            const SizedBox(height: 8),
            const Text(
              'سرویس برنامه آماده نشد. می‌توانید دوباره تلاش کنید یا برای بررسی خطا وارد برنامه شوید.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: startup.connect,
                  icon: const Icon(Icons.refresh),
                  label: const Text('تلاش مجدد'),
                ),
                OutlinedButton(
                  onPressed: onContinue,
                  child: const Text('ورود برای بررسی'),
                ),
              ],
            ),
          ],
        );
      }
      return Text(startup.message.value, textAlign: TextAlign.center);
    });
  }
}
