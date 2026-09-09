import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/theme_language_controller.dart';
import '../main.dart';
import '../services/backend_process_manager.dart';
import '../widgets/splash/splash_assembly.dart';
import '../widgets/splash/splash_brand_text.dart';
import '../widgets/splash/splash_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  bool _backendReady = false;
  bool _animationCompleted = false;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();

    // Core ~4.0 second animation sequence
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    );

    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _animationCompleted = true;
        _checkAndNavigate();
      }
    });

    _animController.forward();

    // Warm up and verify backend in parallel with the splash animation
    _initBackend();
  }

  Future<void> _initBackend() async {
    try {
      final ready = await BackendProcessManager.ensureBackendRunning();
      if (mounted) {
        setState(() {
          _backendReady = ready;
        });
        _checkAndNavigate();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _backendReady = true; // Proceed anyway on error so user is never stuck
        });
        _checkAndNavigate();
      }
    }
  }

  void _checkAndNavigate() {
    if (_hasNavigated || !mounted) return;

    // Transition when animation sequence has reached completion AND backend is ready
    if (_animationCompleted && _backendReady) {
      _navigateToDashboard();
    }
  }

  void _navigateToDashboard() {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const DashboardScreen(),
        transitionDuration: const Duration(milliseconds: 550),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.98, end: 1.0).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  void _skipSplash() {
    _navigateToDashboard();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color accentColor = const Color(0xFF00E5FF);
    bool isPersian = true;

    try {
      if (Get.isRegistered<ThemeLanguageController>()) {
        final ctrl = Get.find<ThemeLanguageController>();
        accentColor = ctrl.currentAccentColor;
        isPersian = ctrl.currentLocale.value.languageCode == 'fa';
      }
    } catch (_) {}

    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      body: Stack(
        children: [
          // 1. Technical Circuit & Ambient Background Painter
          Positioned.fill(
            child: CustomPaint(
              painter: _TechnicalBackgroundPainter(accentColor: accentColor),
            ),
          ),

          // 2. Main Centered Animated Visual Sequence
          Center(
            child: AnimatedBuilder(
              animation: _animController,
              builder: (context, _) {
                final progress = _animController.value;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Visual Assembly & Logo Stage
                    SizedBox(
                      width: 400,
                      height: 320,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // 0.0s to 2.1s: Hardware Components Assembly
                          SplashAssemblyWidget(
                            progress: progress,
                            accentColor: accentColor,
                          ),

                          // 2.1s to 4.0s: Markazi Logo Reveal & Shimmer
                          SplashLogoWidget(
                            progress: progress,
                            accentColor: accentColor,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 3.0s to 4.0s: Typography Brand Reveal
                    SizedBox(
                      height: 80,
                      child: SplashBrandTextWidget(
                        progress: progress,
                        accentColor: accentColor,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // 3. Subtle Status indicator (only if backend takes longer than 4.0s)
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _animController,
              builder: (context, _) {
                if (_animationCompleted && !_backendReady) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.0,
                          valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isPersian
                            ? 'در حال اتصال به سرویس هوشمند...'
                            : 'Connecting to backend...',
                        style: TextStyle(
                          fontFamily: 'Vazirmatn',
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),

          // 4. Subtle Accessible Skip Button (Top Corner)
          Positioned(
            top: 20,
            left: isPersian ? null : 20,
            right: isPersian ? 20 : null,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _skipSplash,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isPersian ? 'رد کردن' : 'Skip',
                        style: TextStyle(
                          fontFamily: 'Vazirmatn',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Icon(
                        isPersian
                            ? Icons.chevron_left_rounded
                            : Icons.chevron_right_rounded,
                        size: 16,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TechnicalBackgroundPainter extends CustomPainter {
  final Color accentColor;

  _TechnicalBackgroundPainter({required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Deep radial gradient background
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final bgPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.95,
        colors: [
          const Color(0xFF0E1726),
          const Color(0xFF070B14),
        ],
      ).createShader(rect);

    canvas.drawRect(rect, bgPaint);

    // 2. Extremely subtle technical grid dots
    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.035)
      ..style = PaintingStyle.fill;

    const double step = 44.0;
    for (double x = step / 2; x < size.width; x += step) {
      for (double y = step / 2; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 0.9, dotPaint);
      }
    }

    // 3. Subtle soft ambient center glow
    final centerGlow = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.45,
        colors: [
          accentColor.withValues(alpha: 0.06),
          Colors.transparent,
        ],
      ).createShader(rect);

    canvas.drawRect(rect, centerGlow);
  }

  @override
  bool shouldRepaint(covariant _TechnicalBackgroundPainter oldDelegate) {
    return oldDelegate.accentColor != accentColor;
  }
}
