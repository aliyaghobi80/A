import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../l10n/app_localizations.dart';
import '../models/system_info.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';
import '../services/folder_picker_service.dart';

class SystemInfoController extends GetxController {
  final ApiService _apiService = ApiService();

  final Rx<SystemInfo?> systemInfo = Rx<SystemInfo?>(null);
  final RxBool isLoading = true.obs;
  final RxBool isRefreshing = false.obs;
  final RxBool isDisablingProxy = false.obs;
  final RxBool isRestarting = false.obs;
  final RxString errorMessage = ''.obs;

  // Live USB flash drives
  final RxList<UsbDriveInfo> usbDrives = <UsbDriveInfo>[].obs;
  final RxBool isEjecting = false.obs;
  Timer? _usbPollTimer;
  Future<void>? _activeFetch;
  bool _pendingForceRefresh = false;

  // Session-based installation & restart suggestion tracking
  final RxInt sessionInstalledSoftwareCount = 0.obs;
  final RxInt sessionInstalledDriversCount = 0.obs;
  final RxBool sessionRebootSuggested = false.obs;
  final RxBool isRestartBannerDismissed = false.obs;

  bool get shouldShowRestartBanner {
    if (isRestartBannerDismissed.value) return false;
    return sessionRebootSuggested.value ||
        sessionInstalledDriversCount.value > 0 ||
        sessionInstalledSoftwareCount.value > 0;
  }

  void recordSoftwareInstall() {
    sessionInstalledSoftwareCount.value++;
    sessionRebootSuggested.value = true;
    isRestartBannerDismissed.value = false;
  }

  void recordDriverInstall([int count = 1]) {
    sessionInstalledDriversCount.value += count;
    sessionRebootSuggested.value = true;
    isRestartBannerDismissed.value = false;
  }

  void dismissRestartBanner() {
    isRestartBannerDismissed.value = true;
  }

