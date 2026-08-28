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

      final totalDrivers = drivers.length;
      final needsInstall = drivers.where((d) => d.isPresent && !d.isHealthy).length;
      final upToDate = totalDrivers - needsInstall;

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
                          Icon(Icons.extension_rounded, color: accent, size: 26),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.isPersian ? 'نصب و مدیریت درایورهای سخت‌افزاری' : 'Hardware Drivers Management',
                                  style: const TextStyle(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  driverFolder.isNotEmpty ? driverFolder : 'پوشه مخزن درایورها تنظیم نشده است',
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
                              color: (needsInstall > 0 ? AppTheme.statusWarning : AppTheme.statusSuccess).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$totalDrivers کل • $needsInstall نیاز به نصب • $upToDate آماده',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: needsInstall > 0 ? AppTheme.statusWarning : AppTheme.statusSuccess,
                              ),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: isScanning ? null : () => driverCtrl.selectFolderAndScan(context),
                            icon: const Icon(Icons.folder_open_rounded, size: 16),
                            label: Text(l10n.isPersian ? 'انتخاب پوشه' : 'Select Folder'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              minimumSize: const Size(0, 36),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: isScanning ? null : () => systemCtrl.fetchSystemInfo(forceRefresh: true),
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

                const SizedBox(height: 14),

                // 2. Batch Install Banner (If active)
                if (isBatchRunning) ...[
                  _buildBatchProgressPanel(batchStatus.summaryMessage, driverCtrl, isDark, accent),
                  const SizedBox(height: 14),
                ],

                // 3. Quick Actions Toolbar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'لیست وضعیت درایورهای سخت‌افزاری:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                        ),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: (isBatchRunning || driverFolder.isEmpty)
                            ? null
                            : () => driverCtrl.scanFolder(context, driverFolder),
                        icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
                        label: Text(l10n.isPersian ? 'نصب خودکار درایورها' : 'Auto Install Drivers'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          minimumSize: const Size(0, 36),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // 4. Dense Driver Rows
                if (drivers.isEmpty)
                  EmptyStateWidget(
                    icon: Icons.extension_off_rounded,
                    title: 'درایوری برای نمایش یافت نشد',
                    subtitle: 'دکمه اسکن مجدد را بزنید تا درایورهای سیستم بازخوانی شوند.',
                    action: ElevatedButton.icon(
                      onPressed: () => systemCtrl.fetchSystemInfo(forceRefresh: true),
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('اسکن مجدد سخت‌افزار'),
                      style: ElevatedButton.styleFrom(backgroundColor: accent),
                    ),
                  )
                else
                  ...drivers.map((drv) => _buildDriverRow(drv, isDark, accent)),
              ],
            ),
          );
        },
      );
    });
  }

  Widget _buildDriverRow(DriverItem drv, bool isDark, Color accent) {
    final isOk = drv.isPresent && drv.isHealthy;
    final isOptional = drv.name.toLowerCase().contains('bluetooth') || drv.name.toLowerCase().contains('بلوتوث');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isOk
              ? (isDark ? AppTheme.darkBorder : AppTheme.lightBorder)
              : AppTheme.statusWarning.withValues(alpha: isDark ? 0.45 : 0.35),
          width: isOk ? 1.2 : 1.4,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: (isOk ? AppTheme.statusSuccess : AppTheme.statusWarning).withValues(alpha: isDark ? 0.18 : 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getDriverIcon(drv.name),
              size: 24,
              color: isOk ? AppTheme.statusSuccess : AppTheme.statusWarning,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        drv.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isOptional && !isOk)
                      const StatusBadge(
                        label: 'اختیاری (PC)',
                        status: BadgeStatus.neutral,
                        showIcon: false,
                        fontSize: 11,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  drv.statusDescription.isNotEmpty ? drv.statusDescription : (isOk ? 'درایور نصب و فعال است' : 'نیاز به نصب یا به‌روزرسانی'),
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          StatusBadge(
            label: isOk ? 'نصب شده' : 'نیاز به نصب',
            status: isOk ? BadgeStatus.success : BadgeStatus.warning,
            fontSize: 12,
          ),
        ],
      ),
    );
  }

  IconData _getDriverIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('graphic') || lower.contains('vga') || lower.contains('display') || lower.contains('گرافیک')) {
      return Icons.videogame_asset_rounded;
    }
    if (lower.contains('audio') || lower.contains('sound') || lower.contains('صدا')) {
      return Icons.volume_up_rounded;
    }
    if (lower.contains('network') || lower.contains('lan') || lower.contains('ethernet') || lower.contains('شبکه')) {
      return Icons.lan_rounded;
    }
    if (lower.contains('wi-fi') || lower.contains('wifi') || lower.contains('wireless') || lower.contains('وای فای')) {
      return Icons.wifi_rounded;
    }
    if (lower.contains('bluetooth') || lower.contains('بلوتوث')) {
      return Icons.bluetooth_rounded;
    }
    if (lower.contains('chipset') || lower.contains('چیپست')) {
      return Icons.developer_board_rounded;
    }
    return Icons.extension_rounded;
  }

  Widget _buildBatchProgressPanel(String status, DriverInstallController ctrl, bool isDark, Color accent) {
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
              status.isNotEmpty ? status : 'در حال اجرای عملیات نصب درایورها...',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
