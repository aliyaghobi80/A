import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../l10n/app_localizations.dart';
import '../models/system_info.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';
import '../services/folder_picker_service.dart';
import 'system_info_controller.dart';
import 'device_settings_controller.dart';
import 'deployment_preferences.dart';
import 'qc_controller.dart';

bool officeInstallBlockedForWindows(
  SoftwarePackage package,
  WindowsInfo? windows,
) => package.isMicrosoftOfficePackage && windows?.isHomeEdition == true;

Set<String> toggledSoftwareSelection(
  Set<String> current,
  Set<String> selectable,
) {
  final result = Set<String>.from(current);
  if (selectable.isEmpty) return result;
  if (result.containsAll(selectable)) {
    result.removeAll(selectable);
  } else {
    result.addAll(selectable);
  }
  return result;
}

class SoftwareController extends GetxController {
  SoftwareController({ApiService? apiService})
    : _apiService = apiService ?? ApiService();

  final ApiService _apiService;

  final Rx<PackagesResponse> packagesResponse = PackagesResponse.empty().obs;
  final RxBool isScanning = false.obs;
  final RxString installingPackageId = ''.obs;
  final RxString uninstallingPackageId = ''.obs;
  final RxBool isBatchUninstalling = false.obs;
  final RxString windowsUpdateActionPackageId = ''.obs;
  final RxString officeShortcutPackageId = ''.obs;

  bool isOfficeBlockedOnHome(SoftwarePackage package) {
    if (!Get.isRegistered<SystemInfoController>()) {
      return false;
    }
    return officeInstallBlockedForWindows(
      package,
      Get.find<SystemInfoController>().systemInfo.value?.windows,
    );
  }

