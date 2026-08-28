import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../l10n/app_localizations.dart';
import '../models/system_info.dart';
import '../services/api_service.dart';
import '../services/folder_picker_service.dart';
import 'system_info_controller.dart';

class SoftwareController extends GetxController {
  final ApiService _apiService = ApiService();

  final Rx<PackagesResponse> packagesResponse = PackagesResponse.empty().obs;
  final RxBool isScanning = false.obs;
  final RxBool hideDuplicates = true.obs;

  void toggleHideDuplicates() => hideDuplicates.toggle();
  final RxString installingPackageId = ''.obs;
  final RxString uninstallingPackageId = ''.obs;

  // Batch auto-install state
  final RxBool isBatchInstalling = false.obs;
  final Rx<BatchInstallStatus> batchStatus = BatchInstallStatus.empty().obs;

  Timer? _pollTimer;
  Timer? _debounceTimer;
  Timer? _periodicSyncTimer;
  Timer? _batchPollTimer;
  StreamSubscription<FileSystemEvent>? _dirWatcherSub;
  String? _currentlyWatchedDir;

  List<SoftwarePackage> get packages => packagesResponse.value.packages;
  PackageSummary get summary => packagesResponse.value.summary;
  bool get directoryExists => packagesResponse.value.directoryExists;
  String get packagesDirectory => packagesResponse.value.packagesDirectory;

  @override
  void onInit() {
    super.onInit();
    fetchPackages();
    _startPeriodicSync();
    _checkInitialBatchStatus();
  }

  @override
  void onClose() {
    _pollTimer?.cancel();
    _debounceTimer?.cancel();
    _periodicSyncTimer?.cancel();
    _batchPollTimer?.cancel();
    _dirWatcherSub?.cancel();
    super.onClose();
  }

  Future<void> changePackagesDirectory(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final selectedPath = await FolderPickerService.pickFolder(
      title: l10n.isPersian
          ? 'انتخاب پوشه نرم‌افزارها'
          : 'Select Software Packages Folder',
    );

    if (selectedPath != null && selectedPath.isNotEmpty) {
      isScanning.value = true;
      try {
        final res = await _apiService.setPackagesDirectory(selectedPath);
        packagesResponse.value = res;
        _updateWatcher(res.packagesDirectory);

        if (context.mounted) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(
                l10n.isPersian
                    ? '✓ پوشه نرم‌افزارها با موفقیت تغییر یافت: $selectedPath'
                    : '✓ Packages folder updated: $selectedPath',
              ),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('Error updating packages folder: $e'),
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } finally {
        isScanning.value = false;
      }
    }
  }

  Future<void> fetchPackages({String? customDir}) async {
    try {
      final res = await _apiService.fetchPackages(customDir: customDir);
      packagesResponse.value = res;
      _updateWatcher(res.packagesDirectory);
    } catch (e) {
      debugPrint('[SoftwareController] fetchPackages error: $e');
    }
  }

  Future<void> scanPackages({bool silent = false}) async {
    if (!silent) {
      isScanning.value = true;
    }
    try {
      final res = await _apiService.scanPackages();
      packagesResponse.value = res;
      _updateWatcher(res.packagesDirectory);
    } catch (e) {
      debugPrint('[SoftwareController] scanPackages error: $e');
    } finally {
      if (!silent) {
        isScanning.value = false;
      }
    }
  }

  void _updateWatcher(String dirPath) {
    if (dirPath.isEmpty || dirPath == _currentlyWatchedDir) return;

    try {
      final dir = Directory(dirPath);
      if (dir.existsSync()) {
        _dirWatcherSub?.cancel();
        _currentlyWatchedDir = dirPath;
        debugPrint(
          '[SoftwareController] Watching Packages directory in real-time: $dirPath',
        );

        _dirWatcherSub = dir
            .watch(recursive: true)
            .listen(
              (event) {
                debugPrint(
                  '[SoftwareController] File change detected in Packages: ${event.path} (${event.type})',
                );
                // Debounce by 600ms so multi-file copies or large installers finish writing
                _debounceTimer?.cancel();
                _debounceTimer = Timer(const Duration(milliseconds: 600), () {
                  scanPackages(silent: true);
                });
              },
              onError: (err) {
                debugPrint(
                  '[SoftwareController] Directory watcher error: $err',
                );
              },
            );
      }
    } catch (e) {
      debugPrint('[SoftwareController] Could not attach file watcher: $e');
    }
  }

