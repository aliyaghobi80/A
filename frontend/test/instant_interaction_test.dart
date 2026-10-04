import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:markazi_system_checker/widgets/common/copyable_value.dart';
import 'package:markazi_system_checker/widgets/common/instant_option_tile.dart';

void main() {
  testWidgets(
    'option checkmark updates in one frame without rebuilding shell',
    (tester) async {
      final value = false.obs;
      var shellBuilds = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                shellBuilds++;
                return SizedBox(
                  width: 290,
                  child: InstantOptionTile(
                    value: value,
                    enabled: true,
                    title: 'KMS',
                    subtitle: 'Optional',
                    semanticLabel: 'KMS option',
                  ),
                );
              },
            ),
          ),
        ),
      );

      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      expect(value.value, isTrue);
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
      expect(shellBuilds, 1);
    },
  );

  testWidgets('tapping a copyable motherboard model invokes copy action', (
    tester,
  ) async {
    var copies = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CopyableValue(
            tooltip: 'Copy motherboard model',
            onCopy: () => copies++,
            child: const Text('ROG STRIX B860-F GAMING WIFI'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('ROG STRIX B860-F GAMING WIFI'));
    await tester.pump();
    expect(copies, 1);
  });
}
