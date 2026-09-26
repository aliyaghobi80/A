import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/system_info.dart';
import '../services/api_service.dart';
import '../services/folder_picker_service.dart';
import 'system_info_controller.dart';

Set<String> toggledSelectAll(Set<String> current, Set<String> selectable) {
  if (selectable.isEmpty) return Set<String>.from(current);
  final result = Set<String>.from(current);
  if (result.containsAll(selectable)) {
    result.removeAll(selectable);
  } else {
    result.addAll(selectable);
  }
  return result;
}

class DriverInstallController extends GetxController {
  final ApiService _apiService = ApiService();

  final RxString driverFolder = ''.obs;
  final RxBool isScanning = false.obs;
  final RxBool isBatchInstalling = false.obs;
  final Rx<DriverBatchStatus> batchStatus = DriverBatchStatus.empty().obs;
  final Rx<DriverScanResult> scanResult = DriverScanResult.empty().obs;
  final RxSet<String> selectedPackageIds = <String>{}.obs;
  final RxBool isAdvancedMode = false.obs;
  final RxList<RemovableDriverSource> removableSources =
      <RemovableDriverSource>[].obs;
  final RxList<ScannedDriverFile> scannedFiles =
      <ScannedDriverFile>[].obs; // For backwards compatibility

  Timer? _pollTimer;
  bool _pollInFlight = false;
  int _scanGeneration = 0;

  @override
  void onInit() {
    super.onInit();
    _loadInitialConfig();
    _checkInitialDriverBatchStatus();
  }

  @override
  void onClose() {
    _scanGeneration++;
    _pollTimer?.cancel();
    super.onClose();
  }

