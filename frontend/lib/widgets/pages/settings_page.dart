import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/theme_language_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../services/folder_picker_service.dart';
import '../../theme/app_theme.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeCtrl = Get.find<ThemeLanguageController>();
    final l10n = AppLocalizations.of(context);
    final accent = themeCtrl.currentAccentColor;

    return Obx(() {
      final currentTheme = themeCtrl.themeMode.value;
      final currentAccent = themeCtrl.accentColorName.value;
      final customLogo = themeCtrl.customLogoPath.value;
      final isFa = themeCtrl.isPersian;

      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.isPersian ? 'تنظیمات برنامه' : 'Application Settings',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: isDark
                    ? AppTheme.darkTextPrimary
                    : AppTheme.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 14),

            // 1. Theme Selection
            _buildSettingCard(
              title: 'حالت تم (Theme Mode)',
              child: Row(
                children: [
                  _buildThemeOption(
                    'روشن (پیش‌فرض)',
                    Icons.light_mode_rounded,
                    currentTheme == ThemeMode.light,
                    () => themeCtrl.setThemeMode(ThemeMode.light),
                    isDark,
                    accent,
                  ),
                  const SizedBox(width: 12),
                  _buildThemeOption(
                    'تیره (Dark)',
                    Icons.dark_mode_rounded,
                    currentTheme == ThemeMode.dark,
                    () => themeCtrl.setThemeMode(ThemeMode.dark),
                    isDark,
                    accent,
                  ),
                  const SizedBox(width: 12),
                  _buildThemeOption(
                    'همگام با سیستم',
                    Icons.brightness_auto_rounded,
                    currentTheme == ThemeMode.system,
                    () => themeCtrl.setThemeMode(ThemeMode.system),
                    isDark,
                    accent,
                  ),
                ],
              ),
              isDark: isDark,
            ),

            const SizedBox(height: 14),

            // 2. Accent Color Swatches
            _buildSettingCard(
              title: 'رنگ شاخص برنامه (Accent Color)',
              child: Wrap(
                spacing: 10,
                runSpacing: 8,
                children: AppTheme.accentColors.entries.map((entry) {
                  final colorName = entry.key;
                  final colorVal = entry.value;
                  final isSelected = currentAccent == colorName;

                  return InkWell(
                    onTap: () => themeCtrl.setAccentColor(colorName),
                    borderRadius: BorderRadius.circular(8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colorVal
                            : (isDark
                                  ? AppTheme.darkCard
                                  : const Color(0xFFF8FAFC)),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? colorVal
                              : (isDark
                                    ? AppTheme.darkBorder
                                    : AppTheme.lightBorder),
                          width: isSelected ? 2.0 : 1.2,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: colorVal.withValues(alpha: 0.35),
                                  blurRadius: 8,
                                  spreadRadius: 0,
                                ),
                              ]
                            : [],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white.withValues(alpha: 0.3)
                                  : colorVal,
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(color: Colors.white, width: 1.5)
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            colorName,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : (isDark
                                        ? AppTheme.darkTextSecondary
                                        : AppTheme.lightTextPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              isDark: isDark,
            ),

            const SizedBox(height: 14),

            // 3. Logo Management
            _buildSettingCard(
              title: 'لوگوی اختصاصی شرکت (Branding Logo)',
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFF8FAFC),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark
                            ? AppTheme.darkBorder
                            : AppTheme.lightBorder,
                      ),
                    ),
                    child: ClipOval(
                      child: customLogo != null && File(customLogo).existsSync()
                          ? Image.file(File(customLogo), fit: BoxFit.cover)
                          : Image.asset(
                              'assets/logo/camputermarkazi.png',
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      customLogo != null
                          ? 'لوگوی سفارشی در برنامه بارگذاری شده است.'
                          : 'لوگوی پیش‌فرض شرکت کامپیوتر مرکزی فعال است.',
                      style: TextStyle(
                        fontSize: 13.5,
                        color: isDark
                            ? AppTheme.darkTextPrimary
                            : AppTheme.lightTextPrimary,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final path = await FolderPickerService.pickFolder(
                        title: 'انتخاب فایل تصویر لوگو (PNG)',
                      );
                      if (path != null && path.isNotEmpty) {
                        themeCtrl.setCustomLogo(path);
                      }
                    },
                    icon: const Icon(Icons.upload_file_rounded, size: 16),
                    label: const Text('انتخاب فایل PNG'),
                  ),
                  if (customLogo != null) ...[
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => themeCtrl.setCustomLogo(null),
                      child: const Text(
                        'بازنشانی به پیش‌فرض',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.statusDanger,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              isDark: isDark,
            ),

            const SizedBox(height: 14),

            // 4. Language
            _buildSettingCard(
              title: 'زبان و مشخصات رابط کاربری',
              child: Row(
                children: [
                  Text(
                    'زبان نمایش: ',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: isDark
                          ? AppTheme.darkTextMuted
                          : AppTheme.lightTextMuted,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('فارسی (پیش‌فرض)'),
                    selected: isFa,
                    onSelected: (_) => themeCtrl.setLocale(const Locale('fa')),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('English'),
                    selected: !isFa,
                    onSelected: (_) => themeCtrl.setLocale(const Locale('en')),
                  ),
                ],
              ),
              isDark: isDark,
            ),

            const SizedBox(height: 20),

            // 5. Actions Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () async {
                    await themeCtrl.resetToDefaults();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('تنظیمات به حالت اولیه بازنشانی شدند.'),
                          backgroundColor: Color(0xFF64748B),
                        ),
                      );
                    }
                  },
                  child: const Text('بازنشانی به پیش‌فرض'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () async {
                    await themeCtrl.persistSettings();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('✓ تنظیمات با موفقیت ذخیره شدند.'),
                          backgroundColor: AppTheme.statusSuccess,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: accent),
                  child: const Text('ذخیره تنظیمات'),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  Widget _buildSettingCard({
    required String title,
    required Widget child,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: isDark
                  ? AppTheme.darkTextPrimary
                  : AppTheme.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildThemeOption(
    String label,
    IconData icon,
    bool isSelected,
    VoidCallback onTap,
    bool isDark,
    Color accent,
  ) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark
                      ? accent.withValues(alpha: 0.20)
                      : accent.withValues(alpha: 0.10))
                : (isDark ? AppTheme.darkCard : const Color(0xFFF8FAFC)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? accent
                  : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
              width: isSelected ? 2.0 : 1.2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.25),
                      blurRadius: 10,
                      spreadRadius: 0,
                    ),
                  ]
                : [],
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 24,
                color: isSelected
                    ? accent
                    : (isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.lightTextMuted),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? (isDark ? accent : accent)
                      : (isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.lightTextPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
