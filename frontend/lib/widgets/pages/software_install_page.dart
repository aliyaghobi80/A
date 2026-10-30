import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/software_controller.dart';
import '../../controllers/system_info_controller.dart';
import '../../controllers/theme_language_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../models/system_info.dart';
import '../../theme/app_theme.dart';
import '../common/design_components.dart';
import '../common/deployment_flow_panel.dart';
import '../common/instant_option_tile.dart';
import '../common/queue_card.dart';
import '../common/queue_preview_modal.dart';

class SoftwareInstallPage extends StatelessWidget {
  const SoftwareInstallPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final softwareCtrl = Get.find<SoftwareController>();
    final themeCtrl = Get.find<ThemeLanguageController>();
    final l10n = AppLocalizations.of(context);
    final accent = themeCtrl.currentAccentColor;

    return Obx(() {
      final packages = softwareCtrl.packages;
      final selectedPackageIds = softwareCtrl.selectedPackageIds.toSet();
      final isScanning = softwareCtrl.isScanning.value;
      final isBatchRunning = softwareCtrl.hasActiveBatch;
      final isBatchUninstalling = softwareCtrl.isBatchUninstalling.value;
      final batchStatus = softwareCtrl.batchStatus.value;
      final dir = softwareCtrl.packagesDirectory;
      final isHomeEdition =
          Get.find<SystemInfoController>()
              .systemInfo
              .value
              ?.windows
              .isHomeEdition ??
          false;
      bool officeBlocked(SoftwarePackage package) =>
          isHomeEdition && package.isMicrosoftOfficePackage;

      // Duplicate installers are always hidden; the canonical entry remains.
      final visiblePackages = packages.where((p) => !p.isDuplicate).toList();

      final readyPackages = visiblePackages
          .where(
            (p) =>
                !p.isInstalled &&
                p.isValid &&
                !p.isPortable &&
                !officeBlocked(p),
          )
          .toList();
      final readyIds = readyPackages.map((package) => package.id).toSet();
      final selectedReadyIds = selectedPackageIds.intersection(readyIds);
      final installedPackages = visiblePackages
          .where((p) => p.isInstalled && !p.isPortable)
          .toList();
      final selectablePackages = visiblePackages
          .where(
            (package) =>
                package.isValid &&
                !package.isPortable &&
                !officeBlocked(package),
          )
          .toList();
      final selectableIds = selectablePackages
          .map((package) => package.id)
          .toSet();
      final selectedVisibleIds = selectedPackageIds.intersection(selectableIds);
      final allVisibleSelected =
          selectableIds.isNotEmpty &&
          selectedVisibleIds.length == selectableIds.length;
      final selectionValue = allVisibleSelected
          ? true
          : (selectedVisibleIds.isEmpty ? false : null);
      final selectedInstalledPackages = installedPackages
          .where((package) => selectedPackageIds.contains(package.id))
          .toList();
      final hasSelection = selectedVisibleIds.isNotEmpty;
      final installTargetIds = hasSelection ? selectedReadyIds : readyIds;
      final filteredPackages = visiblePackages;

      final hasBottomBar = isBatchRunning ||
          (batchStatus.items.isNotEmpty && batchStatus.total > 0);

      return LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 750;

          return Stack(
            children: [
              Positioned.fill(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    isNarrow ? 12 : 20,
                    16,
                    isNarrow ? 12 : 20,
                    hasBottomBar ? 110 : 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Header Toolbar (Responsive Wrap)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? AppTheme.darkBorder
                          : AppTheme.lightBorder,
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.apps_rounded, color: accent, size: 26),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.isPersian
                                      ? 'نصب و مدیریت نرم‌افزارهای کاربردی'
                                      : 'Software Deployment',
                                  style: const TextStyle(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  dir.isNotEmpty
                                      ? dir
                                      : 'پوشه مخزن نرم‌افزارها تنظیم نشده است',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontFamily: 'monospace',
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
                                  (readyPackages.isNotEmpty
                                          ? const Color(0xFF0284C7)
                                          : AppTheme.statusSuccess)
                                      .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${visiblePackages.length} نرم‌افزار • ${installedPackages.length} نصب شده • ${readyPackages.length} آماده نصب',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: readyPackages.isNotEmpty
                                    ? const Color(0xFF0284C7)
                                    : AppTheme.statusSuccess,
                              ),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: isScanning || isBatchRunning
                                ? null
                                : () => softwareCtrl.changePackagesDirectory(
                                    context,
                                  ),
                            icon: const Icon(
                              Icons.folder_open_rounded,
                              size: 16,
                            ),
                            label: const Text('انتخاب پوشه'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              minimumSize: const Size(0, 36),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: isScanning || isBatchRunning
                                ? null
                                : () => softwareCtrl.fetchPackages(),
                            icon: isScanning || isBatchRunning
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.refresh_rounded, size: 16),
                            label: Text(
                              isBatchRunning
                                  ? 'نصب در حال اجراست'
                                  : (isScanning
                                        ? 'در حال اسکن...'
                                        : 'اسکن مجدد'),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accent,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              minimumSize: const Size(0, 36),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // 2. Batch Progress (If running or recently completed)
                if (isBatchRunning ||
                    (batchStatus.items.isNotEmpty &&
                        batchStatus.total > 0)) ...[
                  DeploymentFlowPanel(
                    batchStatus: batchStatus,
                    softwareCtrl: softwareCtrl,
                    isDark: isDark,
                    accentColor: accent,
                  ),
                  const SizedBox(height: 8),
                  ...batchStatus.items.map((item) {
                    final pkg = packages.firstWhereOrNull(
                      (p) =>
                          p.id == item.id ||
                          (p.relativePath.isNotEmpty &&
                              p.relativePath == item.relativePath),
                    );
                    return SoftwareQueueCard(
                      item: item,
                      package: pkg,
                      isDark: isDark,
                      accentColor: accent,
                      onRetry: () {
                        if (pkg != null) {
                          softwareCtrl.installPackageSilent(context, pkg);
                        } else {
                          softwareCtrl.startAutoInstallAll(
                            context,
                            targetPackageIds: [item.id],
                          );
                        }
                      },
                    );
                  }),
                  const SizedBox(height: 12),
                ],

                // 3. Compact bulk-action toolbar
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark
                          ? AppTheme.darkBorder
                          : AppTheme.lightBorder,
                    ),
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.start,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Semantics(
                        button: true,
                        checked: allVisibleSelected,
                        label: allVisibleSelected
                            ? 'لغو انتخاب همه نرم‌افزارها'
                            : 'انتخاب همه نرم‌افزارها',
                        child: InkWell(
                          onTap: selectableIds.isEmpty
                              ? null
                              : () => softwareCtrl.toggleSelectAllPackages(
                                  selectableIds,
                                ),
                          borderRadius: BorderRadius.circular(8),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 44),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Checkbox(
                                  tristate: true,
                                  value: selectionValue,
                                  activeColor: accent,
                                  onChanged: selectableIds.isEmpty
                                      ? null
                                      : (_) => softwareCtrl
                                            .toggleSelectAllPackages(
                                              selectableIds,
                                            ),
                                ),
                                Text(
                                  allVisibleSelected
                                      ? 'لغو انتخاب همه'
                                      : 'انتخاب همه',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? AppTheme.darkTextPrimary
                                        : AppTheme.lightTextPrimary,
                                  ),
                                ),
                                if (selectedVisibleIds.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    '(${selectedVisibleIds.length})',
                                    style: TextStyle(
                                      color: accent,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                                const SizedBox(width: 10),
                              ],
                            ),
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed:
                            isBatchRunning ||
                                isBatchUninstalling ||
                                selectedInstalledPackages.isEmpty
                            ? null
                            : () async {
                                final removed = await softwareCtrl
                                    .uninstallSelectedPackages(
                                      context,
                                      selectedInstalledPackages,
                                    );
                                if (removed.isNotEmpty) {
                                  softwareCtrl.removePackageSelections(removed);
                                }
                              },
                        icon: isBatchUninstalling
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.delete_outline_rounded,
                                size: 18,
                              ),
                        label: Text(
                          selectedInstalledPackages.isEmpty
                              ? 'حذف انتخابی'
                              : 'حذف انتخابی (${selectedInstalledPackages.length})',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFEF4444),
                          minimumSize: const Size(0, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed:
                            isBatchRunning ||
                                isBatchUninstalling ||
                                installTargetIds.isEmpty
                            ? null
                            : () {
                                final targets = readyPackages
                                    .where((p) => installTargetIds.contains(p.id))
                                    .toList();
                                QueuePreviewModal.showSoftwarePreview(
                                  context: context,
                                  packages: targets.isNotEmpty ? targets : readyPackages,
                                  isDark: isDark,
                                  accentColor: accent,
                                  doubleSpeed: softwareCtrl.doubleSpeed.value,
                                  onConfirm: () => softwareCtrl.startAutoInstallAll(
                                    context,
                                    targetPackageIds: installTargetIds.toList(),
                                  ),
                                );
                              },
                        icon: isBatchRunning
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.play_arrow_rounded, size: 18),
                        label: Text(
                          isBatchRunning
                              ? 'در حال نصب (${batchStatus.completed}/${batchStatus.total})'
                              : 'نصب خودکار (${installTargetIds.length})',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          minimumSize: const Size(0, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                      ),
                      SizedBox(
                        width: 290,
                        child: InstantOptionTile(
                          value: softwareCtrl.includeActivation,
                          enabled:
                              !isBatchRunning && softwareCtrl.activationAllowed,
                          title: 'KMS',
                          subtitle: softwareCtrl.activationAllowed
                              ? 'فعال‌سازی اختیاری'
                              : 'برای Windows Home غیرفعال است',
                          semanticLabel: 'فعال‌سازی اختیاری KMS',
                        ),
                      ),
                      SizedBox(
                        width: 290,
                        child: InstantOptionTile(
                          value: softwareCtrl.doubleSpeed,
                          enabled: !isBatchRunning,
                          title: '2X',
                          subtitle: 'دو نصب سازگار هم‌زمان',
                          semanticLabel: 'حالت نصب دو برابر',
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // 4. Dense Software Rows
                if (filteredPackages.isEmpty)
                  EmptyStateWidget(
                    icon: Icons.apps_outage_rounded,
                    title: 'هیچ نرم‌افزاری در این دسته یافت نشد',
                    subtitle: 'پوشه نرم‌افزارها را انتخاب یا دوباره اسکن کنید.',
                    action: ElevatedButton.icon(
                      onPressed: () =>
                          softwareCtrl.changePackagesDirectory(context),
                      icon: const Icon(Icons.folder_open_rounded, size: 16),
                      label: const Text('انتخاب پوشه نرم‌افزارها'),
                      style: ElevatedButton.styleFrom(backgroundColor: accent),
                    ),
                  )
                else
                  ...filteredPackages.map((pkg) {
                    final isThisInstalling = softwareCtrl.isCurrentInstalling(
                      pkg,
                    );
                    final isThisQueued = softwareCtrl.isCurrentQueued(pkg);
                    final isThisUninstalling = softwareCtrl
                        .isCurrentUninstalling(pkg);
                    return _buildPackageRow(
                      context,
                      pkg,
                      softwareCtrl,
                      isThisInstalling,
                      isThisQueued,
                      isThisUninstalling,
                      isDark,
                      accent,
                      officeBlocked(pkg),
                    );
                  }),
                if (packages.isNotEmpty && softwareCtrl.directoryExists) ...[
                  Builder(
                    builder: (context) {
                      final sysCtrl = Get.isRegistered<SystemInfoController>()
                          ? Get.find<SystemInfoController>()
                          : null;
                      final isOfficeInstalled =
                          sysCtrl
                              ?.systemInfo
                              .value
                              ?.officeActivation
                              .installed ??
                          false;
                      if (isOfficeInstalled) return const SizedBox.shrink();
                      return _buildOfficeReminderBanner(
                        context,
                        softwareCtrl,
                        isDark,
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
          if (hasBottomBar)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: FixedCumulativeProgressBar(
                isRunning: isBatchRunning,
                progressPercent: batchStatus.progressPercent,
                completed: batchStatus.completed,
                total: batchStatus.total,
                failed: batchStatus.failed,
                skipped: batchStatus.skipped,
                interrupted: batchStatus.interrupted,
                startTime: batchStatus.startTime,
                doubleSpeed: softwareCtrl.doubleSpeed.value,
                currentItemName: batchStatus.currentItemName,
                activeItemNames: batchStatus.items
                    .where((i) => i.status == 'installing')
                    .map((i) => i.friendlyDescription)
                    .toList(),
                onCancel: () =>
                    softwareCtrl.cancelBatchInstallInteractive(context),
                onResume: () =>
                    softwareCtrl.startAutoInstallAll(context),
                isDark: isDark,
                accentColor: accent,
                typeName: 'نرم‌افزار',
              ),
            ),
        ],
      );
    },
  );
    });
  }

  Widget _buildPackageIcon(SoftwarePackage pkg, Color accent, bool isDark) {
    if (pkg.iconBase64 != null && pkg.iconBase64!.isNotEmpty) {
      try {
        final clean = pkg.iconBase64!.contains(',')
            ? pkg.iconBase64!.split(',').last
            : pkg.iconBase64!;
        final bytes = base64Decode(clean.trim());
        if (bytes.isNotEmpty) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              bytes,
              fit: BoxFit.contain,
              errorBuilder: (ctx, err, stack) =>
                  Icon(Icons.apps_rounded, size: 24, color: accent),
            ),
          );
        }
      } catch (e) {
        debugPrint(
          '[SoftwareInstallPage] Error decoding icon for ${pkg.id}: $e',
        );
      }
    }
    return Icon(Icons.apps_rounded, size: 24, color: accent);
  }

  Widget _buildPackageRow(
    BuildContext context,
    SoftwarePackage pkg,
    SoftwareController ctrl,
    bool isInstalling,
    bool isQueued,
    bool isUninstalling,
    bool isDark,
    Color accent,
    bool isOfficeBlocked,
  ) {
    final isInstalled = pkg.isInstalled;
    final isSelected = ctrl.selectedPackageIds.contains(pkg.id);

    return Container(
      key: ValueKey('software-package-${pkg.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
              : (isInstalled
                    ? (isDark ? AppTheme.darkBorder : AppTheme.lightBorder)
                    : const Color(
                        0xFF0284C7,
                      ).withValues(alpha: isDark ? 0.5 : 0.35)),
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
      child: Row(
        children: [
          if (pkg.isValid && !pkg.isPortable) ...[
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
              onChanged: isOfficeBlocked
                  ? null
                  : (_) => ctrl.togglePackageSelection(pkg.id),
            ),
            const SizedBox(width: 4),
          ],

          // Safe App Icon / Authentic Brand Thumbnail
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _buildPackageIcon(pkg, accent, isDark),
          ),

          const SizedBox(width: 14),

          // App Name + Publisher + Size + Duplicate Indicators
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        pkg.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? AppTheme.darkTextPrimary
                              : AppTheme.lightTextPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (pkg.isDuplicate) ...[
                      const SizedBox(width: 6),
                      const StatusBadge(
                        label: 'تکراری (Duplicate)',
                        status: BadgeStatus.neutral,
                        showIcon: false,
                        fontSize: 10.5,
                      ),
                    ] else if (pkg.duplicateCount > 0) ...[
                      const SizedBox(width: 6),
                      StatusBadge(
                        label: '${pkg.duplicateCount + 1} فایل نصبی',
                        status: BadgeStatus.info,
                        showIcon: false,
                        fontSize: 10.5,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${pkg.publisher.isNotEmpty ? pkg.publisher : "کاربردی"} • ${pkg.fileSizeDisplay}${pkg.filename.isNotEmpty ? " • ${pkg.filename}" : ""}',
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

          if ((isInstalled || isOfficeBlocked) &&
              pkg.isMicrosoftOfficePackage) ...[
            OutlinedButton.icon(
              onPressed: ctrl.officeShortcutPackageId.value == pkg.id
                  ? null
                  : () => ctrl.createOfficeShortcuts(context, pkg),
              icon: ctrl.officeShortcutPackageId.value == pkg.id
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_to_home_screen_rounded, size: 17),
              label: Text(
                ctrl.officeShortcutPackageId.value == pkg.id
                    ? 'در حال ساخت...'
                    : 'ساخت شورتکات‌ها',
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
            const SizedBox(width: 10),
          ],

          // Status Badge
          StatusBadge(
            label: isOfficeBlocked
                ? 'ویندوز Home اورجینال'
                : isInstalling
                ? 'در حال نصب...'
                : isQueued
                ? 'در صف نصب'
                : pkg.isWindowsUpdateBlocker
                ? (pkg.windowsUpdateBlocked
                      ? 'آپدیت بسته است'
                      : (pkg.windowsUpdateStateKnown
                            ? 'آپدیت فعال است'
                            : 'وضعیت نامشخص'))
                : pkg.isPortable
                ? 'آماده اجرا'
                : (isInstalled ? 'نصب شده' : 'آماده نصب'),
            status: isOfficeBlocked
                ? BadgeStatus.neutral
                : isInstalling
                ? BadgeStatus.info
                : isQueued
                ? BadgeStatus.neutral
                : pkg.isWindowsUpdateBlocker
                ? (pkg.windowsUpdateBlocked
                      ? BadgeStatus.neutral
                      : (pkg.windowsUpdateStateKnown
                            ? BadgeStatus.success
                            : BadgeStatus.info))
                : pkg.isPortable
                ? BadgeStatus.info
                : (isInstalled ? BadgeStatus.success : BadgeStatus.info),
            fontSize: 12,
          ),

          const SizedBox(width: 12),

          // Action Button
          if (isOfficeBlocked)
            const FilledButton(
              onPressed: null,
              child: Text('نصب آفیس لازم نیست'),
            )
          else if (isInstalling)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: accent.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'در حال نصب...',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                ],
              ),
            )
          else if (isQueued)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFCBD5E1),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.hourglass_top_rounded,
                    size: 13,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'در صف انتظار',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            )
          else if (pkg.isPortable)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (pkg.isWindowsUpdateBlocker) ...[
                  OutlinedButton.icon(
                    onPressed: () => ctrl.pinPackageToTaskbar(context, pkg),
                    icon: const Icon(Icons.push_pin_rounded, size: 17),
                    label: const Text('پین به تسک‌بار'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                ElevatedButton.icon(
                  onPressed:
                      pkg.isWindowsUpdateBlocker &&
                          ctrl.windowsUpdateActionPackageId.value == pkg.id
                      ? null
                      : () => pkg.isWindowsUpdateBlocker
                            ? ctrl.setWindowsUpdateState(context, pkg)
                            : ctrl.openInstalledApp(context, pkg),
                  icon:
                      pkg.isWindowsUpdateBlocker &&
                          ctrl.windowsUpdateActionPackageId.value == pkg.id
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          pkg.isWindowsUpdateBlocker
                              ? (pkg.windowsUpdateBlocked
                                    ? Icons.system_update_alt_rounded
                                    : Icons.update_disabled_rounded)
                              : Icons.open_in_new_rounded,
                          size: 17,
                        ),
                  label: Text(
                    pkg.isWindowsUpdateBlocker
                        ? (ctrl.windowsUpdateActionPackageId.value == pkg.id
                              ? 'در حال اعمال...'
                              : (pkg.windowsUpdateBlocked
                                    ? 'فعال کردن آپدیت'
                                    : 'بستن آپدیت'))
                        : 'باز کردن',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        pkg.isWindowsUpdateBlocker && pkg.windowsUpdateBlocked
                        ? const Color(0xFF059669)
                        : const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    minimumSize: const Size(0, 44),
                  ),
                ),
              ],
            )
          else if (isInstalled)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  onPressed: () => ctrl.openInstalledApp(context, pkg),
                  icon: const Icon(Icons.open_in_new_rounded, size: 14),
                  label: const Text('باز کردن'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    minimumSize: const Size(0, 32),
                  ),
                ),
                const SizedBox(width: 6),
                OutlinedButton.icon(
                  onPressed: isUninstalling
                      ? null
                      : () => ctrl.uninstallPackageInteractive(context, pkg),
                  icon: isUninstalling
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(
                          Icons.delete_outline_rounded,
                          size: 15,
                          color: AppTheme.statusDanger,
                        ),
                  label: Text(
                    'حذف',
                    style: TextStyle(
                      color: isDark
                          ? AppTheme.darkTextPrimary
                          : AppTheme.lightTextPrimary,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: const Size(0, 32),
                  ),
                ),
              ],
            )
          else
            ElevatedButton.icon(
              onPressed: () => ctrl.installPackageInteractive(context, pkg),
              icon: const Icon(Icons.download_rounded, size: 15),
              label: const Text('نصب'),
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                minimumSize: const Size(0, 32),
              ),
            ),
        ],
      ),
    );
  }

  // _buildBatchProgressPanel removed – replaced by DeploymentFlowPanel widget

  Widget _buildOfficeReminderBanner(
    BuildContext context,
    SoftwareController softwareCtrl,
    bool isDark,
  ) {
    final sysCtrl = Get.isRegistered<SystemInfoController>()
        ? Get.find<SystemInfoController>()
        : null;
    final isOfficeInstalled =
        sysCtrl?.systemInfo.value?.officeActivation.installed ?? false;
    if (isOfficeInstalled) {
      return const SizedBox.shrink();
    }
    const officeColor = Color(0xFFEA580C);
    final isHomeEdition =
        sysCtrl?.systemInfo.value?.windows.isHomeEdition ?? false;
    if (isHomeEdition) {
      return Container(
        margin: const EdgeInsets.only(top: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))
              .withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
          ),
        ),
        child: const Row(
          children: [
            Icon(Icons.verified_user_rounded, color: Color(0xFF10B981)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Windows Home اورجینال شناسایی شد؛ طبق تنظیمات این برنامه نصب آفیس لازم نیست.',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
            ),
            SizedBox(width: 10),
            FilledButton(onPressed: null, child: Text('نصب آفیس غیرفعال')),
          ],
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFCBD5E1),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.dashboard_customize_rounded,
                    size: 14,
                    color: isDark
                        ? const Color(0xFF64748B)
                        : const Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'بخش اختصاصی آفیس',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? const Color(0xFF64748B)
                          : const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFCBD5E1),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1E140A).withValues(alpha: 0.75)
                : const Color(0xFFFFF7ED),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: officeColor.withValues(alpha: isDark ? 0.35 : 0.4),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: officeColor.withValues(alpha: isDark ? 0.15 : 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEA580C), Color(0xFFC2410C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Icon(
                    Icons.description_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Row(
                      children: [
                        Text(
                          'یادت نره آفیس رو نصب کنی !',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFEA580C),
                          ),
                        ),
                        SizedBox(width: 6),
                        Text('📝', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'نصب خودکار آفیس ۲۰۲۴ (انتخاب خودکار گزینه ۱ و تأیید نصب) یا باز کردن مستقیم پوشه آفیس از روی هارد/فلش.',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Builder(
                builder: (context) {
                  final officePkg = softwareCtrl.packages.firstWhereOrNull(
                    (p) =>
                        p.installerType == 'office_cmd' ||
                        p.id == 'office_2024_pro_plus' ||
                        p.name.toLowerCase().contains('office'),
                  );

                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (officePkg != null) ...[
                        ElevatedButton.icon(
                          onPressed: () => softwareCtrl.startAutoInstallAll(
                            context,
                            targetPackageIds: [officePkg.id],
                          ),
                          icon: const Icon(
                            Icons.play_circle_filled_rounded,
                            size: 15,
                          ),
                          label: const Text(
                            'نصب خودکار آفیس ۲۰۲۴',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEA580C),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 9,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 1.5,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      OutlinedButton.icon(
                        onPressed: () => softwareCtrl.openOfficeFolder(context),
                        icon: const Icon(Icons.folder_open_rounded, size: 15),
                        label: const Text(
                          'پوشه آفیس',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: officeColor,
                          side: BorderSide(
                            color: officeColor.withValues(alpha: 0.6),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 9,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
