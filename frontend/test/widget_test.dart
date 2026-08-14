import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:central_system_checker/l10n/app_localizations.dart';
import 'package:central_system_checker/models/system_info.dart';
import 'package:central_system_checker/widgets/loading_view.dart';
import 'package:central_system_checker/widgets/cards/cpu_card.dart';
import 'package:central_system_checker/widgets/cards/ram_card.dart';
import 'package:central_system_checker/widgets/simple_mode_view.dart';

Widget buildTestableWidget(Widget child, {Locale locale = const Locale('fa')}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(
      body: child,
    ),
  );
}

void main() {
  testWidgets('LoadingView displays expected branding and message in English and Persian', (WidgetTester tester) async {
    // English test
    await tester.pumpWidget(
      buildTestableWidget(
        const LoadingView(),
        locale: const Locale('en'),
      ),
    );

    expect(find.text('Central System Checker'), findsOneWidget);
    expect(find.text('Detecting hardware & Windows specifications...'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    // Persian test
    await tester.pumpWidget(
      buildTestableWidget(
        const LoadingView(),
        locale: const Locale('fa'),
      ),
    );

    expect(find.text('مرکزی سیستم چکر'), findsOneWidget);
    expect(find.text('در حال شناسایی مشخصات سخت‌افزار و ویندوز...'), findsOneWidget);
  });

  testWidgets('CpuCard displays CPU specifications with localization', (WidgetTester tester) async {
    final cpu = CpuInfo(
      name: '12th Gen Intel Core i3-12100F',
      manufacturer: 'Intel',
      cores: 4,
      threads: 8,
      maxClockMhz: 3300,
      maxClockDisplay: '3.30 GHz',
    );

    // English
    await tester.pumpWidget(
      buildTestableWidget(
        CpuCard(cpu: cpu),
        locale: const Locale('en'),
      ),
    );

    expect(find.text('CPU'), findsOneWidget);
    expect(find.text('12th Gen Intel Core i3-12100F'), findsOneWidget);
    expect(find.text('Intel'), findsOneWidget);
    expect(find.text('4 Cores / 8 Threads'), findsOneWidget);
    expect(find.text('3.30 GHz'), findsOneWidget);

    // Persian
    await tester.pumpWidget(
      buildTestableWidget(
        CpuCard(cpu: cpu),
        locale: const Locale('fa'),
      ),
    );

    expect(find.text('سی‌پی‌یو'), findsOneWidget);
    expect(find.text('12th Gen Intel Core i3-12100F'), findsOneWidget);
    expect(find.text('Intel'), findsOneWidget);
    expect(find.text('4 هسته / 8 رشته'), findsOneWidget);
    expect(find.text('3.30 GHz'), findsOneWidget);
  });

  testWidgets('RamCard displays RAM summary and modules', (WidgetTester tester) async {
    final ram = RamInfo(
      totalGb: 16.0,
      totalDisplay: '16 GB',
      moduleCount: 2,
      moduleSummary: '8 GB + 8 GB',
      speedMhz: 2133,
      speedDisplay: '2133 MHz',
      modules: [
        RamModule(
          slot: 'DIMM 0',
          capacityGb: 8.0,
          capacityDisplay: '8 GB',
          speedMhz: 2133,
          speedDisplay: '2133 MHz',
          type: 'DDR4',
          manufacturer: 'Golden Empire',
          partNumber: 'CL15',
        ),
      ],
    );

    await tester.pumpWidget(
      buildTestableWidget(
        RamCard(ram: ram),
        locale: const Locale('fa'),
      ),
    );

    expect(find.text('رم'), findsOneWidget);
    expect(find.text('16 GB'), findsAtLeast(1));
    expect(find.text('8 GB + 8 GB'), findsOneWidget);
    expect(find.text('2133 MHz'), findsAtLeast(1));
  });

  testWidgets('SimpleModeView displays 6 priority components for invoice comparison', (WidgetTester tester) async {
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
        StorageInfo(
          model: 'Kingston SNV2S 500GB',
          type: 'NVMe SSD',
          busType: 'NVMe',
          capacityDisplay: '500 GB',
          serial: '50026B7685D26C4E',
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
    );

    await tester.pumpWidget(
      buildTestableWidget(
        SingleChildScrollView(
          child: SimpleModeView(info: mockInfo),
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
    expect(find.text('ویندوز'), findsOneWidget);

    // Verify Untranslated Technical Hardware Specs
    expect(find.text('Intel Core i3-12100F'), findsOneWidget);
    expect(find.text('16 GB'), findsOneWidget);
    expect(find.text('NVIDIA GeForce RTX 3060'), findsOneWidget);
    expect(find.text('Gigabyte H610M K DDR4'), findsOneWidget);
    expect(find.text('Windows 11 Enterprise'), findsOneWidget);
  });
}
