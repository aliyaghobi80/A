import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../l10n/app_localizations.dart';
import '../../models/system_info.dart';
import '../common/design_components.dart';
import '../common/copyable_value.dart';
import '../common/hardware_illustrations.dart';
import 'card_wrapper.dart';
import 'info_row.dart';

class MotherboardCard extends StatelessWidget {
  final MotherboardInfo motherboard;

  const MotherboardCard({super.key, required this.motherboard});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final brandColor = motherboard.brandColor;

    return CardWrapper(
      icon: motherboard.brandIcon,
      title: l10n.motherboard,
      summarySubtitle:
          '${motherboard.fullDisplayName}${motherboard.effectiveChipset.isNotEmpty ? " (${motherboard.effectiveChipset})" : ""}',
      illustration: const MotherboardIllustration(),
      iconColor: brandColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Brand Badge & Chips
          Row(
            children: [
              MotherboardBrandBadge(
                motherboard: motherboard,
                showChipset: true,
              ),
              const Spacer(),
              if (motherboard.effectiveFormFactor.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
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
                  child: Text(
                    motherboard.effectiveFormFactor,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Model Highlight
          CopyableValue(
            tooltip: l10n.isPersian
                ? 'کپی مدل مادربرد'
                : 'Copy motherboard model',
            onCopy: () {
              Clipboard.setData(
                ClipboardData(text: motherboard.fullDisplayName),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '${l10n.copiedToClipboard}: ${motherboard.fullDisplayName}',
                  ),
                  duration: const Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0F172A)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: brandColor.withValues(alpha: isDark ? 0.35 : 0.25),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        motherboard.fullDisplayName,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? const Color(0xFFF8FAFC)
                              : const Color(0xFF0F172A),
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.copy_rounded, size: 15, color: brandColor),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          InfoRow(
            label: l10n.isPersian ? 'برند و سازنده' : 'Brand & Vendor',
            value:
                '${motherboard.effectiveBrand}${motherboard.effectiveBrandFa.isNotEmpty ? " (${motherboard.effectiveBrandFa})" : ""}',
            icon: Icons.business_rounded,
          ),
          if (motherboard.effectiveChipset.isNotEmpty)
            InfoRow(
              label: l10n.isPersian ? 'چیپست اصلی' : 'Chipset',
              value: motherboard.effectiveChipset,
              icon: Icons.developer_board_rounded,
              forceLtrValue: true,
            ),
          InfoRow(
            label: l10n.modelProduct,
            value: motherboard.model,
            icon: Icons.tag_rounded,
            forceLtrValue: true,
            copyable: true,
          ),
          if (motherboard.uuid.isNotEmpty && motherboard.uuid != '-')
            InfoRow(
              label: 'UUID',
              value: motherboard.uuid,
              icon: Icons.fingerprint_rounded,
              copyable: true,
              isMonospace: true,
            ),
        ],
      ),
    );
  }
}