  bool _showOfficeHomeNotice(BuildContext context, SoftwarePackage package) {
    if (!isOfficeBlockedOnHome(package)) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Windows Home اورجینال شناسایی شد؛ نصب آفیس در این برنامه غیرفعال است.',
        ),
        backgroundColor: Color(0xFF64748B),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return true;
  }

  // Batch auto-install state
  final RxBool isBatchInstalling = false.obs;
  final DeploymentPreferences deploymentPreferences = DeploymentPreferences();
  RxBool get includeActivation => deploymentPreferences.includeActivation;
  RxBool get doubleSpeed => deploymentPreferences.doubleSpeed;
  bool get activationAllowed =>
      Get.isRegistered<SystemInfoController>() &&
      Get.find<SystemInfoController>()
              .systemInfo
              .value
              ?.windows
              .isHomeEdition ==
          false;
  final Rx<BatchInstallStatus> batchStatus = BatchInstallStatus.empty().obs;
  final RxSet<String> selectedPackageIds = <String>{}.obs;

  Timer? _pollTimer;
  Timer? _initialTimer;
  bool _batchPollInFlight = false;
  bool _batchSyncInFlight = false;
  bool _syncInFlight = false;
  int _scanGeneration = 0;
  Timer? _debounceTimer;
  Timer? _periodicSyncTimer;
  Timer? _batchPollTimer;
  StreamSubscription<FileSystemEvent>? _dirWatcherSub;
  String? _currentlyWatchedDir;

  List<SoftwarePackage> get packages => packagesResponse.value.packages;
  PackageSummary get summary => packagesResponse.value.summary;
  bool get directoryExists => packagesResponse.value.directoryExists;
  String get packagesDirectory => packagesResponse.value.packagesDirectory;
  bool get hasActiveBatch =>
      isBatchInstalling.value || batchStatus.value.isRunning;

  void togglePackageSelection(String packageId) {
    if (selectedPackageIds.contains(packageId)) {
      selectedPackageIds.remove(packageId);
    } else {
      selectedPackageIds.add(packageId);
    }
    selectedPackageIds.refresh();
  }

  void toggleSelectAllPackages(Set<String> selectableIds) {
    selectedPackageIds.assignAll(
      toggledSoftwareSelection(selectedPackageIds, selectableIds),
    );
    selectedPackageIds.refresh();
  }

  void removePackageSelections(Iterable<String> packageIds) {
    selectedPackageIds.removeAll(packageIds);
    selectedPackageIds.refresh();
  }

  void _reconcilePackageSelection(Iterable<SoftwarePackage> latestPackages) {
    if (selectedPackageIds.isEmpty) return;
    final knownIds = latestPackages.map((package) => package.id).toSet();
    final staleIds = selectedPackageIds
        .where((packageId) => !knownIds.contains(packageId))
        .toList();
    if (staleIds.isNotEmpty) {
      selectedPackageIds.removeAll(staleIds);
      selectedPackageIds.refresh();
    }
  }

  @override
  void onInit() {
    super.onInit();
    // Queue ownership lives in the backend. Reconnect immediately so a
    // recreated Flutter view never looks idle while installers are running.
    unawaited(_checkInitialBatchStatus());
    _loadCacheAndFetch();
  }

  Future<void> _loadCacheAndFetch() async {
    try {
      final cached = await CacheService.loadCachedPackages();
      if (cached != null && !isClosed) {
        packagesResponse.value = cached;
        _reconcilePackageSelection(cached.packages);
      }
    } catch (_) {}

    // Defer initial scan slightly (500ms) so it does not contest initial frame render
    if (isClosed) return;
    _initialTimer = Timer(const Duration(milliseconds: 500), () {
      if (isClosed) return;
      fetchPackages();
      _startPeriodicSync();
    });
  }

  @override
  void onClose() {
    _initialTimer?.cancel();
    _scanGeneration++;
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
      if (isClosed || isBatchInstalling.value) return;
      final generation = ++_scanGeneration;
      isScanning.value = true;
      try {
        final res = await _apiService.setPackagesDirectory(selectedPath);
        if (isClosed || generation != _scanGeneration) return;
        packagesResponse.value = res;
        _reconcilePackageSelection(res.packages);
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
        if (!isClosed && generation == _scanGeneration) {
          isScanning.value = false;
        }
      }
    }
  }

  Future<void> fetchPackages({String? customDir}) async {
    if (isClosed || isScanning.value) return;
    final generation = ++_scanGeneration;
    try {
      final res = await _apiService.fetchPackages(customDir: customDir);
      if (isClosed || generation != _scanGeneration) return;
      packagesResponse.value = res;
      _reconcilePackageSelection(res.packages);
      _updateWatcher(res.packagesDirectory);
    } catch (e) {
      debugPrint('[SoftwareController] fetchPackages error: $e');
    }
  }

  Future<void> scanPackages({bool silent = false, bool force = false}) async {
    if (isClosed || (isScanning.value && !force)) return;
    final generation = ++_scanGeneration;
    if (!silent) {
      isScanning.value = true;
    }
    try {
      final res = await _apiService.scanPackages();
      if (isClosed || generation != _scanGeneration) return;
      packagesResponse.value = res;
      _reconcilePackageSelection(res.packages);
      _updateWatcher(res.packagesDirectory);
    } catch (e) {
      debugPrint('[SoftwareController] scanPackages error: $e');
    } finally {
      if (!silent && !isClosed) {
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
    // One low-cost heartbeat owns recovery for both package changes and a
    // backend queue that outlived/replaced the current Flutter view.
    _periodicSyncTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (isClosed) return;
      if (_batchPollTimer?.isActive != true) {
        await synchronizeBatchInstallState();
      }
      if (_syncInFlight || isClosed || hasActiveBatch) return;
      if (!isScanning.value && installingPackageId.value.isEmpty) {
        _syncInFlight = true;
        final generation = _scanGeneration;
        try {
          final res = await _apiService.fetchPackages();
          if (isClosed || generation != _scanGeneration) return;
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
            _reconcilePackageSelection(res.packages);
            _updateWatcher(res.packagesDirectory);
          }
        } catch (_) {
          // Background sync is retried on the next tick.
        } finally {
          _syncInFlight = false;
        }
      }
    });
  }

  bool isCurrentInstalling(SoftwarePackage pkg) {
    final targetId = pkg.relativePath.isNotEmpty ? pkg.relativePath : pkg.id;
    if (installingPackageId.value == targetId) return true;
    if (isBatchInstalling.value && batchStatus.value.isRunning) {
      final currentItem = batchStatus.value.items.firstWhereOrNull(
        (it) =>
            it.id == pkg.id ||
            (pkg.relativePath.isNotEmpty &&
                it.relativePath == pkg.relativePath) ||
            it.name.toLowerCase() == pkg.name.toLowerCase(),
      );
      if (currentItem != null) {
        return currentItem.status == 'installing';
      }
      final currentName =
          batchStatus.value.currentItemName?.toLowerCase() ?? '';
      if (currentName.isNotEmpty &&
          (currentName == pkg.name.toLowerCase() ||
              currentName == pkg.id.toLowerCase())) {
        return true;
      }
    }
    return false;
  }

  bool isCurrentQueued(SoftwarePackage pkg) {
    if (!isBatchInstalling.value || !batchStatus.value.isRunning) return false;
    final currentItem = batchStatus.value.items.firstWhereOrNull(
      (it) =>
          it.id == pkg.id ||
          (pkg.relativePath.isNotEmpty &&
              it.relativePath == pkg.relativePath) ||
          it.name.toLowerCase() == pkg.name.toLowerCase(),
    );
    return currentItem != null && currentItem.status == 'queued';
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

    if (_showOfficeHomeNotice(context, pkg)) return;

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
    if (_showOfficeHomeNotice(context, pkg)) return;
    if (await _recoverExistingBatch(scaffoldMessenger)) return;
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
      final res = await _apiService.startBatchInstall(
        packageIds: [targetId],
        customDir: packagesDirectory.isNotEmpty ? packagesDirectory : null,
      );
      if (res['success'] == true) {
        final adoptedExisting = res['already_running'] == true;
        _adoptBatchStartResponse(res, scaffoldMessenger: scaffoldMessenger);
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              adoptedExisting
                  ? 'صف نصب فعال بازیابی شد؛ جزئیات آن اکنون نمایش داده می‌شود.'
                  : 'نصب خودکار و بی‌صدا ${pkg.name} شروع شد...',
            ),
            backgroundColor: adoptedExisting
                ? const Color(0xFF0284C7)
                : const Color(0xFF10B981),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
        if (_batchPollTimer?.isActive != true) {
          _startBatchStatusPolling(scaffoldMessenger);
        }
      } else {
        final recovered = await synchronizeBatchInstallState();
        if (recovered) {
          _showActiveBatchNotice(scaffoldMessenger);
          return;
        }
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
      final recovered = await synchronizeBatchInstallState();
      if (recovered) {
        _showActiveBatchNotice(scaffoldMessenger);
        return;
      }
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
    const maxAttempts = 80; // 80 * 2.5s = 200 seconds (~3.3 minutes)

    _pollTimer = Timer.periodic(const Duration(milliseconds: 2500), (
      timer,
    ) async {
      attempts++;
      await fetchPackages();

      final targetId = pkg.relativePath.isNotEmpty ? pkg.relativePath : pkg.id;
      final updated = packages.firstWhereOrNull(
        (p) => (p.relativePath.isNotEmpty ? p.relativePath : p.id) == targetId,
      );

      if (updated != null && updated.isInstalled) {
        timer.cancel();
        final officeHint = '${pkg.id} ${pkg.name} ${pkg.filename}'
            .toLowerCase();
        if (officeHint.contains('office')) {
          await _apiService.createOfficeDesktopShortcuts();
        }
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
      // 1. If installedExePath or fullPath for portable tools is known, open directly from Flutter desktop session
      final directExe =
          (pkg.installedExePath != null && pkg.installedExePath!.isNotEmpty)
          ? pkg.installedExePath!
          : (pkg.isPortable && pkg.fullPath.isNotEmpty ? pkg.fullPath : null);

      if (!pkg.isWindowsUpdateBlocker &&
          directExe != null &&
          directExe.isNotEmpty &&
          Platform.isWindows) {
        try {
          await Process.run('cmd.exe', [
            '/c',
            'start',
            '',
            directExe,
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
      var res = await _apiService.openPackage(targetId);
      if (res['requires_confirmation'] == true && context.mounted) {
        final windows = res['windows'] as Map<String, dynamic>?;
        final label = windows?['label'] as String? ?? 'Windows Home';
        final confirmed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            icon: const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFF59E0B),
              size: 38,
            ),
            title: Text('$label اورجینال است'),
            content: const Text(
              'بهتر است Windows Update در نسخهٔ Home روشن بماند تا به‌روزرسانی‌های امنیتی دریافت شوند. آیا با آگاهی از این موضوع می‌خواهید آن را غیرفعال کنید؟',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('انصراف'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('بله، غیرفعال کن'),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
        res = await _apiService.openPackage(
          targetId,
          confirmHomeUpdateBlock: true,
        );
      }
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

  Future<void> pinPackageToTaskbar(
    BuildContext context,
    SoftwarePackage pkg,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final targetId = pkg.relativePath.isNotEmpty ? pkg.relativePath : pkg.id;
    final res = await _apiService.pinPackageToTaskbar(targetId);
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(res['message'] as String? ?? 'عملیات Pin انجام نشد.'),
        backgroundColor: res['success'] == true
            ? const Color(0xFF0284C7)
            : const Color(0xFFEF4444),
        duration: const Duration(seconds: 6),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> createOfficeShortcuts(
    BuildContext context,
    SoftwarePackage pkg,
  ) async {
    if (officeShortcutPackageId.value.isNotEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    officeShortcutPackageId.value = pkg.id;
    try {
      final res = await _apiService.createOfficeDesktopShortcuts();
      if (!context.mounted) return;
      final success = res['success'] == true;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            res['message'] as String? ??
                (success
                    ? 'میانبرهای Word، Excel و PowerPoint ساخته شدند.'
                    : 'ساخت میانبرهای Office انجام نشد.'),
          ),
          backgroundColor: success
              ? const Color(0xFF10B981)
              : const Color(0xFFEF4444),
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('خطا در ساخت میانبرهای Office: $e'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      officeShortcutPackageId.value = '';
    }
  }

  Future<void> setWindowsUpdateState(
    BuildContext context,
    SoftwarePackage pkg,
  ) async {
    if (windowsUpdateActionPackageId.value.isNotEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final targetId = pkg.relativePath.isNotEmpty ? pkg.relativePath : pkg.id;
    final enable = pkg.windowsUpdateBlocked;
    windowsUpdateActionPackageId.value = pkg.id;
    try {
      var res = await _apiService.setWindowsUpdateState(
        targetId,
        enable: enable,
      );
      if (res['requires_confirmation'] == true && context.mounted) {
        final windows = res['windows'] as Map<String, dynamic>?;
        final label = windows?['label'] as String? ?? 'Windows Home';
        final confirmed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            icon: const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFF59E0B),
              size: 38,
            ),
            title: Text('$label اورجینال است'),
            content: const Text(
              'بهتر است Windows Update در نسخهٔ Home روشن بماند تا به‌روزرسانی‌های امنیتی دریافت شوند. آیا با آگاهی از این موضوع می‌خواهید آن را غیرفعال کنید؟',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('انصراف'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('بله، غیرفعال کن'),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
        res = await _apiService.setWindowsUpdateState(
          targetId,
          enable: false,
          confirmHomeUpdateBlock: true,
        );
      }
      if (!context.mounted) return;
      final success = res['success'] == true;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            res['message'] as String? ??
                (success
                    ? 'وضعیت Windows Update تغییر کرد.'
                    : 'تغییر وضعیت Windows Update ناموفق بود.'),
          ),
          backgroundColor: success
              ? const Color(0xFF10B981)
              : const Color(0xFFEF4444),
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (success) await scanPackages(silent: true);
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('خطا در تغییر وضعیت Windows Update: $e'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      windowsUpdateActionPackageId.value = '';
    }
  }

  Future<void> openOfficeFolder(BuildContext context) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      final customDir = packagesDirectory;
      final res = await _apiService.openOfficeFolder(
        customDir.isNotEmpty ? customDir : null,
      );
      final success = res['success'] == true;
      final msg =
          res['message'] as String? ??
          (success ? '✓ پوشه آفیس باز شد.' : 'خطا در باز کردن پوشه آفیس.');

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
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('خطا در باز کردن پوشه آفیس: $e'),
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
          // The backend waits for the official uninstaller and verifies
          // Windows registration removal. Refresh before showing success so
          // this card cannot retain a stale "installed" state.
          await scanPackages(silent: true, force: true);
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
          if (res['verified_uninstalled'] != true) {
            _startAutoDetectionPollUninstall(pkg, scaffoldMessenger);
          }
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

  Future<Set<String>> uninstallSelectedPackages(
    BuildContext context,
    List<SoftwarePackage> selectedPackages,
  ) async {
    final l10n = AppLocalizations.of(context);
    final eligible = selectedPackages
        .where((package) => package.isInstalled && !package.isPortable)
        .toList();
    if (eligible.isEmpty || isBatchUninstalling.value) return <String>{};

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.delete_sweep_rounded, color: Color(0xFFEF4444)),
            const SizedBox(width: 10),
            Text(
              l10n.isPersian
                  ? 'حذف برنامه‌های انتخابی'
                  : 'Uninstall selected apps',
            ),
          ],
        ),
        content: Text(
          l10n.isPersian
              ? '${eligible.length} برنامه به‌ترتیب حذف می‌شوند. سیستم به‌صورت خودکار ری‌استارت نخواهد شد.'
              : '${eligible.length} apps will be uninstalled sequentially. The system will not restart automatically.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.delete_forever_rounded, size: 18),
            label: Text(l10n.isPersian ? 'شروع حذف' : 'Start uninstall'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return <String>{};

    final removedIds = <String>{};
    final failures = <String>[];
    isBatchUninstalling.value = true;
    try {
      for (final package in eligible) {
        final targetId = package.relativePath.isNotEmpty
            ? package.relativePath
            : package.id;
        uninstallingPackageId.value = targetId;
        try {
          final result = await _apiService.uninstallPackage(targetId);
          if (result['success'] == true &&
              result['verified_uninstalled'] == true) {
            removedIds.add(package.id);
          } else {
            failures.add(package.name);
            if (result['cancelled'] == true) break;
          }
        } catch (_) {
          failures.add(package.name);
        }
      }
      await scanPackages(silent: true, force: true);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              failures.isEmpty
                  ? (l10n.isPersian
                        ? '✓ ${removedIds.length} برنامه با موفقیت حذف شد.'
                        : '✓ ${removedIds.length} apps were uninstalled.')
                  : (l10n.isPersian
                        ? '${removedIds.length} حذف موفق؛ ${failures.length} مورد نیازمند بررسی است.'
                        : '${removedIds.length} removed; ${failures.length} require attention.'),
            ),
            backgroundColor: failures.isEmpty
                ? const Color(0xFF059669)
                : const Color(0xFFD97706),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      uninstallingPackageId.value = '';
      isBatchUninstalling.value = false;
    }
    return removedIds;
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
    await synchronizeBatchInstallState();
  }

  /// Reconciles the GetX state with the backend-owned queue.
  ///
  /// This is intentionally public so app-resume/navigation hooks can restore
  /// progress after a Flutter view or graphics process is recreated.
  Future<bool> synchronizeBatchInstallState({bool startPolling = true}) async {
    if (_batchSyncInFlight || isClosed) return batchStatus.value.isRunning;
    _batchSyncInFlight = true;
    try {
      final status = await _apiService.getBatchInstallStatus();
      if (isClosed) return false;
      _applyBatchStatus(status, startPolling: startPolling);
      return status.isRunning;
    } catch (error) {
      // Preserve the last known state on a transient backend/HTTP failure.
      // Replacing it with BatchInstallStatus.empty() would make an active
      // installer disappear from the UI and re-enable conflicting controls.
      debugPrint('[SoftwareController] Batch state sync error: $error');
      return batchStatus.value.isRunning;
    } finally {
      _batchSyncInFlight = false;
    }
  }

  void _applyBatchStatus(
    BatchInstallStatus status, {
    bool startPolling = true,
  }) {
    final preserveLastCompleted =
        !status.isRunning &&
        status.total == 0 &&
        batchStatus.value.total > 0 &&
        !batchStatus.value.isRunning;
    if (!preserveLastCompleted) {
      batchStatus.value = status;
    }
    isBatchInstalling.value = status.isRunning;
    deploymentPreferences.reconcileQueue(status);
    if (status.isRunning && startPolling && _batchPollTimer?.isActive != true) {
      _startBatchStatusPolling(null);
    }
  }

  BatchInstallStatus? _statusFromStartResponse(Map<String, dynamic> response) {
    final rawStatus = response['status'];
    if (rawStatus is Map) {
      return BatchInstallStatus.fromJson(Map<String, dynamic>.from(rawStatus));
    }
    if (response.containsKey('is_running')) {
      return BatchInstallStatus.fromJson(response);
    }
    return null;
  }

  bool _adoptBatchStartResponse(
    Map<String, dynamic> response, {
    ScaffoldMessengerState? scaffoldMessenger,
  }) {
    final status = _statusFromStartResponse(response);
    if (status != null) {
      _applyBatchStatus(status, startPolling: false);
    }
    final adoptedExisting = response['already_running'] == true;
    if (status?.isRunning == true || adoptedExisting) {
      isBatchInstalling.value = true;
      _startBatchStatusPolling(scaffoldMessenger);
      return true;
    }
    return false;
  }

  void _showActiveBatchNotice(ScaffoldMessengerState scaffoldMessenger) {
    final status = batchStatus.value;
    final progress = status.total > 0
        ? ' (${status.completed} از ${status.total})'
        : '';
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(
          'صف نصب از قبل در حال اجراست$progress؛ وضعیت زنده بازیابی شد.',
        ),
        backgroundColor: const Color(0xFF0284C7),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<bool> _recoverExistingBatch(
    ScaffoldMessengerState scaffoldMessenger,
  ) async {
    final running = await synchronizeBatchInstallState();
    if (running) {
      _showActiveBatchNotice(scaffoldMessenger);
      if (_batchPollTimer?.isActive != true) {
        _startBatchStatusPolling(null);
      }
      return true;
    }
    return false;
  }

  Future<void> startAutoInstallAll(
    BuildContext context, {
    List<String>? targetPackageIds,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    if (await _recoverExistingBatch(scaffoldMessenger)) return;
    if (!context.mounted) return;

    final List<SoftwarePackage> availablePackages;
    if (targetPackageIds != null && targetPackageIds.isNotEmpty) {
      final targetSet = targetPackageIds.toSet();
      availablePackages = packages
          .where(
            (p) =>
                targetSet.contains(p.id) &&
                p.isValid &&
                !p.isInstalled &&
                !isOfficeBlockedOnHome(p),
          )
          .toList();
    } else {
      availablePackages = packages
          .where(
            (p) =>
                p.isValid &&
                !p.isInstalled &&
                !p.isDuplicate &&
                !isOfficeBlockedOnHome(p),
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
                        'نرم‌افزارها و سپس تنظیمات دستگاه اجرا می‌شوند. فعال‌سازی فقط با انتخاب صریح گزینهٔ KMS و روی ویندوز غیر Home انجام می‌شود.',
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
          customDir: packagesDirectory.isNotEmpty ? packagesDirectory : null,
          includeSystemSetup: true,
          includeActivation: includeActivation.value && activationAllowed,
          doubleSpeed: doubleSpeed.value,
        );
        if (res['success'] == true) {
          final adoptedExisting = res['already_running'] == true;
          _adoptBatchStartResponse(res, scaffoldMessenger: scaffoldMessenger);
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(
                adoptedExisting
                    ? 'صف نصب فعال بازیابی شد؛ جزئیات آن اکنون نمایش داده می‌شود.'
                    : (res['message'] as String? ?? 'نصب خودکار شروع شد...'),
              ),
              backgroundColor: adoptedExisting
                  ? const Color(0xFF0284C7)
                  : const Color(0xFF10B981),
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
          if (_batchPollTimer?.isActive != true) {
            _startBatchStatusPolling(scaffoldMessenger);
          }
        } else {
          final recovered = await synchronizeBatchInstallState();
          if (recovered) {
            _showActiveBatchNotice(scaffoldMessenger);
            return;
          }
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
        final recovered = await synchronizeBatchInstallState();
        if (recovered) {
          _showActiveBatchNotice(scaffoldMessenger);
          return;
        }
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
      if (_batchPollInFlight || isClosed) return;
      _batchPollInFlight = true;
      try {
        final status = await _apiService.getBatchInstallStatus();
        if (isClosed || timer != _batchPollTimer) return;
        _applyBatchStatus(status, startPolling: false);

        // REAL-TIME IN-MEMORY UPDATE:
        // Update package cards immediately as each package finishes in the batch queue
        final currentPkgs = packagesResponse.value.packages;
        bool anyChanged = false;
        final updatedList = <SoftwarePackage>[];

        for (final pkg in currentPkgs) {
          final matchingItem = status.items.firstWhereOrNull(
            (it) =>
                it.id == pkg.id ||
                (pkg.relativePath.isNotEmpty &&
                    it.relativePath == pkg.relativePath) ||
                it.name.toLowerCase() == pkg.name.toLowerCase(),
          );

          if (matchingItem != null &&
              matchingItem.status == 'completed' &&
              !pkg.isInstalled) {
            anyChanged = true;
            updatedList.add(
              pkg.copyWith(
                isInstalled: true,
                installedVersion: matchingItem.installedVersion.isNotEmpty
                    ? matchingItem.installedVersion
                    : (pkg.version.isNotEmpty ? pkg.version : 'نصب شده'),
                status: 'Installed',
              ),
            );
          } else {
            updatedList.add(pkg);
          }
        }

        if (anyChanged) {
          packagesResponse.value = packagesResponse.value.copyWith(
            packages: updatedList,
          );
          packagesResponse.refresh();
        }

        if (!status.isRunning) {
          timer.cancel();
          await scanPackages(silent: true, force: true);

          if (Get.isRegistered<DeviceSettingsController>()) {
            Get.find<DeviceSettingsController>().refreshStatus();
          }
          if (Get.isRegistered<SystemInfoController>()) {
            Get.find<SystemInfoController>().fetchSystemInfo(
              forceRefresh: true,
            );
          }
          if (Get.isRegistered<QcController>()) {
            Get.find<QcController>().fetchInitialQcStatus();
          }

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
          if (status.rebootRequired) {
            _showManualRestartReminder();
          }
        }
      } catch (e) {
        debugPrint('[SoftwareController] Batch poll error: $e');
      } finally {
        _batchPollInFlight = false;
      }
    });
  }

  void _showManualRestartReminder() {
    final context = Get.context;
    if (context == null) return;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.restart_alt_rounded, color: Color(0xFFF59E0B)),
        title: const Text('یادآوری ری‌استارت'),
        content: const Text(
          'نصب نرم‌افزارها تمام شد. برای اعمال کامل تغییرات، بعداً سیستم را به‌صورت دستی ری‌استارت کنید. برنامه سیستم را خودکار ری‌استارت نمی‌کند.',
          textAlign: TextAlign.center,
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('متوجه شدم؛ بعداً ری‌استارت می‌کنم'),
          ),
        ],
      ),
    );
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
