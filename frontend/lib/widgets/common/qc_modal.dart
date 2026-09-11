import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/qc_controller.dart';
import '../../controllers/theme_language_controller.dart';
import '../../models/qc_report.dart';
import '../../theme/app_theme.dart';
import '../common/design_components.dart';

class QuickQcModal extends StatelessWidget {
  const QuickQcModal({super.key});

  static void show(BuildContext context) {
    showDialog(context: context, builder: (ctx) => const QuickQcModal());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final qcCtrl = Get.find<QcController>();
    final themeCtrl = Get.find<ThemeLanguageController>();
    final accent = themeCtrl.currentAccentColor;

    return Dialog(
      backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 640,
        padding: const EdgeInsets.all(24),
        child: Obx(() {
          final isChecking = qcCtrl.isChecking.value;
          final report = qcCtrl.qcReport.value ?? QcReport.empty();
          final isPass = report.isReady;

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    isPass ? Icons.verified_rounded : Icons.gpp_maybe_rounded,
                    size: 28,
                    color: isPass
                        ? AppTheme.statusSuccess
                        : AppTheme.statusWarning,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'گزارش کنترل کیفیت فنی دستگاه (QC Report)',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? AppTheme.darkTextPrimary
                            : AppTheme.lightTextPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              Divider(
                height: 1,
                color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
              ),
              const SizedBox(height: 16),

              // Status Summary Banner
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color:
                      (isPass ? AppTheme.statusSuccess : AppTheme.statusWarning)
                          .withValues(alpha: isDark ? 0.18 : 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color:
                        (isPass
                                ? AppTheme.statusSuccess
                                : AppTheme.statusWarning)
                            .withValues(alpha: 0.4),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    StatusDot(
                      label: isPass
                          ? 'سیستم آماده تحویل است ✓'
                          : 'نیاز به بررسی و اقدام فنی ⚠',
                      status: isPass
                          ? BadgeStatus.success
                          : BadgeStatus.warning,
                      fontSize: 14,
                    ),
                    const Spacer(),
                    Text(
                      'تأیید بخش‌ها: ${report.passedCategoriesCount} از ${report.totalCategoriesCount}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isPass
                            ? AppTheme.statusSuccess
                            : AppTheme.statusWarning,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Checklist
              if (isChecking)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(28.0),
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                )
              else ...[
                Text(
                  'چک‌لیست بخش‌های مورد ارزیابی:',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? AppTheme.darkTextMuted
                        : AppTheme.lightTextMuted,
                  ),
                ),
                const SizedBox(height: 10),
                ...report.categories.map(
                  (cat) => _buildCheckItem(
                    cat.name,
                    cat.displayName,
                    cat.state == QcState.pass,
                    isDark,
                  ),
                ),
              ],

              const SizedBox(height: 18),

              // Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                    child: const Text('بستن پنجره'),
                  ),
                ],
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildCheckItem(
    String name,
    String displayName,
    bool isPass,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        children: [
          Icon(
            isPass ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
            size: 18,
            color: isPass ? AppTheme.statusSuccess : AppTheme.statusWarning,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              displayName.isNotEmpty ? displayName : name,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppTheme.darkTextPrimary
                    : AppTheme.lightTextPrimary,
              ),
            ),
          ),
          Text(
            isPass ? 'تأیید شده ✓' : 'اقدام لازم ⚠',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: isPass ? AppTheme.statusSuccess : AppTheme.statusWarning,
            ),
          ),
        ],
      ),
    );
  }
}
