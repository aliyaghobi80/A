import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:markazi_system_checker/controllers/device_settings_controller.dart';
import 'package:markazi_system_checker/controllers/theme_language_controller.dart';
import 'package:markazi_system_checker/services/api_service.dart';
import 'package:markazi_system_checker/widgets/common/copyable_value.dart';
import 'package:markazi_system_checker/widgets/common/instant_option_tile.dart';
import 'package:markazi_system_checker/widgets/pages/device_settings_page.dart';

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

  testWidgets('apply-all button paints busy state before backend completes', (
    tester,
  ) async {
    Get.testMode = true;
    final api = _PendingDeviceSettingsApi();
    final controller = DeviceSettingsController(api: api);
    Get.put(ThemeLanguageController());
    Get.put(controller);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 1400, height: 900, child: DeviceSettingsPage()),
        ),
      ),
    );
    await tester.pump();

    final button = find.byKey(const Key('apply-all-settings-button'));
    expect(button, findsOneWidget);
    expect(find.text('اعمال خودکار همه تنظیمات'), findsOneWidget);

    await tester.tap(button);
    await tester.pump();

    expect(controller.isApplyingAll.value, isTrue);
    expect(find.text('در حال انجام...'), findsOneWidget);
    expect(find.byKey(const ValueKey('apply-all-loading')), findsOneWidget);
    expect(api.applyCalls, 1);

    api.applyCompleter.complete(<String, dynamic>{
      'success': true,
      'message': 'انجام شد.',
    });
    await tester.pump();
    await tester.pump();
    expect(controller.isApplyingAll.value, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
    Get.delete<DeviceSettingsController>(force: true);
    Get.delete<ThemeLanguageController>(force: true);
    Get.reset();
  });
}

class _PendingDeviceSettingsApi extends ApiService {
  final applyCompleter = Completer<Map<String, dynamic>>();
  int applyCalls = 0;

  @override
  Future<Map<String, dynamic>> applyAllDeviceSettings() {
    applyCalls++;
    return applyCompleter.future;
  }

  @override
  Future<Map<String, dynamic>> getDeviceSettingsStatus() async => {
    'success': true,
    'desktop_time': <String, dynamic>{
      'windows_activated': true,
      'desktop_icons_ready': true,
      'timezone': 'Iran Standard Time',
      'automatic_timezone': true,
      'location_enabled': true,
    },
    'timeouts': <String, dynamic>{
      'all_never': true,
      'values': <String, dynamic>{},
    },
    'startup': <String, dynamic>{
      'all_disabled': true,
      'enabled_count': 0,
      'total': 0,
    },
    'background_apps': <String, dynamic>{'all_disabled': true},
    'power_modes': <String, dynamic>{
      'configured': true,
      'supported': false,
      'ac': 'نامشخص',
      'dc': 'نامشخص',
    },
    'windows': <String, dynamic>{'label': 'Windows 11 Pro'},
    'has_battery': false,
    'background_apps_supported': false,
    'taskbar_pin_requires_confirmation': true,
  };
}
