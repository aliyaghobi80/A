import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/driver_install_controller.dart';
import '../../controllers/qc_controller.dart';
import '../../controllers/software_controller.dart';
import '../../controllers/theme_language_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';

class AppSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final bool isCompact;

  const AppSidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeCtrl = Get.find<ThemeLanguageController>();
    final driverCtrl = Get.find<DriverInstallController>();
    final softwareCtrl = Get.find<SoftwareController>();
    final qcCtrl = Get.find<QcController>();
    final l10n = AppLocalizations.of(context);
    final width = isCompact ? 70.0 : 220.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: width,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        border: Border(
          left: BorderSide(
            color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
            width: 1.2,
          ),
        ),
      ),
      child: Column(
        children: [
          // 1. Sidebar Branding Header
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isCompact ? 8 : 14, vertical: 16),
            child: Obx(() {
              final customPath = themeCtrl.customLogoPath.value;
              final accent = themeCtrl.currentAccentColor;

              Widget logoWidget;
              if (customPath != null && File(customPath).existsSync()) {
                logoWidget = Image.file(
                  File(customPath),
                  width: 32,
                  height: 32,
                  fit: BoxFit.contain,
                );
              } else {
                logoWidget = Image.asset(
                  'assets/logo/camputermarkazi.png',
                  width: 32,
                  height: 32,
                  fit: BoxFit.contain,
                  errorBuilder: (ctx, err, stack) => Icon(
                    Icons.computer_rounded,
                    size: 28,
                    color: accent,
                  ),
                );
              }

              if (isCompact) {
                return Tooltip(
                  message: l10n.isPersian ? 'کامپیوتر مرکزی' : 'Central Computer',
                  child: Container(
                    width: 44,
                    height: 44,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: isDark ? 0.18 : 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(child: logoWidget),
                  ),
                );
              }

              return Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: isDark ? 0.18 : 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(child: logoWidget),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.isPersian ? 'کامپیوتر مرکزی' : 'Central Computer',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),
                        Text(
                          l10n.isPersian ? 'سیستم چکر و استقرار' : 'System Checker',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }),
          ),

          Divider(
            height: 1,
            color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          ),

          const SizedBox(height: 8),

          // 2. Navigation Items
          Expanded(
            child: Obx(() {
              final uninstalledPackages = softwareCtrl.packages.where((p) => !p.isInstalled && p.isValid).length;
              final scannedDrivers = driverCtrl.scannedFiles.length;

              return ListView(
                padding: EdgeInsets.symmetric(horizontal: isCompact ? 6 : 8, vertical: 4),
                children: [
                  _buildNavItem(
                    index: 0,
                    icon: Icons.dashboard_rounded,
                    title: l10n.isPersian ? 'مشخصات سخت‌افزار' : 'System Specs',
                    isDark: isDark,
                    themeCtrl: themeCtrl,
                    isCompact: isCompact,
                  ),
                  _buildNavItem(
                    index: 1,
                    icon: Icons.extension_rounded,
                    title: l10n.isPersian ? 'نصب درایورها' : 'Install Drivers',
                    badgeCount: scannedDrivers > 0 ? scannedDrivers : null,
                    badgeColor: AppTheme.statusWarning,
                    isDark: isDark,
                    themeCtrl: themeCtrl,
                    isCompact: isCompact,
                  ),
                  _buildNavItem(
                    index: 2,
                    icon: Icons.apps_rounded,
                    title: l10n.isPersian ? 'نصب نرم‌افزارها' : 'Install Software',
                    badgeCount: uninstalledPackages > 0 ? uninstalledPackages : null,
                    badgeColor: const Color(0xFF0284C7),
                    isDark: isDark,
                    themeCtrl: themeCtrl,
                    isCompact: isCompact,
                  ),
                  _buildNavItem(
                    index: 3,
                    icon: Icons.verified_user_rounded,
                    title: l10n.isPersian ? 'وضعیت لایسنس' : 'License Status',
                    isDark: isDark,
                    themeCtrl: themeCtrl,
                    isCompact: isCompact,
                  ),
                  _buildNavItem(
                    index: 4,
                    icon: Icons.folder_open_rounded,
                    title: l10n.isPersian ? 'پوشه‌ها و ابزارها' : 'Tools & Folders',
                    isDark: isDark,
                    themeCtrl: themeCtrl,
                    isCompact: isCompact,
                  ),
                  _buildNavItem(
                    index: 5,
                    icon: Icons.settings_rounded,
                    title: l10n.isPersian ? 'تنظیمات برنامه' : 'Settings',
                    isDark: isDark,
                    themeCtrl: themeCtrl,
                    isCompact: isCompact,
                  ),
                ],
              );
            }),
          ),

          // 3. QC Footer Banner
          if (!isCompact) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              child: InkWell(
                onTap: () => qcCtrl.runFullCheck(context),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: themeCtrl.currentAccentColor.withValues(alpha: isDark ? 0.15 : 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: themeCtrl.currentAccentColor.withValues(alpha: isDark ? 0.4 : 0.25),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: themeCtrl.currentAccentColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.isPersian ? 'بررسی آماده‌سازی QC' : 'QC Quality Check',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        Icons.chevron_left_rounded,
                        size: 18,
                        color: themeCtrl.currentAccentColor,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Tooltip(
                message: 'بررسی آماده‌سازی QC',
                child: IconButton(
                  onPressed: () => qcCtrl.runFullCheck(context),
                  icon: Icon(
                    Icons.fact_check_rounded,
                    color: themeCtrl.currentAccentColor,
                    size: 22,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String title,
    int? badgeCount,
    Color? badgeColor,
    required bool isDark,
    required ThemeLanguageController themeCtrl,
    required bool isCompact,
  }) {
    final isSelected = selectedIndex == index;
    final accent = themeCtrl.currentAccentColor;

    if (isCompact) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Tooltip(
          message: title,
          child: InkWell(
            onTap: () => onItemSelected(index),
            borderRadius: BorderRadius.circular(10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              height: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? accent.withValues(alpha: isDark ? 0.22 : 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: isSelected
                    ? Border.all(color: accent.withValues(alpha: 0.4), width: 1.2)
                    : null,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    icon,
                    size: 24,
                    color: isSelected
                        ? accent
                        : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                  ),
                  if (badgeCount != null && badgeCount > 0)
                    Positioned(
                      top: 6,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: badgeColor ?? AppTheme.statusWarning,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: InkWell(
        onTap: () => onItemSelected(index),
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? accent.withValues(alpha: isDark ? 0.18 : 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? accent.withValues(alpha: isDark ? 0.45 : 0.3)
                  : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected
                    ? accent
                    : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected
                        ? accent
                        : (isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (badgeCount != null && badgeCount > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeColor ?? AppTheme.statusWarning,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$badgeCount',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
