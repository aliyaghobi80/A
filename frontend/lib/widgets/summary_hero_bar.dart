import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/system_info.dart';

class SummaryHeroBar extends StatelessWidget {
  final SystemInfo info;

  const SummaryHeroBar({super.key, required this.info});

  Widget _buildChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subLabel,
    required Color color,
    bool forceLtrLabel = true,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131D33) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF22304E) : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Directionality(
                    textDirection: forceLtrLabel ? TextDirection.ltr : Directionality.of(context),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final cpuShort = info.cpu.name
        .replaceAll('12th Gen ', '')
        .replaceAll('(R)', '')
        .replaceAll('(TM)', '')
        .trim();
    final gpuShort = info.gpu.isNotEmpty
        ? info.gpu.first.name.replaceAll('NVIDIA ', '').trim()
        : l10n.noGpuDetected;
    final gpuVram = info.gpu.isNotEmpty ? info.gpu.first.vramDisplay : l10n.notAvailable;

    return Row(
      children: [
        _buildChip(
          context,
          icon: Icons.memory_rounded,
          label: cpuShort,
          subLabel: l10n.coresThreads(info.cpu.cores, info.cpu.threads),
          color: const Color(0xFF3B82F6),
        ),
        const SizedBox(width: 12),
        _buildChip(
          context,
          icon: Icons.storage_rounded,
          label: info.ram.totalDisplay,
          subLabel: info.ram.moduleSummary != 'Not available'
              ? info.ram.moduleSummary
              : l10n.modulesCount(info.ram.moduleCount),
          color: const Color(0xFFF59E0B),
        ),
        const SizedBox(width: 12),
        _buildChip(
          context,
          icon: Icons.videogame_asset_rounded,
          label: gpuShort,
          subLabel: gpuVram != 'Not available' ? gpuVram : l10n.dedicatedGraphics,
          color: const Color(0xFF8B5CF6),
        ),
        const SizedBox(width: 12),
        _buildChip(
          context,
          icon: Icons.album_rounded,
          label: l10n.drivesCount(info.storage.length),
          subLabel: info.storage.isNotEmpty ? info.storage.first.type : l10n.storage,
          color: const Color(0xFF06B6D4),
          forceLtrLabel: false,
        ),
        const SizedBox(width: 12),
        _buildChip(
          context,
          icon: Icons.laptop_windows_rounded,
          label: info.windows.edition,
          subLabel: info.windows.version != 'Not available'
              ? '${info.windows.version} (${info.windows.architecture})'
              : info.windows.architecture,
          color: const Color(0xFF0284C7),
        ),
      ],
    );
  }
}
