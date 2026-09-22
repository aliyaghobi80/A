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

    // Active item description
    BatchInstallItem? activeItem;
    if (isRunning && batch.items.isNotEmpty) {
      for (final it in batch.items) {
        if (it.status == 'installing') {
          activeItem = it;
          break;
        }
      }
    }

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
                            ? (activeItem != null
                                ? 'گام جاری: ${activeItem.friendlyDescription} (${activeItem.stageNameFa})'
                                : (currentItem != null
                                    ? 'در حال پردازش: $currentItem'
                                    : 'در حال آماده‌سازی مراحل...'))
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
                  return _buildItemRow(it, isDark, accent);
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
