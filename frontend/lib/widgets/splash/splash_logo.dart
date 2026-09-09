import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/theme_language_controller.dart';

class SplashLogoWidget extends StatelessWidget {
  final double progress; // 0.0 to 1.0 overall splash progress
  final Color accentColor;

  const SplashLogoWidget({
    super.key,
    required this.progress,
    this.accentColor = const Color(0xFF00E5FF),
  });

  @override
  Widget build(BuildContext context) {
    // Phase 3 starts at 0.525 (2.1s). Logo begins fading in here.
    if (progress < 0.52) {
      return const SizedBox.shrink();
    }

    // Logo entrance animation (0.52 to 0.68)
    final double entranceProgress = ((progress - 0.52) / 0.16).clamp(0.0, 1.0);
    final double curvedEntrance = Curves.easeOutCubic.transform(entranceProgress);

    final double opacity = curvedEntrance;
    final double scale = 0.80 + (curvedEntrance * 0.20);

    // Light sweep animation (passes between 0.62 and 0.80)
    final double sweepProgress = ((progress - 0.62) / 0.18).clamp(0.0, 1.0);

    // Ambient glow pulse in Phase 4 (0.75 to 1.0)
    final double ambientPulse = progress >= 0.75
        ? (0.3 + (0.2 * ((progress - 0.75) / 0.25)))
        : 0.3;

    // Check for custom logo from controller if available
    String? customPath;
    try {
      if (Get.isRegistered<ThemeLanguageController>()) {
        customPath = Get.find<ThemeLanguageController>().customLogoPath.value;
      }
    } catch (_) {}

    final bool hasValidCustom =
        customPath != null && customPath.isNotEmpty && File(customPath).existsSync();

    return Opacity(
      opacity: opacity,
      child: Transform.scale(
        scale: scale,
        child: SizedBox(
          width: 170,
          height: 170,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. Ambient radial backlight glow
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      accentColor.withValues(alpha: ambientPulse * 0.4),
                      accentColor.withValues(alpha: ambientPulse * 0.15),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),

              // 2. Main Markazi Brand Logo
              Container(
                width: 120,
                height: 120,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF0F172A).withValues(alpha: 0.92),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.4 + (ambientPulse * 0.3)),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.2 + (ambientPulse * 0.2)),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: hasValidCustom
                      ? Image.file(
                          File(customPath),
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildDefaultLogo(),
                        )
                      : _buildDefaultLogo(),
                ),
              ),

              // 3. Subtle Light Sweep Shimmer Effect
              if (sweepProgress > 0.0 && sweepProgress < 1.0)
                Positioned.fill(
                  child: ClipOval(
                    child: CustomPaint(
                      painter: _LightSweepPainter(
                        sweepProgress: sweepProgress,
                        sweepColor: Colors.white.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultLogo() {
    return Image.asset(
      'assets/logo/camputermarkazi.png',
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (context, error, stackTrace) {
        // Fallback icon if png cannot be loaded
        return Center(
          child: Icon(
            Icons.computer_rounded,
            size: 54,
            color: accentColor,
          ),
        );
      },
    );
  }
}

class _LightSweepPainter extends CustomPainter {
  final double sweepProgress;
  final Color sweepColor;

  _LightSweepPainter({
    required this.sweepProgress,
    required this.sweepColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Sweep line moves diagonally across from -size.width to +2*size.width
    final sweepX = (-size.width) + (sweepProgress * size.width * 3);
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.transparent,
          sweepColor,
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(
        Rect.fromLTWH(sweepX - 35, 0, 70, size.height),
      );

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant _LightSweepPainter oldDelegate) {
    return oldDelegate.sweepProgress != sweepProgress;
  }
}
