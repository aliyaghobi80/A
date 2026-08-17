import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../models/system_info.dart';

class DriverCard extends StatefulWidget {
  final List<DriverItem> drivers;
  final DriverSummary summary;

  const DriverCard({
    super.key,
    required this.drivers,
    required this.summary,
  });

  @override
  State<DriverCard> createState() => _DriverCardState();
}

class _DriverCardState extends State<DriverCard> {
  String _selectedCategory = 'all';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    final summary = widget.summary;
    final drivers = widget.drivers;

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

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131D33) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF22304E) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D9488).withValues(alpha: isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.developer_board_rounded,
                    color: Color(0xFF0D9488),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.isPersian ? 'بررسی جامع درایورهای سخت‌افزاری' : 'Hardware Drivers Inspection',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.isPersian
                            ? 'بررسی وضعیت تمامی قطعات سخت‌افزاری، گرافیک، صدا، شبکه و درایورهای ناشناخته'
                            : 'Status of all hardware devices, graphics, audio, network and uninstalled drivers',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: badgeColor.withValues(alpha: 0.3),
                    ),
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
                            ? (l10n.isPersian ? '${summary.healthyCount} درایور سالم' : '${summary.healthyCount} Drivers Healthy')
                            : (l10n.isPersian ? '${summary.problemCount} درایور ناقص / نیازمند نصب' : '${summary.problemCount} Missing / Issues'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: badgeColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(
              color: isDark ? const Color(0xFF1E2C4A) : const Color(0xFFF1F5F9),
              thickness: 1,
              height: 1,
            ),
            const SizedBox(height: 14),

            // Missing / Problem Alert Box if any device has driver issues
            if (summary.problemCount > 0) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: isDark ? 0.15 : 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.isPersian
                                ? 'توجه: سخت‌افزار با درایور ناشناخته یا نصب‌نشده شناسایی شد'
                                : 'Attention: Hardware with missing or uninstalled drivers detected',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFEF4444),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.isPersian
                                ? 'برای عملکرد کامل لپتاپ/کامپیوتر، درایورهای مربوط به قطعات زیر باید نصب گردند:'
                                : 'For full system functionality, drivers for the following devices must be installed:',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Filter Chips Bar
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

            // Drivers List
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
                constraints: const BoxConstraints(maxHeight: 380),
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
      ),
    );
  }

  Widget _buildFilterChip(String key, String label, bool isDark, {bool isAlert = false}) {
    final isSelected = _selectedCategory == key;
    Color activeColor = isAlert ? const Color(0xFFEF4444) : const Color(0xFF2563EB);

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
                : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? activeColor
                  : (isAlert ? const Color(0xFFEF4444).withValues(alpha: 0.5) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected
                  ? Colors.white
                  : (isAlert ? const Color(0xFFEF4444) : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569))),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDriverRow(BuildContext context, DriverItem drv, bool isDark, AppLocalizations l10n) {
    final isPresent = drv.isPresent;
    final isHealthy = drv.isHealthy;
    final isProblem = !isHealthy && isPresent;

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (!isPresent) {
      statusColor = isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
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
      child: Row(
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
    );
  }
}
