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
          color: isDark ? const Color(0xFF22304E) : const Color(0xFFE2E8F0),
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
              color: color.withValues(alpha: 0.12),
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
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Directionality(
                textDirection: forceLtrValue ? TextDirection.ltr : Directionality.of(context),
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
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
            // 1. Hardware Status Chip
            _buildChip(
              context,
              icon: Icons.check_circle_rounded,
              title: l10n.hardware,
              value: '✓ ${l10n.ready}',
              color: const Color(0xFF10B981),
            ),
            // 2. Software Status Chip
            _buildChip(
              context,
              icon: Icons.apps_rounded,
              title: l10n.software,
              value: softTotal > 0
                  ? l10n.softwareSummaryCount(softInstalled, softTotal)
                  : l10n.notAvailable,
              color: softColor,
            ),
            // 3. Required Files Status Chip
            _buildChip(
              context,
              icon: Icons.folder_special_rounded,
              title: l10n.requiredFiles,
              value: filesTotal > 0
                  ? l10n.filesSummaryCount(filesPresent, filesTotal)
                  : l10n.notAvailable,
              color: filesColor,
            ),
            // 4. CPU Chip
            _buildChip(
              context,
              icon: Icons.memory_rounded,
              title: l10n.cpu,
              value: cpuShort,
              color: const Color(0xFF3B82F6),
              forceLtrValue: true,
            ),
            // 5. RAM Chip
            _buildChip(
              context,
              icon: Icons.storage_rounded,
              title: l10n.ram,
              value: info.ram.totalDisplay,
              color: const Color(0xFFF59E0B),
              forceLtrValue: true,
            ),
            // 6. Windows Chip
            _buildChip(
              context,
              icon: Icons.laptop_windows_rounded,
              title: l10n.windows,
              value: info.windows.edition,
              color: const Color(0xFF0284C7),
              forceLtrValue: true,
            ),
          ],
        );
      },
    );
  }
}
