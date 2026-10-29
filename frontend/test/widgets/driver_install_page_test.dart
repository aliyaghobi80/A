import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:markazi_system_checker/controllers/activation_controller.dart';
import 'package:markazi_system_checker/controllers/driver_install_controller.dart';
import 'package:markazi_system_checker/controllers/qc_controller.dart';
import 'package:markazi_system_checker/controllers/software_controller.dart';
import 'package:markazi_system_checker/controllers/system_info_controller.dart';
import 'package:markazi_system_checker/controllers/theme_language_controller.dart';
import 'package:markazi_system_checker/l10n/app_localizations.dart';
import 'package:markazi_system_checker/models/system_info.dart';
import 'package:markazi_system_checker/widgets/pages/driver_install_page.dart';

Widget buildTestableWidget(Widget child, {Locale locale = const Locale('fa')}) {
  return GetMaterialApp(
    key: ValueKey(locale.languageCode),
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(body: child),
  );
}

void main() {
  late DriverInstallController driverCtrl;

  setUp(() {
    Get.reset();
    Get.put(ThemeLanguageController());
    Get.put(SystemInfoController());
    Get.put(SoftwareController());
    driverCtrl = Get.put(DriverInstallController());
    Get.put(ActivationController());
    Get.put(QcController());
  });

  tearDown(() {
    Get.reset();
  });

  group('DriverInstallPage Widget Tests', () {
    testWidgets(
      'renders GPU screen flashing warning banner when installing GPU driver',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        // Configure active GPU installation
        driverCtrl.isBatchInstalling.value = true;
        driverCtrl.batchStatus.value = DriverBatchStatus(
          isRunning: true,
          total: 3,
          completed: 0,
          failed: 0,
          currentFile: 'NVIDIA GeForce Game Ready Driver',
          items: [
            DriverInstallItem(
              filename: 'setup.exe',
              packageId: 'drv_gpu_nv_01',
              displayName: 'NVIDIA GeForce Game Ready Driver',
              category: 'gpu',
              status: 'installing',
              workerId: 1,
            ),
          ],
          activeItems: [
            DriverActiveItem(
              packageId: 'drv_gpu_nv_01',
              displayName: 'NVIDIA GeForce Game Ready Driver',
              category: 'gpu',
              workerId: 1,
              status: 'installing',
              elapsedSeconds: 15.0,
            ),
          ],
        );

        await tester.pumpWidget(buildTestableWidget(const DriverInstallPage()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // 1. Verify warning banner container key is present
        final bannerFinder = find.byKey(
          const ValueKey('gpu-screen-flashing-warning'),
        );
        expect(bannerFinder, findsOneWidget);

        // 2. Verify exact Persian warning text
        expect(
          find.text('«ممکن است صفحه چند ثانیه چشمک بزند؛ برنامه ادامه می‌دهد»'),
          findsOneWidget,
        );

        // 3. Verify TV / display warning icon is present
        expect(find.byIcon(Icons.tv_rounded), findsOneWidget);
      },
    );

    testWidgets(
      'hides GPU screen flashing warning banner when non-GPU driver is installing',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        // Configure active Audio installation (non-GPU)
        driverCtrl.isBatchInstalling.value = true;
        driverCtrl.batchStatus.value = DriverBatchStatus(
          isRunning: true,
          total: 2,
          completed: 0,
          failed: 0,
          currentFile: 'Realtek High Definition Audio',
          items: [
            DriverInstallItem(
              filename: 'setup.exe',
              packageId: 'drv_audio_01',
              displayName: 'Realtek High Definition Audio',
              category: 'audio',
              status: 'installing',
              workerId: 1,
            ),
          ],
          activeItems: [
            DriverActiveItem(
              packageId: 'drv_audio_01',
              displayName: 'Realtek High Definition Audio',
              category: 'audio',
              workerId: 1,
              status: 'installing',
              elapsedSeconds: 5.0,
            ),
          ],
        );

        await tester.pumpWidget(buildTestableWidget(const DriverInstallPage()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Warning banner must NOT be rendered
        expect(
          find.byKey(const ValueKey('gpu-screen-flashing-warning')),
          findsNothing,
        );
        expect(
          find.text('«ممکن است صفحه چند ثانیه چشمک بزند؛ برنامه ادامه می‌دهد»'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'renders dual active items display in 2X mode with stable ValueKeys',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        // Configure 2X mode with two concurrently installing packages
        driverCtrl.isBatchInstalling.value = true;
        driverCtrl.batchStatus.value = DriverBatchStatus(
          isRunning: true,
          doubleSpeed: true,
          mode: '2X',
          workerCount: 2,
          activeWorkers: 2,
          total: 6,
          completed: 2,
          failed: 0,
          currentFile: 'Realtek LAN Driver • Intel Wi-Fi Driver',
          items: [
            DriverInstallItem(
              filename: 'setup.exe',
              packageId: 'pkg_lan_101',
              displayName: 'Realtek LAN Driver',
              category: 'lan',
              status: 'installing',
              workerId: 1,
            ),
            DriverInstallItem(
              filename: 'setup.exe',
              packageId: 'pkg_wifi_102',
              displayName: 'Intel Wi-Fi Driver',
              category: 'wifi',
              status: 'installing',
              workerId: 2,
            ),
          ],
          activeItems: [
            DriverActiveItem(
              packageId: 'pkg_lan_101',
              displayName: 'Realtek LAN Driver',
              category: 'lan',
              workerId: 1,
              status: 'installing',
              elapsedSeconds: 12.0,
            ),
            DriverActiveItem(
              packageId: 'pkg_wifi_102',
              displayName: 'Intel Wi-Fi Driver',
              category: 'wifi',
              workerId: 2,
              status: 'installing',
              elapsedSeconds: 8.0,
            ),
          ],
        );

        await tester.pumpWidget(buildTestableWidget(const DriverInstallPage()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // 1. Verify 2X concurrent header subtitle text
        expect(
          find.text('در حال نصب (۲ مورد هم‌زمان): Realtek LAN Driver • Intel Wi-Fi Driver'),
          findsOneWidget,
        );

        // 2. Verify dual active item slots with stable ValueKeys
        final item1Slot = find.byKey(const ValueKey('queue-item-pkg_lan_101'));
        final item2Slot = find.byKey(const ValueKey('queue-item-pkg_wifi_102'));
        expect(item1Slot, findsAtLeast(1));
        expect(item2Slot, findsAtLeast(1));

        // 3. Verify worker tags
        expect(find.text('Worker 1'), findsOneWidget);
        expect(find.text('Worker 2'), findsOneWidget);

        // 4. Verify display names
        expect(find.text('Realtek LAN Driver'), findsAtLeast(1));
        expect(find.text('Intel Wi-Fi Driver'), findsAtLeast(1));

        // 5. Verify elapsed seconds
        expect(find.text('12 ثانیه'), findsOneWidget);
        expect(find.text('8 ثانیه'), findsOneWidget);
      },
    );
  });
}
