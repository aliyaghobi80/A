import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../l10n/app_localizations.dart';
import '../../models/system_info.dart';
import '../common/hardware_illustrations.dart';
import 'card_wrapper.dart';

class DriverCard extends StatefulWidget {
  final List<DriverItem> drivers;
  final DriverSummary summary;
  final RebootInfo? reboot;
  final VoidCallback? onRestart;
  final VoidCallback? onAutoInstallDrivers;
  final bool isBatchInstalling;
  final DriverBatchStatus? batchStatus;
  final VoidCallback? onCancelBatch;

  const DriverCard({
    super.key,
    required this.drivers,
    required this.summary,
    this.reboot,
    this.onRestart,
    this.onAutoInstallDrivers,
    this.isBatchInstalling = false,
    this.batchStatus,
    this.onCancelBatch,
  });

  @override
  State<DriverCard> createState() => _DriverCardState();
}

class _DriverCardState extends State<DriverCard> {
  String _selectedCategory = 'all';

  void _copyToClipboard(BuildContext context, String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF10B981),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    final summary = widget.summary;
    final drivers = widget.drivers;
    final recs = summary.recommendations;

    final isAllHealthy = summary.allHealthy && summary.problemCount == 0;
    final badgeColor = isAllHealthy ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    // Filter drivers based on selected tab
    final filteredDrivers = drivers.where((drv) {
      if (_selectedCategory == 'all') return true;
      if (_selectedCategory == 'problem') return !drv.isHealthy;
      if (_selectedCategory == 'display') return drv.category == 'Display';
      if (_selectedCategory == 'network') return drv.category == 'Wi-Fi' || drv.category == 'Ethernet' || drv.category == 'Bluetooth';
      if (_selectedCategory == 'audio') return drv.category == 'Audio';
      if (_selectedCategory == 'chipset') return drv.category == 'Chipset & System' || drv.category == 'Storage Controller';
      return true;
    }).toList();

