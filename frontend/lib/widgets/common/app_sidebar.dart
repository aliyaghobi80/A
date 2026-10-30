import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/driver_install_controller.dart';
import '../../controllers/hardware_test_controller.dart';
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
    final hardwareCtrl = Get.isRegistered<HardwareTestController>()
        ? Get.find<HardwareTestController>()
        : Get.put(HardwareTestController(), permanent: true);
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
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 8 : 14,
              vertical: 16,
            ),
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
                  errorBuilder: (ctx, err, stack) =>
                      Icon(Icons.computer_rounded, size: 28, color: accent),
                );
              }

              if (isCompact) {
                return Tooltip(
                  message: l10n.isPersian
                      ? 'کامپیوتر مرکزی'
                      : 'Markazi Computer',
                  child: Container(
                    width: 44,
                    height: 44,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: isDark ? 0.18 : 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: ClipOval(child: Center(child: logoWidget)),
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
                      shape: BoxShape.circle,
                    ),
                    child: ClipOval(child: Center(child: logoWidget)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.isPersian
                              ? 'کامپیوتر مرکزی'
                              : 'Markazi Computer',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? AppTheme.darkTextPrimary
                                : AppTheme.lightTextPrimary,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),
                        Text(
                          l10n.isPersian
                              ? 'سیستم چکر و استقرار'
                              : 'System Checker',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? AppTheme.darkTextMuted
                                : AppTheme.lightTextMuted,
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
              final uninstalledPackages = softwareCtrl.packages
                  .where((p) => !p.isInstalled && p.isValid)
                  .length;
              final scannedDrivers = driverCtrl.scannedFiles.length;
              final softwareBatch = softwareCtrl.batchStatus.value;
              final driverBatch = driverCtrl.batchStatus.value;
              final softwareBusy = softwareCtrl.hasActiveBatch;
              final driverBusy =
                  driverCtrl.isBatchInstalling.value || driverBatch.isRunning;

              return ListView(
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 6 : 8,
                  vertical: 4,
                ),
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
                    isBusy: driverBusy,
                    busyProgress: driverBatch.total > 0
                        ? '${driverBatch.completed}/${driverBatch.total}'
                        : null,
                    badgeCount: scannedDrivers > 0 ? scannedDrivers : null,
                    badgeColor: AppTheme.statusWarning,
                    isDark: isDark,
                    themeCtrl: themeCtrl,
                    isCompact: isCompact,
                  ),
                  _buildNavItem(
                    index: 2,
                    icon: Icons.apps_rounded,
                    title: l10n.isPersian
                        ? 'نصب نرم‌افزارها'
                        : 'Install Software',
                    isBusy: softwareBusy,
                    busyProgress: softwareBatch.total > 0
                        ? '${softwareBatch.completed}/${softwareBatch.total}'
                        : null,
                    badgeCount: uninstalledPackages > 0
                        ? uninstalledPackages
                        : null,
                    badgeColor: const Color(0xFF0284C7),
                    isDark: isDark,
                    themeCtrl: themeCtrl,
                    isCompact: isCompact,
                  ),
                  if (isCompact)
                    _buildNavItem(
                      index: 3,
                      icon: Icons.fact_check_rounded,
                      title: l10n.isPersian ? 'تست قطعات' : 'Hardware Tests',
                      isDark: isDark,
                      themeCtrl: themeCtrl,
                      isCompact: isCompact,
                    )
                  else
                    _buildHardwareTestsAccordion(
                      isDark: isDark,
                      themeCtrl: themeCtrl,
                      hardwareCtrl: hardwareCtrl,
                      l10n: l10n,
                    ),
                  _buildNavItem(
                    index: 4,
                    icon: Icons.verified_user_rounded,
                    title: l10n.isPersian ? 'وضعیت لایسنس' : 'License Status',
                    isDark: isDark,
                    themeCtrl: themeCtrl,
                    isCompact: isCompact,
                  ),
                  _buildNavItem(
                    index: 5,
                    icon: Icons.folder_open_rounded,
                    title: l10n.isPersian
                        ? 'پوشه‌ها و ابزارها'
                        : 'Tools & Folders',
                    isDark: isDark,
                    themeCtrl: themeCtrl,
                    isCompact: isCompact,
                  ),
                  _buildNavItem(
                    index: 6,
                    icon: Icons.important_devices_rounded,
                    title: l10n.isPersian
                        ? 'تنظیمات مهم دستگاه'
                        : 'Device Setup',
                    isDark: isDark,
                    themeCtrl: themeCtrl,
                    isCompact: isCompact,
                  ),
                  _buildNavItem(
                    index: 7,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: themeCtrl.currentAccentColor.withValues(
                      alpha: isDark ? 0.15 : 0.08,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: themeCtrl.currentAccentColor.withValues(
                        alpha: isDark ? 0.4 : 0.25,
                      ),
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
                          l10n.isPersian
                              ? 'بررسی آماده‌سازی QC'
                              : 'QC Quality Check',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppTheme.darkTextPrimary
                                : AppTheme.lightTextPrimary,
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
    bool isBusy = false,
    String? busyProgress,
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
                    ? (isDark
                          ? accent.withValues(alpha: 0.28)
                          : accent.withValues(alpha: 0.14))
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: isSelected
                    ? Border.all(
                        color: isDark ? accent : accent.withValues(alpha: 0.5),
                        width: 1.5,
                      )
                    : null,
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: accent.withValues(alpha: isDark ? 0.35 : 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    icon,
                    size: 24,
                    color: isSelected
                        ? (isDark ? Colors.white : accent)
                        : (isDark
                              ? AppTheme.darkTextSecondary
                              : AppTheme.lightTextSecondary),
                  ),
                  if (isBusy)
                    Positioned(
                      top: 5,
                      right: 8,
                      child: SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: badgeColor ?? accent,
                        ),
                      ),
                    )
                  else if (badgeCount != null && badgeCount > 0)
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
                ? (isDark
                      ? accent.withValues(alpha: 0.25)
                      : accent.withValues(alpha: 0.12))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? (isDark ? accent : accent.withValues(alpha: 0.4))
                  : Colors.transparent,
              width: 1.2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: isDark ? 0.25 : 0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              if (isSelected)
                Container(
                  width: 3.5,
                  height: 18,
                  margin: const EdgeInsets.only(left: 6),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              Icon(
                icon,
                size: 20,
                color: isSelected
                    ? (isDark ? Colors.white : accent)
                    : (isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.lightTextSecondary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected
                        ? (isDark ? Colors.white : accent)
                        : (isDark
                              ? AppTheme.darkTextSecondary
                              : AppTheme.lightTextPrimary),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isBusy) ...[
                Semantics(
                  label: 'عملیات نصب در حال اجرا است',
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: (badgeColor ?? accent).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: badgeColor ?? accent,
                          ),
                        ),
                        if (busyProgress != null) ...[
                          const SizedBox(width: 5),
                          Text(
                            busyProgress,
                            textDirection: TextDirection.ltr,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: badgeColor ?? accent,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ] else if (badgeCount != null && badgeCount > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
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

  Widget _buildHardwareTestsAccordion({
    required bool isDark,
    required ThemeLanguageController themeCtrl,
    required HardwareTestController hardwareCtrl,
    required AppLocalizations l10n,
  }) {
    final isSelected = selectedIndex == 3;
    final isExpanded = hardwareCtrl.isAccordionExpanded.value;
    final accent = themeCtrl.currentAccentColor;

    final subItems = [
      {
        'id': 'hub',
        'title': l10n.isPersian ? 'داشبورد آزمون‌ها' : 'Overview',
        'icon': Icons.grid_view_rounded,
      },
      {
        'id': 'monitor',
        'title': l10n.isPersian ? 'مانیتور و پیکسل' : 'Monitor Test',
        'icon': Icons.desktop_windows_rounded,
      },
      {
        'id': 'audio',
        'title': l10n.isPersian ? 'صدا و هدفون' : 'Audio & Headphones',
        'icon': Icons.headphones_rounded,
      },
      {
        'id': 'mic',
        'title': l10n.isPersian ? 'میکروفون' : 'Microphone',
        'icon': Icons.mic_rounded,
      },
      {
        'id': 'webcam',
        'title': l10n.isPersian ? 'وب‌کم و دوربین' : 'Webcam',
        'icon': Icons.videocam_rounded,
      },
      {
        'id': 'keyboard',
        'title': l10n.isPersian ? 'کیبورد' : 'Keyboard',
        'icon': Icons.keyboard_rounded,
      },
      {
        'id': 'mouse',
        'title': l10n.isPersian ? 'موس و اسکرول' : 'Mouse & Scroll',
        'icon': Icons.mouse_rounded,
      },
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.5),
          child: InkWell(
            onTap: () {
              onItemSelected(3);
              hardwareCtrl.toggleAccordion();
            },
            borderRadius: BorderRadius.circular(8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDark
                          ? accent.withValues(alpha: 0.25)
                          : accent.withValues(alpha: 0.12))
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? (isDark ? accent : accent.withValues(alpha: 0.4))
                      : Colors.transparent,
                  width: 1.2,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: accent.withValues(alpha: isDark ? 0.25 : 0.1),
                          blurRadius: 6,
                          offset: const Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  if (isSelected)
                    Container(
                      width: 3.5,
                      height: 18,
                      margin: const EdgeInsetsDirectional.only(end: 6),
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  Icon(
                    Icons.fact_check_rounded,
                    size: 20,
                    color: isSelected
                        ? (isDark ? Colors.white : accent)
                        : (isDark
                              ? AppTheme.darkTextSecondary
                              : AppTheme.lightTextSecondary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.isPersian ? 'تست قطعات' : 'Hardware Tests',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected
                            ? (isDark ? Colors.white : accent)
                            : (isDark
                                  ? AppTheme.darkTextSecondary
                                  : AppTheme.lightTextPrimary),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (isExpanded)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 14, top: 2, bottom: 4),
            child: Column(
              children: subItems.map((item) {
                final itemId = item['id'] as String;
                final itemTitle = item['title'] as String;
                final itemIcon = item['icon'] as IconData;
                final isSubActive =
                    isSelected && hardwareCtrl.activeSubTest.value == itemId;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1.5),
                  child: InkWell(
                    onTap: () {
                      onItemSelected(3);
                      hardwareCtrl.selectSubTest(itemId);
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6.5,
                      ),
                      decoration: BoxDecoration(
                        color: isSubActive
                            ? accent.withValues(alpha: isDark ? 0.2 : 0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isSubActive
                              ? accent.withValues(alpha: 0.35)
                              : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            itemIcon,
                            size: 15,
                            color: isSubActive
                                ? (isDark ? Colors.white : accent)
                                : (isDark
                                      ? AppTheme.darkTextMuted
                                      : AppTheme.lightTextMuted),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              itemTitle,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSubActive
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSubActive
                                    ? (isDark ? Colors.white : accent)
                                    : (isDark
                                          ? AppTheme.darkTextSecondary
                                          : AppTheme.lightTextSecondary),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}
