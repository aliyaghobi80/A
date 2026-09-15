import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:markazi_system_checker/l10n/app_localizations.dart';
import 'package:markazi_system_checker/models/system_info.dart';
import 'package:markazi_system_checker/widgets/common/ram_slot_summary.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets(
      'four slots keep A2 populated, other slots empty (dark=$dark)',
      (tester) async {
        tester.view.resetPhysicalSize();
        tester.view.physicalSize = const Size(750, 1400);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final ram = RamInfo.fromJson({
          'total_slots': 4,
          'module_count': 2,
          'modules': [
            {'slot': 'A2', 'capacity_display': '16 GB', 'rated_cl': 40},
            {'slot': 'B2', 'capacity_display': '16 GB', 'rated_cl': 40},
          ],
          'slots': [
            {'slot': 'A1', 'occupied': false},
            {'slot': 'A2', 'occupied': true, 'module_index': 0},
            {'slot': 'B1', 'occupied': false},
            {'slot': 'B2', 'occupied': true, 'module_index': 1},
          ],
        });
        expect(ram.modules.first.ratedCl, 40);
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? ThemeData.dark() : ThemeData.light(),
            locale: const Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: Scaffold(
              body: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
                child: RamSlotSummary(ram: ram),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('A1 — Empty'), findsOneWidget);
        expect(find.text('A2 — 16 GB'), findsOneWidget);
        expect(find.text('B1 — Empty'), findsOneWidget);
        expect(find.text('B2 — 16 GB'), findsOneWidget);
        expect(find.text('4 RAM slots • 2 occupied • 2 empty'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
