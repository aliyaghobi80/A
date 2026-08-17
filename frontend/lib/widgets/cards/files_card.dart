import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../models/system_info.dart';
import 'card_wrapper.dart';
import 'info_row.dart';

class FilesCard extends StatelessWidget {
  final List<RequiredFileItem> files;
  final FilesSummary summary;
  final Function(String reqId, String reqName)? onChangePath;

  const FilesCard({
    super.key,
    required this.files,
    required this.summary,
    this.onChangePath,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    final allGood = summary.allPresent;
    final badgeColor = allGood ? const Color(0xFF10B981) : const Color(0xFFF59E0B);

    return CardWrapper(
      icon: Icons.folder_special_rounded,
      title: l10n.requiredFiles,
      iconColor: const Color(0xFF0EA5E9),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: badgeColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
        ),
        child: Text(
          l10n.filesSummaryCount(summary.presentCount, summary.totalCount),
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
          if (files.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                l10n.noFilesConfigured,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            )
          else
            ...files.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return _buildFileItem(context, item, isDark, l10n, isLast: index == files.length - 1);
            }),
        ],
      ),
    );
  }

  Widget _buildFileItem(
    BuildContext context,
    RequiredFileItem item,
    bool isDark,
    AppLocalizations l10n, {
    required bool isLast,
  }) {
    final exists = item.exists;
    final statusColor = exists ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    final isFolder = item.type.toLowerCase() == 'folder';

    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: exists
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
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  isFolder ? (exists ? Icons.folder_rounded : Icons.folder_off_rounded) : (exists ? Icons.insert_drive_file_rounded : Icons.file_present_rounded),
                  size: 16,
                  color: statusColor,
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
                      color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
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
                  exists ? l10n.present : l10n.missing,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          InfoRow(
            label: l10n.filePath,
            value: item.path,
            icon: Icons.link_rounded,
            forceLtrValue: true,
            isMonospace: true,
            copyable: true,
          ),
          InfoRow(
            label: l10n.fileType,
            value: isFolder ? l10n.folder : l10n.file,
            icon: isFolder ? Icons.folder_open_rounded : Icons.description_outlined,
          ),
          if (onChangePath != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => onChangePath!(item.id, item.displayName),
                icon: const Icon(Icons.folder_open_rounded, size: 14),
                label: Text(
                  l10n.isPersian ? 'تغییر مسیر' : 'Change Path',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF0EA5E9),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