    return CardWrapper(
      icon: Icons.developer_board_rounded,
      title: l10n.isPersian ? 'بررسی جامع درایورهای سخت‌افزاری' : 'Hardware Drivers Inspection',
      summarySubtitle: isAllHealthy
          ? (l10n.isPersian ? '${summary.healthyCount} درایور سالم و آماده' : '${summary.healthyCount} Drivers Healthy')
          : (l10n.isPersian ? '${summary.problemCount} درایور نیازمند نصب / بررسی' : '${summary.problemCount} Drivers Need Attention'),
      illustration: const MotherboardIllustration(color: Color(0xFF0D9488)),
      iconColor: const Color(0xFF0D9488),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.onAutoInstallDrivers != null) ...[
            ElevatedButton.icon(
              onPressed: widget.isBatchInstalling ? null : widget.onAutoInstallDrivers,
              icon: widget.isBatchInstalling
                  ? const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.drive_file_rename_outline_rounded, size: 13),
              label: Text(
                widget.isBatchInstalling
                    ? (l10n.isPersian ? 'در حال نصب...' : 'Installing...')
                    : (l10n.isPersian ? 'نصب خودکار از پوشه' : 'Auto Install Drivers'),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D9488),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isAllHealthy ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                  size: 14,
                  color: badgeColor,
                ),
                const SizedBox(width: 6),
                Text(
                  isAllHealthy
                      ? (l10n.isPersian ? '${summary.healthyCount} سالم' : '${summary.healthyCount} OK')
                      : (l10n.isPersian ? '${summary.problemCount} ناقص' : '${summary.problemCount} Issues'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: badgeColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Driver Batch Progress Card
          if (widget.batchStatus != null && (widget.batchStatus!.isRunning || (widget.isBatchInstalling && widget.batchStatus!.items.isNotEmpty))) ...[
            _buildDriverBatchProgress(context, isDark, l10n),
            const SizedBox(height: 14),
          ],
          // 0. Pending Reboot Suggestion Banner (Only shown after driver install in this session)
          if (widget.batchStatus?.rebootRequired == true || (widget.batchStatus != null && !widget.batchStatus!.isRunning && widget.batchStatus!.completed > 0)) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.5 : 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.restart_alt_rounded, color: Color(0xFF6366F1), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.isPersian ? 'پیشنهاد ری‌استارت پس از اتمام نصب درایورها' : 'Restart Recommended After Driver Install',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF6366F1),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.isPersian
                              ? 'پس از اجرای فایل‌های نصبی درایورها، جهت شناسایی کامل سخت‌افزارها توسط ویندوز سیستم را ری‌استارت کنید.'
                              : 'After installing driver packages, restart the system to finalize full hardware detection.',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.onRestart != null) ...[
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: widget.onRestart,
                      icon: const Icon(Icons.restart_alt_rounded, size: 14),
                      label: Text(l10n.isPersian ? 'ری‌استارت سیستم' : 'Restart System'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          // 1. Smart Troubleshooting & Official Recommendation Assistant
          if (recs.mainSearchQuery.isNotEmpty) ...[
            _buildSmartRecommendationBox(context, recs, isDark, l10n),
            const SizedBox(height: 14),
          ],

          // 2. Filter Chips Bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('all', l10n.isPersian ? 'همه درایورها (${drivers.length})' : 'All (${drivers.length})', isDark),
                if (summary.problemCount > 0)
                  _buildFilterChip('problem', l10n.isPersian ? 'ناقص / نیازمند نصب (${summary.problemCount})' : 'Missing / Issues (${summary.problemCount})', isDark, isAlert: true),
                _buildFilterChip('display', l10n.isPersian ? 'کارت گرافیک' : 'Graphics', isDark),
                _buildFilterChip('network', l10n.isPersian ? 'شبکه و وای‌فای' : 'Network & Wi-Fi', isDark),
                _buildFilterChip('audio', l10n.isPersian ? 'صدا و مالتی‌مدیا' : 'Audio', isDark),
                _buildFilterChip('chipset', l10n.isPersian ? 'چیپست و کنترلرها' : 'Chipset & Storage', isDark),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 3. Drivers List
          if (filteredDrivers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  l10n.notAvailable,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: filteredDrivers.length,
                itemBuilder: (context, index) {
                  final drv = filteredDrivers[index];
                  return _buildDriverRow(context, drv, isDark, l10n);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSmartRecommendationBox(
    BuildContext context,
    SystemDriverRecommendations recs,
    bool isDark,
    AppLocalizations l10n,
  ) {
    final hasIssues = recs.hasMissing;
    final boxColor = hasIssues ? const Color(0xFFF59E0B) : const Color(0xFF0D9488);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: boxColor.withValues(alpha: isDark ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: boxColor.withValues(alpha: isDark ? 0.35 : 0.25),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasIssues ? Icons.lightbulb_rounded : Icons.verified_user_rounded,
                color: boxColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.isPersian
                      ? 'راهنمای هوشمند و پورتال رسمی دانلود درایور (${recs.deviceTypeFa})'
                      : 'Smart Driver Recommendation & Support Portal (${recs.brand})',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.isPersian ? recs.techTipsFa : 'Search the exact model below on official manufacturer support portal.',
            style: TextStyle(
              fontSize: 11,
              height: 1.4,
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 10),

          // Google Search Query Box with 1-Click Copy
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: (isDark ? const Color(0xFF0F172A) : Colors.white),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.search_rounded, size: 16, color: Color(0xFF3B82F6)),
                const SizedBox(width: 8),
                Expanded(
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      recs.mainSearchQuery,
                      style: TextStyle(
                        fontFamily: 'Consolas',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: l10n.isPersian ? 'کپی عبارت جستجو در گوگل' : 'Copy Search Query',
                  child: InkWell(
                    onTap: () => _copyToClipboard(
                      context,
                      recs.mainSearchQuery,
                      l10n.isPersian ? 'عبارت جستجوی رسمی درایور کپی شد' : 'Search query copied',
                    ),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.copy_rounded, size: 12, color: Color(0xFF3B82F6)),
                          const SizedBox(width: 4),
                          Text(
                            l10n.copy,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF3B82F6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label, bool isDark, {bool isAlert = false}) {
    final isSelected = _selectedCategory == key;
    Color activeColor = isAlert ? const Color(0xFFEF4444) : const Color(0xFF0D9488);

    return Padding(
      padding: const EdgeInsets.only(left: 6, right: 6),
      child: InkWell(
        onTap: () => setState(() => _selectedCategory = key),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? activeColor
                : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? activeColor
                  : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected
                  ? Colors.white
                  : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDriverRow(BuildContext context, DriverItem drv, bool isDark, AppLocalizations l10n) {
    final isPresent = drv.isPresent;
    final isHealthy = drv.isHealthy;
    final isProblem = isPresent && !isHealthy;

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (!isPresent) {
      statusColor = const Color(0xFF64748B);
      statusText = l10n.isPersian ? 'موجود نیست' : 'Not Present';
      statusIcon = Icons.remove_circle_outline_rounded;
    } else if (isHealthy) {
      statusColor = const Color(0xFF10B981);
      statusText = l10n.isPersian ? 'سالم (نصب شده)' : 'Installed (OK)';
      statusIcon = Icons.check_circle_rounded;
    } else {
      statusColor = const Color(0xFFEF4444);
      statusText = drv.problemCode == 28
          ? (l10n.isPersian ? 'درایور نصب نشده (کد ۲۸)' : 'Driver Missing (Code 28)')
          : (l10n.isPersian ? 'خطای درایور (کد ${drv.problemCode})' : 'Driver Error (Code ${drv.problemCode})');
      statusIcon = Icons.error_outline_rounded;
    }

    // Category Icon Mapping
    IconData categoryIcon = Icons.devices_other_rounded;
    if (drv.category == 'Display') {
      categoryIcon = Icons.tv_rounded;
    } else if (drv.category == 'Audio') {
      categoryIcon = Icons.volume_up_rounded;
    } else if (drv.category == 'Wi-Fi') {
      categoryIcon = Icons.wifi_rounded;
    } else if (drv.category == 'Ethernet') {
      categoryIcon = Icons.settings_ethernet_rounded;
    } else if (drv.category == 'Bluetooth') {
      categoryIcon = Icons.bluetooth_rounded;
    } else if (drv.category == 'Camera') {
      categoryIcon = Icons.videocam_rounded;
    } else if (drv.category == 'Storage Controller') {
      categoryIcon = Icons.storage_rounded;
    } else if (drv.category == 'Chipset & System') {
      categoryIcon = Icons.memory_rounded;
    } else if (drv.category == 'Input & Touchpad') {
      categoryIcon = Icons.touch_app_rounded;
    }

    final rec = drv.recommendation;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? (isProblem ? const Color(0xFF1F1318) : const Color(0xFF0F172A))
            : (isProblem ? const Color(0xFFFFF1F2) : const Color(0xFFF8FAFC)),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: (!isPresent)
              ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0))
              : isHealthy
                  ? statusColor.withValues(alpha: isDark ? 0.3 : 0.2)
                  : const Color(0xFFEF4444).withValues(alpha: 0.5),
          width: isProblem ? 1.4 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(categoryIcon, size: 16, color: statusColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Directionality(
                            textDirection: TextDirection.ltr,
                            child: Text(
                              drv.displayName,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        if (drv.manufacturer.isNotEmpty && drv.manufacturer != 'Unknown' && drv.manufacturer != 'N/A') ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              drv.manufacturer,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            l10n.isPersian ? drv.categoryFa : drv.category,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0D9488),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.isPersian ? drv.statusDescription : drv.statusDescriptionEn,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: isProblem
                                  ? const Color(0xFFEF4444)
                                  : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 12, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Actionable Search & Guide for Problem Drivers
          if (isProblem && rec != null && rec.searchQuery.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.download_for_offline_rounded, size: 14, color: Color(0xFF3B82F6)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l10n.isPersian ? rec.guideFa : rec.guideEn,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () => _copyToClipboard(
                      context,
                      rec.searchQuery,
                      l10n.isPersian ? 'عبارت جستجوی درایور کپی شد' : 'Driver search query copied',
                    ),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (isDark ? const Color(0xFF1E293B) : Colors.white),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.copy_rounded, size: 10, color: Color(0xFF3B82F6)),
                          const SizedBox(width: 3),
                          Text(
                            l10n.copy,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF3B82F6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDriverBatchProgress(BuildContext context, bool isDark, AppLocalizations l10n) {
    final b = widget.batchStatus!;
    final isRunning = b.isRunning;
    final total = b.total;
    final percent = b.progressPercent;
    final currentFile = b.currentFile;
    final failed = b.failed;

    Color color = isRunning ? const Color(0xFF0D9488) : (failed == 0 ? const Color(0xFF0D9488) : const Color(0xFFF59E0B));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF081C1B) : const Color(0xFFF0FDFA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.6 : 0.4),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              isRunning
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0D9488)),
                    )
                  : Icon(
                      failed == 0 ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                      color: color,
                      size: 18,
                    ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isRunning
                      ? (currentFile != null
                          ? 'نصب خودکار: $currentFile (${b.currentIndex + 1} از $total)'
                          : 'در حال نصب خودکار درایورها...')
                      : b.summaryMessage,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                  ),
                ),
              ),
              Text(
                '${percent.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              if (isRunning && widget.onCancelBatch != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: widget.onCancelBatch,
                  tooltip: 'لغو',
                  icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFFEF4444)),
                  style: IconButton.styleFrom(
                    padding: const EdgeInsets.all(4),
                    minimumSize: Size.zero,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total > 0 ? (percent / 100.0).clamp(0.0, 1.0) : null,
              minHeight: 5,
              backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          if (b.items.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              decoration: BoxDecoration(
                color: (isDark ? const Color(0xFF0F172A) : Colors.white),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                ),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                itemCount: b.items.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                ),
                itemBuilder: (context, index) {
                  final item = b.items[index];
                  final isItemRunning = item.status == 'installing';
                  final isItemDone = item.status == 'completed';
                  final isItemFailed = item.status == 'failed';
                  final isItemSkipped = item.status == 'skipped';

                  Color itemColor = isItemDone
                      ? const Color(0xFF10B981)
                      : (isItemFailed
                          ? const Color(0xFFEF4444)
                          : (isItemRunning
                              ? const Color(0xFF0D9488)
                              : const Color(0xFF94A3B8)));

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (isItemRunning)
                              const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF0D9488)),
                              )
                            else
                              Icon(
                                isItemDone
                                    ? Icons.check_circle_rounded
                                    : (isItemFailed
                                        ? Icons.cancel_rounded
                                        : (isItemSkipped ? Icons.skip_next_rounded : Icons.schedule_rounded)),
                                size: 14,
                                color: itemColor,
                              ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: itemColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                item.type.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  color: itemColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Directionality(
                                textDirection: TextDirection.ltr,
                                child: Text(
                                  item.filename,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isItemRunning ? FontWeight.w700 : FontWeight.w500,
                                    color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            if (item.fileSizeDisplay.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Text(
                                item.fileSizeDisplay,
                                style: TextStyle(
                                  fontSize: 9,
                                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (item.message.isNotEmpty && (isItemFailed || isItemDone)) ...[
                          const SizedBox(height: 2),
                          Padding(
                            padding: const EdgeInsets.only(right: 20, left: 6),
                            child: Text(
                              item.message,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: isItemFailed ? FontWeight.w600 : FontWeight.w500,
                                color: isItemFailed
                                    ? const Color(0xFFEF4444)
                                    : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
