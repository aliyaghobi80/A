import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/qc_controller.dart';
import '../../controllers/system_info_controller.dart';
import '../../controllers/theme_language_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../utils/persian_date_time.dart';
import 'copyable_value.dart';

class GlobalAppHeader extends StatefulWidget {
  const GlobalAppHeader({super.key});

  static String formatTimestamp(String raw) {
    if (raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw.split('.').first.replaceAll('T', ' ');
    }
  }

  @override
  State<GlobalAppHeader> createState() => _GlobalAppHeaderState();
}

class _GlobalAppHeaderState extends State<GlobalAppHeader> {
  late DateTime _now;
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final systemCtrl = Get.find<SystemInfoController>();
    final themeCtrl = Get.find<ThemeLanguageController>();
    final qcCtrl = Get.find<QcController>();
    final l10n = AppLocalizations.of(context);

    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
            width: 1.2,
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 680;

          return Row(
            children: [
              // 1. Hostname + Formatted Scan Timestamp
              Expanded(
                child: Obx(() {
                  final info = systemCtrl.systemInfo.value;
                  final host = info?.system.deviceDisplayName.isNotEmpty == true
                      ? info!.system.deviceDisplayName
                      : 'WINDOWS-PC';
                  final rawTimestamp = info?.timestamp ?? '';
                  final timestamp = GlobalAppHeader.formatTimestamp(
                    rawTimestamp,
                  );
                  final accent = themeCtrl.currentAccentColor;

                  return Row(
                    children: [
                      Icon(
                        Icons.desktop_windows_rounded,
                        size: 20,
                        color: accent,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: CopyableValue(
                          tooltip: info == null
                              ? host
                              : '${l10n.isPersian ? "کپی مدل دستگاه" : "Copy device model"}: $host • ${info.system.computerName}',
                          onCopy: () => systemCtrl.copyToClipboard(
                            context,
                            host,
                            '${l10n.copiedToClipboard}: $host',
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Directionality(
                                  textDirection: TextDirection.ltr,
                                  child: Text(
                                    host,
                                    style: TextStyle(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w800,
                                      color: isDark
                                          ? AppTheme.darkTextPrimary
                                          : AppTheme.lightTextPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 5),
                              Icon(Icons.copy_rounded, size: 13, color: accent),
                            ],
                          ),
                        ),
                      ),
                      if (isNarrow) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            l10n.isPersian
                                ? formatCompactPersianDateTime(_now)
                                : '${_now.month.toString().padLeft(2, '0')}/${_now.day.toString().padLeft(2, '0')} • ${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppTheme.darkTextMuted
                                  : AppTheme.lightTextMuted,
                            ),
                          ),
                        ),
                      ],
                      if (!isNarrow) ...[
                        const SizedBox(width: 10),
                        Text(
                          '•',
                          style: TextStyle(
                            color: isDark
                                ? AppTheme.darkTextMuted
                                : AppTheme.lightTextMuted,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Directionality(
                            textDirection: TextDirection.ltr,
                            child: Text(
                              l10n.isPersian
                                  ? formatPersianDateTime(_now)
                                  : '${_now.year}-${_now.month.toString().padLeft(2, '0')}-${_now.day.toString().padLeft(2, '0')} • ${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? AppTheme.darkTextMuted
                                    : AppTheme.lightTextMuted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      if (timestamp.isNotEmpty && !isNarrow) ...[
                        const SizedBox(width: 10),
                        Tooltip(
                          message: l10n.isPersian
                              ? 'زمان آخرین اسکن: $timestamp'
                              : 'Last scan: $timestamp',
                          child: Icon(
                            Icons.history_rounded,
                            size: 16,
                            color: isDark
                                ? AppTheme.darkTextMuted
                                : AppTheme.lightTextMuted,
                          ),
                        ),
                      ],
                    ],
                  );
                }),
              ),

              const SizedBox(width: 10),

              // 2. Action Buttons: [ گزارش سریع QC ] + [ بررسی مجدد ]
              Obx(() {
                final isRefreshing = systemCtrl.isRefreshing.value;
                final isQcChecking = qcCtrl.isChecking.value;
                final accent = themeCtrl.currentAccentColor;

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton.icon(
                      onPressed: isQcChecking
                          ? null
                          : () => qcCtrl.runFullCheck(context),
                      icon: const Icon(Icons.fact_check_rounded, size: 16),
                      label: Text(
                        isNarrow
                            ? 'QC'
                            : (l10n.isPersian ? 'گزارش QC' : 'QC Report'),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          horizontal: isNarrow ? 10 : 14,
                          vertical: 8,
                        ),
                        minimumSize: const Size(0, 36),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: isRefreshing
                          ? null
                          : () =>
                                systemCtrl.fetchSystemInfo(forceRefresh: true),
                      icon: isRefreshing
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.refresh_rounded, size: 16),
                      label: Text(
                        isRefreshing
                            ? '...'
                            : (isNarrow
                                  ? (l10n.isPersian ? 'اسکن' : 'Scan')
                                  : (l10n.isPersian
                                        ? 'بررسی مجدد'
                                        : 'Refresh')),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        padding: EdgeInsets.symmetric(
                          horizontal: isNarrow ? 10 : 14,
                          vertical: 8,
                        ),
                        minimumSize: const Size(0, 36),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ],
          );
        },
      ),
    );
  }
}
