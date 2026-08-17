// frontend/lib/controllers/qc_controller.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../l10n/app_localizations.dart';
import '../models/qc_report.dart';
import '../services/api_service.dart';
import 'activation_controller.dart';
import 'software_controller.dart';
import 'system_info_controller.dart';

class QcController extends GetxController {
  final ApiService _apiService = ApiService();

  final RxBool isChecking = false.obs;
  final RxInt currentStepIndex = 0.obs;
  final RxString currentStepName = ''.obs;
  final Rx<QcReport?> qcReport = Rx<QcReport?>(null);
  final RxBool hasRunFullCheck = false.obs;

  // Batch Preparation States
  final RxBool isPreparing = false.obs;
  final RxString batchProgressText = ''.obs;
  final RxInt batchCurrentIndex = 0.obs;
  final RxInt batchTotalCount = 0.obs;

  @override
  void onInit() {
    super.onInit();
    // Load initial QC status when controller initializes
    fetchInitialQcStatus();
  }

  Future<void> fetchInitialQcStatus() async {
    try {
      final report = await _apiService.fetchQcStatus();
      qcReport.value = report;
    } catch (_) {}
  }

  /// 8 Check Steps for Animated Progress UI
  List<String> getCheckStepKeys() {
    return [
      'qcStepHardware',
      'qcStepWindows',
      'qcStepDrivers',
      'qcStepSoftware',
      'qcStepFiles',
      'qcStepWindowsActivation',
      'qcStepOfficeInstallation',
      'qcStepOfficeActivation',
    ];
  }

  String getStepTitle(String key, AppLocalizations l10n) {
    switch (key) {
      case 'qcStepHardware':
        return l10n.isPersian ? 'بررسی سخت‌افزار' : 'Hardware Information';
      case 'qcStepWindows':
        return l10n.isPersian ? 'بررسی ویندوز' : 'Windows Information';
      case 'qcStepDrivers':
        return l10n.isPersian ? 'بررسی درایورها' : 'Important Drivers';
      case 'qcStepSoftware':
        return l10n.isPersian ? 'بررسی نرم‌افزارها' : 'Required Software';
      case 'qcStepFiles':
        return l10n.isPersian ? 'بررسی فایل‌ها و پوشه‌ها' : 'Required Files & Folders';
      case 'qcStepWindowsActivation':
        return l10n.isPersian ? 'بررسی فعال‌سازی ویندوز' : 'Windows Activation';
      case 'qcStepOfficeInstallation':
        return l10n.isPersian ? 'بررسی نصب آفیس' : 'Office Installation';
      case 'qcStepOfficeActivation':
        return l10n.isPersian ? 'بررسی فعال‌سازی آفیس' : 'Office Activation';
      default:
        return key;
    }
  }