  void _startPeriodicSync() {
    _periodicSyncTimer?.cancel();
    // Heartbeat every 4 seconds to catch any USB drive inserts or changes where watcher events might not fire
    _periodicSyncTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (!isScanning.value && installingPackageId.value.isEmpty) {
        try {
          final res = await _apiService.fetchPackages();
          // Only update if count, items, or directory status actually changed
          if (res.packages.length != packagesResponse.value.packages.length ||
              res.directoryExists != packagesResponse.value.directoryExists ||
              res.summary.installedPackages !=
                  packagesResponse.value.summary.installedPackages ||
              res.summary.blockedPackages !=
                  packagesResponse.value.summary.blockedPackages ||
              res.summary.autoInstallable !=
                  packagesResponse.value.summary.autoInstallable) {
            debugPrint(
              '[SoftwareController] Real-time periodic sync updated package list.',
            );
            packagesResponse.value = res;
            _updateWatcher(res.packagesDirectory);
          }
        } catch (_) {}
      }
    });
  }

  bool isCurrentInstalling(SoftwarePackage pkg) {
    final targetId = pkg.relativePath.isNotEmpty ? pkg.relativePath : pkg.id;
    return installingPackageId.value == targetId;
  }

  bool isCurrentUninstalling(SoftwarePackage pkg) {
    final targetId = pkg.relativePath.isNotEmpty ? pkg.relativePath : pkg.id;
    return uninstallingPackageId.value == targetId;
  }

  Future<void> installPackageInteractive(
    BuildContext context,
    SoftwarePackage pkg,
  ) async {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    if (!pkg.isValid || !pkg.manualInstallSupported) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            pkg.validationError ??
                (l10n.isPersian
                    ? 'فایل نامعتبر است و اجرا نمی‌شود.'
                    : 'Invalid installer; execution is blocked.'),
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final targetId = pkg.relativePath.isNotEmpty ? pkg.relativePath : pkg.id;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF131D33) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(
              Icons.admin_panel_settings_rounded,
              color: Color(0xFF2563EB),
              size: 24,
            ),
            const SizedBox(width: 10),
            Text(
              l10n.confirmInstallTitle,
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.isPersian
                  ? 'نصاب ${pkg.name} با دسترسی مدیر اجرا شود؟'
                  : 'Run ${pkg.name} installer with administrator access?',
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? const Color(0xFFCBD5E1)
                    : const Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${pkg.packageFormat} • ${pkg.installerType}\n${pkg.relativePath}',
              textDirection: TextDirection.ltr,
              style: TextStyle(
                fontSize: 11,
                color: isDark
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.isPersian
                  ? 'برنامه هیچ گزینه ری‌استارتی را تأیید نمی‌کند؛ اگر نصاب سؤال کرد «Restart later» را انتخاب کنید.'
                  : 'The app never confirms a restart. If prompted, choose “Restart later”.',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFFF59E0B),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            icon: const Icon(Icons.play_arrow_rounded, size: 16),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            label: Text(l10n.install),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      installingPackageId.value = targetId;

      try {
        final res = await _apiService.installPackage(targetId);
        final isCancelled = res['cancelled'] == true;
        final isSuccess = res['success'] == true;
        final message = res['message'] as String? ?? '';

        if (isCancelled) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(
                message.isNotEmpty
                    ? message
                    : (l10n.isPersian
                          ? 'عملیات نصب لغو شد.'
                          : 'Installation cancelled.'),
              ),
              backgroundColor: const Color(0xFF64748B),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else if (isSuccess) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(
                message.isNotEmpty
                    ? message
                    : 'پنجره نصب ${pkg.name} با دسترسی مدیر باز شد.',
              ),
              backgroundColor: const Color(0xFF2563EB),
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
            ),
          );
          _startAutoDetectionPoll(pkg, scaffoldMessenger);
        } else {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(
                message.isNotEmpty ? message : 'خطا در اجرای برنامه نصب.',
              ),
              backgroundColor: const Color(0xFFEF4444),
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('خطا در اجرای برنامه نصب: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } finally {
        installingPackageId.value = '';
      }
    }
  }

  Future<void> installPackageSilent(
    BuildContext context,
    SoftwarePackage pkg,
  ) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final targetId = pkg.relativePath.isNotEmpty ? pkg.relativePath : pkg.id;

    if (!pkg.isValid || !pkg.autoInstallSupported) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            pkg.validationError ?? 'این نصاب فقط در حالت دستی قابل اجرا است.',
          ),
          backgroundColor: const Color(0xFFF59E0B),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    isBatchInstalling.value = true;
    try {
      final res = await _apiService.startBatchInstall(packageIds: [targetId]);
      if (res['success'] == true) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('نصب خودکار و بی‌صدا ${pkg.name} شروع شد...'),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _startBatchStatusPolling(scaffoldMessenger);
      } else {
        isBatchInstalling.value = false;
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              res['message'] as String? ?? 'خطا در شروع نصب خودکار.',
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

  void _startAutoDetectionPoll(
    SoftwarePackage pkg,
    ScaffoldMessengerState scaffoldMessenger,
  ) {
    _pollTimer?.cancel();
    int attempts = 0;
    const maxAttempts = 20; // 20 * 3s = 60 seconds

    _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      attempts++;
      await fetchPackages();

      final targetId = pkg.relativePath.isNotEmpty ? pkg.relativePath : pkg.id;
      final updated = packages.firstWhereOrNull(
        (p) => (p.relativePath.isNotEmpty ? p.relativePath : p.id) == targetId,
      );

      if (updated != null && updated.isInstalled) {
        timer.cancel();
        if (Get.isRegistered<SystemInfoController>()) {
          Get.find<SystemInfoController>().recordSoftwareInstall();
        }
        final ver = updated.installedVersion;
        final verStr = (ver.isNotEmpty && ver != 'Not available')
            ? ' (نسخه $ver)'
            : '';
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              '✓ ${pkg.name} با موفقیت در سیستم شناسایی شد$verStr.',
            ),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (attempts >= maxAttempts) {
        timer.cancel();
      }
    });
  }

  Future<void> openInstalledApp(
    BuildContext context,
    SoftwarePackage pkg,
  ) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final targetId = pkg.relativePath.isNotEmpty ? pkg.relativePath : pkg.id;

    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text('در حال باز کردن ${pkg.name}...'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );

    try {
      // 1. If installedExePath is known, open directly from Flutter desktop session
      if (pkg.installedExePath != null &&
          pkg.installedExePath!.isNotEmpty &&
          Platform.isWindows) {
        try {
          await Process.run('cmd.exe', [
            '/c',
            'start',
            '',
            pkg.installedExePath!,
          ], runInShell: true);
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('✓ نرم‌افزار ${pkg.name} باز شد.'),
              backgroundColor: const Color(0xFF10B981),
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        } catch (_) {}
      }

      // 2. Open via backend open endpoint
      final res = await _apiService.openPackage(targetId);
      final success = res['success'] == true;
      final msg =
          res['message'] as String? ??
          (success ? '✓ برنامه باز شد.' : 'خطا در باز کردن برنامه.');

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: success
              ? const Color(0xFF10B981)
              : const Color(0xFFEF4444),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('خطا در اجرای برنامه: $e'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> uninstallPackageInteractive(
    BuildContext context,
    SoftwarePackage pkg,
  ) async {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final targetId = pkg.relativePath.isNotEmpty ? pkg.relativePath : pkg.id;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF131D33) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(
              Icons.delete_forever_rounded,
              color: Color(0xFFEF4444),
              size: 24,
            ),
            const SizedBox(width: 10),
            Text(
              l10n.confirmUninstallTitle,
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
          l10n.confirmUninstallMessage(pkg.name),
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
            icon: const Icon(Icons.delete_sweep_rounded, size: 16),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            label: Text(l10n.uninstall),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      uninstallingPackageId.value = targetId;

      try {
        final res = await _apiService.uninstallPackage(targetId);
        final isCancelled = res['cancelled'] == true;
        final isSuccess = res['success'] == true;
        final message = res['message'] as String? ?? '';

        if (isCancelled) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(
                message.isNotEmpty
                    ? message
                    : (l10n.isPersian
                          ? 'عملیات حذف لغو شد.'
                          : 'Uninstallation cancelled.'),
              ),
              backgroundColor: const Color(0xFF64748B),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else if (isSuccess) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(
                message.isNotEmpty
                    ? message
                    : 'برنامه حذف‌کننده ${pkg.name} اجرا شد.',
              ),
              backgroundColor: const Color(0xFFEF4444),
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
            ),
          );
          _startAutoDetectionPollUninstall(pkg, scaffoldMessenger);
        } else {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(
                message.isNotEmpty ? message : l10n.uninstallFailed(pkg.name),
              ),
              backgroundColor: const Color(0xFFEF4444),
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('${l10n.uninstallFailed(pkg.name)}: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } finally {
        uninstallingPackageId.value = '';
      }
    }
  }

  void _startAutoDetectionPollUninstall(
    SoftwarePackage pkg,
    ScaffoldMessengerState scaffoldMessenger,
  ) {
    _pollTimer?.cancel();
    int attempts = 0;
    const maxAttempts = 20; // 20 * 3s = 60 seconds

    _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      attempts++;
      await fetchPackages();

      final targetId = pkg.relativePath.isNotEmpty ? pkg.relativePath : pkg.id;
      final updated = packages.firstWhereOrNull(
        (p) => (p.relativePath.isNotEmpty ? p.relativePath : p.id) == targetId,
      );

      if (updated == null || !updated.isInstalled) {
        timer.cancel();
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('✓ ${pkg.name} با موفقیت از سیستم حذف شد.'),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (attempts >= maxAttempts) {
        timer.cancel();
      }
    });
  }

  // -------------------------------------------------------------
  // Batch Auto-Install Queue Management
  // -------------------------------------------------------------

  Future<void> _checkInitialBatchStatus() async {
    try {
      final status = await _apiService.getBatchInstallStatus();
      batchStatus.value = status;
      if (status.isRunning) {
        isBatchInstalling.value = true;
        _startBatchStatusPolling(null);
      }
    } catch (_) {}
  }

  Future<void> startAutoInstallAll(
    BuildContext context, {
    List<String>? targetPackageIds,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final List<SoftwarePackage> availablePackages;
    if (targetPackageIds != null && targetPackageIds.isNotEmpty) {
      final targetSet = targetPackageIds.toSet();
      availablePackages = packages
          .where((p) => targetSet.contains(p.id) && p.isValid && !p.isInstalled)
          .toList();
    } else {
      availablePackages = packages
          .where(
            (p) =>
                p.installAllowed &&
                p.autoInstallSupported &&
                p.isValid &&
                !p.isInstalled &&
                (!hideDuplicates.value || !p.isDuplicate),
          )
          .toList();
    }

    if (availablePackages.isEmpty) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text(
            'تمام نرم‌افزارهای انتخابی قبلاً نصب شده‌اند یا برنامه‌ای برای نصب وجود ندارد.',
          ),
          backgroundColor: Color(0xFF64748B),
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF131D33) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.auto_fix_high_rounded,
                color: Color(0xFF10B981),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'نصب خودکار نرم‌افزارها',
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
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'تعداد ${availablePackages.length} نرم‌افزار برای نصب خودکار در صف قرار می‌گیرند:',
                style: TextStyle(
                  fontSize: 14,
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
                  itemCount: availablePackages.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 8),
                  itemBuilder: (_, idx) {
                    final pkg = availablePackages[idx];
                    return Row(
                      children: [
                        const Icon(
                          Icons.check_circle_outline_rounded,
                          size: 16,
                          color: Color(0xFF10B981),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            pkg.name,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? const Color(0xFFCBD5E1)
                                  : const Color(0xFF334155),
                            ),
                          ),
                        ),
                        Text(
                          pkg.fileSizeDisplay,
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
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: Color(0xFF3B82F6),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'نصب‌ها به صورت کاملاً بی‌صدا (Silent) و خودکار بدون نیاز به تداخل انجام می‌شوند.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF3B82F6),
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
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            label: const Text('شروع نصب خودکار'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      isBatchInstalling.value = true;
      try {
        final res = await _apiService.startBatchInstall(
          packageIds: availablePackages.map((p) => p.id).toList(),
        );
        if (res['success'] == true) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(
                res['message'] as String? ?? 'نصب خودکار شروع شد...',
              ),
              backgroundColor: const Color(0xFF10B981),
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
          _startBatchStatusPolling(scaffoldMessenger);
        } else {
          isBatchInstalling.value = false;
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(
                res['message'] as String? ?? 'خطا در شروع نصب خودکار.',
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
  }

  void _startBatchStatusPolling(ScaffoldMessengerState? scaffoldMessenger) {
    _batchPollTimer?.cancel();
    _batchPollTimer = Timer.periodic(const Duration(milliseconds: 1500), (
      timer,
    ) async {
      try {
        final status = await _apiService.getBatchInstallStatus();
        batchStatus.value = status;

        if (!status.isRunning) {
          timer.cancel();
          isBatchInstalling.value = false;
          await fetchPackages();

          if (status.completed > 0 &&
              Get.isRegistered<SystemInfoController>()) {
            Get.find<SystemInfoController>().recordSoftwareInstall();
          }

          if (scaffoldMessenger != null && status.summaryMessage.isNotEmpty) {
            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: Text(status.summaryMessage),
                backgroundColor: status.failed == 0
                    ? const Color(0xFF10B981)
                    : const Color(0xFFF59E0B),
                duration: const Duration(seconds: 6),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('[SoftwareController] Batch poll error: $e');
      }
    });
  }

  Future<void> cancelBatchInstallInteractive(BuildContext context) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      final res = await _apiService.cancelBatchInstall();
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
