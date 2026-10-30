import 'dart:convert';
import 'package:flutter/material.dart';
import '../../models/system_info.dart';
import '../../theme/app_theme.dart';

/// Live status classification for deployment items.
enum QueueItemStatus {
  pending,
  installing,
  completed,
  failed,
  skipped,
  interrupted,
}

QueueItemStatus parseQueueStatus(String? rawStatus) {
  final s = (rawStatus ?? 'pending').toLowerCase().trim();
  switch (s) {
    case 'installing':
    case 'running':
      return QueueItemStatus.installing;
    case 'completed':
    case 'done':
    case 'success':
      return QueueItemStatus.completed;
    case 'failed':
    case 'error':
      return QueueItemStatus.failed;
    case 'skipped':
    case 'ignored':
      return QueueItemStatus.skipped;
    case 'interrupted':
    case 'cancelled':
    case 'paused':
      return QueueItemStatus.interrupted;
    case 'pending':
    case 'queued':
    case 'waiting':
    default:
      return QueueItemStatus.pending;
  }
}

/// Formats elapsed seconds nicely into Persian/LTR duration string.
String formatDuration(double? seconds) {
  if (seconds == null || seconds <= 0) return '0s';
  final totalSecs = seconds.round();
  if (totalSecs < 60) {
    return '${totalSecs}s';
  }
  final mins = totalSecs ~/ 60;
  final remSecs = totalSecs % 60;
  return '${mins}m ${remSecs}s';
}

/// Rich status badge for a queue card with distinct visual styles per state.
class QueueStatusChip extends StatelessWidget {
  final QueueItemStatus status;
  final bool isDark;

