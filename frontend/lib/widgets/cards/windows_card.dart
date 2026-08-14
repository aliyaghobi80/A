import 'package:flutter/material.dart';
import '../../models/system_info.dart';
import 'card_wrapper.dart';
import 'info_row.dart';

class WindowsCard extends StatelessWidget {
  final WindowsInfo windows;
  final SystemMetaInfo system;

  const WindowsCard({
    super.key,
    required this.windows,
    required this.system,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return CardWrapper(
      icon: Icons.window_rounded,
      title: 'Windows Information',
      iconColor: const Color(0xFF0284C7),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF0284C7).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          windows.architecture,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFF7DD3FC) : const Color(0xFF0369A1),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Edition banner
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
                    windows.edition,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                if (windows.version != 'Not available')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      windows.version,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFF7DD3FC) : const Color(0xFF0369A1),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          InfoRow(
            label: 'OS Edition',
            value: windows.edition,
            icon: Icons.laptop_windows_rounded,
          ),
          InfoRow(
            label: 'Version',
            value: windows.version,
            icon: Icons.flag_circle_rounded,
          ),
          InfoRow(
            label: 'Build Number',
            value: windows.build,
            icon: Icons.numbers_rounded,
            isMonospace: true,
            copyable: true,
          ),
          InfoRow(
            label: 'Architecture',
            value: windows.architecture,
            icon: Icons.architecture_rounded,
          ),
          InfoRow(
            label: 'Computer Name',
            value: system.computerName,
            icon: Icons.computer_rounded,
            copyable: true,
          ),
          if (system.model != 'Not available')
            InfoRow(
              label: 'System Model',
              value: system.model,
              icon: Icons.devices_rounded,
            ),
          if (system.manufacturer != 'Not available')
            InfoRow(
              label: 'Manufacturer',
              value: system.manufacturer,
              icon: Icons.business_rounded,
            ),
        ],
      ),
    );
  }
}
