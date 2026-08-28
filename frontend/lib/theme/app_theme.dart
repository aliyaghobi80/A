import 'package:flutter/material.dart';

class AppTheme {
  // Font Family: Pure Offline Local Asset (Zero Runtime CDN)
  static const String fontFamily = 'Vazirmatn';

  // Light Palette (Default - Clean Enterprise Windows 11 Desktop)
  static const Color lightBackground = Color(0xFFF6F8FB);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightBorderSubtle = Color(0xFFEDF2F7);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightTextMuted = Color(0xFF94A3B8);

  // Dark Palette (Optional Dark Mode)
  static const Color darkBackground = Color(0xFF0B1220);
  static const Color darkSurface = Color(0xFF111C2E);
  static const Color darkCard = Color(0xFF162238);
  static const Color darkBorder = Color(0xFF263752);
  static const Color darkBorderSubtle = Color(0xFF1D2C42);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextMuted = Color(0xFF64748B);

  // Semantic Status Colors
  static const Color statusSuccess = Color(0xFF10B981);
  static const Color statusWarning = Color(0xFFF59E0B);
  static const Color statusDanger = Color(0xFFEF4444);
  static const Color statusNeutral = Color(0xFF64748B);
  static const Color statusInfo = Color(0xFF0284C7);

  // Accent Colors
  static const Map<String, Color> accentColors = {
    'blue': Color(0xFF2563EB),
    'purple': Color(0xFF7C3AED),
    'green': Color(0xFF10B981),
    'orange': Color(0xFFF59E0B),
    'red': Color(0xFFEF4444),
    'teal': Color(0xFF0D9488),
    'neutral': Color(0xFF475569),
  };

  static Color getAccentColor(String name) {
    return accentColors[name.toLowerCase()] ?? accentColors['blue']!;
  }

  static TextTheme _buildTextTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final primaryColor = isDark ? darkTextPrimary : lightTextPrimary;
    final secondaryColor = isDark ? darkTextSecondary : lightTextSecondary;
    final mutedColor = isDark ? darkTextMuted : lightTextMuted;

    return TextTheme(
      // Page Titles (24–28px)
      displayLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 26,
        fontWeight: FontWeight.w800,
        color: primaryColor,
        letterSpacing: -0.4,
      ),
      // Section Titles (18–20px)
      titleLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 19,
        fontWeight: FontWeight.w800,
        color: primaryColor,
        letterSpacing: -0.2,
      ),
      // Card Titles / Device Names (16–18px)
      titleMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 16.5,
        fontWeight: FontWeight.w700,
        color: primaryColor,
      ),
      // Secondary Titles (14–16px)
      titleSmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 14.5,
        fontWeight: FontWeight.w700,
        color: primaryColor,
      ),
      // Main Body / Values (14–15px)
      bodyLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: primaryColor,
      ),
      // Secondary Body (13–14px)
      bodyMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: secondaryColor,
      ),
      // Captions & Metadata (11.5–12.5px)
      bodySmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: mutedColor,
      ),
      // Labels (11–12px)
      labelSmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        color: mutedColor,
      ),
    );
  }

  static ThemeData getLightTheme({
    String languageCode = 'fa',
    String accentColorName = 'blue',
  }) {
    final primary = getAccentColor(accentColorName);
    final textTheme = _buildTextTheme(Brightness.light);

    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackground,
      colorScheme: ColorScheme.light(
        primary: primary,
        secondary: const Color(0xFF0284C7),
        surface: lightSurface,
        error: statusDanger,
      ),
      textTheme: textTheme,
      cardTheme: CardThemeData(
        color: lightCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: lightBorder, width: 1.2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(0, 38),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: lightTextPrimary,
          minimumSize: const Size(0, 38),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          side: const BorderSide(color: lightBorder, width: 1.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        side: const BorderSide(color: Color(0xFF94A3B8), width: 1.5),
      ),
    );
  }

  static ThemeData getDarkTheme({
    String languageCode = 'fa',
    String accentColorName = 'blue',
  }) {
    final primary = getAccentColor(accentColorName);
    final textTheme = _buildTextTheme(Brightness.dark);

    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      colorScheme: ColorScheme.dark(
        primary: primary,
        secondary: const Color(0xFF06B6D4),
        surface: darkSurface,
        error: statusDanger,
      ),
      textTheme: textTheme,
      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: darkBorder, width: 1.2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(0, 38),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkTextPrimary,
          minimumSize: const Size(0, 38),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          side: const BorderSide(color: darkBorder, width: 1.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        side: const BorderSide(color: Color(0xFF64748B), width: 1.5),
      ),
    );
  }
}
