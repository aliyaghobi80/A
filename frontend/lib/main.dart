import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'controllers/activation_controller.dart';
import 'controllers/driver_install_controller.dart';
import 'controllers/qc_controller.dart';
import 'controllers/software_controller.dart';
import 'controllers/system_info_controller.dart';
import 'controllers/theme_language_controller.dart';
import 'l10n/app_localizations.dart';
import 'services/backend_process_manager.dart';
import 'services/settings_service.dart';
import 'theme/app_theme.dart';
import 'widgets/common/app_sidebar.dart';
import 'widgets/common/global_app_header.dart';
import 'widgets/dialogs/exit_dialog.dart';
import 'widgets/error_view.dart';
import 'widgets/loading_view.dart';
import 'widgets/pages/driver_install_page.dart';
import 'widgets/pages/license_status_page.dart';
import 'widgets/pages/settings_page.dart';
import 'widgets/pages/software_install_page.dart';
import 'widgets/pages/system_specs_page.dart';
import 'widgets/pages/tools_source_folders_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await SettingsService.loadSettings();

  // Initialize GetX Controllers
  final themeLanguageCtrl = Get.put(ThemeLanguageController());
  themeLanguageCtrl.loadFromSettings(settings);

  Get.put(SystemInfoController());
  Get.put(SoftwareController());
  Get.put(DriverInstallController());
  Get.put(ActivationController());
  Get.put(QcController());

  runApp(const CentralSystemCheckerApp());
}

class CentralSystemCheckerApp extends StatelessWidget {
  const CentralSystemCheckerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeLanguageCtrl = Get.find<ThemeLanguageController>();

    return Obx(() {
      final themeMode = themeLanguageCtrl.themeMode.value;
      final locale = themeLanguageCtrl.currentLocale.value;
      final languageCode = locale.languageCode;
      final isPersian = languageCode == 'fa';
      final accentName = themeLanguageCtrl.accentColorName.value;
      final textDirection = isPersian ? TextDirection.rtl : TextDirection.ltr;

      return GetMaterialApp(
        title: isPersian ? 'مرکزی سیستم چکر' : 'Markazi System Checker',
        debugShowCheckedModeBanner: false,
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.getLightTheme(
          languageCode: languageCode,
          accentColorName: accentName,
        ),
        darkTheme: AppTheme.getDarkTheme(
          languageCode: languageCode,
          accentColorName: accentName,
        ),
        themeMode: themeMode,
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

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    BackendProcessManager.terminateAll();
    super.dispose();
  }

  @override
  Future<AppExitResponse> didRequestAppExit() async {
    await BackendProcessManager.terminateAll();
    return AppExitResponse.exit;
  }

  @override
  Widget build(BuildContext context) {
    final themeLanguageCtrl = Get.find<ThemeLanguageController>();
    final systemCtrl = Get.find<SystemInfoController>();
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompactScreen = constraints.maxWidth < 850;

              return Obx(() {
                final isLoading = systemCtrl.isLoading.value;
                final error = systemCtrl.errorMessage.value;
                final info = systemCtrl.systemInfo.value;
                final navIndex = themeLanguageCtrl.activeNavIndex.value;

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

                return Row(
                  children: [
                    // Adaptive Responsive Sidebar (220px desktop, 70px compact rail for tablet / small screens)
                    AppSidebar(
                      selectedIndex: navIndex,
                      onItemSelected: (idx) => themeLanguageCtrl.setNavIndex(idx),
                      isCompact: isCompactScreen,
                    ),

                    // Main Content Workspace
                    Expanded(
                      child: Column(
                        children: [
                          // Global AppHeader (Sticky on top)
                          const GlobalAppHeader(),

                          // 6-Page Navigation Content Stack
                          Expanded(
                            child: IndexedStack(
                              index: navIndex,
                              children: [
                                // Page 0: مشخصات سیستم
                                SystemSpecsPage(info: info),
                                // Page 1: نصب درایورها
                                const DriverInstallPage(),
                                // Page 2: نصب نرم‌افزارها
                                const SoftwareInstallPage(),
                                // Page 3: وضعیت لایسنس
                                const LicenseStatusPage(),
                                // Page 4: ابزارها
                                const ToolsSourceFoldersPage(),
                                // Page 5: تنظیمات
                                const SettingsPage(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              });
            },
          ),
        ),
      ),
    );
  }
}
