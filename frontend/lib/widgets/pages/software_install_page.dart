import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/software_controller.dart';
import '../../controllers/theme_language_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../models/system_info.dart';
import '../../theme/app_theme.dart';
import '../common/design_components.dart';

class SoftwareInstallPage extends StatefulWidget {
  const SoftwareInstallPage({super.key});

  @override
  State<SoftwareInstallPage> createState() => _SoftwareInstallPageState();
}

class _SoftwareInstallPageState extends State<SoftwareInstallPage> {
  String selectedCategory = 'all';
  final Set<String> selectedPackageIds = {};

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final softwareCtrl = Get.find<SoftwareController>();
    final themeCtrl = Get.find<ThemeLanguageController>();
    final l10n = AppLocalizations.of(context);
    final accent = themeCtrl.currentAccentColor;

    return Obx(() {
      final packages = softwareCtrl.packages;
      final hideDuplicates = softwareCtrl.hideDuplicates.value;
      final isScanning = softwareCtrl.isScanning.value;
      final isBatchRunning = softwareCtrl.isBatchInstalling.value;
      final batchStatus = softwareCtrl.batchStatus.value;
      final dir = softwareCtrl.packagesDirectory;

      final totalDuplicates = packages.where((p) => p.isDuplicate).length;

      // Filtered active list according to hideDuplicates and category
      final visiblePackages = packages.where((p) {
        if (hideDuplicates && p.isDuplicate) return false;
        return true;
      }).toList();

      final readyPackages = visiblePackages.where((p) => !p.isInstalled && p.isValid).toList();
      final installedPackages = visiblePackages.where((p) => p.isInstalled).toList();

      final filteredPackages = visiblePackages.where((p) {
        if (selectedCategory == 'all') return true;
        if (selectedCategory == 'ready') return !p.isInstalled && p.isValid;
        if (selectedCategory == 'installed') return p.isInstalled;
        return p.publisher.toLowerCase().contains(selectedCategory.toLowerCase()) ||
            p.name.toLowerCase().contains(selectedCategory.toLowerCase());
      }).toList();

      return LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 750;

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: isNarrow ? 12 : 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Header Toolbar (Responsive Wrap)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder, width: 1.2),
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
                                  l10n.isPersian ? 'نصب و مدیریت نرم‌افزارهای کاربردی' : 'Software Deployment',
                                  style: const TextStyle(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  dir.isNotEmpty ? dir : 'پوشه مخزن نرم‌افزارها تنظیم نشده است',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                    color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
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
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: (readyPackages.isNotEmpty ? const Color(0xFF0284C7) : AppTheme.statusSuccess).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${visiblePackages.length} نرم‌افزار • ${installedPackages.length} نصب شده • ${readyPackages.length} آماده نصب',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: readyPackages.isNotEmpty ? const Color(0xFF0284C7) : AppTheme.statusSuccess,
                              ),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: isScanning ? null : () => softwareCtrl.changePackagesDirectory(context),
                            icon: const Icon(Icons.folder_open_rounded, size: 16),
                            label: const Text('انتخاب پوشه'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              minimumSize: const Size(0, 36),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: isScanning ? null : () => softwareCtrl.fetchPackages(),
                            icon: isScanning
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.refresh_rounded, size: 16),
                            label: Text(isScanning ? 'در حال اسکن...' : 'اسکن مجدد'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accent,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              minimumSize: const Size(0, 36),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // 2. Batch Progress (If running)
                if (isBatchRunning) ...[
                  _buildBatchProgressPanel(batchStatus.summaryMessage, softwareCtrl, isDark, accent),
                  const SizedBox(height: 12),
                ],

                // 3. Category Filter Chips + Deduplication Toggle + Bulk Toolbar (Responsive Layout)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                  ),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildFilterTab('all', 'همه (${visiblePackages.length})', isDark, accent),
                          const SizedBox(width: 6),
                          _buildFilterTab('ready', 'آماده نصب (${readyPackages.length})', isDark, accent),
                          const SizedBox(width: 6),
                          _buildFilterTab('installed', 'نصب شده (${installedPackages.length})', isDark, accent),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Deduplication Toggle Chip
                          InkWell(
                            onTap: () => softwareCtrl.toggleHideDuplicates(),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                              decoration: BoxDecoration(
                                color: hideDuplicates
                                    ? accent.withValues(alpha: isDark ? 0.22 : 0.12)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: hideDuplicates
                                      ? accent.withValues(alpha: 0.5)
                                      : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    hideDuplicates ? Icons.filter_alt_rounded : Icons.filter_alt_off_rounded,
                                    size: 15,
                                    color: hideDuplicates ? accent : (isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    totalDuplicates > 0
                                        ? 'مخفی کردن تکراری‌ها ($totalDuplicates)'
                                        : 'مخفی کردن تکراری‌ها',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: hideDuplicates ? FontWeight.w800 : FontWeight.w500,
                                      color: hideDuplicates ? accent : (isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          Checkbox(
                            value: selectedPackageIds.length == readyPackages.length && readyPackages.isNotEmpty,
                            activeColor: accent,
                            onChanged: readyPackages.isEmpty
                                ? null
                                : (val) {
                                    setState(() {
                                      if (val == true) {
                                        selectedPackageIds.addAll(readyPackages.map((p) => p.id));
                                      } else {
                                        selectedPackageIds.clear();
                                      }
                                    });
                                  },
                          ),
                          Text(
                            'انتخاب همه (${selectedPackageIds.length})',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton.icon(
                            onPressed: (isBatchRunning || readyPackages.isEmpty)
                                ? null
                                : () => softwareCtrl.startAutoInstallAll(
                                      context,
                                      targetPackageIds: selectedPackageIds.isNotEmpty
                                          ? selectedPackageIds.toList()
                                          : null,
                                    ),
                            icon: const Icon(Icons.play_arrow_rounded, size: 16),
                            label: Text(
                              selectedPackageIds.isNotEmpty
                                  ? 'نصب انتخابی (${selectedPackageIds.length})'
                                  : 'نصب خودکار همه آماده‌ها (${readyPackages.length})',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accent,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              minimumSize: const Size(0, 36),
                            ),
                          ),
                        ],
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
                    subtitle: 'پوشه نرم‌افزارها را انتخاب کنید یا فیلتر نمایش را تغییر دهید.',
                    action: ElevatedButton.icon(
                      onPressed: () => softwareCtrl.changePackagesDirectory(context),
                      icon: const Icon(Icons.folder_open_rounded, size: 16),
                      label: const Text('انتخاب پوشه نرم‌افزارها'),
                      style: ElevatedButton.styleFrom(backgroundColor: accent),
                    ),
                  )
                else
                  ...filteredPackages.map((pkg) {
                    final isThisInstalling = softwareCtrl.isCurrentInstalling(pkg);
                    final isThisUninstalling = softwareCtrl.isCurrentUninstalling(pkg);
                    return _buildPackageRow(pkg, softwareCtrl, isThisInstalling, isThisUninstalling, isDark, accent);
                  }),
              ],
            ),
          );
        },
      );
    });
  }

  Widget _buildFilterTab(String cat, String label, bool isDark, Color accent) {
    final isSelected = selectedCategory == cat;

    return InkWell(
      onTap: () => setState(() => selectedCategory = cat),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? accent.withValues(alpha: isDark ? 0.25 : 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? accent : (isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted),
          ),
        ),
      ),
    );
  }

  Widget _buildPackageIcon(SoftwarePackage pkg, Color accent, bool isDark) {
    if (pkg.iconBase64 != null && pkg.iconBase64!.isNotEmpty) {
      try {
        final clean = pkg.iconBase64!.contains(',') ? pkg.iconBase64!.split(',').last : pkg.iconBase64!;
        final bytes = base64Decode(clean.trim());
        if (bytes.isNotEmpty) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              bytes,
              fit: BoxFit.contain,
              errorBuilder: (ctx, err, stack) => Icon(Icons.apps_rounded, size: 24, color: accent),
            ),
          );
        }
      } catch (e) {
        debugPrint('[SoftwareInstallPage] Icon decode error for ${pkg.name}: $e');
      }
    }
    return Icon(Icons.apps_rounded, size: 24, color: accent);
  }

  Widget _buildPackageRow(
    SoftwarePackage pkg,
    SoftwareController ctrl,
    bool isInstalling,
    bool isUninstalling,
    bool isDark,
    Color accent,
  ) {
    final isInstalled = pkg.isInstalled;
    final isSelected = selectedPackageIds.contains(pkg.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelected
              ? accent
              : (isInstalled ? (isDark ? AppTheme.darkBorder : AppTheme.lightBorder) : const Color(0xFF0284C7).withValues(alpha: 0.35)),
          width: isSelected ? 1.8 : 1.2,
        ),
      ),
      child: Row(
        children: [
          if (!isInstalled && pkg.isValid) ...[
            Checkbox(
              value: isSelected,
              activeColor: accent,
              onChanged: (val) {
                setState(() {
                  if (val == true) {
                    selectedPackageIds.add(pkg.id);
                  } else {
                    selectedPackageIds.remove(pkg.id);
                  }
                });
              },
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
                          color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
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
                    color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
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
            label: isInstalled ? 'نصب شده' : 'آماده نصب',
            status: isInstalled ? BadgeStatus.success : BadgeStatus.info,
            fontSize: 12,
          ),

          const SizedBox(width: 12),

          // Action Button
          if (isInstalling)
            const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
          else if (isInstalled)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  onPressed: () => ctrl.openInstalledApp(context, pkg),
                  icon: const Icon(Icons.open_in_new_rounded, size: 14),
                  label: const Text('باز کردن'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: const Size(0, 32),
                  ),
                ),
                const SizedBox(width: 6),
                OutlinedButton.icon(
                  onPressed: isUninstalling ? null : () => ctrl.uninstallPackageInteractive(context, pkg),
                  icon: isUninstalling
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.delete_outline_rounded, size: 15, color: AppTheme.statusDanger),
                  label: Text(
                    'حذف',
                    style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                minimumSize: const Size(0, 32),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBatchProgressPanel(String status, SoftwareController ctrl, bool isDark, Color accent) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isDark ? 0.18 : 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              status.isNotEmpty ? status : 'در حال نصب بسته نرم‌افزاری...',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
