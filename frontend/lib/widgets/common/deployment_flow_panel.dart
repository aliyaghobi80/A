import 'package:flutter/material.dart';
import '../../models/system_info.dart';
import '../../controllers/software_controller.dart';

class DeploymentFlowPanel extends StatefulWidget {
  final BatchInstallStatus batchStatus;
  final SoftwareController softwareCtrl;
  final bool isDark;
  final Color accentColor;

  const DeploymentFlowPanel({
    super.key,
    required this.batchStatus,
    required this.softwareCtrl,
    required this.isDark,
    required this.accentColor,
  });

  @override
  State<DeploymentFlowPanel> createState() => _DeploymentFlowPanelState();
}

class _DeploymentFlowPanelState extends State<DeploymentFlowPanel> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final batch = widget.batchStatus;
    final isDark = widget.isDark;
    final accent = widget.accentColor;
    final isRunning = batch.isRunning;
    final total = batch.total;
    final completed = batch.completed;
    final failed = batch.failed;
    final percent = batch.progressPercent;
    final currentItem = batch.currentItemName;

    final Color statusColor = isRunning
        ? accent
        : (failed == 0 ? const Color(0xFF10B981) : const Color(0xFFF59E0B));

    final stage1Completed = batch.isStageCompleted(1);
    final stage2Completed = batch.isStageCompleted(2);
    final stage3Completed = batch.isStageCompleted(3);

    final stage1Running = batch.isStageRunning(1);
    final stage2Running = batch.isStageRunning(2);
    final stage3Running = batch.isStageRunning(3);

    // Active item description (supports concurrent active items in 2X mode)
    final activeItems = isRunning
        ? batch.items.where((it) => it.status == 'installing').toList()
        : <BatchInstallItem>[];
    final activeItem = activeItems.isNotEmpty ? activeItems.first : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withValues(alpha: isDark ? 0.45 : 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: isDark ? 0.18 : 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Top Header Bar
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: isRunning
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: statusColor,
                          ),
                        )
                      : Icon(
                          failed == 0
                              ? Icons.check_circle_rounded
                              : Icons.info_outline_rounded,
                          color: statusColor,
                          size: 22,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            isRunning
                                ? 'استقرار خودکار سیستم طبق فلو استاندارد'
                                : (failed == 0
                                    ? 'استقرار خودکار و تنظیمات با موفقیت پایان یافت'
                                    : 'عملیات پایان یافت (نیازمند بررسی برخی موارد)'),
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? const Color(0xFFF1F5F9)
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${percent.toStringAsFixed(0)}٪',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isRunning
                            ? (activeItems.length >= 2
                                ? 'گام‌های جاری (۲ مورد هم‌زمان): ${activeItems.map((a) => a.friendlyDescription).join(' • ')}'
                                : (activeItem != null
                                    ? 'گام جاری: ${activeItem.friendlyDescription} (${activeItem.stageNameFa})'
                                    : (currentItem != null
                                        ? 'در حال پردازش: $currentItem'
                                        : 'در حال آماده‌سازی مراحل...')))
                            : (batch.summaryMessage.isNotEmpty
                                ? batch.summaryMessage
                                : 'تمام مراحل استقرار و تنظیمات به پایان رسید.'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (isRunning) ...[
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () =>
                        widget.softwareCtrl.cancelBatchInstallInteractive(context),
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 15,
                      color: Color(0xFFEF4444),
                    ),
                    label: const Text(
                      'لغو',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFFEF4444),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFEF4444), width: 1.1),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      minimumSize: const Size(0, 34),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Dual Active Items Slots (when 2 items run concurrently in 2X mode)
          if (isRunning && activeItems.length >= 2) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Row(
                children: [
                  for (int i = 0; i < activeItems.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        key: ValueKey('queue-item-${activeItems[i].id}'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: isDark ? 0.15 : 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: accent.withValues(alpha: isDark ? 0.4 : 0.25),
                          ),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: accent,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'خط ${i + 1}',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: accent,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                activeItems[i].friendlyDescription,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? const Color(0xFFE2E8F0)
                                      : const Color(0xFF1E293B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 6),
          ],

          // 2. Visual 3-Stage Stepper Flow
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF090E17) : const Color(0xFFF8FAFC),
              border: Border.symmetric(
                horizontal: BorderSide(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFE2E8F0),
                ),
              ),
            ),
            child: Row(
              children: [
                // Step 1: Prerequisites & Activation
                Expanded(
                  child: _buildStageStepItem(
                    stepNumber: 1,
                    title: '۱. پیش‌نیازها و فعال‌سازی',
                    subtitle: 'آفیس • KMS • آیکن‌ها',
                    isCompleted: stage1Completed,
                    isRunning: stage1Running,
                    isDark: isDark,
                    accent: accent,
                  ),
                ),
                _buildStageConnector(
                  isPassed: stage1Completed,
                  isDark: isDark,
                  accent: accent,
                ),
                // Step 2: Software Installation
                Expanded(
                  child: _buildStageStepItem(
                    stepNumber: 2,
                    title: '۲. نصب نرم‌افزارها',
                    subtitle: '${batch.stage2Items.length} برنامه انتخابی',
                    isCompleted: stage2Completed,
                    isRunning: stage2Running,
                    isDark: isDark,
                    accent: accent,
                  ),
                ),
                _buildStageConnector(
                  isPassed: stage2Completed,
                  isDark: isDark,
                  accent: accent,
                ),
                // Step 3: Device Optimization & Settings
                Expanded(
                  child: _buildStageStepItem(
                    stepNumber: 3,
                    title: '۳. تنظیمات و بهینه‌سازی',
                    subtitle: 'Sleep Never • ساعت • باتری',
                    isCompleted: stage3Completed,
                    isRunning: stage3Running,
                    isDark: isDark,
                    accent: accent,
                  ),
                ),
              ],
            ),
          ),

          // 3. Progress Bar & Counts Row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: total > 0 ? (percent / 100.0).clamp(0.0, 1.0) : null,
                    minHeight: 8,
                    backgroundColor: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$completed از $total مرحله تکمیل شد',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? const Color(0xFFCBD5E1)
                            : const Color(0xFF334155),
                      ),
                    ),
                    if (failed > 0)
                      Text(
                        '$failed مرحله ناموفق',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                    InkWell(
                      onTap: () => setState(() => _isExpanded = !_isExpanded),
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _isExpanded ? 'بستن جزئیات' : 'مشاهده جزئیات فلو',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: accent,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              _isExpanded
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              size: 16,
                              color: accent,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 4. Expandable Detailed Stage Items List
          if (_isExpanded && batch.items.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF090E17) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                ),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: batch.items.length,
                separatorBuilder: (context, index) => const Divider(height: 6),
                itemBuilder: (context, idx) {
                  final it = batch.items[idx];
                  return KeyedSubtree(
                    key: ValueKey('queue-item-${it.id}'),
                    child: _buildItemRow(it, isDark, accent),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStageStepItem({
    required int stepNumber,
    required String title,
    required String subtitle,
    required bool isCompleted,
    required bool isRunning,
    required bool isDark,
    required Color accent,
  }) {
    final Color itemColor = isCompleted
        ? const Color(0xFF10B981)
        : (isRunning ? accent : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)));

    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleted
                ? const Color(0xFF10B981)
                : (isRunning
                    ? accent.withValues(alpha: 0.2)
                    : (isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFE2E8F0))),
            border: Border.all(
              color: itemColor,
              width: 1.5,
            ),
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                : (isRunning
                    ? SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: accent,
                        ),
                      )
                    : Text(
                        '$stepNumber',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                        ),
                      )),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: isCompleted
                      ? (isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B))
                      : (isRunning ? accent : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8))),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? const Color(0xFF64748B)
                      : const Color(0xFF94A3B8),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStageConnector({
    required bool isPassed,
    required bool isDark,
    required Color accent,
  }) {
    return Container(
      width: 20,
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: isPassed
          ? const Color(0xFF10B981)
          : (isDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1)),
    );
  }

  Widget _buildItemRow(BatchInstallItem item, bool isDark, Color accent) {
    Color iconColor;
    IconData icon;
    String statusText;

    if (item.status == 'completed') {
      iconColor = const Color(0xFF10B981);
      icon = Icons.check_circle_rounded;
      statusText = 'انجام شد';
    } else if (item.status == 'installing') {
      iconColor = accent;
      icon = Icons.autorenew_rounded;
      statusText = 'در حال انجام...';
    } else if (item.status == 'failed') {
      iconColor = const Color(0xFFEF4444);
      icon = Icons.cancel_rounded;
      statusText = 'خطا';
    } else if (item.status == 'skipped') {
      iconColor = const Color(0xFF64748B);
      icon = Icons.skip_next_rounded;
      statusText = 'رد شده';
    } else {
      iconColor = isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8);
      icon = Icons.schedule_rounded;
      statusText = 'در صف انتظار';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          item.status == 'installing'
              ? SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: accent),
                )
              : Icon(icon, size: 15, color: iconColor),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              item.stageNameFa,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              item.friendlyDescription,
              style: TextStyle(
                fontSize: 12,
                fontWeight: item.status == 'installing'
                    ? FontWeight.w800
                    : FontWeight.w600,
                color: isDark
                    ? const Color(0xFFCBD5E1)
                    : const Color(0xFF334155),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: iconColor,
            ),
          ),
        ],
      ),
    );
  }
}


