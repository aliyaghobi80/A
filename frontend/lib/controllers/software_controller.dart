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

  List<SoftwarePackage> get packages => packagesResponse.value.packages;
  PackageSummary get summary => packagesResponse.value.summary;
  bool get directoryExists => packagesResponse.value.directoryExists;
  String get packagesDirectory => packagesResponse.value.packagesDirectory;

  @override
  void onInit() {
    super.onInit();
    fetchPackages();
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
            const Icon(Icons.install_desktop_rounded, color: Color(0xFF2563EB), size: 24),
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
          l10n.confirmInstallMessage(pkg.name),
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
          ElevatedButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(l10n.install),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      installingPackageId.value = targetId;

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('${l10n.installing} ${pkg.name}... (پنجره نصب باز شد)'),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );

      try {
        final res = await _apiService.installPackage(targetId);
        final success = res['success'] == true;
        final isNowInstalled = res['is_installed'] == true;
        final installedVer = res['installed_version'] as String? ?? '';

        String resultMsg;
        if (isNowInstalled) {
          resultMsg = installedVer.isNotEmpty && installedVer != 'Not available'
              ? '✓ ${pkg.name} با موفقیت نصب شد (نسخه $installedVer).'
              : '✓ ${pkg.name} با موفقیت نصب شد.';
        } else {
          resultMsg = res['message'] ?? (success ? l10n.installSuccess(pkg.name) : l10n.installFailed(pkg.name));
        }

        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(resultMsg),
            backgroundColor: isNowInstalled ? const Color(0xFF10B981) : (success ? const Color(0xFF2563EB) : const Color(0xFFEF4444)),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Update package list from result or fetch
        if (res['packages_result'] != null) {
          packagesResponse.value = PackagesResponse.fromJson(Map<String, dynamic>.from(res['packages_result']));
        } else {
          await scanPackages();
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
}
