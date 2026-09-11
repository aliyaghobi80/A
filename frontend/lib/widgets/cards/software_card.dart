import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../models/system_info.dart';
import 'card_wrapper.dart';
import 'info_row.dart';

class SoftwareCard extends StatelessWidget {
  final List<SoftwareItem> software;
  final SoftwareSummary summary;

  const SoftwareCard({
    super.key,
    required this.software,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    final allGood = summary.allInstalled;
    final badgeColor = allGood
        ? const Color(0xFF10B981)
        : const Color(0xFFF59E0B);

    return CardWrapper(
      icon: Icons.apps_rounded,
      title: l10n.software,
      summarySubtitle: l10n.softwareSummaryCount(
        summary.installedCount,
        summary.totalCount,
      ),
      iconColor: const Color(0xFF6366F1),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: badgeColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
        ),
        child: Text(
          l10n.softwareSummaryCount(summary.installedCount, summary.totalCount),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: badgeColor,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (software.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                l10n.noSoftwareConfigured,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B),
                ),
              ),
            )
          else
            ...software.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return _buildSoftwareItem(
                context,
                item,
                isDark,
                l10n,
                isLast: index == software.length - 1,
              );
            }),
        ],
      ),
    );
  }

  Widget _buildSoftwareItem(
    BuildContext context,
    SoftwareItem item,
    bool isDark,
    AppLocalizations l10n, {
    required bool isLast,
  }) {
    final isInstalled = item.isInstalled;
    final statusColor = isInstalled
        ? const Color(0xFF10B981)
        : const Color(0xFFEF4444);

    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: isInstalled
              ? statusColor.withValues(alpha: isDark ? 0.25 : 0.2)
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Name + Status Badge
          Row(
            children: [
              Tooltip(
                message: isInstalled
                    ? (item.installLocation.isNotEmpty &&
                              item.installLocation != 'Not available'
                          ? 'مسیر نصب:\n${item.installLocation}'
                          : 'نرم‌افزار در رجیستری ویندوز ثبت شده است.')
                    : 'نرم‌افزار هنوز نصب نشده است.',
                waitDuration: const Duration(milliseconds: 250),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    isInstalled
                        ? Icons.check_circle_rounded
                        : Icons.cancel_rounded,
                    size: 16,
                    color: statusColor,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    item.displayName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? const Color(0xFFF8FAFC)
                          : const Color(0xFF0F172A),
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isInstalled ? l10n.installed : l10n.notInstalled,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),

          if (isInstalled) ...[
            const SizedBox(height: 10),
            InfoRow(
              label: l10n.version,
              value: item.version,
              icon: Icons.tag_rounded,
              forceLtrValue: true,
              isMonospace: true,
            ),
            if (item.productName != item.displayName &&
                item.productName != 'Not available')
              InfoRow(
                label: l10n.modelProduct,
                value: item.productName,
                icon: Icons.badge_outlined,
                forceLtrValue: true,
              ),
            InfoRow(
              label: l10n.detectionSource,
              value: item.detectionSource,
              icon: Icons.travel_explore_rounded,
              forceLtrValue: true,
            ),
            if (item.installLocation != 'Not available' &&
                item.installLocation.isNotEmpty)
              InfoRow(
                label: l10n.installLocation,
                value: item.installLocation,
                icon: Icons.folder_open_rounded,
                forceLtrValue: true,
                copyable: true,
              ),
          ],
        ],
      ),
    );
  }
}
