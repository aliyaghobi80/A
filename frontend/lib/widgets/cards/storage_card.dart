import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../models/system_info.dart';
import '../common/hardware_illustrations.dart';
import 'card_wrapper.dart';
import 'info_row.dart';

class StorageCard extends StatelessWidget {
  final List<StorageInfo> storage;

  const StorageCard({super.key, required this.storage});

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 GB';
    final gb = bytes / (1024 * 1024 * 1024);
    return '${gb >= 100 ? gb.toStringAsFixed(0) : gb.toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    final summarySub = storage.isNotEmpty
        ? storage.map((s) => '${s.capacityDisplay} ${s.type}').join(' • ')
        : l10n.noStorageDetected;

    final primaryStorage = storage.isNotEmpty ? storage.first : null;

    return CardWrapper(
      icon: Icons.album_rounded,
      title: l10n.physicalStorageDevices,
      summarySubtitle: summarySub,
      illustration: StorageIllustration(
        storageType: primaryStorage?.type,
        busType: primaryStorage?.busType,
        model: primaryStorage?.model,
        typeDescription: primaryStorage?.typeDescription,
      ),
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

              final isSsd =
                  drive.type.toUpperCase().contains('SSD') ||
                  drive.type.toUpperCase().contains('NVME');
              final badgeColor = isSsd
                  ? (isDark ? const Color(0xFF06B6D4) : const Color(0xFF0891B2))
                  : (isDark
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFFD97706));

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (idx > 0) ...[
                    const SizedBox(height: 14),
                    Divider(
                      color: isDark
                          ? const Color(0xFF1E2C4A)
                          : const Color(0xFFF1F5F9),
                    ),
                    const SizedBox(height: 10),
                  ],
                  // Header row with drive model and type badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: StorageIllustration(
                          storageType: drive.type,
                          busType: drive.busType,
                          model: drive.model,
                          typeDescription: drive.typeDescription,
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
                                  color: isDark
                                      ? const Color(0xFFF1F5F9)
                                      : const Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
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
                                        color: isDark
                                            ? const Color(0xFF94A3B8)
                                            : const Color(0xFF64748B),
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
                            color: isDark
                                ? const Color(0xFF38BDF8)
                                : const Color(0xFF0284C7),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (drive.mountedCapacityBytes > 0) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF0F172A)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF263654)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'فضای آزاد ${_formatBytes(drive.freeBytes)}',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? const Color(0xFF34D399)
                                        : const Color(0xFF047857),
                                  ),
                                ),
                              ),
                              Text(
                                'مصرف‌شده ${_formatBytes(drive.usedBytes)} • ${drive.percentUsed.toStringAsFixed(0)}٪',
                                textDirection: TextDirection.rtl,
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
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              minHeight: 8,
                              value: (drive.percentUsed / 100).clamp(0.0, 1.0),
                              color: drive.percentUsed >= 90
                                  ? const Color(0xFFEF4444)
                                  : drive.percentUsed >= 75
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0xFF06B6D4),
                              backgroundColor: isDark
                                  ? const Color(0xFF24324B)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          if (drive.volumes.isNotEmpty) ...[
                            const SizedBox(height: 7),
                            Directionality(
                              textDirection: TextDirection.ltr,
                              child: Text(
                                'Volumes: ${drive.volumes.join('  •  ')}',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: isDark
                                      ? const Color(0xFF64748B)
                                      : const Color(0xFF94A3B8),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
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
