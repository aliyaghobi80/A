// frontend/lib/widgets/dialogs/qc_results_dialog.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/qc_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../models/qc_report.dart';

class QcResultsDialog extends StatelessWidget {
  final QcReport report;

  const QcResultsDialog({super.key, required this.report});

  static void show(BuildContext context, QcReport report) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => QcResultsDialog(report: report),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final qcCtrl = Get.find<QcController>();

    final isReady = report.isReady;
    final problems = report.problems;
    final hasProblems = problems.isNotEmpty;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 720,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Modal Header
            _buildHeader(context, isDark, l10n, isReady),

            // 2. Scrollable Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // System Status Summary Card
                    _buildSummaryCard(context, isDark, l10n, isReady),
                    const SizedBox(height: 16),

                    // Problems and Actionable Solutions List
                    if (hasProblems) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.build_circle_outlined,
                            size: 18,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF475569),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.isPersian
                                ? 'موارد نیازمند توجه و راهکارهای حل پیشنهادی (${problems.length} مورد):'
                                : 'Issues & Recommended Solutions (${problems.length} items):',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? const Color(0xFFE2E8F0)
                                  : const Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...problems.map(
                        (prob) => _buildProblemSolutionCard(
                          context,
                          prob,
                          isDark,
                          l10n,
                          qcCtrl,
                        ),
                      ),
                    ] else ...[
                      _buildAllClearCard(context, isDark, l10n),
                    ],
                  ],
                ),
              ),
            ),

            // 3. Modal Footer
            _buildFooter(context, isDark, l10n, qcCtrl, hasProblems),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    bool isDark,
    AppLocalizations l10n,
    bool isReady,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isReady
                  ? const Color(0xFF10B981).withValues(alpha: 0.15)
                  : const Color(0xFFF59E0B).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isReady
                  ? Icons.verified_user_rounded
                  : Icons.health_and_safety_rounded,
              color: isReady
                  ? const Color(0xFF10B981)
                  : const Color(0xFFF59E0B),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.isPersian
                      ? 'گزارش ارزیابی و بررسی کامل سیستم (QC)'
                      : 'System QC Evaluation Report',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? const Color(0xFFF8FAFC)
                        : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.isPersian
                      ? 'پایش سخت‌افزار، ویندوز، درایورها، فعال‌سازی و نرم‌افزارها'
                      : 'Hardware, OS, Drivers, Licenses & Apps audit',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, size: 20),
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    bool isDark,
    AppLocalizations l10n,
    bool isReady,
  ) {
    final passedCats = report.passedCategoriesCount;
    final totalCats = report.totalCategoriesCount;
    final problemsCount = report.problemsCount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isReady
            ? const Color(0xFF10B981).withValues(alpha: isDark ? 0.15 : 0.08)
            : const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isReady
              ? const Color(0xFF10B981).withValues(alpha: 0.4)
              : const Color(0xFFF59E0B).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isReady
                  ? const Color(0xFF10B981)
                  : const Color(0xFFF59E0B),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              isReady
                  ? (l10n.isPersian ? 'آماده تحویل' : 'READY')
                  : (l10n.isPersian ? 'نیازمند بررسی' : 'NEEDS ATTENTION'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isReady
                      ? (l10n.isPersian
                            ? 'تمامی $totalCats بخش سیستم تایید شدند و سیستم آماده تحویل به مشتری است.'
                            : 'All $totalCats check categories passed. System is fully verified.')
                      : (l10n.isPersian
                            ? 'تعداد $problemsCount مورد برای تکمیل آماده‌سازی سیستم یافت شد.'
                            : '$problemsCount item(s) need resolution before handoff.'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? const Color(0xFFF8FAFC)
                        : const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.isPersian
                      ? '$passedCats از $totalCats بخش سیستم بدون هیچ‌گونه نقصی تایید شده‌اند.'
                      : '$passedCats of $totalCats domains passed successfully.',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProblemSolutionCard(
    BuildContext context,
    QcIssue prob,
    bool isDark,
    AppLocalizations l10n,
    QcController qcCtrl,
  ) {
    final isFail = prob.severity == QcState.fail;
    final sevColor = isFail ? const Color(0xFFEF4444) : const Color(0xFFF59E0B);
    final sevText = isFail
        ? (l10n.isPersian ? 'بحرانی' : 'FAIL')
        : (l10n.isPersian ? 'هشدار' : 'WARNING');

    final hasSolution =
        prob.solutionTitle.isNotEmpty || prob.solutionSteps.isNotEmpty;
    final hasAction = prob.actionType.isNotEmpty && prob.actionType != 'none';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Category, Name, Severity Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: sevColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  sevText,
                  style: TextStyle(
                    color: sevColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  prob.categoryName.isNotEmpty
                      ? prob.categoryName
                      : prob.category,
                  style: TextStyle(
                    color: isDark
                        ? const Color(0xFFCBD5E1)
                        : const Color(0xFF475569),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  prob.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? const Color(0xFFF8FAFC)
                        : const Color(0xFF0F172A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Problem Description
          Text(
            prob.description,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
              height: 1.4,
            ),
          ),

          // Solution Box
          if (hasSolution) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(
                  0xFF2563EB,
                ).withValues(alpha: isDark ? 0.15 : 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(
                    0xFF2563EB,
                  ).withValues(alpha: isDark ? 0.4 : 0.2),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.lightbulb_outline_rounded,
                    color: Color(0xFF2563EB),
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (prob.solutionTitle.isNotEmpty)
                          Text(
                            '${l10n.isPersian ? "راهکار پیشنهادی: " : "Recommended Fix: "}${prob.solutionTitle}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        if (prob.solutionSteps.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            prob.solutionSteps,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? const Color(0xFFCBD5E1)
                                  : const Color(0xFF334155),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Action Button
          if (hasAction) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: _buildActionButton(context, prob, isDark, l10n, qcCtrl),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    QcIssue prob,
    bool isDark,
    AppLocalizations l10n,
    QcController qcCtrl,
  ) {
    final actionType = prob.actionType;
    final label = prob.actionLabel.isNotEmpty
        ? prob.actionLabel
        : (l10n.isPersian ? 'اقدام فوری' : 'Fix Now');

    Color btnColor = const Color(0xFF2563EB);
    IconData btnIcon = Icons.bolt_rounded;

    if (actionType == 'activate_windows' || actionType == 'activate_office') {
      btnColor = const Color(0xFF10B981);
      btnIcon = Icons.key_rounded;
    } else if (actionType == 'disable_proxy') {
      btnColor = const Color(0xFF0D9488);
      btnIcon = Icons.link_off_rounded;
    } else if (actionType == 'install_software') {
      btnColor = const Color(0xFF2563EB);
      btnIcon = Icons.download_rounded;
    } else if (actionType == 'install_drivers') {
      btnColor = const Color(0xFF0D9488);
      btnIcon = Icons.settings_input_component_rounded;
    } else if (actionType == 'open_folder') {
      btnColor = const Color(0xFF64748B);
      btnIcon = Icons.folder_open_rounded;
    }

    return ElevatedButton.icon(
      onPressed: () async {
        Navigator.of(context).pop();
        await qcCtrl.executeSingleAction(context, prob);
      },
      icon: Icon(btnIcon, size: 16),
      label: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: btnColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 1,
      ),
    );
  }

  Widget _buildAllClearCard(
    BuildContext context,
    bool isDark,
    AppLocalizations l10n,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF10B981),
              size: 48,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.isPersian
                ? 'سیستم ۱۰۰٪ بدون نقص و آماده است!'
                : 'System is 100% Ready & Verified!',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.isPersian
                ? 'تمامی سخت‌افزارها، درایورها، فعال‌سازی ویندوز و آفیس، و نرم‌افزارهای موردنیاز بررسی شده و بدون اشکال هستند.'
                : 'All hardware, drivers, activations, and software requirements have been validated successfully.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(
    BuildContext context,
    bool isDark,
    AppLocalizations l10n,
    QcController qcCtrl,
    bool hasProblems,
  ) {
    final autoFixable = report.problems.where((p) => p.canAutoPrepare).toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (hasProblems && autoFixable.isNotEmpty)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                qcCtrl.executeBatchPreparation(context, autoFixable);
              },
              icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
              label: Text(
                l10n.isPersian
                    ? 'اصلاح خودکار تمام موارد قابل حل (${autoFixable.length})'
                    : 'Auto-Fix All Resolvable (${autoFixable.length})',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            )
          else
            const SizedBox.shrink(),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(l10n.isPersian ? 'بستن' : 'Close'),
          ),
        ],
      ),
    );
  }
}