  const QueueStatusChip({
    super.key,
    required this.status,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final String label;
    final Color color;
    final IconData? icon;
    final bool showSpinner;

    switch (status) {
      case QueueItemStatus.pending:
        label = 'در انتظار';
        color = const Color(0xFF64748B);
        icon = Icons.hourglass_empty_rounded;
        showSpinner = false;
        break;
      case QueueItemStatus.installing:
        label = 'در حال نصب';
        color = const Color(0xFF0284C7);
        icon = null;
        showSpinner = true;
        break;
      case QueueItemStatus.completed:
        label = 'نصب شد';
        color = const Color(0xFF10B981);
        icon = Icons.check_circle_rounded;
        showSpinner = false;
        break;
      case QueueItemStatus.failed:
        label = 'خطا';
        color = const Color(0xFFEF4444);
        icon = Icons.error_outline_rounded;
        showSpinner = false;
        break;
      case QueueItemStatus.skipped:
        label = 'رد شد';
        color = const Color(0xFF94A3B8);
        icon = Icons.redo_rounded;
        showSpinner = false;
        break;
      case QueueItemStatus.interrupted:
        label = 'متوقف شد';
        color = const Color(0xFFF59E0B);
        icon = Icons.pause_circle_outline_rounded;
        showSpinner = false;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.6 : 0.4),
          width: 1.1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showSpinner) ...[
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(width: 6),
          ] else if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Rich queue card for Software deployment items.
///
/// Features:
/// - Stable [ValueKey] `software-item-${item.id}`
/// - Live status chips with distinct visual styles
/// - Brand icon from base64 data or category fallback
/// - Active elapsed timer formatted nicely (e.g. `24s`, `1m 12s`)
/// - Expandable execution log drawer disclosing stdout/stderr and details
/// - Per-item retry button for failed/interrupted items (>=44px touch target)
/// - Serial Barrier vs 2X Parallel badge
class SoftwareQueueCard extends StatefulWidget {
  final BatchInstallItem item;
  final SoftwarePackage? package;
  final VoidCallback? onRetry;
  final bool isDark;
  final Color accentColor;

  SoftwareQueueCard({
    required this.item,
    this.package,
    this.onRetry,
    required this.isDark,
    required this.accentColor,
  }) : super(key: ValueKey('software-item-${item.id}'));

  @override
  State<SoftwareQueueCard> createState() => _SoftwareQueueCardState();
}

class _SoftwareQueueCardState extends State<SoftwareQueueCard> {
  bool _isLogExpanded = false;

  bool _isBarrierSoftware(BatchInstallItem item, SoftwarePackage? pkg) {
    if (item.orchestratorAction != null && item.orchestratorAction!.isNotEmpty) {
      return true;
    }
    final nameLower = '${item.name} ${pkg?.name ?? ''}'.toLowerCase();
    if (nameLower.contains('office') ||
        nameLower.contains('visual c++') ||
        nameLower.contains('vcredist') ||
        nameLower.contains('.net') ||
        nameLower.contains('directx')) {
      return true;
    }
    final installerType = (item.installerType ?? pkg?.installerType ?? '').toLowerCase();
    if (installerType == 'msi' || installerType == 'cmd' || installerType == 'bat') {
      return true;
    }
    return false;
  }

  Widget _buildBrandIcon() {
    final pkg = widget.package;
    if (pkg?.iconBase64 != null && pkg!.iconBase64!.isNotEmpty) {
      try {
        final clean = pkg.iconBase64!.contains(',')
            ? pkg.iconBase64!.split(',').last
            : pkg.iconBase64!;
        final bytes = base64Decode(clean.trim());
        if (bytes.isNotEmpty) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              bytes,
              width: 38,
              height: 38,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => _buildFallbackIcon(),
            ),
          );
        }
      } catch (_) {}
    }
    return _buildFallbackIcon();
  }

  Widget _buildFallbackIcon() {
    final nameLower = widget.item.name.toLowerCase();
    IconData icon = Icons.apps_rounded;
    Color iconColor = widget.accentColor;

    if (nameLower.contains('chrome')) {
      icon = Icons.public_rounded;
      iconColor = const Color(0xFFEA4335);
    } else if (nameLower.contains('firefox')) {
      icon = Icons.local_fire_department_rounded;
      iconColor = const Color(0xFFFF7139);
    } else if (nameLower.contains('office') || nameLower.contains('word') || nameLower.contains('excel')) {
      icon = Icons.description_rounded;
      iconColor = const Color(0xFFD83B01);
    } else if (nameLower.contains('vlc') || nameLower.contains('kmplayer')) {
      icon = Icons.play_circle_fill_rounded;
      iconColor = const Color(0xFFFF8800);
    } else if (nameLower.contains('winrar') || nameLower.contains('7-zip')) {
      icon = Icons.folder_zip_rounded;
      iconColor = const Color(0xFF8B5CF6);
    } else if (nameLower.contains('visual c++') || nameLower.contains('.net')) {
      icon = Icons.settings_applications_rounded;
      iconColor = const Color(0xFF0284C7);
    }

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: widget.isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 22, color: iconColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isDark = widget.isDark;
    final accent = widget.accentColor;
    final status = parseQueueStatus(item.status);
    final isBarrier = _isBarrierSoftware(item, widget.package);

    // Border color based on status
    Color cardBorderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    if (status == QueueItemStatus.installing) {
      cardBorderColor = accent;
    } else if (status == QueueItemStatus.completed) {
      cardBorderColor = const Color(0xFF10B981).withValues(alpha: isDark ? 0.5 : 0.35);
    } else if (status == QueueItemStatus.failed) {
      cardBorderColor = const Color(0xFFEF4444).withValues(alpha: isDark ? 0.6 : 0.45);
    } else if (status == QueueItemStatus.interrupted) {
      cardBorderColor = const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.6 : 0.45);
    }

    // Has details / logs to display
    final hasLogs = item.message.isNotEmpty ||
        (item.errorMessage != null && item.errorMessage!.isNotEmpty) ||
        item.exitCode != null ||
        (widget.package?.fullPath.isNotEmpty == true);

    return Container(
      key: ValueKey('software-item-${item.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorderColor, width: status == QueueItemStatus.installing ? 1.6 : 1.1),
        boxShadow: status == QueueItemStatus.installing
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: isDark ? 0.25 : 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // 1. Brand / Category Icon
                _buildBrandIcon(),
                const SizedBox(width: 12),

                // 2. Name & Description
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.name,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Barrier / Parallel badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (isBarrier ? const Color(0xFF8B5CF6) : const Color(0xFF0D9488))
                                  .withValues(alpha: isDark ? 0.22 : 0.12),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: (isBarrier ? const Color(0xFF8B5CF6) : const Color(0xFF0D9488))
                                    .withValues(alpha: 0.35),
                              ),
                            ),
                            child: Text(
                              isBarrier ? 'سد متوالی' : 'موازی ۲X',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: isBarrier ? const Color(0xFFA78BFA) : const Color(0xFF0D9488),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.friendlyDescription.isNotEmpty
                                  ? item.friendlyDescription
                                  : (item.message.isNotEmpty ? item.message : item.filename),
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (widget.package?.fileSizeDisplay.isNotEmpty == true) ...[
                            const SizedBox(width: 6),
                            Directionality(
                              textDirection: TextDirection.ltr,
                              child: Text(
                                widget.package!.fileSizeDisplay,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // 3. Status Chip
                QueueStatusChip(status: status, isDark: isDark),

                // 4. Log Drawer Toggle Button (min 44px touch target)
                if (hasLogs) ...[
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                    child: IconButton(
                      icon: Icon(
                        _isLogExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                        size: 20,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                      tooltip: _isLogExpanded ? 'پنهان‌سازی لاگ' : 'مشاهده گزارش',
                      onPressed: () => setState(() => _isLogExpanded = !_isLogExpanded),
                    ),
                  ),
                ],

                // 5. Retry Button (if failed or interrupted)
                if ((status == QueueItemStatus.failed || status == QueueItemStatus.interrupted) &&
                    widget.onRetry != null) ...[
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: widget.onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('تلاش مجدد'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Log / Details Drawer (expandable)
          if (_isLogExpanded && hasLogs) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF090D16) : const Color(0xFFF1F5F9),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(11)),
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.terminal_rounded, size: 15, color: Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Text(
                        'گزارش و خروجی لاگ:',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                        ),
                      ),
                      const Spacer(),
                      if (item.exitCode != null)
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (item.exitCode == 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444))
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'exit_code: ${item.exitCode}',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w700,
                                color: item.exitCode == 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: SelectableText(
                      item.errorMessage?.isNotEmpty == true
                          ? item.errorMessage!
                          : (item.message.isNotEmpty ? item.message : 'No logs recorded.'),
                      style: TextStyle(
                        fontFamily: 'Consolas',
                        fontSize: 11,
                        height: 1.4,
                        color: status == QueueItemStatus.failed
                            ? const Color(0xFFF87171)
                            : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
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
}

/// Rich queue card for Driver deployment items.
///
/// Features:
/// - Stable [ValueKey] `driver-queue-${item.packageId}`
/// - Live status chips with distinct visual styles
/// - Category icon & category badges
/// - Active elapsed timer formatted nicely (e.g. `24s`, `1m 12s`)
/// - Worker attribution badge (`Worker 1` / `Worker 2`)
/// - Expandable execution log drawer disclosing stdout/stderr and details
/// - Per-item retry button for failed/interrupted items (>=44px touch target)
/// - Serial Barrier vs 2X Parallel badge
class DriverQueueCard extends StatefulWidget {
  final DriverInstallItem item;
  final IntelligentDriverPackage? package;
  final VoidCallback? onRetry;
  final bool isDark;
  final Color accentColor;

  DriverQueueCard({
    required this.item,
    this.package,
    this.onRetry,
    required this.isDark,
    required this.accentColor,
  }) : super(
          key: ValueKey(
            'driver-queue-${item.packageId ?? item.displayName ?? item.filename}',
          ),
        );

  @override
  State<DriverQueueCard> createState() => _DriverQueueCardState();
}

class _DriverQueueCardState extends State<DriverQueueCard> {
  bool _isLogExpanded = false;

  bool _isBarrierDriver(DriverInstallItem item) {
    final cat = item.category.toLowerCase().trim();
    if (cat == 'chipset' ||
        cat == 'system_mei' ||
        cat == 'storage' ||
        cat == 'gpu' ||
        item.filename.toLowerCase().endsWith('.msi')) {
      return true;
    }
    return false;
  }

  IconData _getCategoryIcon(String cat) {
    final c = cat.toLowerCase().trim();
    if (c == 'chipset') return Icons.developer_board_rounded;
    if (c == 'system_mei') return Icons.memory_rounded;
    if (c == 'storage') return Icons.storage_rounded;
    if (c == 'gpu') return Icons.videogame_asset_rounded;
    if (c == 'audio') return Icons.volume_up_rounded;
    if (c == 'wifi') return Icons.wifi_rounded;
    if (c == 'lan') return Icons.settings_ethernet_rounded;
    if (c == 'bluetooth') return Icons.bluetooth_rounded;
    if (c == 'touchpad') return Icons.touch_app_rounded;
    if (c == 'card_reader') return Icons.credit_card_rounded;
    if (c == 'camera') return Icons.camera_alt_rounded;
    if (c == 'usb') return Icons.usb_rounded;
    return Icons.extension_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isDark = widget.isDark;
    final accent = widget.accentColor;
    final status = parseQueueStatus(item.status);
    final isBarrier = _isBarrierDriver(item);
    final displayName = item.displayName ?? item.filename;
    final catFa = item.categoryFa ?? (widget.package?.categoryFa ?? 'سایر دستگاه‌ها');

    Color cardBorderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    if (status == QueueItemStatus.installing) {
      cardBorderColor = const Color(0xFF0D9488);
    } else if (status == QueueItemStatus.completed) {
      cardBorderColor = const Color(0xFF10B981).withValues(alpha: isDark ? 0.5 : 0.35);
    } else if (status == QueueItemStatus.failed) {
      cardBorderColor = const Color(0xFFEF4444).withValues(alpha: isDark ? 0.6 : 0.45);
    } else if (status == QueueItemStatus.interrupted) {
      cardBorderColor = const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.6 : 0.45);
    }

    final hasLogs = item.message.isNotEmpty ||
        (item.errorMessage != null && item.errorMessage!.isNotEmpty) ||
        (item.failureReason != null && item.failureReason!.isNotEmpty) ||
        item.exitCode != null;

    final elapsedStr = formatDuration(item.elapsedSeconds);

    return Container(
      key: ValueKey('driver-queue-${item.packageId ?? item.displayName ?? item.filename}'),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cardBorderColor,
          width: status == QueueItemStatus.installing ? 1.6 : 1.1,
        ),
        boxShadow: status == QueueItemStatus.installing
            ? [
                BoxShadow(
                  color: const Color(0xFF0D9488).withValues(alpha: isDark ? 0.25 : 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // 1. Driver Category Icon
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: (isBarrier ? const Color(0xFF8B5CF6) : const Color(0xFF0D9488))
                        .withValues(alpha: isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getCategoryIcon(item.category),
                    size: 20,
                    color: isBarrier ? const Color(0xFFA78BFA) : const Color(0xFF0D9488),
                  ),
                ),
                const SizedBox(width: 12),

                // 2. Main Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              displayName,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Category badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              catFa,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: accent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Barrier vs Parallel badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (isBarrier ? const Color(0xFF8B5CF6) : const Color(0xFF0D9488))
                                  .withValues(alpha: isDark ? 0.22 : 0.12),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: (isBarrier ? const Color(0xFF8B5CF6) : const Color(0xFF0D9488))
                                    .withValues(alpha: 0.35),
                              ),
                            ),
                            child: Text(
                              isBarrier ? 'سد متوالی' : 'موازی ۲X',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: isBarrier ? const Color(0xFFA78BFA) : const Color(0xFF0D9488),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.message.isNotEmpty
                                  ? item.message
                                  : (item.failureReason ?? item.filename),
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (item.workerId != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Worker ${item.workerId}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0284C7),
                                ),
                              ),
                            ),
                          ],
                          if (item.elapsedSeconds != null && item.elapsedSeconds! > 0) ...[
                            const SizedBox(width: 8),
                            Directionality(
                              textDirection: TextDirection.ltr,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF1E293B)
                                      : const Color(0xFFE2E8F0),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  elapsedStr,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // 3. Status Chip
                QueueStatusChip(status: status, isDark: isDark),

                // 4. Log Toggle Button (min 44px)
                if (hasLogs) ...[
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                    child: IconButton(
                      icon: Icon(
                        _isLogExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                        size: 20,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                      tooltip: _isLogExpanded ? 'پنهان‌سازی لاگ' : 'مشاهده گزارش',
                      onPressed: () => setState(() => _isLogExpanded = !_isLogExpanded),
                    ),
                  ),
                ],

                // 5. Retry Button (if failed or interrupted)
                if ((status == QueueItemStatus.failed || status == QueueItemStatus.interrupted) &&
                    widget.onRetry != null) ...[
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: widget.onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('تلاش مجدد'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Log / Details Drawer (expandable)
          if (_isLogExpanded && hasLogs) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF090D16) : const Color(0xFFF1F5F9),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(11)),
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.terminal_rounded, size: 15, color: Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Text(
                        'گزارش و خروجی درایور:',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                        ),
                      ),
                      const Spacer(),
                      if (item.retryCount > 0) ...[
                        Text(
                          'تلاش مجدد: ${item.retryCount}',
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: Color(0xFFF59E0B),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (item.exitCode != null)
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (item.exitCode == 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444))
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'exit_code: ${item.exitCode}',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w700,
                                color: item.exitCode == 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: SelectableText(
                      item.failureReason?.isNotEmpty == true
                          ? item.failureReason!
                          : (item.errorMessage?.isNotEmpty == true
                              ? item.errorMessage!
                              : (item.message.isNotEmpty ? item.message : 'No detailed logs.')),
                      style: TextStyle(
                        fontFamily: 'Consolas',
                        fontSize: 11,
                        height: 1.4,
                        color: status == QueueItemStatus.failed
                            ? const Color(0xFFF87171)
                            : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
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
}
