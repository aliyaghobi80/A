import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/activation_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../models/system_info.dart';
import 'card_wrapper.dart';
import 'info_row.dart';

class WindowsCard extends StatelessWidget {
  final WindowsInfo windows;
  final SystemMetaInfo system;
  final WindowsActivationInfo? activation;

  const WindowsCard({
    super.key,
    required this.windows,
    required this.system,
    this.activation,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final activationCtrl = Get.find<ActivationController>();

    final act = activation ?? WindowsActivationInfo.empty();
    final isActivated = act.activated;
    final statusColor = isActivated ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    final statusLabel = isActivated ? l10n.activated : l10n.notActivated;

    return CardWrapper(
      icon: Icons.window_rounded,
      title: l10n.windowsInformation,
      iconColor: const Color(0xFF0284C7),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: statusColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActivated ? Icons.check_circle_rounded : Icons.cancel_rounded,
              size: 13,
              color: statusColor,
            ),
            const SizedBox(width: 4),
            Text(
              statusLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: statusColor,
              ),
            ),
          ],
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
                  child: Directionality(
                    textDirection: TextDirection.ltr,
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
                ),
                if (windows.version != 'Not available')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        windows.version,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFF7DD3FC) : const Color(0xFF0369A1),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          InfoRow(
            label: l10n.osEdition,
            value: windows.edition,
            icon: Icons.laptop_windows_rounded,
            forceLtrValue: true,
          ),
          InfoRow(
            label: l10n.version,
            value: windows.version,
            icon: Icons.flag_circle_rounded,
            forceLtrValue: true,
          ),
          InfoRow(
            label: l10n.buildNumber,
            value: windows.build,
            icon: Icons.numbers_rounded,
            isMonospace: true,
            copyable: true,
          ),
          InfoRow(
            label: l10n.architecture,
            value: windows.architecture,
            icon: Icons.architecture_rounded,
            forceLtrValue: true,
          ),
          InfoRow(
            label: l10n.licenseChannel,
            value: act.channel,
            icon: Icons.tune_rounded,
            forceLtrValue: true,
          ),
          if (act.partialKey != 'Not available')
            InfoRow(
              label: l10n.partialProductKey,
              value: '••••• ••••• ••••• ••••• ${act.partialKey}',
              icon: Icons.key_rounded,
              isMonospace: true,
              copyable: true,
            ),
          InfoRow(
            label: l10n.licenseExpiration,
            value: act.expiration ?? (isActivated ? l10n.permanentLicense : l10n.notAvailable),
            icon: Icons.event_available_rounded,
            forceLtrValue: true,
          ),
          InfoRow(
            label: l10n.activationTool,
            value: act.toolAvailable ? l10n.toolAvailable : l10n.toolNotFound,
            icon: Icons.build_circle_rounded,
          ),
          InfoRow(
            label: l10n.computerName,
            value: system.computerName,
            icon: Icons.computer_rounded,
            copyable: true,
            forceLtrValue: true,
          ),
          if (system.model != 'Not available')
            InfoRow(
              label: l10n.systemModel,
              value: system.model,
              icon: Icons.devices_rounded,
              forceLtrValue: true,
            ),
          if (system.manufacturer != 'Not available')
            InfoRow(
              label: l10n.manufacturer,
              value: system.manufacturer,
              icon: Icons.business_rounded,
            ),

          // Activation Action Button (Only if not activated & tool is available)
          if (!isActivated && act.toolAvailable) ...[
            const SizedBox(height: 12),
            Obx(() {
              final isRunning = activationCtrl.isActivatingWindows.value;
              return SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isRunning ? null : () => activationCtrl.activateWindows(context),
                  icon: isRunning
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.verified_user_rounded, size: 16),
                  label: Text(
                    isRunning ? l10n.activatingWindows : l10n.activateWindows,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
