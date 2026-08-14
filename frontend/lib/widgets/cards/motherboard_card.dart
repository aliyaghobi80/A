import 'package:flutter/material.dart';
import '../../models/system_info.dart';
import 'card_wrapper.dart';
import 'info_row.dart';

class MotherboardCard extends StatelessWidget {
  final MotherboardInfo motherboard;

  const MotherboardCard({super.key, required this.motherboard});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return CardWrapper(
      icon: Icons.developer_board_rounded,
      title: 'Motherboard',
      iconColor: const Color(0xFF10B981),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Model Highlight
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
            child: Text(
              motherboard.model,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                letterSpacing: -0.2,
              ),
            ),
          ),
          const SizedBox(height: 12),
          InfoRow(
            label: 'Manufacturer',
            value: motherboard.manufacturer,
            icon: Icons.domain_rounded,
          ),
          InfoRow(
            label: 'Model / Product',
            value: motherboard.model,
            icon: Icons.tag_rounded,
          ),
          InfoRow(
            label: 'Serial Number',
            value: motherboard.serial,
            icon: Icons.qr_code_rounded,
            copyable: true,
            isMonospace: true,
          ),
        ],
      ),
    );
  }
}
