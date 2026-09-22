import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/driver_install_controller.dart';
import '../../controllers/system_info_controller.dart';
import '../../controllers/theme_language_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../models/system_info.dart';
import '../../theme/app_theme.dart';
import '../common/design_components.dart';

class DriverInstallPage extends StatefulWidget {
  const DriverInstallPage({super.key});

  @override
  State<DriverInstallPage> createState() => _DriverInstallPageState();
}

class _DriverInstallPageState extends State<DriverInstallPage> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final driverCtrl = Get.find<DriverInstallController>();
    final systemCtrl = Get.find<SystemInfoController>();
    final themeCtrl = Get.find<ThemeLanguageController>();
    final l10n = AppLocalizations.of(context);
    final accent = themeCtrl.currentAccentColor;

    return Obx(() {
      final info = systemCtrl.systemInfo.value;
      final drivers = info?.drivers ?? [];
      final isScanning = driverCtrl.isScanning.value;
      final isBatchRunning = driverCtrl.isBatchInstalling.value;
      final batchStatus = driverCtrl.batchStatus.value;
      final driverFolder = driverCtrl.driverFolder.value;
      final scanRes = driverCtrl.scanResult.value;
      final packages = scanRes.packages;
      final selectedIds = driverCtrl.selectedPackageIds;
      final isAdvanced = driverCtrl.isAdvancedMode.value;
      final removables = driverCtrl.removableSources;

      final totalDrivers = drivers.length;
      final needsInstall = drivers
          .where((d) => d.isPresent && !d.isHealthy)
          .length;
      final upToDate = totalDrivers - needsInstall;

      return LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 780;

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isNarrow ? 12 : 20,
              vertical: 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Header Toolbar (Repository Path + USB Sources + Scan)
                _buildHeaderToolbar(
                  context,
                  driverCtrl,
                  systemCtrl,
                  l10n,
                  isDark,
                  accent,
                  isScanning,
                  driverFolder,
                  totalDrivers,
                  needsInstall,
                  upToDate,
                  removables,
                ),

                const SizedBox(height: 14),

                // 2. Active Installation Queue Banner (If running)
                if (isBatchRunning) ...[
                  _buildQueueProgressPanel(
                    batchStatus,
                    driverCtrl,
                    isDark,
                    accent,
                  ),
                  const SizedBox(height: 14),
                ],

                // 3. Scan Results Toolbar & Actions (Checkboxes, Select All, Install Selected)
                if (packages.isNotEmpty) ...[
                  _buildPackagesActionBar(
                    context,
                    driverCtrl,
                    l10n,
                    isDark,
                    accent,
                    scanRes,
                    selectedIds,
                    isAdvanced,
                    isBatchRunning,
                  ),
                  const SizedBox(height: 10),
                ],

                // 4. Detected Driver Package Cards (or hardware status list if no scan yet)
                if (packages.isNotEmpty)
                  ...packages.map(
                    (pkg) => _buildPackageCard(
                      context,
                      pkg,
                      driverCtrl,
                      isDark,
                      accent,
                      isAdvanced,
                      batchStatus,
                      isBatchRunning,
                    ),
                  )
                else if (drivers.isNotEmpty) ...[
                  _buildHardwareStatusHeader(
                    isDark,
                    accent,
                    driverCtrl,
                    context,
                  ),
                  const SizedBox(height: 10),
                  ...drivers.map(
                    (drv) => _buildHardwareDriverRow(drv, isDark, accent),
                  ),
                ] else
                  EmptyStateWidget(
                    icon: Icons.extension_off_rounded,
                    title: 'پوشه درایورها اسکن نشده است',
                    subtitle:
                        'جهت شناسایی و نصب خودکار درایورها، دکمه «اسکن پوشه درایورها» را انتخاب نمایید.',
                    action: ElevatedButton.icon(
                      onPressed: isScanning
                          ? null
                          : () => driverCtrl.scanDrivers(context),
                      icon: const Icon(Icons.search_rounded, size: 16),
                      label: const Text('اسکن هوشمند درایورها'),
                      style: ElevatedButton.styleFrom(backgroundColor: accent),
                    ),
                  ),
              ],
            ),
          );
        },
      );
    });
  }

  Widget _buildHeaderToolbar(
    BuildContext context,
    DriverInstallController driverCtrl,
    SystemInfoController systemCtrl,
    AppLocalizations l10n,
    bool isDark,
    Color accent,
    bool isScanning,
    String driverFolder,
    int totalDrivers,
    int needsInstall,
    int upToDate,
    List<RemovableDriverSource> removables,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.extension_rounded, color: accent, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.isPersian
                          ? 'مدیریت و نصب هوشمند درایورها'
                          : 'Intelligent Driver Manager',
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      driverFolder.isNotEmpty
                          ? driverFolder
                          : 'پوشه پیش‌فرض درایورها تنظیم نشده است',
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'Consolas',
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
          ),

          // Removable Flash Drive Chips if any detected
          if (removables.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: removables.map((rem) {
                return ActionChip(
                  avatar: const Icon(
                    Icons.usb_rounded,
                    size: 16,
                    color: Color(0xFF0D9488),
                  ),
                  label: Text(
                    'فلش دیسک: ${rem.displayName}',
                    style: const TextStyle(fontSize: 11.5),
                  ),
                  backgroundColor: const Color(
                    0xFF0D9488,
                  ).withValues(alpha: 0.1),
                  side: const BorderSide(color: Color(0xFF0D9488)),
                  onPressed: () =>
                      driverCtrl.selectRemovableSource(context, rem),
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color:
                      (needsInstall > 0
                              ? AppTheme.statusWarning
                              : AppTheme.statusSuccess)
                          .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$totalDrivers سخت‌افزار • $needsInstall نیاز به درایور • $upToDate آماده',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: needsInstall > 0
                        ? AppTheme.statusWarning
                        : AppTheme.statusSuccess,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: isScanning
                    ? null
                    : () => driverCtrl.selectFolderAndScan(context),
                icon: const Icon(Icons.folder_open_rounded, size: 16),
                label: Text(l10n.isPersian ? 'انتخاب پوشه' : 'Select Folder'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  minimumSize: const Size(0, 36),
                ),
              ),
              ElevatedButton.icon(
                onPressed: isScanning
                    ? null
                    : () => driverCtrl.scanDrivers(context),
                icon: isScanning
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.search_rounded, size: 16),
                label: Text(
                  isScanning ? 'در حال اسکن...' : 'اسکن هوشمند درایورها',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  minimumSize: const Size(0, 36),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPackagesActionBar(
    BuildContext context,
    DriverInstallController ctrl,
    AppLocalizations l10n,
    bool isDark,
    Color accent,
    DriverScanResult scanRes,
    Set<String> selectedIds,
    bool isAdvanced,
    bool isBatchRunning,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
        ),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'بسته‌های درایور شناسایی‌شده (${scanRes.totalPackages}):',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppTheme.darkTextPrimary
                      : AppTheme.lightTextPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: selectedIds.isEmpty
                      ? const Color(0xFF64748B).withValues(alpha: 0.12)
                      : accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${selectedIds.length} از ${scanRes.totalPackages} انتخاب شده',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: selectedIds.isEmpty
                        ? (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))
                        : accent,
                  ),
                ),
              ),
              InkWell(
                onTap: ctrl.installablePackageIds.isEmpty
                    ? null
                    : ctrl.toggleSelectAllPackages,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: ctrl.triStateSelectionValue,
                        tristate: true,
                        activeColor: accent,
                        checkColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        onChanged: ctrl.installablePackageIds.isEmpty
                            ? null
                            : (_) => ctrl.toggleSelectAllPackages(),
                      ),
                      Text(
                        ctrl.areAllInstallableSelected
                            ? 'لغو انتخاب همه'
                            : 'انتخاب همه',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppTheme.darkTextPrimary
                              : AppTheme.lightTextPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: ctrl.installablePackageIds.isEmpty
                    ? null
                    : ctrl.selectAllPackages,
                icon: const Icon(Icons.select_all_rounded, size: 14),
                label: const Text('انتخاب همه', style: TextStyle(fontSize: 11.5)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: const Size(0, 30),
                ),
              ),
              OutlinedButton.icon(
                onPressed: ctrl.selectedPackageIds.isEmpty
                    ? null
                    : ctrl.clearSelection,
                icon: const Icon(Icons.deselect_rounded, size: 14),
                label: const Text('لغو انتخاب', style: TextStyle(fontSize: 11.5)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: const Size(0, 30),
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Advanced Mode Toggle
              OutlinedButton.icon(
                onPressed: ctrl.toggleAdvancedMode,
                icon: Icon(
                  isAdvanced
                      ? Icons.visibility_off_rounded
                      : Icons.tune_rounded,
                  size: 16,
                ),
                label: Text(
                  isAdvanced ? 'نمای ساده' : 'نمای پیشرفته',
                  style: const TextStyle(fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  minimumSize: const Size(0, 34),
                ),
              ),
              // Auto Install Selected Button
              ElevatedButton.icon(
                onPressed: (isBatchRunning || selectedIds.isEmpty)
                    ? null
                    : () => ctrl.installSelectedDrivers(context),
                icon: const Icon(Icons.auto_mode_rounded, size: 16),
                label: Text('نصب خودکار (${selectedIds.length})'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFE2E8F0),
                  disabledForegroundColor: isDark
                      ? const Color(0xFF64748B)
                      : const Color(0xFF94A3B8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  minimumSize: const Size(0, 34),
                ),
              ),
              // Manual Install Selected Button
              ElevatedButton.icon(
                onPressed: (isBatchRunning || selectedIds.isEmpty)
                    ? null
                    : () => ctrl.installSelectedDriversManual(context),
                icon: const Icon(Icons.launch_rounded, size: 16),
                label: Text('نصب دستی (${selectedIds.length})'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFE2E8F0),
                  disabledForegroundColor: isDark
                      ? const Color(0xFF64748B)
                      : const Color(0xFF94A3B8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  minimumSize: const Size(0, 34),
                ),
              ),
              // Install All Button
              ElevatedButton.icon(
                onPressed: isBatchRunning
                    ? null
                    : () => ctrl.installAllDrivers(context),
                icon: const Icon(Icons.play_arrow_rounded, size: 16),
                label: const Text('نصب خودکار همه'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFE2E8F0),
                  disabledForegroundColor: isDark
                      ? const Color(0xFF64748B)
                      : const Color(0xFF94A3B8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  minimumSize: const Size(0, 34),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPackageCard(
    BuildContext context,
    IntelligentDriverPackage pkg,
    DriverInstallController ctrl,
    bool isDark,
    Color accent,
    bool isAdvanced,
    DriverBatchStatus batchStatus,
    bool isBatchRunning,
  ) {
    final match = pkg.match;
    final isSelected = ctrl.selectedPackageIds.contains(pkg.packageId);

    // Find any batch installation status item for this driver
    DriverInstallItem? queueItem;
    for (final item in batchStatus.items) {
      if ((item.packageId != null && item.packageId == pkg.packageId) ||
          (item.displayName != null && item.displayName == pkg.displayName) ||
          (item.filename == pkg.installerFile)) {
        queueItem = item;
        break;
      }
    }

    Color statusColor = AppTheme.statusSuccess;
    String statusBadgeText = 'آماده';
    BadgeStatus badgeStatus = BadgeStatus.success;

    if (queueItem != null) {
      if (queueItem.status == 'installing') {
        statusColor = const Color(0xFFF59E0B);
        statusBadgeText = 'در حال نصب...';
        badgeStatus = BadgeStatus.warning;
      } else if (queueItem.status == 'queued' ||
          queueItem.status == 'pending') {
        statusColor = const Color(0xFF0284C7);
        statusBadgeText = 'در صف نصب';
        badgeStatus = BadgeStatus.info;
      } else if (queueItem.status == 'completed') {
        statusColor = const Color(0xFF10B981);
        statusBadgeText = 'نصب شد';
        badgeStatus = BadgeStatus.success;
      } else if (queueItem.status == 'failed') {
        statusColor = const Color(0xFFEF4444);
        statusBadgeText = 'خطا در نصب';
        badgeStatus = BadgeStatus.danger;
      } else if (queueItem.status == 'skipped') {
        statusColor = const Color(0xFF64748B);
        statusBadgeText = 'رد شد';
        badgeStatus = BadgeStatus.neutral;
      }
    } else if (match != null) {
      if (match.status == 'needs_install') {
        statusColor = const Color(0xFFEF4444);
        statusBadgeText = 'نیاز به نصب';
        badgeStatus = BadgeStatus.danger;
      } else if (match.status == 'update_available') {
        statusColor = const Color(0xFF0284C7);
        statusBadgeText = 'نسخه جدید';
        badgeStatus = BadgeStatus.info;
      } else if (match.status == 'up_to_date') {
        statusColor = const Color(0xFF10B981);
        statusBadgeText = 'به‌روز است';
        badgeStatus = BadgeStatus.success;
      } else if (match.confidence == 'UNKNOWN') {
        statusColor = const Color(0xFFF59E0B);
        statusBadgeText = 'بررسی توسط نصاب';
        badgeStatus = BadgeStatus.warning;
      } else if (!match.isMatched) {
        statusColor = const Color(0xFF64748B);
        statusBadgeText = 'نامربوط';
        badgeStatus = BadgeStatus.neutral;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isSelected
            ? (isDark
                  ? accent.withValues(alpha: 0.16)
                  : accent.withValues(alpha: 0.08))
            : (isDark ? AppTheme.darkCard : AppTheme.lightCard),
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
                  color: accent.withValues(alpha: isDark ? 0.28 : 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Selection Checkbox
              Checkbox(
                value: isSelected,
                activeColor: accent,
                checkColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                side: BorderSide(
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B),
                  width: 1.8,
                ),
                onChanged: (_) => ctrl.togglePackageSelection(pkg.packageId),
              ),
              // Category Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: isDark ? 0.18 : 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getCategoryIcon(pkg.category),
                  size: 22,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 12),
              // Main Driver Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            pkg.displayName,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? AppTheme.darkTextPrimary
                                  : AppTheme.lightTextPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            pkg.categoryFa,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      match != null && match.isMatched
                          ? 'متناظر: ${match.matchedDeviceName}'
                          : (match?.statusFa.isNotEmpty == true
                                ? match!.statusFa
                                : 'فایل نصبی: ${pkg.installerFile}'),
                      style: TextStyle(
                        fontSize: 12,
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
              const SizedBox(width: 10),
              // Status Badge
              StatusBadge(
                label: statusBadgeText,
                status: badgeStatus,
                fontSize: 11.5,
              ),
            ],
          ),

          // Failure Reason Banner (if failed during batch installation)
          if (queueItem != null && queueItem.status == 'failed') ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.error_outline_rounded,
                      size: 16,
                      color: Color(0xFFEF4444),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'علت عدم نصب: ${(queueItem.failureReason?.isNotEmpty == true
                          ? queueItem.failureReason!
                          : queueItem.message.isNotEmpty
                          ? queueItem.message
                          : "خطای نامشخص در نصب درایور")}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFFDC2626),
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Advanced Mode Extended Details
          if (isAdvanced) ...[
            const Divider(height: 14),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0F172A)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 16,
                    runSpacing: 4,
                    children: [
                      Text(
                        'روش نصب: ${pkg.installMethod}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontFamily: 'Consolas',
                        ),
                      ),
                      Text(
                        'حجم: ${pkg.fileSizeDisplay}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      if (pkg.driverVersion.isNotEmpty)
                        Text(
                          'نسخه درایور: ${pkg.driverVersion}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontFamily: 'Consolas',
                          ),
                        ),
                      if (match != null)
                        Text(
                          'سطح اطمینان: ${match.confidence}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                    ],
                  ),
                  if (pkg.hardwareIds.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'شناسه سخت‌افزاری (Hardware ID): ${pkg.hardwareIds.first}',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontFamily: 'Consolas',
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (pkg.alternativeInstallers.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'سایر نصاب‌های شناسایی‌شده: ${pkg.alternativeInstallers.join(", ")}',
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          // Actions Row (Auto Install, Manual Install, Open Folder)
          const SizedBox(height: 8),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: (isBatchRunning || queueItem?.status == 'installing')
                    ? null
                    : () => ctrl.installSingleDriverAuto(context, pkg),
                icon: const Icon(Icons.auto_mode_rounded, size: 14),
                label: const Text(
                  'نصب خودکار',
                  style: TextStyle(fontSize: 11.5),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  minimumSize: const Size(0, 30),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: (isBatchRunning || queueItem?.status == 'installing')
                    ? null
                    : () => ctrl.installSingleDriverInteractive(context, pkg),
                icon: const Icon(Icons.touch_app_rounded, size: 14),
                label: const Text('نصب دستی', style: TextStyle(fontSize: 11.5)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  minimumSize: const Size(0, 30),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => ctrl.openPackageFolder(context, pkg),
                icon: const Icon(Icons.folder_open_rounded, size: 14),
                label: const Text(
                  'پوشه درایور',
                  style: TextStyle(fontSize: 11.5),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF475569),
                  side: BorderSide(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFCBD5E1),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  minimumSize: const Size(0, 30),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHardwareStatusHeader(
    bool isDark,
    Color accent,
    DriverInstallController ctrl,
    BuildContext context,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
        ),
      ),
      child: Row(
        children: [
          const Text(
            'وضعیت درایورهای سخت‌افزاری سیستم:',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: () => ctrl.scanDrivers(context),
            icon: const Icon(Icons.search_rounded, size: 16),
            label: const Text('اسکن پوشه درایورها'),
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: const Size(0, 34),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHardwareDriverRow(DriverItem drv, bool isDark, Color accent) {
    final isOk = drv.isPresent && drv.isHealthy;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isOk
              ? (isDark ? AppTheme.darkBorder : AppTheme.lightBorder)
              : AppTheme.statusWarning.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _getCategoryIcon(drv.name.toLowerCase()),
            size: 22,
            color: isOk ? AppTheme.statusSuccess : AppTheme.statusWarning,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  drv.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                ),
                Text(
                  drv.statusDescription.isNotEmpty
                      ? drv.statusDescription
                      : (isOk
                            ? 'درایور فعال و سالم است'
                            : 'نیاز به نصب درایور'),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppTheme.darkTextMuted
                        : AppTheme.lightTextMuted,
                  ),
                ),
              ],
            ),
          ),
          StatusBadge(
            label: isOk ? 'نصب شده' : 'نیاز به نصب',
            status: isOk ? BadgeStatus.success : BadgeStatus.warning,
            fontSize: 11.5,
          ),
        ],
      ),
    );
  }

  Widget _buildQueueProgressPanel(
    DriverBatchStatus status,
    DriverInstallController ctrl,
    bool isDark,
    Color accent,
  ) {
    final isRunning = status.isRunning;
    final total = status.total;
    final completed = status.completed;
    final failed = status.failed;
    final done = completed + failed;
    final percent = total > 0 ? (done / total * 100).clamp(0.0, 100.0) : 0.0;
    final currentItem = status.currentFile;

    final Color statusColor = isRunning
        ? accent
        : (failed == 0 ? const Color(0xFF10B981) : const Color(0xFFF59E0B));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: statusColor.withValues(alpha: isDark ? 0.45 : 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: isDark ? 0.18 : 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: isRunning
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: statusColor,
                        ),
                      )
                    : Icon(
                        failed == 0
                            ? Icons.check_circle_rounded
                            : Icons.info_outline_rounded,
                        color: statusColor,
                        size: 22,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          isRunning
                              ? 'صف نصب خودکار درایورها'
                              : (failed == 0
                                  ? 'نصب درایورها با موفقیت پایان یافت'
                                  : 'عملیات پایان یافت (نیازمند بررسی)'),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? const Color(0xFFF1F5F9)
                                : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${percent.toStringAsFixed(0)}٪',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isRunning
                          ? (currentItem != null && currentItem.isNotEmpty
                              ? 'در حال نصب: $currentItem ($done از $total)'
                              : 'در حال آماده‌سازی...')
                          : (status.summaryMessage.isNotEmpty
                              ? status.summaryMessage
                              : '$completed درایور نصب شد'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (isRunning) ...[
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => ctrl.cancelDriverAutoInstall(context),
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 15,
                    color: Color(0xFFEF4444),
                  ),
                  label: const Text(
                    'لغو',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFFEF4444),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                      color: Color(0xFFEF4444),
                      width: 1.1,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    minimumSize: const Size(0, 34),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ] else if (status.cancelled || status.items.any((i) => i.status == 'failed' || i.status == 'pending')) ...[
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => ctrl.resumeDriverAutoInstall(context),
                  icon: const Icon(
                    Icons.play_arrow_rounded,
                    size: 15,
                    color: Color(0xFF0D9488),
                  ),
                  label: const Text(
                    'شروع مجدد',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF0D9488),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                      color: Color(0xFF0D9488),
                      width: 1.1,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    minimumSize: const Size(0, 34),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: total > 0 ? (percent / 100.0).clamp(0.0, 1.0) : null,
              minHeight: 8,
              backgroundColor: isDark
                  ? const Color(0xFF1E293B)
                  : const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
          const SizedBox(height: 8),

          // Counts Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$done از $total درایور پردازش شد',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? const Color(0xFFCBD5E1)
                      : const Color(0xFF334155),
                ),
              ),
              if (failed > 0)
                Text(
                  '$failed درایور ناموفق',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFEF4444),
                  ),
                ),
            ],
          ),

          // Mini Item Chips
          if (status.items.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: status.items.map((item) {
                Color chipColor;
                IconData chipIcon;
                if (item.status == 'completed') {
                  chipColor = const Color(0xFF10B981);
                  chipIcon = Icons.check_circle_rounded;
                } else if (item.status == 'installing') {
                  chipColor = const Color(0xFF3B82F6);
                  chipIcon = Icons.autorenew_rounded;
                } else if (item.status == 'failed') {
                  chipColor = const Color(0xFFEF4444);
                  chipIcon = Icons.cancel_rounded;
                } else if (item.status == 'skipped') {
                  chipColor = const Color(0xFF64748B);
                  chipIcon = Icons.skip_next_rounded;
                } else {
                  chipColor = const Color(0xFF94A3B8);
                  chipIcon = Icons.schedule_rounded;
                }

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0A1224) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: chipColor.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      item.status == 'installing'
                          ? SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: chipColor,
                              ),
                            )
                          : Icon(chipIcon, size: 13, color: chipColor),
                      const SizedBox(width: 5),
                      Text(
                        item.displayName ?? item.filename,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? const Color(0xFFCBD5E1)
                              : const Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String key) {
    final lower = key.toLowerCase();
    if (lower.contains('gpu') ||
        lower.contains('graphic') ||
        lower.contains('vga') ||
        lower.contains('display') ||
        lower.contains('گرافیک')) {
      return Icons.videogame_asset_rounded;
    }
    if (lower.contains('audio') ||
        lower.contains('sound') ||
        lower.contains('صدا')) {
      return Icons.volume_up_rounded;
    }
    if (lower.contains('lan') ||
        lower.contains('ethernet') ||
        lower.contains('شبکه')) {
      return Icons.lan_rounded;
    }
    if (lower.contains('wifi') ||
        lower.contains('wi-fi') ||
        lower.contains('wireless') ||
        lower.contains('وای فای')) {
      return Icons.wifi_rounded;
    }
    if (lower.contains('bluetooth') || lower.contains('بلوتوث')) {
      return Icons.bluetooth_rounded;
    }
    if (lower.contains('chipset') ||
        lower.contains('چیپست') ||
        lower.contains('mei') ||
        lower.contains('system')) {
      return Icons.developer_board_rounded;
    }
    if (lower.contains('storage') ||
        lower.contains('sata') ||
        lower.contains('nvme') ||
        lower.contains('raid')) {
      return Icons.storage_rounded;
    }
    if (lower.contains('touchpad') || lower.contains('تاچ')) {
      return Icons.touch_app_rounded;
    }
    if (lower.contains('camera') || lower.contains('دوربین')) {
      return Icons.camera_alt_rounded;
    }
    return Icons.extension_rounded;
  }
}
