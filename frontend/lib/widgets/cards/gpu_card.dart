import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/theme_language_controller.dart';
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
    final needsGraphicsDriver = gpus.any(
      (gpu) => gpu.isMicrosoftBasicDisplayAdapter,
    );
    final missingDriverCount = gpus
        .where((gpu) => gpu.isMicrosoftBasicDisplayAdapter)
        .length;

    final discreteNeedsDriver = gpus.any((g) => g.isDiscrete && g.isMicrosoftBasicDisplayAdapter);
    final integratedNeedsDriver = gpus.any((g) => g.isIntegrated && g.isMicrosoftBasicDisplayAdapter);

    String warningText;
    if (discreteNeedsDriver && integratedNeedsDriver) {
      warningText = 'درایورهای هر دو کارت گرافیک (سی‌پی‌یو و کارت مجزا) نصب نشده‌اند؛ لطفاً درایورها را نصب کنید.';
    } else if (discreteNeedsDriver) {
      warningText = 'درایور کارت گرافیک مجزا نصب نشده است؛ لطفاً درایور گرافیک را نصب کنید.';
    } else if (integratedNeedsDriver) {
      warningText = 'درایور پردازنده گرافیکی سی‌پی‌یو نصب نشده است؛ لطفاً درایور گرافیک داخلی را نصب کنید.';
    } else if (missingDriverCount > 1) {
      warningText = 'درایور اصلی $missingDriverCount پردازندهٔ گرافیکی نصب نیست؛ درایورهای گرافیک را نصب کنید.';
    } else {
      warningText = 'درایور اصلی کارت گرافیک نصب نیست؛ درایور گرافیک را نصب کنید.';
    }

    final summarySub = gpus.isNotEmpty
        ? gpus
            .map((g) => g.vramDisplay != 'Not available' && g.vramDisplay != 'Shared'
                ? '${g.name} (${g.vramDisplay})'
                : g.name)
            .join(' • ')
        : l10n.noGpuDetected;

    return CardWrapper(
      icon: Icons.videogame_asset_rounded,
      title: l10n.gpuGraphics,
      summarySubtitle: summarySub,
      illustration: const GpuIllustration(),
      iconColor: const Color(0xFF8B5CF6),
      trailing: needsGraphicsDriver
          ? const _GraphicsDriverWarningBadge()
          : gpus.length > 1
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
                  color: isDark
                      ? const Color(0xFFC4B5FD)
                      : const Color(0xFF7C3AED),
                ),
              ),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (needsGraphicsDriver) ...[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(
                  0xFFF59E0B,
                ).withValues(alpha: isDark ? 0.16 : 0.10),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.45),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFF59E0B),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      warningText,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      try {
                        Get.find<ThemeLanguageController>().setNavIndex(1);
                      } catch (_) {}
                    },
                    icon: const Icon(Icons.download_rounded, size: 14),
                    label: const Text(
                      'نصب درایور',
                      style: TextStyle(fontSize: 11),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD97706),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      minimumSize: const Size(0, 28),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
                      color: isDark
                          ? const Color(0xFF1E2C4A)
                          : const Color(0xFFF1F5F9),
                    ),
                    const SizedBox(height: 8),
                  ],
                  // GPU Name container
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2.5,
                              ),
                              margin: const EdgeInsets.only(left: 8),
                              decoration: BoxDecoration(
                                color: (gpu.isDiscrete
                                        ? const Color(0xFF8B5CF6)
                                        : const Color(0xFF0D9488))
                                    .withValues(alpha: isDark ? 0.22 : 0.12),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                gpu.typeLabelFa,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: gpu.isDiscrete
                                      ? (isDark
                                          ? const Color(0xFFC4B5FD)
                                          : const Color(0xFF7C3AED))
                                      : (isDark
                                          ? const Color(0xFF5EEAD4)
                                          : const Color(0xFF0F766E)),
                                ),
                              ),
                            ),
                            if (gpu.isMicrosoftBasicDisplayAdapter)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444).withValues(
                                    alpha: isDark ? 0.22 : 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'نیاز به نصب درایور',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFEF4444),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Directionality(
                                textDirection: TextDirection.ltr,
                                child: Text(
                                  gpu.name,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? const Color(0xFFF8FAFC)
                                        : const Color(0xFF0F172A),
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                            ),
                            if (gpu.vramDisplay != 'Not available')
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF8B5CF6,
                                  ).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Directionality(
                                  textDirection: TextDirection.ltr,
                                  child: Text(
                                    gpu.vramDisplay,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? const Color(0xFFDDD6FE)
                                          : const Color(0xFF6D28D9),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  InfoRow(
                    label: 'نوع کارت',
                    value: gpu.typeLabelFa,
                    icon: Icons.devices_rounded,
                  ),
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
                  InfoRow(
                    label: 'وضعیت درایور',
                    value: gpu.isMicrosoftBasicDisplayAdapter
                        ? 'نیاز به نصب درایور سازنده'
                        : 'نصب و شناسایی شده',
                    icon: gpu.isMicrosoftBasicDisplayAdapter
                        ? Icons.warning_amber_rounded
                        : Icons.verified_rounded,
                  ),
                ],
              );
            }),
        ],
      ),
    );
  }
}

class _GraphicsDriverWarningBadge extends StatelessWidget {
  const _GraphicsDriverWarningBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded, size: 15, color: Color(0xFFF59E0B)),
          SizedBox(width: 4),
          Text(
            'نصب درایور گرافیک',
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
