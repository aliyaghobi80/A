import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'controllers/activation_controller.dart';
import 'controllers/driver_install_controller.dart';
import 'controllers/device_settings_controller.dart';
import 'controllers/hardware_test_controller.dart';
import 'controllers/qc_controller.dart';
import 'controllers/software_controller.dart';
import 'controllers/system_info_controller.dart';
import 'controllers/theme_language_controller.dart';
import 'l10n/app_localizations.dart';
import 'services/backend_process_manager.dart';
import 'services/settings_service.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/common/app_frame.dart';
import 'widgets/common/app_sidebar.dart';
import 'widgets/common/global_app_header.dart';
import 'widgets/dialogs/exit_dialog.dart';
import 'widgets/error_view.dart';
import 'widgets/loading_view.dart';
import 'widgets/pages/driver_install_page.dart';
import 'widgets/pages/device_settings_page.dart';
import 'widgets/pages/hardware_tests_page.dart';
import 'widgets/pages/license_status_page.dart';
import 'widgets/pages/settings_page.dart';
import 'widgets/pages/software_install_page.dart';
import 'widgets/pages/system_specs_page.dart';
import 'widgets/pages/tools_source_folders_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Pre-warm backend process asynchronously in parallel with Flutter startup
  unawaited(BackendProcessManager.ensureBackendRunning());

  final settings = await SettingsService.loadSettings().timeout(
    const Duration(seconds: 3),
    onTimeout: () => const AppSettings(),
  );

  // Initialize GetX Controllers
  final themeLanguageCtrl = Get.put(ThemeLanguageController(), permanent: true);
  themeLanguageCtrl.loadFromSettings(settings);

  // These controllers own app-wide sessions, not individual pages. Keeping
  // them permanent prevents GetX route/view rebuilds from discarding active
  // queues, selections, filters, or live installation progress.
  Get.put(SystemInfoController(), permanent: true);
  Get.put(SoftwareController(), permanent: true);
  Get.put(DriverInstallController(), permanent: true);
  Get.put(DeviceSettingsController(), permanent: true);
  Get.put(ActivationController(), permanent: true);
  Get.put(HardwareTestController(), permanent: true);
  Get.put(QcController(), permanent: true);

  runApp(const MarkaziSystemCheckerApp());
}

class MarkaziSystemCheckerApp extends StatelessWidget {
  const MarkaziSystemCheckerApp({super.key});

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
            child: AppFrame(
              child: child ?? const SizedBox.shrink(),
            ),
          );
        },
        home: const SplashScreen(),
      );
    });
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // A dashboard/widget disposal is not necessarily an application exit
    // (theme/navigation rebuilds and renderer recovery can also dispose it).
    // Explicit exits are handled by didRequestAppExit / ExitDialog; otherwise
    // keep the backend-owned installation queue alive for the replacement UI.
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (Get.isRegistered<SoftwareController>()) {
      unawaited(Get.find<SoftwareController>().synchronizeBatchInstallState());
    }
    if (Get.isRegistered<DriverInstallController>()) {
      unawaited(
        Get.find<DriverInstallController>().synchronizeDriverBatchState(),
      );
    }
  }

  void _selectNavigationPage(int index) {
    Get.find<ThemeLanguageController>().setNavIndex(index);
    if (index == 2 && Get.isRegistered<SoftwareController>()) {
      unawaited(Get.find<SoftwareController>().synchronizeBatchInstallState());
    } else if (index == 1 && Get.isRegistered<DriverInstallController>()) {
      unawaited(
        Get.find<DriverInstallController>().synchronizeDriverBatchState(),
      );
    }
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
                    onRetry: () =>
                        systemCtrl.fetchSystemInfo(forceRefresh: true),
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
                      onItemSelected: _selectNavigationPage,
                      isCompact: isCompactScreen,
                    ),

                    // Main Content Workspace
                    Expanded(
                      child: Column(
                        children: [
                          // Global AppHeader (Sticky on top)
                          const GlobalAppHeader(),

                          // Main technician workflow pages
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
                                // Page 3: تست قطعات
                                const HardwareTestsPage(),
                                // Page 4: وضعیت لایسنس
                                const LicenseStatusPage(),
                                // Page 5: ابزارها
                                const ToolsSourceFoldersPage(),
                                // Page 6: تنظیمات
                                const DeviceSettingsPage(),
                                // Page 7: تنظیمات برنامه
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
