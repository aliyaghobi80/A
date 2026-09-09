import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/theme_language_controller.dart';

class SplashBrandTextWidget extends StatelessWidget {
  final double progress; // 0.0 to 1.0 overall splash progress
  final Color accentColor;

  const SplashBrandTextWidget({
    super.key,
    required this.progress,
    this.accentColor = const Color(0xFF00E5FF),
  });

  @override
  Widget build(BuildContext context) {
    // Brand text begins revealing at 0.75 (3.0s)
    if (progress < 0.73) {
      return const SizedBox.shrink();
    }

    // Reveal progress from 0.73 to 0.90
    final double textProgress = ((progress - 0.73) / 0.17).clamp(0.0, 1.0);
    final double curvedText = Curves.easeOutCubic.transform(textProgress);

    final double opacity = curvedText;
    final double slideY = (1.0 - curvedText) * 14.0;

    // Determine current language
    bool isPersian = true;
    try {
      if (Get.isRegistered<ThemeLanguageController>()) {
        final ctrl = Get.find<ThemeLanguageController>();
        isPersian = ctrl.currentLocale.value.languageCode == 'fa';
      }
    } catch (_) {}

    final String primaryTitle = isPersian ? 'مرکزی سیستم چکر' : 'Markazi System Checker';
    final String secondarySubtitle = isPersian ? 'Markazi System Checker' : 'مرکزی سیستم چکر';

    return Opacity(
      opacity: opacity,
      child: Transform.translate(
        offset: Offset(0, slideY),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Primary Brand Title
            Text(
              primaryTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Vazirmatn',
                fontSize: isPersian ? 22.0 : 20.0,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: isPersian ? 0.3 : 1.2,
                shadows: [
                  Shadow(
                    color: accentColor.withValues(alpha: 0.4),
                    blurRadius: 16,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),

            // Subtle divider line with accent dot
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 1.0,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                Container(
                  width: 4,
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accentColor,
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.6),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 32,
                  height: 1.0,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Secondary Subtitle
            Text(
              secondarySubtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Vazirmatn',
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF94A3B8),
                letterSpacing: isPersian ? 1.0 : 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
