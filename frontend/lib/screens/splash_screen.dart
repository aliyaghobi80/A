import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/startup_controller.dart';
import '../main.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.connect, this.onReady});
  final Future<bool> Function()? connect;
  final VoidCallback? onReady;
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  late final StartupController _startup;
  late final Worker _statusWorker;
  Timer? _minimumTimer;
  bool _minimumElapsed = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _startup = StartupController(connect: widget.connect);
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..forward();
    _statusWorker = ever(_startup.status, (_) => _navigateIfReady());
    _minimumTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      setState(() => _minimumElapsed = true);
      _navigateIfReady();
    });
    unawaited(_startup.connect());
  }

  void _navigateIfReady() {
    if (_startup.status.value == StartupStatus.ready) _continue();
  }

  void _continue() {
    if (!mounted || !_minimumElapsed || _navigated) return;
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
    _minimumTimer?.cancel();
    _statusWorker.dispose();
    _startup.onDelete();
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _animation,
                    builder: (context, _) {
                      final progress = reducedMotion ? 1.0 : _animation.value;
                      final entrance = Curves.easeOutCubic.transform(
                        (progress / 0.3).clamp(0.0, 1.0),
                      );
                      final pulse = reducedMotion
                          ? 0.5
                          : (math.sin(progress * math.pi * 5) + 1) / 2;
                      return Column(
                        children: [
                          Opacity(
                            opacity: entrance,
                            child: SizedBox(
                              width: 156,
                              height: 156,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: 148,
                                    height: 148,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: colors.primary.withValues(
                                            alpha: 0.10 + pulse * 0.08,
                                          ),
                                          blurRadius: 24 + pulse * 10,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Transform.rotate(
                                    angle: reducedMotion
                                        ? 0
                                        : progress * math.pi * 1.2,
                                    child: Container(
                                      width: 142,
                                      height: 142,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: colors.primary.withValues(
                                            alpha: 0.22,
                                          ),
                                        ),
                                      ),
                                      child: Align(
                                        alignment: Alignment.topCenter,
                                        child: Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: colors.primary,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Transform.scale(
                                    scale: 0.88 + 0.12 * entrance,
                                    child: Container(
                                      width: 118,
                                      height: 118,
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: colors.surface,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: colors.primary.withValues(
                                            alpha: 0.16,
                                          ),
                                        ),
                                      ),
                                      child: ClipOval(
                                        child: Image.asset(
                                          'assets/logo/camputermarkazi.png',
                                          semanticLabel: 'لوگوی مارکازی',
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) => Icon(
                                            Icons.computer_rounded,
                                            size: 82,
                                            color: colors.primary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 26),
                          Semantics(
                            label: 'مرکزی سیستم چکر',
                            excludeSemantics: true,
                            child: Directionality(
                              textDirection: TextDirection.rtl,
                              child: Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 8,
                                children: List.generate(3, (index) {
                                  final phase = Curves.easeOutBack.transform(
                                    ((progress - 0.18 - index * 0.13) / 0.28)
                                        .clamp(0.0, 1.0),
                                  );
                                  return Opacity(
                                    opacity: phase.clamp(0.0, 1.0),
                                    child: Transform.translate(
                                      offset: Offset(
                                        (1 - phase) * (index - 1) * 28,
                                        (1 - phase) * 14,
                                      ),
                                      child: Transform.scale(
                                        scale: 0.92 + phase * 0.08,
                                        child: Text(
                                          ['مرکزی', 'سیستم', 'چکر'][index],
                                          style: Theme.of(context)
                                              .textTheme
                                              .headlineSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: -0.4,
                                              ),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Opacity(
                            opacity: Curves.easeOut.transform(
                              ((progress - 0.58) / 0.18).clamp(0.0, 1.0),
                            ),
                            child: Text(
                              'Markazi System Checker',
                              textDirection: TextDirection.ltr,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: colors.onSurfaceVariant,
                                    letterSpacing: 0.4,
                                  ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Container(
                            width: 176,
                            height: 4,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: Curves.easeInOutCubic.transform(
                                progress,
                              ),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      colors.primary.withValues(alpha: 0.55),
                                      colors.primary,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 40),
                  Obx(() {
                    final status = _startup.status.value;
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
                                onPressed: _startup.connect,
                                icon: const Icon(Icons.refresh),
                                label: const Text('تلاش مجدد'),
                              ),
                              OutlinedButton(
                                onPressed: _minimumElapsed ? _continue : null,
                                child: const Text('ورود برای بررسی'),
                              ),
                            ],
                          ),
                        ],
                      );
                    }
                    return Text(
                      status == StartupStatus.ready
                          ? 'آمادهٔ شروع'
                          : 'در حال آماده‌سازی برنامه…',
                      textAlign: TextAlign.center,
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
