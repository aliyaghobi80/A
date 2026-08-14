import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../l10n/app_localizations.dart';
import '../models/system_info.dart';
import '../services/api_service.dart';

class SoftwareController extends GetxController {
  final ApiService _apiService = ApiService();

  final Rx<PackagesResponse> packagesResponse = PackagesResponse.empty().obs;
  final RxBool isScanning = false.obs;
  final RxString installingPackageId = ''.obs;
  Timer? _pollTimer;

  List<SoftwarePackage> get packages => packagesResponse.value.packages;
  PackageSummary get summary => packagesResponse.value.summary;
  bool get directoryExists => packagesResponse.value.directoryExists;
  String get packagesDirectory => packagesResponse.value.packagesDirectory;

  @override
  void onInit() {
    super.onInit();
    fetchPackages();
  }

  @override
  void onClose() {
    _pollTimer?.cancel();
    super.onClose();
  }

  Future<void> fetchPackages({String? customDir}) async {
    final res = await _apiService.fetchPackages(customDir: customDir);
    packagesResponse.value = res;
  }

  Future<void> scanPackages() async {
    isScanning.value = true;
    try {
      final res = await _apiService.scanPackages();
      packagesResponse.value = res;
    } finally {
      isScanning.value = false;
    }
  }

  bool isCurrentInstalling(SoftwarePackage pkg) {
    final targetId = pkg.relativePath.isNotEmpty ? pkg.relativePath : pkg.id;
    return installingPackageId.value == targetId;
  }

  Future<void> installPackageInteractive(BuildContext context, SoftwarePackage pkg) async {
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
            const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF2563EB), size: 24),
            const SizedBox(width: 10),
            Text(
              l10n.confirmInstallTitle,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        content: Text(
          'آیا مایل به اجرای نصاب ${pkg.name} با دسترسی مدیر (Run as Administrator) هستید؟',
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
            icon: const Icon(Icons.play_arrow_rounded, size: 16),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            label: Text(l10n.install),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      installingPackageId.value = targetId;

      try {
        final targetPath = pkg.fullPath.isNotEmpty
            ? pkg.fullPath
            : (packagesDirectory.isNotEmpty
                ? '$packagesDirectory\\${pkg.relativePath.replaceAll('/', '\\')}'
                : pkg.relativePath);

        // 1. Direct interactive foreground desktop launch via Windows cmd start
        if (Platform.isWindows && targetPath.isNotEmpty) {
          try {
            await Process.run('cmd.exe', ['/c', 'start', '', targetPath], runInShell: true);
          } catch (pe) {
            debugPrint('[SoftwareController] Direct desktop start error: $pe');
          }
        }

        // 2. Also notify backend API (which invokes ShellExecuteW runas)
        final res = await _apiService.installPackage(targetId);
        final message = res['message'] as String? ?? '';

        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(message.isNotEmpty ? message : 'پنجره نصب ${pkg.name} با دسترسی مدیر باز شد.'),
            backgroundColor: const Color(0xFF2563EB),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );

        _startAutoDetectionPoll(pkg, scaffoldMessenger);
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

  void _startAutoDetectionPoll(SoftwarePackage pkg, ScaffoldMessengerState scaffoldMessenger) {
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
        final ver = updated.installedVersion;
        final verStr = (ver.isNotEmpty && ver != 'Not available') ? ' (نسخه $ver)' : '';
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('✓ ${pkg.name} با موفقیت در سیستم شناسایی شد$verStr.'),
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

  Future<void> openInstalledApp(BuildContext context, SoftwarePackage pkg) async {
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
      if (pkg.installedExePath != null && pkg.installedExePath!.isNotEmpty && Platform.isWindows) {
        try {
          await Process.run('cmd.exe', ['/c', 'start', '', pkg.installedExePath!], runInShell: true);
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
      final msg = res['message'] as String? ?? (success ? '✓ برنامه باز شد.' : 'خطا در باز کردن برنامه.');

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: success ? const Color(0xFF10B981) : const Color(0xFFEF4444),
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
}
