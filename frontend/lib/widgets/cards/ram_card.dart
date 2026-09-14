import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../models/system_info.dart';
import '../common/hardware_illustrations.dart';
import 'card_wrapper.dart';
import 'info_row.dart';

class RamCard extends StatelessWidget {
  final RamInfo ram;

  const RamCard({super.key, required this.ram});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return CardWrapper(
      icon: Icons.storage_rounded,
      title: l10n.ramMemory,
      summarySubtitle: '${ram.totalDisplay} (${ram.moduleSummary})',
      illustration: const RamIllustration(),
      iconColor: const Color(0xFFF59E0B),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Text(
            ram.totalDisplay,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFFFCD34D) : const Color(0xFFD97706),
            ),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoRow(
            label: l10n.totalCapacity,
            value: ram.totalDisplay,
            icon: Icons.pie_chart_rounded,
            isPrimary: true,
            forceLtrValue: true,
          ),
          InfoRow(
            label: l10n.installedModules,
            value: ram.moduleCount > 0
                ? l10n.modulesCount(ram.moduleCount)
                : l10n.notAvailable,
            icon: Icons.view_column_rounded,
          ),
          if (ram.moduleSummary != 'Not available')
            InfoRow(
              label: l10n.configuration,
              value: ram.moduleSummary,
              icon: Icons.splitscreen_rounded,
              forceLtrValue: true,
            ),
          InfoRow(
            label: l10n.configuredSpeed,
            value: ram.speedDisplay,
            icon: Icons.speed_rounded,
            forceLtrValue: true,
          ),
          InfoRow(
            label: l10n.isPersian ? 'اسلات‌های گزارش‌شده' : 'Reported slots',
            value: ram.totalSlots == null
                ? l10n.notAvailable
                : '${ram.moduleCount} / ${ram.totalSlots}',
            forceLtrValue: true,
          ),
          if (ram.modules.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              l10n.moduleDetails,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 6),
            ...ram.modules.asMap().entries.map((entry) {
              final idx = entry.key;
              final mod = entry.value;
              final serialText =
                  (mod.serial != 'Not available' &&
                      mod.serial != '00000000' &&
                      mod.serial.isNotEmpty)
                  ? mod.serial
                  : (mod.partNumber != 'Not available' ? mod.partNumber : null);

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color:
                            (isDark
                                    ? const Color(0xFFF59E0B)
                                    : const Color(0xFFD97706))
                                .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                          width: 0.8,
                        ),
                      ),
                      child: const RamIllustration(color: Color(0xFFF59E0B)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${l10n.isPersian ? "رم" : "RAM"} ${idx + 1} — ${l10n.isPersian ? "اسلات" : "Slot"} ${mod.slot}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? const Color(0xFFF1F5F9)
                                      : const Color(0xFF0F172A),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFF59E0B,
                                  ).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  mod.capacityDisplay,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFF59E0B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (mod.slotDetails.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Directionality(
                                textDirection: TextDirection.ltr,
                                child: Text(
                                  mod.slotDetails,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: isDark
                                        ? const Color(0xFF94A3B8)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: 4),
                          Directionality(
                            textDirection: TextDirection.ltr,
                            child: Text(
                              '${mod.type} • ${mod.speedDisplay} • ${mod.clDisplay}${mod.manufacturer != "Not available" ? " • ${mod.manufacturer}" : ""}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                          if (serialText != null &&
                              serialText.isNotEmpty &&
                              serialText != 'Default string') ...[
                            const SizedBox(height: 4),
                            Text(
                              '${l10n.isPersian ? "سریال: " : "S/N: "}$serialText',
                              style: TextStyle(
                                fontFamily: 'Consolas',
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? const Color(0xFFCBD5E1)
                                    : const Color(0xFF475569),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