/// Fixed Sticky Bottom Cumulative Progress Bar for deployment pages.
///
/// Displayed at the bottom of Software and Driver installation pages.
/// Shows:
/// - Overall percentage ([progressPercent])
/// - Completed count vs total count (`تکمیل شده: X از Y`)
/// - Active elapsed time counter
/// - Concurrency mode indicator (`1X متوالی` / `2X موازی`)
/// - Stop / Cancel button (if active) and Resume button (if interrupted)
/// - Touch targets >= 44px
class FixedCumulativeProgressBar extends StatefulWidget {
  final bool isRunning;
  final double progressPercent;
  final int completed;
  final int total;
  final int failed;
  final int skipped;
  final int interrupted;
  final double? startTime;
  final double? elapsedSeconds;
  final bool doubleSpeed;
  final String? currentItemName;
  final List<String> activeItemNames;
  final VoidCallback? onCancel;
  final VoidCallback? onResume;
  final bool isDark;
  final Color accentColor;
  final String typeName; // 'نرم‌افزار' or 'درایور'

  const FixedCumulativeProgressBar({
    super.key,
    required this.isRunning,
    required this.progressPercent,
    required this.completed,
    required this.total,
    this.failed = 0,
    this.skipped = 0,
    this.interrupted = 0,
    this.startTime,
    this.elapsedSeconds,
    this.doubleSpeed = false,
    this.currentItemName,
    this.activeItemNames = const [],
    this.onCancel,
    this.onResume,
    required this.isDark,
    required this.accentColor,
    this.typeName = 'مورد',
  });

