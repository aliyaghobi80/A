import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../l10n/app_localizations.dart';
import '../models/system_info.dart';
import '../services/api_service.dart';
import '../services/folder_picker_service.dart';

class SystemInfoController extends GetxController {
  final ApiService _apiService = ApiService();

  final Rx<SystemInfo?> systemInfo = Rx<SystemInfo?>(null);
  final RxBool isLoading = true.obs;
  final RxBool isRefreshing = false.obs;
  final RxBool isDisablingProxy = false.obs;
  final RxBool isRestarting = false.obs;
  final RxString errorMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    fetchSystemInfo();
  }

  Future<void> changeFileRequirementPath(BuildContext context, String reqId, String reqName) async {
    final l10n = AppLocalizations.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final selectedPath = await FolderPickerService.pickFolder(
      title: '${l10n.isPersian ? "انتخاب مسیر برای" : "Select Path for"} $reqName',
    );

    if (selectedPath != null && selectedPath.isNotEmpty) {
      try {
        final success = await _apiService.setFilesDirectory(reqId, selectedPath);
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
    if (forceRefresh) {
      isRefreshing.value = true;
    } else {
      isLoading.value = true;
    }
    errorMessage.value = '';

    try {
      final info = await _apiService.fetchSystemInfo(forceRefresh: forceRefresh);
      systemInfo.value = info;
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
      isRefreshing.value = false;
    }
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

  String buildAllSpecsSummary(AppLocalizations l10n, PackagesResponse? packagesRes) {
    final info = systemInfo.value;
    if (info == null) return '';

    final buffer = StringBuffer();
    buffer.writeln('=== ${l10n.appName} ===');
    buffer.writeln('[${l10n.hardware}]');
    buffer.writeln('${l10n.cpu}: ${info.cpu.name}');
    buffer.writeln('${l10n.ram}: ${info.ram.totalDisplay}${info.ram.speedDisplay != 'Not available' ? ' (${info.ram.speedDisplay})' : ''}');

    if (info.gpu.isNotEmpty) {
      final gpuList = info.gpu.map((g) => '${g.name}${g.vramDisplay != 'Not available' ? ' (${g.vramDisplay})' : ''}').join(', ');
      buffer.writeln('${l10n.gpu}: $gpuList');
    } else {
      buffer.writeln('${l10n.gpu}: ${l10n.noGpuDetected}');
    }

    buffer.writeln('${l10n.motherboard}: ${info.motherboard.model != 'Not available' ? info.motherboard.model : info.motherboard.manufacturer}');

    if (info.storage.isNotEmpty) {
      final drives = info.storage.map((d) => '${d.capacityDisplay} ${d.type} (${d.model})').join('\n  - ');
      buffer.writeln('${l10n.storage}:\n  - $drives');
    } else {
      buffer.writeln('${l10n.storage}: ${l10n.noStorageDetected}');
    }

    final winAct = info.windowsActivation.activated ? l10n.activated : l10n.notActivated;
    buffer.writeln('${l10n.windows}: ${info.windows.edition} (${info.windows.architecture}) - ${l10n.activation}: $winAct');

    if (info.officeActivation.installed) {
      final offAct = info.officeActivation.activated ? l10n.activated : l10n.notActivated;
      buffer.writeln('${l10n.microsoftOffice}: ${info.officeActivation.product} (${info.officeActivation.version}) - ${l10n.activation}: $offAct');
    } else {
      buffer.writeln('${l10n.microsoftOffice}: ${l10n.notInstalled}');
    }

    if (info.drivers.isNotEmpty) {
      buffer.writeln('\n[${l10n.drivers}]');
      for (final d in info.drivers) {
        final st = !d.isPresent ? l10n.notPresent : (d.isHealthy ? l10n.driverOk : l10n.driverProblem);
        buffer.writeln('- ${d.displayName} (${d.deviceName}): $st');
      }
    }

    if (packagesRes != null && packagesRes.packages.isNotEmpty) {
      buffer.writeln('\n[${l10n.availableSoftware}]');
      for (final p in packagesRes.packages) {
        final st = p.isInstalled ? '${l10n.installed} (${p.version})' : l10n.notInstalled;
        buffer.writeln('- ${p.name} (${p.filename}): $st');
      }
    } else if (info.software.isNotEmpty) {
      buffer.writeln('\n[${l10n.software}]');
      for (final s in info.software) {
        final statusStr = s.isInstalled ? '${l10n.installed} (${s.version})' : l10n.notInstalled;
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
      final msg = res['message'] as String? ?? (success ? (l10n.isPersian ? '✓ پروکسی دستی با موفقیت خاموش شد.' : '✓ Manual proxy disabled successfully.') : 'خطا در خاموش کردن پروکسی');

      if (context.mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: success ? const Color(0xFF10B981) : const Color(0xFFEF4444),
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

  Future<void> restartSystemInteractive(BuildContext context, {int delaySeconds = 4, String reason = ''}) async {
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
            const Icon(Icons.restart_alt_rounded, color: Color(0xFF2563EB), size: 24),
            const SizedBox(width: 10),
            Text(
              l10n.isPersian ? 'ری‌استارت سیستم' : 'Restart System',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            label: Text(l10n.isPersian ? 'ری‌استارت الآن' : 'Restart Now'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      isRestarting.value = true;
      try {
        final res = await _apiService.restartSystem(delaySeconds: delaySeconds, reason: reason);
        final success = res['success'] == true;
        final msg = res['message'] as String? ?? (success ? (l10n.isPersian ? 'سیستم به زودی ری‌استارت می‌شود...' : 'System restarting...') : 'خطا در ری‌استارت');

        if (context.mounted) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(msg),
              backgroundColor: success ? const Color(0xFF2563EB) : const Color(0xFFEF4444),
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
      final res = await _apiService.cancelRestart();
      final success = res['success'] == true;
      final msg = res['message'] as String? ?? (success ? (l10n.isPersian ? 'دستور ری‌استارت لغو شد.' : 'Restart cancelled.') : 'خطا');

      if (context.mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {}
  }
}
