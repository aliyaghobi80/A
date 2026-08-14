import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ThemeLanguageController extends GetxController {
  final Rx<ThemeMode> themeMode = ThemeMode.dark.obs;
  final Rx<Locale> currentLocale = const Locale('fa').obs;
  final RxBool isSimpleMode = true.obs;

  bool get isDarkMode => themeMode.value == ThemeMode.dark;
  bool get isPersian => currentLocale.value.languageCode == 'fa';

  void toggleTheme() {
    themeMode.value = isDarkMode ? ThemeMode.light : ThemeMode.dark;
    Get.changeThemeMode(themeMode.value);
  }

  void setThemeMode(ThemeMode mode) {
    themeMode.value = mode;
    Get.changeThemeMode(mode);
  }

  void toggleLanguage() {
    final nextLocale = isPersian ? const Locale('en') : const Locale('fa');
    setLocale(nextLocale);
  }

  void setLocale(Locale locale) {
    currentLocale.value = locale;
    Get.updateLocale(locale);
  }

  void toggleViewMode() {
    isSimpleMode.value = !isSimpleMode.value;
  }

  void setSimpleMode(bool simple) {
    isSimpleMode.value = simple;
  }
}
