import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:central_system_checker/controllers/activation_controller.dart';
import 'package:central_system_checker/controllers/driver_install_controller.dart';
import 'package:central_system_checker/controllers/qc_controller.dart';
import 'package:central_system_checker/controllers/software_controller.dart';
import 'package:central_system_checker/controllers/system_info_controller.dart';
import 'package:central_system_checker/controllers/theme_language_controller.dart';
import 'package:central_system_checker/l10n/app_localizations.dart';
import 'package:central_system_checker/models/system_info.dart';
import 'package:central_system_checker/widgets/loading_view.dart';
import 'package:central_system_checker/widgets/cards/cpu_card.dart';
import 'package:central_system_checker/widgets/cards/ram_card.dart';
import 'package:central_system_checker/widgets/cards/driver_card.dart';
import 'package:central_system_checker/widgets/cards/office_card.dart';
import 'package:central_system_checker/widgets/cards/packages_card.dart';
import 'package:central_system_checker/widgets/simple_mode_view.dart';

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
  setUp(() {
    Get.reset();
    Get.put(ThemeLanguageController());
    Get.put(SystemInfoController());
    Get.put(SoftwareController());
    Get.put(DriverInstallController());
    Get.put(ActivationController());
    Get.put(QcController());
  });

  testWidgets(
    'LoadingView displays expected branding and message in English and Persian',
    (WidgetTester tester) async {
      // English test
      await tester.pumpWidget(
        buildTestableWidget(const LoadingView(), locale: const Locale('en')),
      );

      expect(find.text('Central System Checker'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      // Persian test
      await tester.pumpWidget(
        buildTestableWidget(const LoadingView(), locale: const Locale('fa')),
      );

      expect(find.text('مرکزی سیستم چکر'), findsOneWidget);
    },
  );

  testWidgets('CpuCard displays CPU specifications with localization', (
    WidgetTester tester,
  ) async {
    final cpu = CpuInfo(
      name: '12th Gen Intel Core i3-12100F',
      manufacturer: 'Intel',
      cores: 4,
      threads: 8,
      maxClockMhz: 3300,
      maxClockDisplay: '3.30 GHz',
    );

    await tester.pumpWidget(
      buildTestableWidget(CpuCard(cpu: cpu), locale: const Locale('fa')),
    );

    expect(find.text('سی‌پی‌یو'), findsOneWidget);
    expect(find.text('12th Gen Intel Core i3-12100F'), findsAtLeast(1));
    expect(find.text('4 هسته / 8 رشته'), findsOneWidget);
  });

  testWidgets('RamCard displays RAM summary and modules', (
    WidgetTester tester,
  ) async {
    final ram = RamInfo(
      totalGb: 16.0,
      totalDisplay: '16 GB',
      moduleCount: 2,
      moduleSummary: '8 GB + 8 GB',
      speedMhz: 2133,
      speedDisplay: '2133 MHz',
      modules: [],
    );

    await tester.pumpWidget(
      buildTestableWidget(RamCard(ram: ram), locale: const Locale('fa')),
    );

    expect(find.text('حافظه رم'), findsOneWidget);
    expect(find.text('16 GB'), findsAtLeast(1));
  });

  testWidgets('DriverCard and PackagesCard display diagnostics accurately', (
    WidgetTester tester,
  ) async {
    final drivers = [
      DriverItem(
        id: 'graphics',
        name: 'Graphics / GPU',
        displayName: 'Graphics / GPU',
        deviceName: 'NVIDIA GeForce RTX 3060',
        category: 'Display',
        status: 'OK',
        isHealthy: true,
        isPresent: true,
        problemCode: 0,
        statusDescription: 'Device is working properly',
        instanceId: 'PCI\\VEN_10DE',
      ),
      DriverItem(
        id: 'bluetooth',
        name: 'Bluetooth Adapter',
        displayName: 'Bluetooth Adapter',
        deviceName: 'Not present',
        category: 'Bluetooth',
        status: 'Not Present',
        isHealthy: true,
        isPresent: false,
        problemCode: 0,
        statusDescription: 'Bluetooth hardware is not present',
        instanceId: 'Not available',
      ),
    ];
    final driverSummary = DriverSummary(
      healthyCount: 1,
      totalPresentCount: 1,
      allHealthy: true,
      hasProblem: false,
      statusText: 'Ready',
    );

    final packages = [
      SoftwarePackage(
        id: '7zip',
        name: '7-Zip',
        filename: '7Zip.EXE',
        relativePath: 'Utilities/7Zip.EXE',
        fullPath: r'G:\MarkaziSystem\Packages\Utilities\7Zip.EXE',
        version: '24.09',
        publisher: 'Igor Pavlov',
        fileSizeDisplay: '564.0 KB',
        isValid: true,
        status: 'Not Installed',
        isInstalled: false,
        installedVersion: 'Not available',
        installAllowed: true,
        hasIcon: false,
      ),
    ];
    final pkgSummary = PackageSummary(
      totalPackages: 1,
      validPackages: 1,
      installedPackages: 0,
      availableToInstall: 1,
    );

    await tester.pumpWidget(
      buildTestableWidget(
        Column(
          children: [
            DriverCard(drivers: drivers, summary: driverSummary),
            PackagesCard(
              packages: packages,
              summary: pkgSummary,
              packagesDirectory: r'G:\MarkaziSystem\Packages',
              directoryExists: true,
            ),
          ],
        ),
        locale: const Locale('fa'),
      ),
    );

    expect(find.text('بررسی جامع درایورهای سخت‌افزاری'), findsOneWidget);
    expect(find.text('1 سالم'), findsOneWidget);

    expect(find.text('نرم‌افزارها'), findsOneWidget);
    expect(find.text('7-Zip'), findsAtLeast(1));
  });

  testWidgets(
    'SimpleModeView displays quick status bar, 6 large spec cards, drivers and software',
    (WidgetTester tester) async {
      final mockInfo = SystemInfo(
        status: 'success',
        timestamp: '2026-08-14T07:00:00',
        scanDurationMs: 95.0,
        cpu: CpuInfo(
          name: 'Intel Core i3-12100F',
          manufacturer: 'Intel',
          cores: 4,
          threads: 8,
          maxClockDisplay: '3.30 GHz',
        ),
        motherboard: MotherboardInfo(
          manufacturer: 'Gigabyte Technology Co., Ltd.',
          model: 'Gigabyte H610M K DDR4',
          serial: 'Not available',
        ),
        ram: RamInfo(
          totalGb: 16.0,
          totalDisplay: '16 GB',
          moduleCount: 2,
          moduleSummary: '8 GB + 8 GB',
          speedMhz: 2133,
          speedDisplay: '2133 MHz',
          modules: [],
        ),
        gpu: [
          GpuInfo(
            name: 'NVIDIA GeForce RTX 3060',
            manufacturer: 'NVIDIA',
            vramGb: 12.0,
            vramDisplay: '12 GB VRAM',
            driverVersion: '32.0.16.1088',
          ),
        ],
        storage: [
          StorageInfo(
            model: 'Samsung SSD 870 EVO 500GB',
            type: 'SATA SSD',
            busType: 'SATA',
            capacityDisplay: '500 GB',
            serial: 'S5Y1NJ0NC40889T',
            healthStatus: 'Healthy',
          ),
        ],
        windows: WindowsInfo(
          edition: 'Windows 11 Enterprise',
          version: 'Version 25H2',
          build: '26200.9168',
          architecture: '64-bit',
        ),
        system: SystemMetaInfo(
          computerName: 'DESKTOP-TEST',
          manufacturer: 'Gigabyte Technology Co., Ltd.',
          model: 'H610M K DDR4',
        ),
        bios: BiosInfo(
          manufacturer: 'American Megatrends',
          version: 'F22',
          date: '2023-06-05',
        ),
        network: [],
        drivers: [
          DriverItem(
            id: 'graphics',
            name: 'Graphics / GPU',
            displayName: 'Graphics / GPU',
            deviceName: 'NVIDIA GeForce RTX 3060',
            category: 'Display',
            status: 'OK',
            isHealthy: true,
            isPresent: true,
            problemCode: 0,
            statusDescription: 'Device is working properly',
            instanceId: 'PCI\\VEN_10DE',
          ),
        ],
        driverSummary: DriverSummary(
          healthyCount: 1,
          totalPresentCount: 1,
          allHealthy: true,
          hasProblem: false,
          statusText: 'Ready',
        ),
        software: [
          SoftwareItem(
            id: 'chrome',
            name: 'Google Chrome',
            displayName: 'Google Chrome',
            status: 'Installed',
            isInstalled: true,
            version: '151.0.7922.138',
            productName: 'Google Chrome',
            detectionSource: 'Registry',
            installLocation: 'C:\\Program Files\\Google\\Chrome\\Application',
            required: true,
          ),
        ],
        softwareSummary: SoftwareSummary(
          installedCount: 1,
          totalCount: 1,
          allInstalled: true,
        ),
        requiredFiles: [
          RequiredFileItem(
            id: 'hosts',
            name: 'System Hosts File',
            displayName: 'System Hosts File',
            path: r'C:\Windows\System32\drivers\etc\hosts',
            type: 'file',
            status: 'Present',
            exists: true,
            required: true,
          ),
        ],
        filesSummary: FilesSummary(
          presentCount: 1,
          totalCount: 1,
          allPresent: true,
        ),
        windowsActivation: WindowsActivationInfo(
          installed: true,
          activated: true,
          statusCode: 1,
          statusText: 'Licensed',
          channel: 'Retail',
          partialKey: '8HV2C',
          edition: 'Windows 11 Enterprise',
          description: 'Windows(R) Operating System',
          expiration: null,
          isPermanent: true,
          toolAvailable: true,
          toolPath: r'Tools\WindowsActivation\activate.cmd',
        ),
        officeActivation: OfficeActivationInfo(
          installed: true,
          product: 'Microsoft Office Professional Plus 2024',
          version: '16.0.20228.20158',
          architecture: '64-bit',
          installType: 'Click-to-Run',
          activated: true,
          statusCode: 1,
          statusText: 'Licensed',
          channel: 'Retail',
          partialKey: '88KC6',
          expiration: null,
          toolAvailable: true,
          toolPath: r'Tools\OfficeActivation\activate.cmd',
        ),
      );

      final mockDiscoveredPackages = PackagesResponse(
        directoryExists: true,
        packagesDirectory: r'G:\MarkaziSystem\Packages',
        packages: [
          SoftwarePackage(
            id: 'chromesetup',
            name: 'Google Chrome',
            filename: 'ChromeSetup.exe',
            relativePath: 'Apps/Browsers/ChromeSetup.exe',
            fullPath:
                r'G:\MarkaziSystem\Packages\Apps\Browsers\ChromeSetup.exe',
            version: '151.0.7922.138',
            publisher: 'Google LLC',
            fileSizeDisplay: '564.0 KB',
            isValid: true,
            status: 'Installed',
            isInstalled: true,
            installedVersion: '151.0.7922.138',
            installAllowed: false,
            hasIcon: false,
          ),
          SoftwarePackage(
            id: 'vlc',
            name: 'VLC Media Player',
            filename: 'vlc-setup.exe',
            relativePath: 'Tools/vlc-setup.exe',
            fullPath: r'G:\MarkaziSystem\Packages\Tools\vlc-setup.exe',
            version: '3.0.21',
            publisher: 'VideoLAN',
            fileSizeDisplay: '42.1 MB',
            isValid: true,
            status: 'Not Installed',
            isInstalled: false,
            installedVersion: 'Not available',
            installAllowed: true,
            hasIcon: false,
          ),
        ],
        summary: PackageSummary(
          totalPackages: 2,
          validPackages: 2,
          installedPackages: 1,
          availableToInstall: 1,
        ),
      );

      final softCtrl = Get.find<SoftwareController>();
      softCtrl.packagesResponse.value = mockDiscoveredPackages;

      await tester.pumpWidget(
        buildTestableWidget(
          SingleChildScrollView(
            child: SimpleModeView(
              info: mockInfo,
              initialPackages: mockDiscoveredPackages,
            ),
          ),
          locale: const Locale('fa'),
        ),
      );

      // Verify Persian hardware section titles
      expect(find.text('سی‌پی‌یو'), findsOneWidget);
      expect(find.text('رم'), findsOneWidget);
      expect(find.text('کارت گرافیک'), findsOneWidget);
      expect(find.text('مادربرد'), findsOneWidget);
      expect(find.text('حافظه ذخیره‌سازی'), findsOneWidget);
      expect(find.text('ویندوز'), findsAtLeast(1));

      // Verify Driver and Software sections
      expect(find.text('درایورها'), findsAtLeast(1));
      expect(find.text('نرم‌افزارها'), findsAtLeast(1));
      expect(find.text('Google Chrome'), findsAtLeast(1));
      expect(find.text('VLC Media Player'), findsAtLeast(1));
      expect(find.text('مایکروسافت آفیس'), findsAtLeast(1));
    },
  );

  testWidgets(
    'OfficeCard displays Microsoft Office activation and licensing status',
    (WidgetTester tester) async {
      final officeActivated = OfficeActivationInfo(
        installed: true,
        product: 'Microsoft Office Professional Plus 2024',
        version: '16.0.20228.20158',
        architecture: '64-bit',
        installType: 'Click-to-Run',
        activated: true,
        statusCode: 1,
        statusText: 'Licensed',
        channel: 'Retail',
        partialKey: '88KC6',
        expiration: null,
        toolAvailable: true,
        toolPath: r'Tools\OfficeActivation\activate.cmd',
      );

      await tester.pumpWidget(
        buildTestableWidget(
          OfficeCard(office: officeActivated),
          locale: const Locale('fa'),
        ),
      );

      expect(find.text('مایکروسافت آفیس'), findsOneWidget);
      expect(
        find.text('Microsoft Office Professional Plus 2024'),
        findsAtLeast(1),
      );
      expect(find.text('فعال است'), findsOneWidget);
      expect(find.text('Retail'), findsOneWidget);
      // Activation button should NOT be shown because already activated
      expect(find.text('فعالسازی آفیس'), findsNothing);
    },
  );
}