  Future<void> _loadInitialConfig() async {
    try {
      final cfg = await _apiService.getDriverDirectoryConfig();
      final path =
          cfg['resolved_path'] as String? ??
          cfg['configured_path'] as String? ??
          'Drivers';
      driverFolder.value = path;

      final rawRemovables = cfg['removable_sources'] as List<dynamic>? ?? [];
      removableSources.value = rawRemovables
          .map((e) => RemovableDriverSource.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[DriverInstallController] Error loading driver config: $e');
    }
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

  void toggleAdvancedMode() {
    isAdvancedMode.value = !isAdvancedMode.value;
  }

  void _replaceSelection(Iterable<String> packageIds) {
    selectedPackageIds.assignAll(packageIds);
    selectedPackageIds.refresh();
  }

  void togglePackageSelection(String packageId) {
    if (selectedPackageIds.contains(packageId)) {
      selectedPackageIds.remove(packageId);
    } else {
      selectedPackageIds.add(packageId);
    }
    selectedPackageIds.refresh();
  }

  /// All inspected packages are shown because the selected folder belongs to
  /// the current device model.  Hardware matching stays visible as guidance,
  /// but it must not silently remove OEM components from the user's queue.
  Set<String> get installablePackageIds =>
      scanResult.value.packages.map((package) => package.packageId).toSet();

  bool get areAllInstallableSelected {
    final ids = installablePackageIds;
    return ids.isNotEmpty && selectedPackageIds.containsAll(ids);
  }

  bool? get triStateSelectionValue {
    final ids = installablePackageIds;
    if (ids.isEmpty || selectedPackageIds.isEmpty) return false;
    final selectedCount = ids
        .where((id) => selectedPackageIds.contains(id))
        .length;
    if (selectedCount == 0) return false;
    if (selectedCount == ids.length) return true;
    return null; // Indeterminate
  }

  void selectAllPackages() {
    selectedPackageIds.assignAll(installablePackageIds);
    selectedPackageIds.refresh();
  }

  void clearSelection() {
    selectedPackageIds.clear();
    selectedPackageIds.refresh();
  }

  void toggleSelectAllPackages() {
    final ids = installablePackageIds;
    if (ids.isEmpty) return;
    if (areAllInstallableSelected) {
      clearSelection();
    } else {
      selectAllPackages();
    }
  }

  Future<void> selectFolderAndScan(BuildContext context) async {
    final selectedPath = await FolderPickerService.pickFolder(
      title: 'انتخاب پوشه حاوی فایل‌های نصبی درایور',
    );

    if (selectedPath != null && selectedPath.isNotEmpty) {
      driverFolder.value = selectedPath;
      await _apiService.setDriverDirectoryConfig(selectedPath);
      if (context.mounted) {
        await scanDrivers(context, folderPath: selectedPath);
      }
    }
  }

  Future<void> selectRemovableSource(
    BuildContext context,
    RemovableDriverSource source,
  ) async {
    driverFolder.value = source.driverPath;
    await _apiService.setDriverDirectoryConfig(source.driverPath);
    if (context.mounted) {
      await scanDrivers(context, folderPath: source.driverPath);
    }
  }

  Future<void> scanDrivers(BuildContext context, {String? folderPath}) async {
    if (isBatchInstalling.value || isClosed) return;
    final generation = ++_scanGeneration;
    final targetPath = folderPath ?? driverFolder.value;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    isScanning.value = true;
    _replaceSelection(const <String>{});

    try {
      final result = await _apiService.intelligentScanDrivers(
        folderPath: targetPath,
      );
      if (isClosed || generation != _scanGeneration) return;
      scanResult.value = result;

      // Update removable sources if discovered
      if (result.removableSources.isNotEmpty) {
        removableSources.value = result.removableSources;
      }

      // Populate scannedFiles for backwards compatibility
      scannedFiles.value = result.packages
          .map(
            (p) => ScannedDriverFile(
              filename: p.installerFile.isNotEmpty
                  ? p.installerFile
                  : p.displayName,
              relativePath: p.relativePath,
              fullPath: p.sourcePath,
              type: p.packageType,
              fileSizeDisplay: p.fileSizeDisplay,
              installerType: p.installMethod,
              autoInstallSupported: true,
              isValid: true,
            ),
          )
          .toList();

      // A driver repository is selected for this exact device model.  Queue
      // every inspected package by default; matching remains an informative
      // badge, not a hidden exclusion that leaves a device half-installed.
      _replaceSelection(result.packages.map((package) => package.packageId));

      if (!result.success || result.packages.isEmpty) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              result.message.isNotEmpty
                  ? result.message
                  : 'هیچ بسته درایور معتبری در این پوشه شناسایی نشد.',
            ),
            backgroundColor: const Color(0xFFF59E0B),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (isClosed || generation != _scanGeneration) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('خطا در اسکن درایورها: $e'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (!isClosed && generation == _scanGeneration) isScanning.value = false;
    }
  }

  // Compatibility wrapper
  Future<void> scanFolder(BuildContext context, String folderPath) async {
    await scanDrivers(context, folderPath: folderPath);
  }

  Future<void> installSelectedDrivers(BuildContext context) async {
    if (selectedPackageIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لطفاً حداقل یک بسته درایور را انتخاب کنید.'),
          backgroundColor: Color(0xFFF59E0B),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final selectedIds = Set<String>.from(selectedPackageIds).toList();
    final selectedCount = selectedIds.length;
    final confirmed = await _showInstallConfirmationDialog(
      context,
      title: 'تأیید نصب درایورهای انتخاب‌شده',
      message:
          'تعداد $selectedCount بسته درایور در صف نصب خودکار قرار خواهند گرفت.',
      packageIds: selectedIds,
    );

    if (confirmed == true && context.mounted) {
      await _executeDriverQueue(context, packageIds: selectedIds);
    }
  }

  Future<void> installAllDrivers(BuildContext context) async {
    final pkgs = scanResult.value.packages;
    final targetList = pkgs;

    if (targetList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('هیچ بسته درایور معتبری برای نصب وجود ندارد.'),
          backgroundColor: Color(0xFFF59E0B),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final confirmed = await _showInstallConfirmationDialog(
      context,
      title: 'تأیید نصب همه درایورها',
      message:
          'این ${targetList.length} بسته به ترتیب اجرا می‌شوند. سازگاری بسته‌های با مشخصات نامشخص توسط نصاب سازنده بررسی خواهد شد.',
      packageIds: targetList.map((p) => p.packageId).toList(),
    );

    if (confirmed == true && context.mounted) {
      await _executeDriverQueue(
        context,
        packageIds: targetList.map((p) => p.packageId).toList(),
      );
    }
  }

  Future<bool?> _showInstallConfirmationDialog(
    BuildContext context, {
    required String title,
    required String message,
    required List<String> packageIds,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pkgs = scanResult.value.packages
        .where((p) => packageIds.contains(p.packageId))
        .toList();

    return showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF131D33) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF0D9488).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.extension_rounded,
                color: Color(0xFF0D9488),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? const Color(0xFFF1F5F9)
                      : const Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? const Color(0xFFE2E8F0)
                      : const Color(0xFF1E293B),
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
                  itemCount: pkgs.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 8),
                  itemBuilder: (_, idx) {
                    final p = pkgs[idx];
                    return Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF0D9488,
                            ).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            p.categoryFa,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0D9488),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            p.displayName,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? const Color(0xFFCBD5E1)
                                  : const Color(0xFF334155),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          p.fileSizeDisplay,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? const Color(0xFF64748B)
                                : const Color(0xFF94A3B8),
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
                      Icons.shield_outlined,
                      size: 18,
                      color: Color(0xFF0D9488),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'نصب با دسترسی Administrator و ترتیب اولویت استاندارد (چیپست، شبکه، صدا، گرافیک) انجام خواهد شد.',
                        style: TextStyle(
                          fontSize: 11.5,
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
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            icon: const Icon(Icons.play_arrow_rounded, size: 18),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D9488),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            label: Text('شروع صف نصب (${pkgs.length})'),
          ),
        ],
      ),
    );
  }

  Future<void> _executeDriverQueue(
    BuildContext context, {
    List<String>? packageIds,
    bool resume = false,
  }) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    isBatchInstalling.value = true;

    try {
      final res = await _apiService.startDriverQueueInstall(
        packageIds: packageIds,
        folderPath: driverFolder.value,
        resume: resume,
      );

      if (res['success'] == true) {
        if (!resume) {
          batchStatus.value = DriverBatchStatus.empty();
        }
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              res['message'] as String? ?? 'صف نصب درایورها شروع شد...',
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
              res['message'] as String? ?? 'خطا در شروع صف نصب درایورها.',
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
    int lastCompletedCount = batchStatus.value.completed;
    _pollTimer = Timer.periodic(const Duration(milliseconds: 1500), (
      timer,
    ) async {
      if (_pollInFlight || isClosed) return;
      _pollInFlight = true;
      try {
        final status = await _apiService.getDriverQueueStatus();
        if (isClosed || timer != _pollTimer) return;
        batchStatus.value = status;

        // Update the session counters in real time, but do not launch a full
        // WMI/hardware refresh after every package. That refresh used to pile
        // up exactly while graphics installers were resetting the display.
        if (status.completed > lastCompletedCount) {
          final newlyCompleted = status.completed - lastCompletedCount;
          lastCompletedCount = status.completed;
          try {
            if (Get.isRegistered<SystemInfoController>()) {
              Get.find<SystemInfoController>().recordDriverInstall(
                newlyCompleted,
              );
            }
          } catch (_) {}
        }

        if (!status.isRunning) {
          timer.cancel();
          isBatchInstalling.value = false;

          // Let Windows finish rebuilding the display stack, then refresh the
          // hardware and folder once. GPU queues receive a longer settle time.
          unawaited(_refreshAfterCompletedQueue(status));

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

          // If reboot is required, show reboot dialog
          if (status.rebootRequired) {
            _showRebootRequiredDialog();
          }
        }
      } catch (e) {
        debugPrint('[DriverInstallController] Queue poll error: $e');
      } finally {
        _pollInFlight = false;
      }
    });
  }

  Future<void> _refreshAfterCompletedQueue(DriverBatchStatus status) async {
    final touchedGraphics = status.items.any(
      (item) => item.category.toLowerCase() == 'gpu',
    );
    await Future<void>.delayed(Duration(seconds: touchedGraphics ? 8 : 2));
    if (isClosed) return;

    try {
      if (Get.isRegistered<SystemInfoController>()) {
        await Get.find<SystemInfoController>().fetchSystemInfo(
          forceRefresh: true,
        );
      }
    } catch (error) {
      debugPrint('[DriverInstallController] System refresh failed: $error');
    }

    final folder = driverFolder.value;
    if (folder.isEmpty || isClosed) return;
    final generation = _scanGeneration;
    try {
      final result = await _apiService.intelligentScanDrivers(
        folderPath: folder,
      );
      if (!isClosed &&
          generation == _scanGeneration &&
          folder == driverFolder.value) {
        scanResult.value = result;
      }
    } catch (error) {
      debugPrint('[DriverInstallController] Rescan failed: $error');
    }
  }

  void _showRebootRequiredDialog() {
    final context = Get.context;
    if (context == null) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF131D33) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.restart_alt_rounded,
                color: Color(0xFFF59E0B),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'نیاز به راه‌اندازی مجدد سیستم',
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
          'نصب‌ها تمام شد. برای اعمال کامل درایورها، بعداً سیستم را به‌صورت دستی ری‌استارت کنید.\n\nیادتان نرود پیش از تحویل دستگاه این کار را انجام دهید.',
          style: TextStyle(
            fontSize: 13.5,
            height: 1.6,
            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('متوجه شدم؛ بعداً ری‌استارت می‌کنم'),
          ),
        ],
      ),
    );
  }

  Future<void> resumeDriverAutoInstall(BuildContext context) async {
    await _executeDriverQueue(context, resume: true);
  }

  Future<void> cancelDriverAutoInstall(BuildContext context) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      final res = await _apiService.cancelDriverQueue();
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

  Future<void> installSingleDriverAuto(
    BuildContext context,
    IntelligentDriverPackage pkg,
  ) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    isBatchInstalling.value = true;
    try {
      final res = await _apiService.startDriverQueueInstall(
        packageIds: [pkg.packageId],
        folderPath: driverFolder.value,
      );
      if (res['success'] == true) {
        _startDriverBatchPolling(scaffoldMessenger);
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('نصب خودکار «${pkg.displayName}» آغاز شد.'),
            backgroundColor: const Color(0xFF0D9488),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        isBatchInstalling.value = false;
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(res['message'] as String? ?? 'خطا در شروع نصب.'),
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
          content: Text('خطا در شروع نصب خودکار: $e'),
          backgroundColor: const Color(0xFFEF4444),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> installSingleDriverInteractive(
    BuildContext context,
    IntelligentDriverPackage pkg,
  ) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      final res = await _apiService.installDriverInteractive(
        pkg.packageId,
        folderPath: driverFolder.value,
      );
      final ok = res['success'] == true;
      final msg = res['message'] as String? ?? '';
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            msg.isNotEmpty
                ? msg
                : (ok
                      ? 'پنجره نصب با موفقیت باز شد.'
                      : 'خطا در باز کردن نصاب.'),
          ),
          backgroundColor: ok
              ? const Color(0xFF2563EB)
              : const Color(0xFFEF4444),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (ok) {
        Get.find<SystemInfoController>().recordDriverInstall(1);
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('خطا در باز کردن نصاب دستی: $e'),
          backgroundColor: const Color(0xFFEF4444),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> openPackageFolder(
    BuildContext context,
    IntelligentDriverPackage pkg,
  ) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      final res = await _apiService.openDriverFolder(
        pkg.packageId,
        folderPath: driverFolder.value,
      );
      if (res['success'] != true) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(res['message'] as String? ?? 'خطا در باز کردن پوشه.'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('خطا در باز کردن پوشه: $e'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> installSelectedDriversManual(BuildContext context) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final selected = scanResult.value.packages
        .where((p) => selectedPackageIds.contains(p.packageId))
        .toList();
    if (selected.isEmpty) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('هیچ درایوری انتخاب نشده است.'),
          backgroundColor: Color(0xFFF59E0B),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Launch each selected driver installer interactively
    int launched = 0;
    for (final pkg in selected) {
      try {
        final res = await _apiService.installDriverInteractive(
          pkg.packageId,
          folderPath: driverFolder.value,
        );
        if (res['success'] == true) {
          launched++;
        }
      } catch (_) {}
    }

    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text('$launched نصاب درایور به صورت دستی باز شدند.'),
        backgroundColor: const Color(0xFF2563EB),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
    if (launched > 0) {
      Get.find<SystemInfoController>().recordDriverInstall(launched);
    }
  }
}
