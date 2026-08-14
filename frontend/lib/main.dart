import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'controllers/software_controller.dart';
import 'controllers/system_info_controller.dart';
import 'controllers/theme_language_controller.dart';
import 'l10n/app_localizations.dart';
import 'services/settings_service.dart';
import 'theme/app_theme.dart';
import 'widgets/advanced_mode_view.dart';
import 'widgets/app_header.dart';
import 'widgets/dialogs/exit_dialog.dart';
import 'widgets/error_view.dart';
import 'widgets/loading_view.dart';
import 'widgets/simple_mode_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await SettingsService.loadSettings();

  // Initialize GetX Controllers
  final themeLanguageCtrl = Get.put(ThemeLanguageController());
  themeLanguageCtrl.setLocale(Locale(settings.languageCode));
  themeLanguageCtrl.setThemeMode(settings.isDarkMode ? ThemeMode.dark : ThemeMode.light);
  themeLanguageCtrl.setSimpleMode(settings.displayMode == DisplayMode.simple);

  Get.put(SystemInfoController());
  Get.put(SoftwareController());

  runApp(const CentralSystemCheckerApp());
}

class CentralSystemCheckerApp extends StatelessWidget {
  const CentralSystemCheckerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeLanguageCtrl = Get.find<ThemeLanguageController>();

    return Obx(() {
      final isDarkMode = themeLanguageCtrl.isDarkMode;
      final locale = themeLanguageCtrl.currentLocale.value;
      final languageCode = locale.languageCode;
      final isPersian = languageCode == 'fa';
      final textDirection = isPersian ? TextDirection.rtl : TextDirection.ltr;

      return GetMaterialApp(
        title: isPersian ? 'مرکزی سیستم چکر' : 'Central System Checker',
        debugShowCheckedModeBanner: false,
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.getLightTheme(languageCode: languageCode),
        darkTheme: AppTheme.getDarkTheme(languageCode: languageCode),
        themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
        builder: (context, child) {
          return Directionality(
            textDirection: textDirection,
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: const DashboardScreen(),
      );
    });
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeLanguageCtrl = Get.find<ThemeLanguageController>();
    final systemCtrl = Get.find<SystemInfoController>();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          ExitDialog.show(context);
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Obx(() {
          final isLoading = systemCtrl.isLoading.value;
          final isRefreshing = systemCtrl.isRefreshing.value;
          final error = systemCtrl.errorMessage.value;
          final info = systemCtrl.systemInfo.value;

          if (isLoading && info == null) {
            return LoadingView(message: l10n.loadingMessage);
          }

          if (error.isNotEmpty && info == null) {
            return ErrorView(
              errorMessage: error,
              onRetry: () => systemCtrl.fetchSystemInfo(forceRefresh: true),
            );
          }

          if (info == null) {
            return LoadingView(message: l10n.initializingMessage);
          }

          final isSimple = themeLanguageCtrl.isSimpleMode.value;
          final isDarkMode = themeLanguageCtrl.isDarkMode;
          final currentLanguage = themeLanguageCtrl.currentLocale.value.languageCode;

          return Column(
            children: [
              // Top App Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF101728) : Colors.white,
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? const Color(0xFF1E2C4A) : const Color(0xFFE2E8F0),
                    ),
                  ),
                ),
                child: AppHeader(
                  isRefreshing: isRefreshing,
                  onRefresh: () => systemCtrl.fetchSystemInfo(forceRefresh: true),
                  isDarkMode: isDarkMode,
                  onToggleTheme: () => themeLanguageCtrl.toggleTheme(),
                  displayMode: isSimple ? DisplayMode.simple : DisplayMode.advanced,
                  onModeChanged: (mode) => themeLanguageCtrl.setSimpleMode(mode == DisplayMode.simple),
                  currentLanguage: currentLanguage,
                  onLanguageChanged: (lang) => themeLanguageCtrl.setLocale(Locale(lang)),
                  lastUpdated: info.timestamp,
                ),
              ),

              // Main Scrollable Dashboard Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isSimple)
                        SimpleModeView(info: info)
                      else
                        AdvancedModeView(info: info),

                      const SizedBox(height: 24),

                      // Footer Status Bar
                      Center(
                        child: Directionality(
                          textDirection: currentLanguage == 'fa'
                              ? TextDirection.rtl
                              : TextDirection.ltr,
                          child: Text(
                            l10n.scanCompleted(info.scanDurationMs, info.system.computerName),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    ),
    );
  }
}
