import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../l10n/app_localizations.dart';
import '../models/system_info.dart';
import '../services/api_service.dart';
import '../services/folder_picker_service.dart';
import 'system_info_controller.dart';

class ActivationController extends GetxController {
  final ApiService _apiService = ApiService();

  final RxBool isActivatingWindows = false.obs;
  final RxBool isActivatingOffice = false.obs;

  final Rx<ActivationResult?> lastWindowsResult = Rx<ActivationResult?>(null);
  final Rx<ActivationResult?> lastOfficeResult = Rx<ActivationResult?>(null);

  Future<void> changeToolsDirectory(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final selectedPath = await FolderPickerService.pickFolder(
      title: l10n.isPersian ? 'انتخاب پوشه ابزارهای فعالسازی (KMS Tools)' : 'Select KMS Activation Tools Folder',
    );

    if (selectedPath != null && selectedPath.isNotEmpty) {
      try {
        final success = await _apiService.setToolsDirectory(selectedPath);
        if (success) {
          if (Get.isRegistered<SystemInfoController>()) {
            Get.find<SystemInfoController>().fetchSystemInfo(forceRefresh: true);
          }
          if (context.mounted) {
            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: Text(
                  l10n.isPersian
                      ? '✓ پوشه فعالسازها به $selectedPath تغییر یافت.'
                      : '✓ Activation tools folder updated: $selectedPath',
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
              content: Text('Error setting tools directory: $e'),
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  /// Auto-polling to detect newly applied activation status in real-time
  void _triggerAutoDetectPolling() {
    if (!Get.isRegistered<SystemInfoController>()) return;
    final sysCtrl = Get.find<SystemInfoController>();

    // Step 1: Immediate re-scan
    sysCtrl.fetchSystemInfo(forceRefresh: true);

    // Step 2: Progressive follow-up polls (1.5s, 4s, 8s, 12s)
    const intervals = [1500, 4000, 8000, 12000];
    for (final ms in intervals) {
      Future.delayed(Duration(milliseconds: ms), () {
        sysCtrl.fetchSystemInfo(forceRefresh: true);
      });
    }
  }

  Future<void> activateWindows(BuildContext context) async {
    if (isActivatingWindows.value) return;

    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF131D33) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF0284C7), size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.confirmActivateWindowsTitle,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
        content: Text(
          l10n.confirmActivateWindowsMessage,
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
            icon: const Icon(Icons.verified_user_rounded, size: 16),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            label: Text(l10n.activateWindows),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      isActivatingWindows.value = true;
      try {
        final result = await _apiService.activateWindows();
        lastWindowsResult.value = result;

        if (result.cancelled) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(l10n.activationCancelled),
              backgroundColor: const Color(0xFF64748B),
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else if (result.success) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('✓ ${l10n.windowsActivationCompleted}'),
              backgroundColor: const Color(0xFF10B981),
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
            ),
          );
          _triggerAutoDetectPolling();
        } else {
          final errorText = result.output.isNotEmpty ? result.output : result.message;
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('✕ ${l10n.windowsActivationFailed}: $errorText'),
              backgroundColor: const Color(0xFFEF4444),
              duration: const Duration(seconds: 5),
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: l10n.retry,
                textColor: Colors.white,
                onPressed: () => activateWindows(context),
              ),
            ),
          );
          _triggerAutoDetectPolling();
        }
      } catch (e) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('✕ ${l10n.windowsActivationFailed}: $e'),
            backgroundColor: const Color(0xFFEF4444),
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } finally {
        isActivatingWindows.value = false;
      }
    }
  }

  Future<void> activateOffice(BuildContext context) async {
    if (isActivatingOffice.value) return;

    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF131D33) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFFD97706), size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.confirmActivateOfficeTitle,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
        content: Text(
          l10n.confirmActivateOfficeMessage,
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
            icon: const Icon(Icons.verified_user_rounded, size: 16),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            label: Text(l10n.activateOffice),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      isActivatingOffice.value = true;
      try {
        final result = await _apiService.activateOffice();
        lastOfficeResult.value = result;

        if (result.cancelled) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(l10n.activationCancelled),
              backgroundColor: const Color(0xFF64748B),
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else if (result.success) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('✓ ${l10n.officeActivationCompleted}'),
              backgroundColor: const Color(0xFF10B981),
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
            ),
          );
          _triggerAutoDetectPolling();
        } else {
          final errorText = result.output.isNotEmpty ? result.output : result.message;
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('✕ ${l10n.officeActivationFailed}: $errorText'),
              backgroundColor: const Color(0xFFEF4444),
              duration: const Duration(seconds: 5),
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: l10n.retry,
                textColor: Colors.white,
                onPressed: () => activateOffice(context),
              ),
            ),
          );
          _triggerAutoDetectPolling();
        }
      } catch (e) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('✕ ${l10n.officeActivationFailed}: $e'),
            backgroundColor: const Color(0xFFEF4444),
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } finally {
        isActivatingOffice.value = false;
      }
    }
  }
}
