import 'package:flutter/material.dart';
import '../../models/system_info.dart';
import 'card_wrapper.dart';
import 'info_row.dart';

class RamCard extends StatelessWidget {
  final RamInfo ram;

  const RamCard({super.key, required this.ram});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return CardWrapper(
      icon: Icons.storage_rounded,
      title: 'RAM (Memory)',
      iconColor: const Color(0xFFF59E0B),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          ram.totalDisplay,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isDark ? const Color(0xFFFCD34D) : const Color(0xFFD97706),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoRow(
            label: 'Total Capacity',
            value: ram.totalDisplay,
            icon: Icons.pie_chart_rounded,
            isPrimary: true,
          ),
          InfoRow(
            label: 'Installed Modules',
            value: ram.moduleCount > 0 ? '${ram.moduleCount} Module${ram.moduleCount > 1 ? 's' : ''}' : 'Not available',
            icon: Icons.view_column_rounded,
          ),
          if (ram.moduleSummary != 'Not available')
            InfoRow(
              label: 'Configuration',
              value: ram.moduleSummary,
              icon: Icons.splitscreen_rounded,
            ),
          InfoRow(
            label: 'Configured Speed',
            value: ram.speedDisplay,
            icon: Icons.speed_rounded,
          ),
          
          if (ram.modules.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Module Details',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 6),
            ...ram.modules.map((mod) {
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: (isDark ? const Color(0xFFF59E0B) : const Color(0xFFD97706)).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(
                        Icons.memory_rounded,
                        size: 14,
                        color: isDark ? const Color(0xFFFCD34D) : const Color(0xFFD97706),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${mod.capacityDisplay} ${mod.type} • ${mod.speedDisplay}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            '${mod.manufacturer != 'Not available' ? mod.manufacturer : 'Module'} (${mod.slot})',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
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