  @override
  State<FixedCumulativeProgressBar> createState() => _FixedCumulativeProgressBarState();
}

class _FixedCumulativeProgressBarState extends State<FixedCumulativeProgressBar> {
  // Timer for ticking elapsed seconds during active installation
  double _localElapsed = 0.0;

  @override
  void initState() {
    super.initState();
    _updateElapsed();
  }

  @override
  void didUpdateWidget(FixedCumulativeProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateElapsed();
  }

  void _updateElapsed() {
    if (widget.elapsedSeconds != null && widget.elapsedSeconds! > 0) {
      _localElapsed = widget.elapsedSeconds!;
    } else if (widget.startTime != null && widget.startTime! > 0) {
      final now = DateTime.now().millisecondsSinceEpoch / 1000.0;
      final diff = now - widget.startTime!;
      _localElapsed = diff > 0 ? diff : 0.0;
    }
  }

  String _formatElapsed(double seconds) {
    final s = seconds.round();
    final m = s ~/ 60;
    final rem = s % 60;
    if (m == 0) return '${rem}s';
    return '${m}m ${rem.toString().padLeft(2, '0')}s';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final accent = widget.accentColor;
    final isRunning = widget.isRunning;
    final total = widget.total;
    final completed = widget.completed;
    final failed = widget.failed;
    final percent = widget.progressPercent.clamp(0.0, 100.0);
    final doubleSpeed = widget.doubleSpeed;

    final Color statusColor = isRunning
        ? accent
        : (failed == 0 ? const Color(0xFF10B981) : const Color(0xFFF59E0B));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        key: const ValueKey('fixed-bottom-progress-bar'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          border: Border(
            top: BorderSide(
              color: statusColor.withValues(alpha: isDark ? 0.45 : 0.3),
              width: 1.5,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Percentage, Counts, Elapsed Timer, Concurrency Mode & Actions
            Row(
              children: [
                // Live status icon / spinner
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: isRunning
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: statusColor,
                            ),
                          )
                        : Icon(
                            failed == 0
                                ? Icons.check_circle_rounded
                                : Icons.info_outline_rounded,
                            color: statusColor,
                            size: 20,
                          ),
                  ),
                ),
                const SizedBox(width: 10),

                // Overall Percentage Chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      '${percent.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Item Counts: "تکمیل شده: X از Y"
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        'تکمیل شده: $completed از $total ${widget.typeName}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? const Color(0xFFF1F5F9)
                              : const Color(0xFF0F172A),
                        ),
                      ),
                      if (failed > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '$failed ناموفق',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFEF4444),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Active Elapsed Time Counter
                if (_localElapsed > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.timer_outlined, size: 14, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(
                            _formatElapsed(_localElapsed),
                            style: TextStyle(
                              fontSize: 11.5,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w700,
                              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                ],

                // Concurrency Mode Badge: 1X متوالی / 2X موازی
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (doubleSpeed ? const Color(0xFF0D9488) : const Color(0xFF0284C7))
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: (doubleSpeed ? const Color(0xFF0D9488) : const Color(0xFF0284C7))
                          .withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        doubleSpeed ? Icons.bolt_rounded : Icons.lock_clock_rounded,
                        size: 14,
                        color: doubleSpeed ? const Color(0xFF0D9488) : const Color(0xFF0284C7),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        doubleSpeed ? '۲X موازی' : '۱X متوالی',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: doubleSpeed ? const Color(0xFF0D9488) : const Color(0xFF0284C7),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // Action Button: Stop / Cancel (if running) or Resume
                if (isRunning && widget.onCancel != null)
                  ElevatedButton.icon(
                    onPressed: widget.onCancel,
                    icon: const Icon(Icons.stop_rounded, size: 16),
                    label: const Text('توقف عملیات'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  )
                else if (!isRunning && (failed > 0 || widget.interrupted > 0) && widget.onResume != null)
                  ElevatedButton.icon(
                    onPressed: widget.onResume,
                    icon: const Icon(Icons.play_arrow_rounded, size: 16),
                    label: const Text('ادامه صف نصب'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Middle: Cumulative Linear Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: total > 0 ? (percent / 100.0).clamp(0.0, 1.0) : null,
                minHeight: 6,
                backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            ),

            // Bottom Subtitle: Active items / current installation info
            if (isRunning) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.activeItemNames.length >= 2
                          ? 'در حال اجرای ۲ مورد هم‌زمان: ${widget.activeItemNames.join(' • ')}'
                          : (widget.currentItemName?.isNotEmpty == true
                              ? 'در حال نصب: ${widget.currentItemName}'
                              : 'در حال اجرای گام‌های استقرار سیستم...'),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
