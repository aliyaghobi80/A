import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/activation_controller.dart';
import '../../controllers/system_info_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../models/system_info.dart';
import '../../theme/app_theme.dart';
import '../common/design_components.dart';

class LicenseStatusPage extends StatelessWidget {
  const LicenseStatusPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final systemCtrl = Get.find<SystemInfoController>();
    final activationCtrl = Get.put(ActivationController());
    final l10n = AppLocalizations.of(context);

    return Obx(() {
      final info = systemCtrl.systemInfo.value;
      final win = info?.windowsActivation ?? WindowsActivationInfo.empty();
      final off = info?.officeActivation ?? OfficeActivationInfo.empty();
      final isActivatingWin = activationCtrl.isActivatingWindows.value;
      final isActivatingOff = activationCtrl.isActivatingOffice.value;

      final isWinActive = win.activated;
      final isOffActive = off.activated;
      final hasOffice = off.installed;

      final isOemOriginal = win.channel.toUpperCase().contains('OEM') ||
          win.channel.toUpperCase().contains('RETAIL') ||
          win.statusText.contains('اورجینال') ||
          win.statusText.contains('دیجیتال') ||
          (win.statusText.toUpperCase().contains('LICENSED') && !win.channel.toUpperCase().contains('VOLUME'));

      final isAllReady = isWinActive && (!hasOffice || isOffActive);

      return LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 750;

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: isNarrow ? 12 : 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status Banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: (isAllReady ? AppTheme.statusSuccess : AppTheme.statusWarning)
                        .withValues(alpha: isDark ? 0.15 : 0.09),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (isAllReady ? AppTheme.statusSuccess : AppTheme.statusWarning)
                          .withValues(alpha: isDark ? 0.4 : 0.25),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isAllReady ? Icons.verified_user_rounded : Icons.gpp_maybe_rounded,
                        size: 26,
                        color: isAllReady ? AppTheme.statusSuccess : AppTheme.statusWarning,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isAllReady
                              ? (l10n.isPersian ? 'لایسنس‌های سیستم تأیید شدند و آماده تحویل است.' : 'System licenses valid.')
                              : (l10n.isPersian ? 'نیاز به اقدام: لایسنس ویندوز یا آفیس فعال نیست.' : 'Action required: Inactive license.'),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Windows Card
                Container(
                  padding: EdgeInsets.all(isNarrow ? 16 : 20),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder, width: 1.2),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: isNarrow ? 56 : 72,
                        height: isNarrow ? 56 : 72,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7).withValues(alpha: isDark ? 0.18 : 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.window_rounded, color: const Color(0xFF0284C7), size: isNarrow ? 34 : 44),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'لایسنس سیستم‌عامل ویندوز (Windows)',
                                    style: TextStyle(
                                      fontSize: isNarrow ? 16 : 17.5,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                                    ),
                                  ),
                                ),
                                StatusBadge(
                                  label: isWinActive ? 'فعال (Activated)' : 'غیرفعال',
                                  status: isWinActive ? BadgeStatus.success : BadgeStatus.danger,
                                  fontSize: 12.5,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              win.description.isNotEmpty ? win.description : (isWinActive ? 'ویندوز با موفقیت فعال است.' : 'نیاز به فعال‌سازی با اسکریپت یا لایسنس دیجیتال'),
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                              ),
                            ),
                            if (win.channel.isNotEmpty && win.channel != 'Unknown') ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  MetaTag(label: 'نوع کانال لایسنس', value: win.channel),
                                  if (win.partialKey.isNotEmpty && win.partialKey != '-')
                                    MetaTag(label: '۵ رقم آخر کلید', value: win.partialKey),
                                  if (isOemOriginal)
                                    const StatusBadge(label: 'لایسنس اصلی / دیجیتال OEM', status: BadgeStatus.info, showIcon: false, fontSize: 11),
                                ],
                              ),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (!isWinActive)
                                  ElevatedButton.icon(
                                    onPressed: isActivatingWin ? null : () => activationCtrl.activateWindows(context),
                                    icon: isActivatingWin
                                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                        : const Icon(Icons.bolt_rounded, size: 16),
                                    label: Text(isActivatingWin ? 'در حال فعال‌سازی...' : 'فعال‌سازی خودکار ویندوز'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0284C7),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      minimumSize: const Size(0, 36),
                                    ),
                                  )
                                else
                                  OutlinedButton.icon(
                                    onPressed: () => systemCtrl.fetchSystemInfo(forceRefresh: true),
                                    icon: const Icon(Icons.check_circle_outline_rounded, size: 16, color: AppTheme.statusSuccess),
                                    label: const Text('ویندوز فعال است'),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      minimumSize: const Size(0, 34),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Office Card
                Container(
                  padding: EdgeInsets.all(isNarrow ? 16 : 20),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder, width: 1.2),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: isNarrow ? 56 : 72,
                        height: isNarrow ? 56 : 72,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD97706).withValues(alpha: isDark ? 0.18 : 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.description_rounded, color: const Color(0xFFD97706), size: isNarrow ? 34 : 44),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'مایکروسافت آفیس (Microsoft Office)',
                                    style: TextStyle(
                                      fontSize: isNarrow ? 16 : 17.5,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                                    ),
                                  ),
                                ),
                                StatusBadge(
                                  label: !hasOffice
                                      ? 'نصب نشده'
                                      : (isOffActive ? 'فعال (Activated)' : 'غیرفعال'),
                                  status: !hasOffice
                                      ? BadgeStatus.neutral
                                      : (isOffActive ? BadgeStatus.success : BadgeStatus.danger),
                                  fontSize: 12.5,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              !hasOffice
                                  ? 'مجموعه آفیس روی این سیستم نصب نشده است.'
                                  : (off.product.isNotEmpty
                                      ? off.product
                                      : (isOffActive ? 'آفیس با موفقیت فعال است.' : 'نیاز به فعال‌سازی آفیس')),
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                              ),
                            ),
                            if (hasOffice && off.product.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  MetaTag(label: 'نسخه آفیس', value: off.product),
                                  if (off.version.isNotEmpty && off.version != 'Not available')
                                    MetaTag(label: 'شماره ساخت', value: off.version),
                                  if (off.partialKey.isNotEmpty && off.partialKey != 'Not available')
                                    MetaTag(label: '۵ رقم آخر کلید', value: off.partialKey),
                                ],
                              ),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (hasOffice && !isOffActive)
                                  ElevatedButton.icon(
                                    onPressed: isActivatingOff ? null : () => activationCtrl.activateOffice(context),
                                    icon: isActivatingOff
                                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                        : const Icon(Icons.bolt_rounded, size: 16),
                                    label: Text(isActivatingOff ? 'در حال فعال‌سازی...' : 'فعال‌سازی خودکار آفیس'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFD97706),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      minimumSize: const Size(0, 36),
                                    ),
                                  )
                                else if (hasOffice && isOffActive)
                                  OutlinedButton.icon(
                                    onPressed: () => systemCtrl.fetchSystemInfo(forceRefresh: true),
                                    icon: const Icon(Icons.check_circle_outline_rounded, size: 16, color: AppTheme.statusSuccess),
                                    label: const Text('آفیس فعال است'),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      minimumSize: const Size(0, 34),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          );
        },
      );
    });
  }
}
