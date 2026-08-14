import 'package:flutter/material.dart';
import '../../models/system_info.dart';
import 'card_wrapper.dart';
import 'info_row.dart';

class CpuCard extends StatelessWidget {
  final CpuInfo cpu;

  const CpuCard({super.key, required this.cpu});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return CardWrapper(
      icon: Icons.memory_rounded,
      title: 'CPU',
      iconColor: const Color(0xFF3B82F6),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: (isDark ? const Color(0xFF3B82F6) : const Color(0xFF2563EB)).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          cpu.coresThreadsDisplay,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Prominent CPU Model Name
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    cpu.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          InfoRow(
            label: 'Manufacturer',
            value: cpu.manufacturer,
            icon: Icons.business_rounded,
          ),
          InfoRow(
            label: 'Physical Cores',
            value: cpu.cores.toString(),
            icon: Icons.grid_view_rounded,
          ),
          InfoRow(
            label: 'Logical Threads',
            value: cpu.threads.toString(),
            icon: Icons.timeline_rounded,
          ),
          InfoRow(
            label: 'Max Clock Speed',
            value: cpu.maxClockDisplay,
            icon: Icons.speed_rounded,
          ),
        ],
      ),
    );
  }
}
