import 'package:flutter/material.dart';
import '../../models/system_info.dart';
import 'card_wrapper.dart';
import 'info_row.dart';

class BiosCard extends StatelessWidget {
  final BiosInfo bios;

  const BiosCard({super.key, required this.bios});

  @override
  Widget build(BuildContext context) {
    return CardWrapper(
      icon: Icons.settings_input_component_rounded,
      title: 'BIOS / UEFI',
      iconColor: const Color(0xFFEC4899),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoRow(
            label: 'Manufacturer / Vendor',
            value: bios.manufacturer,
            icon: Icons.business_rounded,
          ),
          InfoRow(
            label: 'BIOS Version',
            value: bios.version,
            icon: Icons.info_outline_rounded,
            copyable: true,
            isMonospace: true,
          ),
          InfoRow(
            label: 'Release Date',
            value: bios.date,
            icon: Icons.calendar_today_rounded,
          ),
        ],
      ),
    );
  }
}
