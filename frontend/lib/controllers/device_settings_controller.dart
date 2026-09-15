import 'package:flutter/material.dart';
import 'dart:async';
import 'package:get/get.dart';
import '../services/api_service.dart';
import 'qc_controller.dart';

class DeviceSettingsController extends GetxController {
  final ApiService _api;
  DeviceSettingsController({ApiService? api}) : _api = api ?? ApiService();

  final isLoading = false.obs;
  final isPinningSecurity = false.obs;
  final isSettingSleep = false.obs;
  final isDisablingStartup = false.obs;
  final isDisablingBackgroundApps = false.obs;
  final hasBattery = false.obs;
  final windowsLabel = 'Windows'.obs;
  final isWindows10 = false.obs;
  final pinNeedsConfirmation = false.obs;
  final sleepReady = RxnBool();
  final windowsActivated = false.obs;
  final desktopIconsReady = false.obs;
  final timezoneReady = false.obs;
  final timezoneDescription = 'در حال بررسی...'.obs;
  final isSettingDesktopTime = false.obs;
  final startupReady = RxnBool();
  final backgroundReady = RxnBool();
  final powerReady = RxnBool();
  final powerSupported = false.obs;
  final isSettingPower = false.obs;
  final powerDescription = 'در حال بررسی...'.obs;
  final startupDescription = 'در حال بررسی...'.obs;
  final timeoutDescription = 'در حال بررسی...'.obs;
  Timer? _statusTimer;

  @override
  void onInit() {
    super.onInit();
    refreshStatus();
    _statusTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => refreshStatus(),
    );
  }

  @override
  void onClose() {
    _statusTimer?.cancel();
    super.onClose();
  }

  Future<void> refreshStatus({bool afterAction = false}) async {
    if (afterAction) {
      while (isLoading.value && !isClosed) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
    if (isLoading.value || isClosed) return;
    isLoading.value = true;
    try {
      final result = await _api.getDeviceSettingsStatus();
      if (isClosed) return;
      final desktop = result['desktop_time'] as Map<String, dynamic>? ?? {};
      windowsActivated.value = desktop['windows_activated'] == true;
      desktopIconsReady.value = desktop['desktop_icons_ready'] == true;
      timezoneReady.value =
          '${desktop['timezone']}'.replaceAll('_dstoff', '') ==
              'Iran Standard Time' &&
          desktop['automatic_timezone'] == true &&
          desktop['location_enabled'] == true;
      timezoneDescription.value =
          'منطقهٔ فعلی: ${desktop['timezone'] ?? 'نامشخص'} • تشخیص خودکار: ${desktop['automatic_timezone'] == true ? 'روشن' : 'خاموش یا نامشخص'}${desktop['location_enabled'] == true ? '' : ' • برای تشخیص خودکار Location را روشن کنید.'}';
      sleepReady.value = result['timeouts']?['all_never'] as bool?;
      startupReady.value = result['startup']?['all_disabled'] as bool?;
      backgroundReady.value =
          result['background_apps']?['all_disabled'] as bool?;
      powerReady.value = result['power_modes']?['configured'] as bool?;
      powerSupported.value = result['power_modes']?['supported'] == true;
      powerDescription.value =
          'برق متصل: ${result['power_modes']?['ac'] ?? 'نامشخص'} • باتری: ${result['power_modes']?['dc'] ?? 'نامشخص'}';
      startupDescription.value = startupReady.value == null
          ? 'وضعیت Startup Apps قابل تأیید نیست.'
          : '${result['startup']?['enabled_count'] ?? 0} برنامهٔ فعال از ${result['startup']?['total'] ?? 0} ورودی Startup';
      final values =
          result['timeouts']?['values'] as Map<String, dynamic>? ?? {};
      timeoutDescription.value = values.isEmpty
          ? 'وضعیت زمان‌ها قابل بررسی نیست.'
          : values.entries
                .map((entry) {
                  final label = entry.key
                      .replaceAll('_ac', ' برق')
                      .replaceAll('_dc', ' باتری');
                  final value = entry.value == null
                      ? 'نامشخص'
                      : entry.value == 0
                      ? 'Never'
                      : '${entry.value} ثانیه';
                  return '$label: $value';
                })
                .join(' • ');
      final windows = result['windows'] as Map<String, dynamic>?;
      hasBattery.value = result['has_battery'] == true;
      windowsLabel.value = windows?['label'] as String? ?? 'Windows';
      isWindows10.value = result['background_apps_supported'] == true;
      pinNeedsConfirmation.value =
          result['taskbar_pin_requires_confirmation'] == true;
    } finally {
      if (!isClosed) isLoading.value = false;
    }
  }

  Future<void> setPowerModes(BuildContext context) async {
    if (isSettingPower.value) return;
    isSettingPower.value = true;
    try {
      final result = await _api.setLaptopPowerModes();
      await refreshStatus(afterAction: true);
      if (context.mounted) _showResult(context, result);
    } finally {
      isSettingPower.value = false;
    }
  }

  Future<void> configureDesktopTime(
    BuildContext context, {
    required bool icons,
  }) async {
    if (isSettingDesktopTime.value || (icons && !windowsActivated.value)) {
      return;
    }
    isSettingDesktopTime.value = true;
    try {
      final result = icons
          ? await _api.showDesktopIcons()
          : await _api.setTehranTimezone();
      await refreshStatus(afterAction: true);
      if (context.mounted) _showResult(context, result);
    } finally {
      isSettingDesktopTime.value = false;
    }
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
    await refreshStatus(afterAction: true);
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
    await refreshStatus(afterAction: true);
    isDisablingStartup.value = false;
    if (!context.mounted) return;
    _showResult(context, result);
  }

  Future<void> disableBackgroundApps(BuildContext context) async {
    if (!isWindows10.value || isDisablingBackgroundApps.value) return;
    isDisablingBackgroundApps.value = true;
    final result = await _api.disableWindows10BackgroundApps();
    await refreshStatus(afterAction: true);
    isDisablingBackgroundApps.value = false;
    if (!context.mounted) return;
    _showResult(context, result);
  }

  void _showResult(BuildContext context, Map<String, dynamic> result) {
    if (Get.isRegistered<QcController>()) {
      unawaited(Get.find<QcController>().fetchInitialQcStatus());
    }
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
