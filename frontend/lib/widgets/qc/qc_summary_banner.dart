// frontend/lib/widgets/qc/qc_summary_banner.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/qc_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../models/qc_report.dart';
import 'prepare_system_dialog.dart';

class QcSummaryBanner extends StatelessWidget {
  const QcSummaryBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final qcCtrl = Get.find<QcController>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return Obx(() {
      final report = qcCtrl.qcReport.value;
      if (report == null) {
        return const SizedBox.shrink();
      }

      final isReady = report.isReady;
      final accentColor = isReady
          ? const Color(0xFF10B981)
          : const Color(0xFFD97706);
      final hasProblems = report.hasProblems;
      final problems = report.problems;
      final preparableIssues = problems.where((p) => p.canAutoPrepare).toList();

      return Container(
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131D33) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isReady
                ? const Color(
                    0xFF10B981,
                  ).withValues(alpha: isDark ? 0.35 : 0.25)
                : const Color(
                    0xFFF59E0B,
                  ).withValues(alpha: isDark ? 0.45 : 0.35),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color:
                  (isReady ? const Color(0xFF10B981) : const Color(0xFFF59E0B))
                      .withValues(alpha: isDark ? 0.12 : 0.08),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Status Hero Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.3),
                      width: 1.2,
                    ),
                  ),
                  child: Icon(
                    isReady
                        ? Icons.verified_rounded
                        : Icons.warning_amber_rounded,
                    color: accentColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            isReady ? l10n.systemReady : l10n.needsAttention,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: isReady
                                  ? const Color(0xFF10B981)
                                  : (isDark
                                        ? const Color(0xFFFBBF24)
                                        : const Color(0xFFD97706)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              l10n.qcPassedCategoriesCount(
                                report.passedCategoriesCount,
                                report.totalCategoriesCount,
                              ),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: accentColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isReady
                            ? (l10n.isPersian
                                  ? 'تمامی بخش‌های سخت‌افزار، سیستم‌عامل، درایورها و لایسنس‌ها با موفقیت تأیید شدند.'
                                  : 'All hardware, OS, drivers, and required licenses are verified and ready.')
                            : l10n.qcProblemsFound(report.problemsCount),
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? const Color(0xFFCBD5E1)
                              : const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),
                // Action Buttons
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    if (!isReady && preparableIssues.isNotEmpty)
                      ElevatedButton.icon(
                        onPressed: () =>
                            PrepareSystemDialog.show(context, problems),
                        icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        label: Text(
                          l10n.prepareSystem,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    OutlinedButton.icon(
                      onPressed: () => qcCtrl.runFullCheck(context),
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark
                            ? const Color(0xFFF1F5F9)
                            : const Color(0xFF0F172A),
                        side: BorderSide(
                          color: isDark
                              ? const Color(0xFF2E3D60)
                              : const Color(0xFFCBD5E1),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      label: Text(
                        l10n.runCheckAgain,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Problem Items List (if any problems)
            if (hasProblems) ...[
              const SizedBox(height: 18),
              Divider(
                color: isDark
                    ? const Color(0xFF1E2C4A)
                    : const Color(0xFFE2E8F0),
                height: 1,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(
                    Icons.assignment_late_outlined,
                    size: 16,
                    color: isDark
                        ? const Color(0xFFFBBF24)
                        : const Color(0xFFD97706),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.problems,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: isDark
                          ? const Color(0xFFF8FAFC)
                          : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isMultiCol = constraints.maxWidth > 700;
                  final problemCards = problems
                      .map(
                        (prob) => _buildProblemCard(
                          context,
                          prob,
                          isDark,
                          l10n,
                          qcCtrl,
                        ),
                      )
                      .toList();

                  if (isMultiCol) {
                    return Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      children: problemCards
                          .map(
                            (w) => SizedBox(
                              width: (constraints.maxWidth - 12) / 2,
                              child: w,
                            ),
                          )
                          .toList(),
                    );
                  } else {
                    return Column(
                      children: problemCards
                          .map(
                            (w) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: w,
                            ),
                          )
                          .toList(),
                    );
                  }
                },
              ),
            ],
          ],
        ),
      );
    });
  }

  Widget _buildProblemCard(
    BuildContext context,
    QcIssue prob,
    bool isDark,
    AppLocalizations l10n,
    QcController qcCtrl,
  ) {
    final isFail = prob.severity == QcState.fail;
    final sevColor = isFail ? const Color(0xFFEF4444) : const Color(0xFFF59E0B);

    IconData actionIcon;
    Color actionBtnColor;

    if (prob.actionType == 'install_software') {
      actionIcon = Icons.download_rounded;
      actionBtnColor = const Color(0xFF2563EB);
    } else if (prob.actionType.startsWith('activate')) {
      actionIcon = Icons.verified_user_rounded;
      actionBtnColor = const Color(0xFFD97706);
    } else if (prob.actionType == 'open_folder') {
      actionIcon = Icons.folder_open_rounded;
      actionBtnColor = const Color(0xFF0EA5E9);
    } else {
      actionIcon = Icons.info_outline_rounded;
      actionBtnColor = const Color(0xFF64748B);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0B132B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: sevColor.withValues(alpha: isDark ? 0.35 : 0.25),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: sevColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isFail ? Icons.cancel_rounded : Icons.warning_amber_rounded,
              color: sevColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        prob.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? const Color(0xFFF8FAFC)
                              : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: sevColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        prob.isRequired
                            ? (l10n.isPersian ? 'ضروری' : 'Required')
                            : (l10n.isPersian ? 'اختیاری' : 'Optional'),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: sevColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  prob.description,
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
          const SizedBox(width: 10),
          if (prob.actionType != 'none')
            ElevatedButton.icon(
              onPressed: () => qcCtrl.executeSingleAction(context, prob),
              icon: Icon(actionIcon, size: 14),
              style: ElevatedButton.styleFrom(
                backgroundColor: actionBtnColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              label: Text(
                prob.actionLabel,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