  Future<void> runFullCheck(BuildContext context) async {
    if (isChecking.value) return;

    final l10n = AppLocalizations.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final steps = getCheckStepKeys();

    isChecking.value = true;
    currentStepIndex.value = 0;
    currentStepName.value = getStepTitle(steps[0], l10n);

    // Show Progress Dialog
    _showProgressDialog(context);

    try {
      // Step through animation steps cleanly
      for (int i = 0; i < steps.length; i++) {
        currentStepIndex.value = i;
        currentStepName.value = getStepTitle(steps[i], l10n);
        await Future.delayed(const Duration(milliseconds: 320));
      }

      // Execute live backend QC evaluation
      final report = await _apiService.runQcCheck();
      qcReport.value = report;
      hasRunFullCheck.value = true;

      // Also refresh SystemInfoController and SoftwareController in sync
      if (Get.isRegistered<SystemInfoController>()) {
        Get.find<SystemInfoController>().fetchSystemInfo(forceRefresh: true);
      }
      if (Get.isRegistered<SoftwareController>()) {
        Get.find<SoftwareController>().fetchPackages();
      }

      // Close progress dialog if open
      if (context.mounted && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      // Show result snackbar
      if (context.mounted) {
        if (report.isReady) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(
                l10n.isPersian
                    ? '✓ بررسی کامل سیستم انجام شد: سیستم کاملاً آماده است.'
                    : '✓ Full check completed: System is Ready.',
              ),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(
                l10n.isPersian
                    ? '⚠ بررسی کامل انجام شد: ${report.problemsCount} مورد نیاز به بررسی دارد.'
                    : '⚠ Full check completed: ${report.problemsCount} item(s) need attention.',
              ),
              backgroundColor: const Color(0xFFD97706),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (context.mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Error running full check: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      isChecking.value = false;
    }
  }

  void _showProgressDialog(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final steps = getCheckStepKeys();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: 440,
            padding: const EdgeInsets.all(24),
            child: Obx(() {
              final activeIdx = currentStepIndex.value;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.shield_outlined, color: Color(0xFF2563EB), size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.isPersian ? 'بررسی کامل سیستم' : 'Full System Check',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l10n.isPersian ? 'پایش خودکار و ارزیابی بخش‌های سیستم...' : 'Automated inspection in progress...',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Linear Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (activeIdx + 1) / steps.length,
                      minHeight: 6,
                      backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Checklist Items
                  ...steps.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final key = entry.value;
                    final title = getStepTitle(key, l10n);

                    Widget statusIcon;
                    Color titleColor;

                    if (idx < activeIdx) {
                      statusIcon = const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18);
                      titleColor = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155);
                    } else if (idx == activeIdx) {
                      statusIcon = const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                        ),
                      );
                      titleColor = const Color(0xFF2563EB);
                    } else {
                      statusIcon = Icon(
                        Icons.radio_button_unchecked_rounded,
                        color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                        size: 18,
                      );
                      titleColor = isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          statusIcon,
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: idx == activeIdx ? FontWeight.w700 : FontWeight.w500,
                                color: titleColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }

  /// Executes single clickable fix action
  Future<void> executeSingleAction(BuildContext context, QcIssue issue) async {
    final l10n = AppLocalizations.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    if (issue.actionType == 'install_software') {
      if (Get.isRegistered<SoftwareController>()) {
        final softCtrl = Get.find<SoftwareController>();
        final pkg = softCtrl.packages.firstWhereOrNull(
          (p) => p.id == issue.actionTarget || p.filename == issue.packageFilename || p.name == issue.name,
        );
        if (pkg != null) {
          await softCtrl.installPackageInteractive(context, pkg);
          // Auto re-check
          await Future.delayed(const Duration(seconds: 2));
          await fetchInitialQcStatus();
        } else {
          if (context.mounted) {
            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: Text('فایل نصبی برای ${issue.name} در پوشه Packages یافت نشد.'),
                backgroundColor: const Color(0xFFEF4444),
              ),
            );
          }
        }
      }
    } else if (issue.actionType == 'activate_windows') {
      if (Get.isRegistered<ActivationController>()) {
        await Get.find<ActivationController>().activateWindows(context);
        await Future.delayed(const Duration(seconds: 2));
        await fetchInitialQcStatus();
      }
    } else if (issue.actionType == 'activate_office') {
      if (Get.isRegistered<ActivationController>()) {
        await Get.find<ActivationController>().activateOffice(context);
        await Future.delayed(const Duration(seconds: 2));
        await fetchInitialQcStatus();
      }
    } else if (issue.actionType == 'disable_proxy') {
      if (Get.isRegistered<SystemInfoController>()) {
        await Get.find<SystemInfoController>().disableProxy(context);
        await Future.delayed(const Duration(seconds: 1));
        await fetchInitialQcStatus();
      }
    } else if (issue.actionType == 'open_folder') {
      final target = issue.actionTarget;
      final folderPath = FileSystemEntity.isDirectorySync(target) ? target : File(target).parent.path;
      if (Directory(folderPath).existsSync()) {
        Process.run('explorer.exe', [folderPath]);
      } else {
        if (context.mounted) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('${l10n.isPersian ? "مسیر پوشه وجود ندارد" : "Folder does not exist"}: $folderPath'),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        }
      }
    }
  }

  /// Batch Prepare System Execution
  Future<void> executeBatchPreparation(BuildContext context, List<QcIssue> selectedIssues) async {
    if (isPreparing.value || selectedIssues.isEmpty) return;

    final l10n = AppLocalizations.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    isPreparing.value = true;
    batchTotalCount.value = selectedIssues.length;
    batchCurrentIndex.value = 0;

    _showBatchProgressDialog(context);

    try {
      for (int i = 0; i < selectedIssues.length; i++) {
        final issue = selectedIssues[i];
        batchCurrentIndex.value = i + 1;
        batchProgressText.value = '${issue.actionLabel}: ${issue.name}';

        if (issue.actionType == 'install_software') {
          await _apiService.installPackage(issue.actionTarget);
        } else if (issue.actionType == 'activate_windows') {
          await _apiService.activateWindows();
        } else if (issue.actionType == 'activate_office') {
          await _apiService.activateOffice();
        } else if (issue.actionType == 'disable_proxy') {
          await _apiService.disableProxy();
        }

        // Small breathing delay between batch tasks
        await Future.delayed(const Duration(milliseconds: 600));
      }

      // Automatically re-evaluate full system QC
      batchProgressText.value = l10n.isPersian ? 'در حال بررسی مجدد وضعیت سیستم...' : 'Re-checking system status...';
      final updatedReport = await _apiService.runQcCheck();
      qcReport.value = updatedReport;

      // Close batch dialog
      if (context.mounted && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (context.mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              l10n.isPersian
                  ? '✓ آماده‌سازی سیستم با موفقیت به پایان رسید.'
                  : '✓ System preparation completed successfully.',
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (context.mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Error during preparation: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      isPreparing.value = false;
    }
  }

  void _showBatchProgressDialog(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(24),
            child: Obx(() {
              final current = batchCurrentIndex.value;
              final total = batchTotalCount.value;
              final text = batchProgressText.value;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(strokeWidth: 3.5, color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l10n.isPersian ? 'در حال آماده‌سازی سیستم' : 'Preparing System',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    text,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF2563EB),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '$current / $total',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }
}
