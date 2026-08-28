import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/system_info.dart';
import '../services/api_service.dart';
import '../services/folder_picker_service.dart';
import 'system_info_controller.dart';

class DriverInstallController extends GetxController {
  final ApiService _apiService = ApiService();

  final RxString driverFolder = ''.obs;
  final RxList<ScannedDriverFile> scannedFiles = <ScannedDriverFile>[].obs;
  final RxBool isScanning = false.obs;
  final RxBool isBatchInstalling = false.obs;
  final Rx<DriverBatchStatus> batchStatus = DriverBatchStatus.empty().obs;

  Timer? _pollTimer;

  @override
  void onInit() {
    super.onInit();
    _checkInitialDriverBatchStatus();
  }

  @override
  void onClose() {
    _pollTimer?.cancel();
    super.onClose();
  }

  Future<void> _checkInitialDriverBatchStatus() async {
    try {
      final status = await _apiService.getDriverBatchStatus();
      batchStatus.value = status;
      if (status.isRunning) {
        isBatchInstalling.value = true;
        driverFolder.value = status.folderPath;
        _startDriverBatchPolling(null);
      }
    } catch (_) {}
  }

  Future<void> selectFolderAndScan(BuildContext context) async {
    final selectedPath = await FolderPickerService.pickFolder(
      title: 'انتخاب پوشه حاوی فایل‌های نصبی درایور',
    );

    if (selectedPath != null && selectedPath.isNotEmpty) {
      driverFolder.value = selectedPath;
      if (context.mounted) {
        await scanFolder(context, selectedPath);
      }
    }
  }

  Future<void> scanFolder(BuildContext context, String folderPath) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    isScanning.value = true;
    try {
      final res = await _apiService.scanDriverFolder(folderPath);
      final success = res['success'] == true;
      final rawFiles = res['files'] as List<dynamic>? ?? [];

      scannedFiles.value = rawFiles
          .map((e) => ScannedDriverFile.fromJson(e as Map<String, dynamic>))
          .toList();
      final autoCount = scannedFiles
          .where((file) => file.isValid && file.autoInstallSupported)
          .length;
      final blockedCount = scannedFiles.where((file) => !file.isValid).length;
      final manualCount = scannedFiles.length - autoCount - blockedCount;

      if (!success || scannedFiles.isEmpty) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              res['message'] as String? ??
                  'هیچ فایل درایوری (.exe, .msi, .inf, .zip, .cab) در این پوشه یافت نشد.',
            ),
            backgroundColor: const Color(0xFFF59E0B),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      // Show confirmation dialog with list of discovered drivers
      if (context.mounted) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            backgroundColor: isDark ? const Color(0xFF131D33) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D9488).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.drive_file_rename_outline_rounded,
                    color: Color(0xFF0D9488),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'درایورهای یافت‌شده برای نصب خودکار',
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
            content: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${scannedFiles.length} فایل یافت شد: $autoCount خودکار، $manualCount دستی و $blockedCount مسدود',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? const Color(0xFFE2E8F0)
                          : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    folderPath,
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'Consolas',
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 220),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: scannedFiles.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 8),
                      itemBuilder: (_, idx) {
                        final file = scannedFiles[idx];
                        Color typeColor = const Color(0xFF2563EB);
                        if (file.type == 'inf') {
                          typeColor = const Color(0xFF10B981);
                        }
                        if (file.type == 'msi') {
                          typeColor = const Color(0xFF8B5CF6);
                        }
                        if (!file.isValid) typeColor = const Color(0xFFEF4444);
                        if (file.isValid && !file.autoInstallSupported) {
                          typeColor = const Color(0xFFF59E0B);
                        }

                        return Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: typeColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                file.type.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: typeColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                file.filename,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? const Color(0xFFCBD5E1)
                                      : const Color(0xFF334155),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              file.fileSizeDisplay,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? const Color(0xFF64748B)
                                    : const Color(0xFF94A3B8),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Tooltip(
                              message: file.validationError ?? '',
                              child: Icon(
                                !file.isValid
                                    ? Icons.gpp_bad_outlined
                                    : (file.autoInstallSupported
                                          ? Icons.check_circle_outline
                                          : Icons.pan_tool_outlined),
                                size: 16,
                                color: typeColor,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          size: 18,
                          color: Color(0xFF0D9488),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'نصب درایورها به ترتیب و به صورت کاملاً خودکار انجام می‌شود و ری‌استارت خودکار جلوگیری خواهد شد.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF0D9488),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(false),
                child: const Text('انصراف'),
              ),
              ElevatedButton.icon(
                onPressed: autoCount > 0
                    ? () => Navigator.of(dialogCtx).pop(true)
                    : null,
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                label: Text('شروع نصب خودکار ($autoCount)'),
              ),
            ],
          ),
        );

        if (confirmed == true && context.mounted) {
          await startDriverAutoInstall(context, folderPath);
        }
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('خطا در اسکن پوشه: $e'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      isScanning.value = false;
    }
  }

  Future<void> startDriverAutoInstall(
    BuildContext context,
    String folderPath,
  ) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    isBatchInstalling.value = true;

    try {
      final res = await _apiService.startDriverBatchInstall(folderPath);
      if (res['success'] == true) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              res['message'] as String? ?? 'نصب خودکار درایورها شروع شد...',
            ),
            backgroundColor: const Color(0xFF0D9488),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _startDriverBatchPolling(scaffoldMessenger);
      } else {
        isBatchInstalling.value = false;
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              res['message'] as String? ?? 'خطا در شروع نصب درایورها.',
            ),
            backgroundColor: const Color(0xFFEF4444),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      isBatchInstalling.value = false;
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('خطا: $e'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _startDriverBatchPolling(ScaffoldMessengerState? scaffoldMessenger) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 1500), (
      timer,
    ) async {
      try {
        final status = await _apiService.getDriverBatchStatus();
        batchStatus.value = status;

        if (!status.isRunning) {
          timer.cancel();
          isBatchInstalling.value = false;

          // Refresh system info to update driver status and record driver install
          try {
            if (Get.isRegistered<SystemInfoController>()) {
              if (status.completed > 0) {
                Get.find<SystemInfoController>().recordDriverInstall(
                  status.completed,
                );
              }
              Get.find<SystemInfoController>().fetchSystemInfo(
                forceRefresh: true,
              );
            }
          } catch (_) {}

          if (scaffoldMessenger != null && status.summaryMessage.isNotEmpty) {
            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: Text(status.summaryMessage),
                backgroundColor: status.failed == 0
                    ? const Color(0xFF0D9488)
                    : const Color(0xFFF59E0B),
                duration: const Duration(seconds: 7),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('[DriverInstallController] Batch poll error: $e');
      }
    });
  }

  Future<void> cancelDriverAutoInstall(BuildContext context) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      final res = await _apiService.cancelDriverBatchInstall();
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(res['message'] as String? ?? 'دستور لغو ارسال شد.'),
          backgroundColor: const Color(0xFF64748B),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('خطا در لغو: $e'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
