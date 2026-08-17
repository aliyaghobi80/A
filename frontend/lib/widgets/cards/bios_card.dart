import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../models/system_info.dart';
import 'card_wrapper.dart';
import 'info_row.dart';

class BiosCard extends StatelessWidget {
  final BiosInfo bios;

  const BiosCard({super.key, required this.bios});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return CardWrapper(
      icon: Icons.settings_input_component_rounded,
      title: l10n.biosUefi,
      summarySubtitle: '${bios.manufacturer} • v${bios.version}',
      iconColor: const Color(0xFFEC4899),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoRow(
            label: l10n.manufacturerVendor,
            value: bios.manufacturer,
            icon: Icons.business_rounded,
          ),
          InfoRow(
            label: l10n.biosVersion,
            value: bios.version,
            icon: Icons.info_outline_rounded,
            copyable: true,
            isMonospace: true,
          ),
          InfoRow(
            label: l10n.releaseDate,
            value: bios.date,
            icon: Icons.calendar_today_rounded,
            forceLtrValue: true,
          ),
        ],
      ),
    );
  }
}
