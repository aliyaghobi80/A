import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/activation_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../models/system_info.dart';
import 'card_wrapper.dart';
import 'info_row.dart';

class OfficeCard extends StatelessWidget {
  final OfficeActivationInfo office;

  const OfficeCard({
    super.key,
    required this.office,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final activationCtrl = Get.find<ActivationController>();

    final isInstalled = office.installed;
    final isActivated = office.activated;

    final statusColor = !isInstalled
        ? const Color(0xFF64748B)
        : (isActivated ? const Color(0xFF10B981) : const Color(0xFFEF4444));

    final statusLabel = !isInstalled
        ? l10n.notInstalled
        : (isActivated ? l10n.activated : l10n.notActivated);

    return CardWrapper(
      icon: Icons.business_center_rounded,
      title: l10n.microsoftOffice,
      iconColor: const Color(0xFFD97706),
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
              isActivated ? Icons.check_circle_rounded : (!isInstalled ? Icons.remove_circle_outline_rounded : Icons.cancel_rounded),
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
          // Product Banner
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
                      isInstalled ? office.product : l10n.notInstalled,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ),
                if (isInstalled && office.version != 'Not available')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        office.version,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          if (!isInstalled)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: Text(
                  'مایکروسافت آفیس روی این سیستم نصب نشده است.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ),
            )
          else ...[
            InfoRow(
              label: l10n.officeProduct,
              value: office.product,
              icon: Icons.apps_rounded,
              forceLtrValue: true,
            ),
            InfoRow(
              label: l10n.version,
              value: office.version,
              icon: Icons.flag_circle_rounded,
              forceLtrValue: true,
            ),
            InfoRow(
              label: l10n.officeArchitecture,
              value: office.architecture,
              icon: Icons.architecture_rounded,
              forceLtrValue: true,
            ),
            InfoRow(
              label: l10n.officeInstallType,
              value: office.installType,
              icon: Icons.folder_zip_rounded,
              forceLtrValue: true,
            ),
            InfoRow(
              label: l10n.licenseChannel,
              value: office.channel,
              icon: Icons.tune_rounded,
              forceLtrValue: true,
            ),
            if (office.partialKey != 'Not available')
              InfoRow(
                label: l10n.partialProductKey,
                value: '••••• ••••• ••••• ••••• ${office.partialKey}',
                icon: Icons.key_rounded,
                isMonospace: true,
                copyable: true,
              ),
            InfoRow(
              label: l10n.licenseExpiration,
              value: office.expiration ?? (isActivated ? l10n.permanentLicense : l10n.notAvailable),
              icon: Icons.event_available_rounded,
              forceLtrValue: true,
            ),
            InfoRow(
              label: l10n.activationTool,
              value: office.toolAvailable ? l10n.toolAvailable : l10n.toolNotFound,
              icon: Icons.build_circle_rounded,
            ),
            if (!office.toolAvailable) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => activationCtrl.changeToolsDirectory(context),
                  icon: const Icon(Icons.folder_open_rounded, size: 14),
                  label: Text(
                    l10n.isPersian ? 'انتخاب پوشه فعال‌سازها (KMS)' : 'Select KMS Tools Folder',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFD97706),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ],

            // Activation Action Section (Only if not activated & tool is available)
            if (!isActivated && office.toolAvailable) ...[
              const SizedBox(height: 12),
              Obx(() {
                final isRunning = activationCtrl.isActivatingOffice.value;
                return SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isRunning ? null : () => activationCtrl.activateOffice(context),
                    icon: isRunning
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.verified_user_rounded, size: 16),
                    label: Text(
                      isRunning ? l10n.activatingOffice : l10n.activateOffice,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD97706),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                );
              }),
            ],
          ],
        ],
      ),
    );
  }
}
