import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/activation_controller.dart';
import '../../controllers/driver_install_controller.dart';
import '../../controllers/software_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../common/design_components.dart';

class ToolsSourceFoldersPage extends StatelessWidget {
  const ToolsSourceFoldersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final softwareCtrl = Get.find<SoftwareController>();
    final driverCtrl = Get.find<DriverInstallController>();
    final activationCtrl = Get.put(ActivationController());
    final l10n = AppLocalizations.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Software Folder Section
          Obx(() {
            final dir = softwareCtrl.packagesDirectory;
            final isConfigured = dir.isNotEmpty && Directory(dir).existsSync();
            final packages = softwareCtrl.packages;

            return _buildFolderSection(
              title: '۱. پوشه نرم‌افزارها (Software Packages)',
              path: dir,
              isConfigured: isConfigured,
              icon: Icons.apps_rounded,
              accentColor: const Color(0xFF2563EB),
              onPick: () => softwareCtrl.changePackagesDirectory(context),
              onRescan: () => softwareCtrl.fetchPackages(),
              contents: packages.map((p) => _FileEntry(
                    title: p.name,
                    subtitle: p.filename,
                    statusText: p.isInstalled ? 'نصب شده' : (p.isValid ? 'آماده' : 'نامعتبر'),
                    isSuccess: p.isInstalled,
                  )).toList(),
              isDark: isDark,
              l10n: l10n,
            );
          }),

          const SizedBox(height: 16),

          // 2. Driver Folder Section
          Obx(() {
            final dir = driverCtrl.driverFolder.value;
            final isConfigured = dir.isNotEmpty && Directory(dir).existsSync();
            final scanned = driverCtrl.scannedFiles;

            return _buildFolderSection(
              title: '۲. پوشه درایورهای این دستگاه (Device Drivers)',
              path: dir,
              isConfigured: isConfigured,
              icon: Icons.extension_rounded,
              accentColor: const Color(0xFF0D9488),
              onPick: () => driverCtrl.selectFolderAndScan(context),
              onRescan: dir.isNotEmpty ? () => driverCtrl.scanFolder(context, dir) : null,
              contents: scanned.map((f) => _FileEntry(
                    title: f.filename,
                    subtitle: f.fileSizeDisplay,
                    statusText: f.autoInstallSupported ? 'خودکار' : 'دستی',
                    isSuccess: f.autoInstallSupported,
                  )).toList(),
              isDark: isDark,
              l10n: l10n,
            );
          }),

          const SizedBox(height: 16),

          // 3. Activation Tools Folder Section (Live & Observable)
          Obx(() {
            final dir = activationCtrl.toolsDirectory.value;
            final isConfigured = dir.isNotEmpty && Directory(dir).existsSync();
            final tools = activationCtrl.tools;

            return _buildFolderSection(
              title: '۳. پوشه فعال‌سازی Windows و Office (KMS Tools)',
              path: dir.isNotEmpty ? dir : 'پوشه ابزارهای فعال‌سازی انتخاب نشده است',
              isConfigured: isConfigured,
              icon: Icons.vpn_key_rounded,
              accentColor: const Color(0xFFD97706),
              onPick: () => activationCtrl.changeToolsDirectory(context),
              onRescan: () => activationCtrl.fetchToolsStatus(),
              contents: tools.map((t) => _FileEntry(
                    title: t.name,
                    subtitle: t.description,
                    statusText: t.statusText,
                    isSuccess: t.isValid,
                  )).toList(),
              isDark: isDark,
              l10n: l10n,
            );
          }),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildFolderSection({
    required String title,
    required String path,
    required bool isConfigured,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onPick,
    required VoidCallback? onRescan,
    required List<_FileEntry> contents,
    required bool isDark,
    required AppLocalizations l10n,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: isDark ? 0.18 : 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                  ),
                ),
              ),
              StatusDot(
                label: isConfigured ? 'پوشه تنظیم شده' : 'ناموجود',
                status: isConfigured ? BadgeStatus.success : BadgeStatus.warning,
                fontSize: 13,
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Folder Path Bar + Buttons
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      path.isNotEmpty ? path : 'مسیر پوشه تنظیم نشده است',
                      style: TextStyle(
                        fontSize: 13,
                        fontFamily: 'monospace',
                        color: isConfigured
                            ? (isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary)
                            : (isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: onPick,
                  icon: const Icon(Icons.folder_open_rounded, size: 15),
                  label: const Text('انتخاب پوشه'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: const Size(0, 34),
                  ),
                ),
                if (onRescan != null) ...[
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: onRescan,
                    icon: const Icon(Icons.refresh_rounded, size: 15),
                    label: const Text('اسکن'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: const Size(0, 34),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Discovered Contents List
          if (contents.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'فایل یا ابزاری در این پوشه شناسایی نشد.',
                style: TextStyle(fontSize: 13, color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted),
              ),
            )
          else
            Column(
              children: contents.map((e) => _buildFileRow(e, isDark)).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildFileRow(_FileEntry entry, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131D33) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
      ),
      child: Row(
        children: [
          Icon(
            Icons.insert_drive_file_rounded,
            size: 18,
            color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    entry.title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (entry.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    entry.subtitle,
                    style: TextStyle(fontSize: 12, color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusBadge(
            label: entry.statusText,
            status: entry.isSuccess ? BadgeStatus.success : BadgeStatus.neutral,
            fontSize: 11.5,
          ),
        ],
      ),
    );
  }
}

class _FileEntry {
  final String title;
  final String subtitle;
  final String statusText;
  final bool isSuccess;

  _FileEntry({
    required this.title,
    required this.subtitle,
    required this.statusText,
    required this.isSuccess,
  });
}
