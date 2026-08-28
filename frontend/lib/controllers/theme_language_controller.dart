import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';

class ThemeLanguageController extends GetxController {
  final Rx<ThemeMode> themeMode = ThemeMode.light.obs;
  final Rx<Locale> currentLocale = const Locale('fa').obs;
  final RxString accentColorName = 'blue'.obs;
  final Rx<String?> customLogoPath = Rx<String?>(null);
  final RxString uiDensity = 'medium'.obs;
  final RxString temperatureUnit = 'C'.obs;
  final RxBool autoScanOnStartup = true.obs;
  final RxBool notificationsEnabled = true.obs;

  // Active navigation page index (0 to 5)
  final RxInt activeNavIndex = 0.obs;

  bool get isDarkMode => themeMode.value == ThemeMode.dark;
  bool get isPersian => currentLocale.value.languageCode == 'fa';
  Color get currentAccentColor => AppTheme.getAccentColor(accentColorName.value);

  double get densityPaddingFactor {
    switch (uiDensity.value) {
      case 'compact':
        return 0.8;
      case 'comfortable':
        return 1.2;
      default:
        return 1.0;
    }
  }

  void loadFromSettings(AppSettings settings) {
    if (settings.themeMode == 'dark') {
      themeMode.value = ThemeMode.dark;
    } else if (settings.themeMode == 'system') {
      themeMode.value = ThemeMode.system;
    } else {
      themeMode.value = ThemeMode.light;
    }

    currentLocale.value = Locale(settings.languageCode);
    accentColorName.value = settings.accentColorName;
    customLogoPath.value = settings.customLogoPath;
    uiDensity.value = settings.uiDensity;
    temperatureUnit.value = settings.temperatureUnit;
    autoScanOnStartup.value = settings.autoScanOnStartup;
    notificationsEnabled.value = settings.notificationsEnabled;
  }

  void setNavIndex(int index) {
    if (index >= 0 && index <= 5) {
      activeNavIndex.value = index;
    }
  }

  void toggleTheme() {
    themeMode.value = isDarkMode ? ThemeMode.light : ThemeMode.dark;
    Get.changeThemeMode(themeMode.value);
    persistSettings();
  }

  void setThemeMode(ThemeMode mode) {
    themeMode.value = mode;
    Get.changeThemeMode(mode);
    persistSettings();
  }

  void setAccentColor(String colorName) {
    if (AppTheme.accentColors.containsKey(colorName.toLowerCase())) {
      accentColorName.value = colorName.toLowerCase();
      persistSettings();
    }
  }

  void setCustomLogo(String? path) {
    customLogoPath.value = path;
    persistSettings();
  }

  void setUiDensity(String density) {
    uiDensity.value = density;
    persistSettings();
  }

  void setTemperatureUnit(String unit) {
    temperatureUnit.value = unit;
    persistSettings();
  }

  void toggleLanguage() {
    final nextLocale = isPersian ? const Locale('en') : const Locale('fa');
    setLocale(nextLocale);
  }

  void setLocale(Locale locale) {
    currentLocale.value = locale;
    Get.updateLocale(locale);
    persistSettings();
  }

  Future<void> persistSettings() async {
    String themeStr = 'light';
    if (themeMode.value == ThemeMode.dark) themeStr = 'dark';
    if (themeMode.value == ThemeMode.system) themeStr = 'system';

    final updated = SettingsService.current.copyWith(
      languageCode: currentLocale.value.languageCode,
      themeMode: themeStr,
      accentColorName: accentColorName.value,
      customLogoPath: customLogoPath.value,
      uiDensity: uiDensity.value,
      temperatureUnit: temperatureUnit.value,
      autoScanOnStartup: autoScanOnStartup.value,
      notificationsEnabled: notificationsEnabled.value,
    );
    await SettingsService.saveSettings(updated);
  }

  Future<void> resetToDefaults() async {
    themeMode.value = ThemeMode.light;
    currentLocale.value = const Locale('fa');
    accentColorName.value = 'blue';
    customLogoPath.value = null;
    uiDensity.value = 'medium';
    temperatureUnit.value = 'C';
    autoScanOnStartup.value = true;
    notificationsEnabled.value = true;

    Get.changeThemeMode(ThemeMode.light);
    Get.updateLocale(const Locale('fa'));
    await persistSettings();
  }
}
