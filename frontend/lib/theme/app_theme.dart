import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Dark Palette
  static const Color darkBackground = Color(0xFF0B0F19);
  static const Color darkSurface = Color(0xFF131B2E);
  static const Color darkCard = Color(0xFF192238);
  static const Color darkBorder = Color(0xFF263554);
  static const Color darkTextPrimary = Color(0xFFF1F5F9);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextMuted = Color(0xFF64748B);
  
  // Light Palette
  static const Color lightBackground = Color(0xFFF4F6F9);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightTextMuted = Color(0xFF94A3B8);

  // Accents
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color primaryBlueHover = Color(0xFF1D4ED8);
  static const Color accentCyan = Color(0xFF06B6D4);
  static const Color accentIndigo = Color(0xFF6366F1);
  static const Color statusSuccess = Color(0xFF10B981);
  static const Color statusWarning = Color(0xFFF59E0B);
  static const Color statusDanger = Color(0xFFEF4444);
  static const Color statusNeutral = Color(0xFF6B7280);

  static ThemeData get darkTheme {
    final textTheme = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: primaryBlue,
        secondary: accentCyan,
        surface: darkSurface,
        error: statusDanger,
      ),
      textTheme: textTheme.copyWith(
        displayLarge: textTheme.displayLarge?.copyWith(color: darkTextPrimary, fontWeight: FontWeight.bold),
        titleLarge: textTheme.titleLarge?.copyWith(color: darkTextPrimary, fontWeight: FontWeight.w600, letterSpacing: -0.3),
        titleMedium: textTheme.titleMedium?.copyWith(color: darkTextPrimary, fontWeight: FontWeight.w600),
        bodyLarge: textTheme.bodyLarge?.copyWith(color: darkTextPrimary),
        bodyMedium: textTheme.bodyMedium?.copyWith(color: darkTextSecondary),
        labelSmall: textTheme.labelSmall?.copyWith(color: darkTextMuted, fontWeight: FontWeight.w500),
      ),
      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: darkBorder, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: darkBorder,
        thickness: 1,
        space: 1,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: darkBorder),
        ),
        textStyle: const TextStyle(color: darkTextPrimary, fontSize: 12),
      ),
    );
  }

  static ThemeData get lightTheme {
    final textTheme = GoogleFonts.interTextTheme(ThemeData.light().textTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackground,
      colorScheme: const ColorScheme.light(
        primary: primaryBlue,
        secondary: primaryBlueHover,
        surface: lightSurface,
        error: statusDanger,
      ),
      textTheme: textTheme.copyWith(
        displayLarge: textTheme.displayLarge?.copyWith(color: lightTextPrimary, fontWeight: FontWeight.bold),
        titleLarge: textTheme.titleLarge?.copyWith(color: lightTextPrimary, fontWeight: FontWeight.w600, letterSpacing: -0.3),
        titleMedium: textTheme.titleMedium?.copyWith(color: lightTextPrimary, fontWeight: FontWeight.w600),
        bodyLarge: textTheme.bodyLarge?.copyWith(color: lightTextPrimary),
        bodyMedium: textTheme.bodyMedium?.copyWith(color: lightTextSecondary),
        labelSmall: textTheme.labelSmall?.copyWith(color: lightTextMuted, fontWeight: FontWeight.w500),
      ),
      cardTheme: CardThemeData(
        color: lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: lightBorder, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: lightBorder,
        thickness: 1,
        space: 1,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}
