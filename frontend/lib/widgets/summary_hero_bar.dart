import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/system_info.dart';

class SummaryHeroBar extends StatelessWidget {
  final SystemInfo info;

  const SummaryHeroBar({super.key, required this.info});

  Widget _buildChip(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    bool forceLtrValue = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131D33) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF2D3F5E) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.18 : 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? const Color(0xFFCBD5E1)
                      : const Color(0xFF64748B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Directionality(
                textDirection: forceLtrValue
                    ? TextDirection.ltr
                    : Directionality.of(context),
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? const Color(0xFFF8FAFC)
                        : const Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // System Status calculation
    final isSystemReady =
        info.driverSummary.allHealthy &&
        info.softwareSummary.allInstalled &&
        info.filesSummary.allPresent;
    final systemStatusText = isSystemReady ? l10n.ready : l10n.needsAttention;
    final systemStatusColor = isSystemReady
        ? const Color(0xFF10B981)
        : const Color(0xFFF59E0B);

    final drvHealthy = info.driverSummary.healthyCount;
    final drvTotal = info.driverSummary.totalPresentCount;
    final drvColor = info.driverSummary.allHealthy
        ? const Color(0xFF10B981)
        : const Color(0xFFF59E0B);

    final softInstalled = info.softwareSummary.installedCount;
    final softTotal = info.softwareSummary.totalCount;
    final softColor = (softTotal > 0 && softInstalled == softTotal)
        ? const Color(0xFF10B981)
        : const Color(0xFFF59E0B);

    final filesPresent = info.filesSummary.presentCount;
    final filesTotal = info.filesSummary.totalCount;
    final filesColor = (filesTotal > 0 && filesPresent == filesTotal)
        ? const Color(0xFF10B981)
        : const Color(0xFFF59E0B);

    final cpuShort = info.cpu.name
        .replaceAll('12th Gen ', '')
        .replaceAll('(R)', '')
        .replaceAll('(TM)', '')
        .trim();

    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            // 1. System Status Chip
            _buildChip(
              context,
              icon: isSystemReady
                  ? Icons.check_circle_rounded
                  : Icons.info_outline_rounded,
              title: l10n.systemStatus,
              value: '● $systemStatusText',
              color: systemStatusColor,
            ),
            // 2. Drivers Chip
            _buildChip(
              context,
              icon: Icons.settings_suggest_rounded,
              title: l10n.drivers,
              value: l10n.driverSummaryCount(drvHealthy, drvTotal),
              color: drvColor,
            ),
            // 3. Software Status Chip
            _buildChip(
              context,
              icon: Icons.apps_rounded,
              title: l10n.software,
              value: softTotal > 0
                  ? l10n.softwareSummaryCount(softInstalled, softTotal)
                  : l10n.notAvailable,
              color: softColor,
            ),
            // 4. Required Files Status Chip
            _buildChip(
              context,
              icon: Icons.folder_special_rounded,
              title: l10n.requiredFiles,
              value: filesTotal > 0
                  ? l10n.filesSummaryCount(filesPresent, filesTotal)
                  : l10n.notAvailable,
              color: filesColor,
            ),
            // 5. CPU Chip
            _buildChip(
              context,
              icon: Icons.memory_rounded,
              title: l10n.cpu,
              value: cpuShort,
              color: const Color(0xFF3B82F6),
              forceLtrValue: true,
            ),
            // 6. RAM Chip
            _buildChip(
              context,
              icon: Icons.storage_rounded,
              title: l10n.ram,
              value: info.ram.totalDisplay,
              color: const Color(0xFFF59E0B),
              forceLtrValue: true,
            ),
            // 7. Windows Chip
            _buildChip(
              context,
              icon: Icons.laptop_windows_rounded,
              title: info.windows.isHomeEdition
                  ? 'ویندوز اورجینال اصلی'
                  : 'لایسنس ویندوز ${info.windowsActivation.activated ? l10n.activated : l10n.notActivated} است',
              value: info.windows.edition,
              color:
                  (info.windows.isHomeEdition ||
                      info.windowsActivation.activated)
                  ? const Color(0xFF0284C7)
                  : const Color(0xFFEF4444),
              forceLtrValue: true,
            ),
            // 8. Office Chip
            if (info.officeActivation.installed)
              _buildChip(
                context,
                icon: Icons.business_center_rounded,
                title:
                    '${l10n.office} (${info.officeActivation.activated ? l10n.activated : l10n.notActivated})',
                value: info.officeActivation.product,
                color: info.officeActivation.activated
                    ? const Color(0xFFD97706)
                    : const Color(0xFFEF4444),
                forceLtrValue: true,
              ),
            // 9. Battery Chip
            if (info.battery.hasBattery)
              _buildChip(
                context,
                icon: Icons.battery_charging_full_rounded,
                title: l10n.isPersian ? 'سلامت باتری' : 'Battery Health',
                value:
                    '${info.battery.healthPercent}% (${l10n.isPersian ? info.battery.healthGradeFa : info.battery.healthGrade})',
                color: (info.battery.healthPercent ?? 100.0) >= 80.0
                    ? const Color(0xFF10B981)
                    : ((info.battery.healthPercent ?? 100.0) >= 60.0
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFFEF4444)),
                forceLtrValue: true,
              ),
          ],
        );
      },
    );
  }
}
