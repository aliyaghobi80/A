import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../models/system_info.dart';
import '../common/hardware_illustrations.dart';
import 'card_wrapper.dart';
import 'info_row.dart';

class GpuCard extends StatelessWidget {
  final List<GpuInfo> gpus;

  const GpuCard({super.key, required this.gpus});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    final summarySub = gpus.isNotEmpty
        ? (gpus.first.vramDisplay != 'Not available' ? '${gpus.first.name} (${gpus.first.vramDisplay})' : gpus.first.name)
        : l10n.noGpuDetected;

    return CardWrapper(
      icon: Icons.videogame_asset_rounded,
      title: l10n.gpuGraphics,
      summarySubtitle: summarySub,
      illustration: const GpuIllustration(),
      iconColor: const Color(0xFF8B5CF6),
      trailing: gpus.length > 1
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                l10n.gpusDetected(gpus.length),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFFC4B5FD) : const Color(0xFF7C3AED),
                ),
              ),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (gpus.isEmpty)
            Text(l10n.noGpuDetected)
          else
            ...gpus.asMap().entries.map((entry) {
              final idx = entry.key;
              final gpu = entry.value;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (idx > 0) ...[
                    const SizedBox(height: 12),
                    Divider(
                      color: isDark ? const Color(0xFF1E2C4A) : const Color(0xFFF1F5F9),
                    ),
                    const SizedBox(height: 8),
                  ],
                  // GPU Name container
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
                          child: Directionality(
                            textDirection: TextDirection.ltr,
                            child: Text(
                              gpu.name,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                        ),
                        if (gpu.vramDisplay != 'Not available')
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Directionality(
                              textDirection: TextDirection.ltr,
                              child: Text(
                                gpu.vramDisplay,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? const Color(0xFFDDD6FE) : const Color(0xFF6D28D9),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  InfoRow(
                    label: l10n.manufacturer,
                    value: gpu.manufacturer,
                    icon: Icons.business_rounded,
                  ),
                  InfoRow(
                    label: l10n.dedicatedVram,
                    value: gpu.vramDisplay,
                    icon: Icons.sd_storage_rounded,
                    forceLtrValue: true,
                  ),
                  InfoRow(
                    label: l10n.driverVersion,
                    value: gpu.driverVersion,
                    icon: Icons.settings_system_daydream_rounded,
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