  @override
  void onInit() {
    super.onInit();
    _loadCacheAndFetch();
    fetchUsbDrives();
    _usbPollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      fetchUsbDrives();
    });
  }

  @override
  void onClose() {
    _usbPollTimer?.cancel();
    super.onClose();
  }

  Future<void> _loadCacheAndFetch() async {
    try {
      final cached = await CacheService.loadCachedSystemInfo();
      if (cached != null) {
        systemInfo.value = cached;
        isLoading.value = false;
      }
    } catch (_) {}
    fetchSystemInfo(forceRefresh: true);
  }

  Future<void> changeFileRequirementPath(
    BuildContext context,
    String reqId,
    String reqName,
  ) async {
    final l10n = AppLocalizations.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final selectedPath = await FolderPickerService.pickFolder(
      title:
          '${l10n.isPersian ? "انتخاب مسیر برای" : "Select Path for"} $reqName',
    );

    if (selectedPath != null && selectedPath.isNotEmpty) {
      try {
        final success = await _apiService.setFilesDirectory(
          reqId,
          selectedPath,
        );
        if (success) {
          await fetchSystemInfo(forceRefresh: true);
          if (context.mounted) {
            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: Text(
                  l10n.isPersian
                      ? '✓ مسیر $reqName به $selectedPath تغییر یافت.'
                      : '✓ Path for $reqName updated: $selectedPath',
                ),
                backgroundColor: const Color(0xFF10B981),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      } catch (e) {
        if (context.mounted) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('Error updating path: $e'),
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Future<void> fetchSystemInfo({bool forceRefresh = false}) async {
    final active = _activeFetch;
    if (active != null) {
      if (forceRefresh) _pendingForceRefresh = true;
      await active;
      if (forceRefresh) {
        // The owner of the active request may adopt the pending refresh. Wait
        // for that replacement request as well so callers never observe stale
        // hardware immediately after awaiting a forced refresh.
        while (!isClosed) {
          final replacement = _activeFetch;
          if (replacement == null) break;
          await replacement;
        }
        if (_pendingForceRefresh && !isClosed) {
          _pendingForceRefresh = false;
          await fetchSystemInfo(forceRefresh: true);
        }
      }
      return;
    }

    final effectiveForce = forceRefresh || _pendingForceRefresh;
    _pendingForceRefresh = false;
    final operation = _fetchSystemInfo(forceRefresh: effectiveForce);
    _activeFetch = operation;
    try {
      await operation;
    } finally {
      if (identical(_activeFetch, operation)) _activeFetch = null;
    }
    if (_pendingForceRefresh && !isClosed) {
      _pendingForceRefresh = false;
      await fetchSystemInfo(forceRefresh: true);
    }
  }

  Future<void> _fetchSystemInfo({required bool forceRefresh}) async {
    if (forceRefresh || systemInfo.value != null) {
      isRefreshing.value = true;
    } else {
      isLoading.value = true;
    }
    errorMessage.value = '';

    try {
      final info = await _apiService.fetchSystemInfo(
        forceRefresh: forceRefresh,
      );
      systemInfo.value = info;
    } catch (e) {
      if (systemInfo.value == null) {
        errorMessage.value = e.toString();
      }
    } finally {
      isLoading.value = false;
      isRefreshing.value = false;
    }
  }

  /// Used by the process-driven splash screen. A transient race while the
  /// local backend starts is retried here instead of showing an immediate
  /// "Retry" page on newly installed/slow Windows systems.
  Future<bool> prepareInitialData({
    void Function(double, String)? report,
  }) async {
    if (systemInfo.value != null) return true;
    for (var attempt = 0; attempt < 3; attempt++) {
      report?.call(
        0.58 + (attempt * 0.1),
        attempt == 0
            ? 'در حال دریافت مشخصات دستگاه…'
            : 'در حال تکمیل اطلاعات سخت‌افزار…',
      );
      await fetchSystemInfo(forceRefresh: false);
      if (systemInfo.value != null) return true;
      if (attempt < 2) {
        await Future<void>.delayed(Duration(milliseconds: 500 + attempt * 500));
      }
    }
    return false;
  }

  void copyToClipboard(BuildContext context, String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String buildAllSpecsSummary(
    AppLocalizations l10n,
    PackagesResponse? packagesRes,
  ) {
    final info = systemInfo.value;
    if (info == null) return '';

    final buffer = StringBuffer();
    buffer.writeln('=== ${l10n.appName} ===');
    buffer.writeln('[${l10n.isPersian ? "هویت دستگاه" : "Device identity"}]');
    buffer.writeln(
      '${l10n.isPersian ? "سازنده / مدل" : "Manufacturer / model"}: ${info.system.manufacturer} ${info.system.model}',
    );
    buffer.writeln(
      '${l10n.isPersian ? "سریال دستگاه" : "Device serial"}: ${info.system.serial}',
    );
    if (info.system.assetTag != 'Not available') {
      buffer.writeln(
        '${l10n.isPersian ? "برچسب دارایی" : "Asset tag"}: ${info.system.assetTag}',
      );
    }
    if (info.system.uuid != 'Not available') {
      buffer.writeln('UUID: ${info.system.uuid}');
    }
    buffer.writeln('');
    buffer.writeln('[${l10n.hardware}]');
    buffer.writeln('${l10n.cpu}: ${info.cpu.name}');
    if (info.cpu.serial.isNotEmpty &&
        info.cpu.serial != 'Not available' &&
        info.cpu.serial != '-') {
      buffer.writeln(
        '  - ${l10n.isPersian ? "شناسه پردازنده" : "Processor ID"}: ${info.cpu.serial}',
      );
    }

    buffer.writeln(
      '${l10n.ram}: ${info.ram.totalDisplay}${info.ram.speedDisplay != 'Not available' ? ' (${info.ram.speedDisplay})' : ''}',
    );
    for (int i = 0; i < info.ram.modules.length; i++) {
      final m = info.ram.modules[i];
      final mSerial =
          (m.serial.isNotEmpty &&
              m.serial != '00000000' &&
              m.serial != 'Not available')
          ? m.serial
          : '-';
      final mPart = (m.partNumber.isNotEmpty && m.partNumber != 'Not available')
          ? m.partNumber
          : '-';
      buffer.writeln(
        '  - ${l10n.isPersian ? "ماژول" : "Slot"} ${i + 1} (${m.slot}): ${m.capacityDisplay} ${m.type} ${m.speedDisplay} | ${l10n.isPersian ? "پارت" : "P/N"}: $mPart | ${l10n.isPersian ? "سریال" : "S/N"}: $mSerial',
      );
    }

    if (info.gpu.isNotEmpty) {
      final gpuList = info.gpu
          .map(
            (g) =>
                '${g.name}${g.vramDisplay != 'Not available' ? ' (${g.vramDisplay})' : ''}',
          )
          .join(', ');
      buffer.writeln('${l10n.gpu}: $gpuList');
    } else {
      buffer.writeln('${l10n.gpu}: ${l10n.noGpuDetected}');
    }

    final mbName = info.motherboard.model != 'Not available'
        ? info.motherboard.model
        : info.motherboard.manufacturer;
    final mbSerial =
        (info.motherboard.serial.isNotEmpty &&
            info.motherboard.serial != 'Not available' &&
            info.motherboard.serial != 'Default string')
        ? info.motherboard.serial
        : '-';
    buffer.writeln(
      '${l10n.motherboard}: $mbName | ${l10n.isPersian ? "سریال" : "S/N"}: $mbSerial',
    );
    if (info.motherboard.uuid.isNotEmpty && info.motherboard.uuid != '-') {
      buffer.writeln('  - UUID: ${info.motherboard.uuid}');
    }

    if (info.storage.isNotEmpty) {
      buffer.writeln('${l10n.storage}:');
      for (final d in info.storage) {
        final dSerial = (d.serial.isNotEmpty && d.serial != 'Not available')
            ? d.serial
            : '-';
        final dPart =
            (d.partNumber.isNotEmpty &&
                d.partNumber != '-' &&
                d.partNumber != d.model)
            ? ' | ${l10n.isPersian ? "پارت" : "P/N"}: ${d.partNumber}'
            : '';
        buffer.writeln(
          '  - ${d.capacityDisplay} ${d.type} (${d.model})$dPart | ${l10n.isPersian ? "سریال" : "S/N"}: $dSerial',
        );
      }
    } else {
      buffer.writeln('${l10n.storage}: ${l10n.noStorageDetected}');
    }

    final winAct = info.windowsActivation.activated
        ? l10n.activated
        : l10n.notActivated;
    buffer.writeln(
      '${l10n.windows}: ${info.windows.edition} (${info.windows.architecture}) - ${l10n.activation}: $winAct',
    );

    if (info.officeActivation.installed) {
      final offAct = info.officeActivation.activated
          ? l10n.activated
          : l10n.notActivated;
      buffer.writeln(
        '${l10n.microsoftOffice}: ${info.officeActivation.product} (${info.officeActivation.version}) - ${l10n.activation}: $offAct',
      );
    } else {
      buffer.writeln('${l10n.microsoftOffice}: ${l10n.notInstalled}');
    }

    if (info.drivers.isNotEmpty) {
      buffer.writeln('\n[${l10n.drivers}]');
      for (final d in info.drivers) {
        final st = !d.isPresent
            ? l10n.notPresent
            : (d.isHealthy ? l10n.driverOk : l10n.driverProblem);
        buffer.writeln('- ${d.displayName} (${d.deviceName}): $st');
      }
    }

    if (packagesRes != null && packagesRes.packages.isNotEmpty) {
      buffer.writeln('\n[${l10n.availableSoftware}]');
      for (final p in packagesRes.packages) {
        final st = !p.isValid
            ? (l10n.isPersian ? 'مسدود/فایل نامعتبر' : 'Blocked/invalid file')
            : (p.isInstalled
                  ? '${l10n.installed} (${p.version})'
                  : l10n.notInstalled);
        buffer.writeln('- ${p.name} (${p.filename}): $st');
      }
    } else if (info.software.isNotEmpty) {
      buffer.writeln('\n[${l10n.software}]');
      for (final s in info.software) {
        final statusStr = s.isInstalled
            ? '${l10n.installed} (${s.version})'
            : l10n.notInstalled;
        buffer.writeln('- ${s.displayName}: $statusStr');
      }
    }

    if (info.requiredFiles.isNotEmpty) {
      buffer.writeln('\n[${l10n.requiredFiles}]');
      for (final f in info.requiredFiles) {
        final statusStr = f.exists ? l10n.present : l10n.missing;
        buffer.writeln('- ${f.displayName}: $statusStr');
      }
    }

    if (info.proxy.hasManualProxy) {
      buffer.writeln('\n[پروکسی دستی ویندوز]');
      buffer.writeln('وضعیت: روشن (${info.proxy.server})');
    }

    return buffer.toString();
  }

  Future<void> disableProxy(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    isDisablingProxy.value = true;
    try {
      final res = await _apiService.disableProxy();
      final success = res['success'] == true;
      final msg =
          res['message'] as String? ??
          (success
              ? (l10n.isPersian
                    ? '✓ پروکسی دستی با موفقیت خاموش شد.'
                    : '✓ Manual proxy disabled successfully.')
              : 'خطا در خاموش کردن پروکسی');

      if (context.mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: success
                ? const Color(0xFF10B981)
                : const Color(0xFFEF4444),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      await fetchSystemInfo(forceRefresh: true);
    } catch (e) {
      if (context.mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('خطا در خاموش کردن پروکسی: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      isDisablingProxy.value = false;
    }
  }

  Future<void> restartSystemInteractive(
    BuildContext context, {
    int delaySeconds = 4,
    String reason = '',
  }) async {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF131D33) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(
              Icons.restart_alt_rounded,
              color: Color(0xFF2563EB),
              size: 24,
            ),
            const SizedBox(width: 10),
            Text(
              l10n.isPersian ? 'ری‌استارت سیستم' : 'Restart System',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? const Color(0xFFF1F5F9)
                    : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        content: Text(
          l10n.isPersian
              ? 'جهت اعمال و شناسایی کامل درایورها و بسته‌های نصب‌شده، آیا مایل به ری‌استارت سیستم هستید؟'
              : 'To finalize and detect all installed drivers and packages, do you want to restart the system now?',
          style: TextStyle(
            fontSize: 14,
            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            icon: const Icon(Icons.restart_alt_rounded, size: 16),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            label: Text(l10n.isPersian ? 'ری‌استارت الآن' : 'Restart Now'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      isRestarting.value = true;
      try {
        bool success = false;
        String msg = '';

        // 1. Try Backend API
        try {
          final res = await _apiService.restartSystem(
            delaySeconds: delaySeconds,
            reason: reason,
          );
          if (res['success'] == true) {
            success = true;
            msg =
                res['message'] as String? ??
                (l10n.isPersian
                    ? 'سیستم تا $delaySeconds ثانیه دیگر ری‌استارت می‌شود...'
                    : 'System restarting in $delaySeconds seconds...');
          }
        } catch (_) {}

        // 2. Direct Native Windows Fallback if backend didn't restart
        if (!success && Platform.isWindows) {
          try {
            final proc = await Process.run('shutdown.exe', [
              '/r',
              '/t',
              '$delaySeconds',
              '/f',
            ]);
            if (proc.exitCode == 0) {
              success = true;
              msg = l10n.isPersian
                  ? 'سیستم تا $delaySeconds ثانیه دیگر ری‌استارت می‌شود...'
                  : 'System restarting in $delaySeconds seconds...';
            } else {
              // Try PowerShell
              final psProc = await Process.run('powershell', [
                '-NoProfile',
                '-NonInteractive',
                '-Command',
                'Restart-Computer -Force',
              ]);
              if (psProc.exitCode == 0) {
                success = true;
                msg = l10n.isPersian
                    ? 'سیستم در حال ری‌استارت است...'
                    : 'System restarting...';
              }
            }
          } catch (_) {}
        }

        if (context.mounted) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(
                success
                    ? msg
                    : (l10n.isPersian
                          ? 'خطا در اجرای ری‌استارت خودکار سیستم'
                          : 'Error restarting system'),
              ),
              backgroundColor: success
                  ? const Color(0xFF2563EB)
                  : const Color(0xFFEF4444),
              duration: Duration(seconds: delaySeconds + 3),
              behavior: SnackBarBehavior.floating,
              action: success
                  ? SnackBarAction(
                      label: l10n.isPersian ? 'لغو ری‌استارت' : 'Cancel',
                      textColor: Colors.amber,
                      onPressed: () => cancelRestart(context),
                    )
                  : null,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('Error restarting: $e'),
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } finally {
        isRestarting.value = false;
      }
    }
  }

  Future<void> cancelRestart(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      bool success = false;
      try {
        final res = await _apiService.cancelRestart();
        if (res['success'] == true) success = true;
      } catch (_) {}

      if (Platform.isWindows) {
        try {
          final proc = await Process.run('shutdown.exe', ['/a']);
          if (proc.exitCode == 0) success = true;
        } catch (_) {}
      }

      if (context.mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? (l10n.isPersian
                        ? 'دستور ری‌استارت سیستم لغو شد.'
                        : 'Restart cancelled.')
                  : (l10n.isPersian
                        ? 'دستور ری‌استارت فعالی یافت نشد.'
                        : 'No active restart.'),
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {}
  }

  // -------------------------------------------------------------
  // Live USB Flash Drives & Safe Eject
  // -------------------------------------------------------------

  Future<void> fetchUsbDrives() async {
    try {
      final list = await _apiService.getConnectedUsbDrives();
      usbDrives.assignAll(list);
    } catch (e) {
      debugPrint('[SystemInfoController] fetchUsbDrives error: $e');
    }
  }

  Future<void> fetchStorageInfo() async {
    try {
      final list = await _apiService.fetchStorageInfo();
      if (list.isNotEmpty && systemInfo.value != null) {
        systemInfo.value = systemInfo.value!.copyWith(storage: list);
      }
    } catch (e) {
      debugPrint('[SystemInfoController] fetchStorageInfo error: $e');
    }
  }

  Future<void> safeEjectDrive(BuildContext context, String driveLetter) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.eject_rounded, color: Color(0xFFEF4444)),
            const SizedBox(width: 8),
            Text(
              l10n.isPersian ? 'خروج ایمن فلش مموری' : 'Safely Eject USB Drive',
            ),
          ],
        ),
        content: Text(
          l10n.isPersian
              ? 'آیا از خروج ایمن فلش مموری $driveLetter مطمئن هستید؟\nارتباط فلش به صورت نرم‌افزاری متوقف شده و آماده جداسازی خواهد بود.'
              : 'Are you sure you want to safely disconnect USB drive $driveLetter?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.isPersian ? 'انصراف' : 'Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.isPersian ? 'خروج ایمن (Eject)' : 'Eject'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    isEjecting.value = true;
    try {
      final res = await _apiService.safeEjectDrive(driveLetter);
      await fetchUsbDrives();
      await fetchSystemInfo(forceRefresh: true);
      if (context.mounted) {
        final success = res['success'] == true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              res['message']?.toString() ??
                  (success
                      ? (l10n.isPersian
                            ? '✓ فلش مموری با موفقیت خارج شد.'
                            : '✓ Drive safely ejected.')
                      : (l10n.isPersian
                            ? 'خطا در خروج درایو'
                            : 'Failed to eject drive')),
            ),
            backgroundColor: success
                ? const Color(0xFF10B981)
                : const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      isEjecting.value = false;
    }
  }
}
