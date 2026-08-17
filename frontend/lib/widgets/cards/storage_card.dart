import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../models/system_info.dart';
import '../common/hardware_illustrations.dart';
import 'card_wrapper.dart';
import 'info_row.dart';

class StorageCard extends StatelessWidget {
  final List<StorageInfo> storage;

  const StorageCard({super.key, required this.storage});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    final summarySub = storage.isNotEmpty
        ? storage.map((s) => '${s.capacityDisplay} ${s.type}').join(' • ')
        : l10n.noStorageDetected;

    return CardWrapper(
      icon: Icons.album_rounded,
      title: l10n.physicalStorageDevices,
      summarySubtitle: summarySub,
      illustration: const StorageIllustration(),
      iconColor: const Color(0xFF06B6D4),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF06B6D4).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          l10n.drivesCount(storage.length),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFF67E8F9) : const Color(0xFF0E7490),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (storage.isEmpty)
            Text(l10n.noStorageDetected)
          else
            ...storage.asMap().entries.map((entry) {
              final idx = entry.key;
              final drive = entry.value;

              final isSsd = drive.type.toUpperCase().contains('SSD') ||
                  drive.type.toUpperCase().contains('NVME');
              final badgeColor = isSsd
                  ? (isDark ? const Color(0xFF06B6D4) : const Color(0xFF0891B2))
                  : (isDark ? const Color(0xFFF59E0B) : const Color(0xFFD97706));

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (idx > 0) ...[
                    const SizedBox(height: 14),
                    Divider(
                      color: isDark ? const Color(0xFF1E2C4A) : const Color(0xFFF1F5F9),
                    ),
                    const SizedBox(height: 10),
                  ],
                  // Header row with drive model and type badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          isSsd ? Icons.speed_rounded : Icons.dns_rounded,
                          size: 16,
                          color: badgeColor,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Directionality(
                              textDirection: TextDirection.ltr,
                              child: Text(
                                drive.model,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: badgeColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Directionality(
                                    textDirection: TextDirection.ltr,
                                    child: Text(
                                      drive.type,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: badgeColor,
                                      ),
                                    ),
                                  ),
                                ),
                                if (drive.busType != 'Not available') ...[
                                  const SizedBox(width: 6),
                                  Directionality(
                                    textDirection: TextDirection.ltr,
                                    child: Text(
                                      '•   ${drive.busType}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          drive.capacityDisplay,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  InfoRow(
                    label: l10n.capacity,
                    value: drive.capacityDisplay,
                    icon: Icons.pie_chart_outline_rounded,
                    forceLtrValue: true,
                  ),
                  InfoRow(
                    label: l10n.interfaceBus,
                    value: drive.busType,
                    icon: Icons.cable_rounded,
                    forceLtrValue: true,
                  ),
                  InfoRow(
                    label: l10n.serialNumber,
                    value: drive.serial,
                    icon: Icons.qr_code_rounded,
                    copyable: true,
                    isMonospace: true,
                  ),
                ],
              );
            }),
        ],
      ),
    );
  }
}
