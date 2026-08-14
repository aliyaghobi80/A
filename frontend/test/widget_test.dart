import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pc_system_inspector/models/system_info.dart';
import 'package:pc_system_inspector/widgets/loading_view.dart';
import 'package:pc_system_inspector/widgets/cards/cpu_card.dart';
import 'package:pc_system_inspector/widgets/cards/ram_card.dart';

void main() {
  testWidgets('LoadingView displays expected branding and message', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LoadingView(message: 'Detecting system information...'),
        ),
      ),
    );

    expect(find.text('PC System Inspector'), findsOneWidget);
    expect(find.text('Detecting system information...'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('CpuCard displays CPU specifications', (WidgetTester tester) async {
    final cpu = CpuInfo(
      name: '12th Gen Intel Core i3-12100F',
      manufacturer: 'Intel',
      cores: 4,
      threads: 8,
      maxClockMhz: 3300,
      maxClockDisplay: '3.30 GHz',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CpuCard(cpu: cpu),
        ),
      ),
    );

    expect(find.text('CPU'), findsOneWidget);
    expect(find.text('12th Gen Intel Core i3-12100F'), findsOneWidget);
    expect(find.text('Intel'), findsOneWidget);
    expect(find.text('4 Cores / 8 Threads'), findsOneWidget);
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
      MaterialApp(
        home: Scaffold(
          body: RamCard(ram: ram),
        ),
      ),
    );

    expect(find.text('RAM (Memory)'), findsOneWidget);
    expect(find.text('16 GB'), findsAtLeast(1));
    expect(find.text('8 GB + 8 GB'), findsOneWidget);
    expect(find.text('2133 MHz'), findsAtLeast(1));
  });
}
