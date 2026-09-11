import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/api_service.dart';

class DeviceSettingsController extends GetxController {
  final ApiService _api = ApiService();

  final isLoading = false.obs;
  final isPinningSecurity = false.obs;
  final isSettingSleep = false.obs;
  final isDisablingStartup = false.obs;
  final isDisablingBackgroundApps = false.obs;
  final hasBattery = false.obs;
  final windowsLabel = 'Windows'.obs;
  final isWindows10 = false.obs;
  final pinNeedsConfirmation = false.obs;

  @override
  void onInit() {
    super.onInit();
    refreshStatus();
  }

  Future<void> refreshStatus() async {
    isLoading.value = true;
    final result = await _api.getDeviceSettingsStatus();
    final windows = result['windows'] as Map<String, dynamic>?;
    hasBattery.value = result['has_battery'] == true;
    windowsLabel.value = windows?['label'] as String? ?? 'Windows';
    isWindows10.value = result['background_apps_supported'] == true;
    pinNeedsConfirmation.value =
        result['taskbar_pin_requires_confirmation'] == true;
    isLoading.value = false;
  }

  Future<void> pinSecurity(BuildContext context) async {
    if (isPinningSecurity.value) return;
    isPinningSecurity.value = true;
    final result = await _api.pinWindowsSecurity();
    isPinningSecurity.value = false;
    if (!context.mounted) return;
    _showResult(context, result);
  }

  Future<void> setSleepNever(BuildContext context) async {
    if (isSettingSleep.value) return;
    isSettingSleep.value = true;
    final result = await _api.setLaptopSleepNever();
    isSettingSleep.value = false;
    if (!context.mounted) return;
    _showResult(context, result);
  }

  Future<void> disableStartupApps(BuildContext context) async {
    if (isDisablingStartup.value) return;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.power_settings_new_rounded,
          color: Color(0xFFF59E0B),
          size: 38,
        ),
        title: const Text('خاموش‌کردن همهٔ Startup Apps؟'),
        content: const Text(
          'برنامه‌هایی که در بخش Startup ویندوز هستند غیرفعال می‌شوند. خود برنامه‌ها حذف نمی‌شوند و بعداً می‌توانید هرکدام را از تنظیمات Startup دوباره روشن کنید.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('انصراف'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.power_off_rounded, size: 18),
            label: const Text('خاموش کن'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    isDisablingStartup.value = true;
    final result = await _api.disableAllStartupApps();
    isDisablingStartup.value = false;
    if (!context.mounted) return;
    _showResult(context, result);
  }

  Future<void> disableBackgroundApps(BuildContext context) async {
    if (!isWindows10.value || isDisablingBackgroundApps.value) return;
    isDisablingBackgroundApps.value = true;
    final result = await _api.disableWindows10BackgroundApps();
    isDisablingBackgroundApps.value = false;
    if (!context.mounted) return;
    _showResult(context, result);
  }

  void _showResult(BuildContext context, Map<String, dynamic> result) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message'] as String? ?? 'عملیات انجام نشد.'),
        backgroundColor: result['success'] == true
            ? const Color(0xFF0284C7)
            : const Color(0xFFEF4444),
        duration: const Duration(seconds: 6),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
