import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:markazi_system_checker/controllers/device_settings_controller.dart';
import 'package:markazi_system_checker/controllers/theme_language_controller.dart';
import 'package:markazi_system_checker/services/api_service.dart';
import 'package:markazi_system_checker/widgets/pages/device_settings_page.dart';

class StatusApi extends ApiService {
  bool? ready;
  @override
  Future<Map<String, dynamic>> getDeviceSettingsStatus() async => {
    'success': true,
    'has_battery': true,
    'windows': {'label': 'Windows 11 Pro'},
    'background_apps_supported': false,
    'desktop_time': {
      'windows_activated': ready,
      'desktop_icons_ready': ready,
      'timezone': ready == true
          ? 'Iran Standard Time'
          : 'Pacific Standard Time',
      'automatic_timezone': ready,
      'location_enabled': ready,
    },
    'timeouts': {
      'all_never': ready,
      'values': {'sleep_ac': ready == true ? 0 : 300},
    },
    'startup': {
      'all_disabled': ready,
      'enabled_count': ready == true ? 0 : 2,
      'total': 4,
    },
    'power_modes': {
      'supported': true,
      'configured': ready,
      'ac': 'Balanced',
      'dc': 'Balanced',
    },
  };
}

void main() {
  for (final dark in [false, true]) {
    testWidgets(
      'verified states change labels and clear on external changes (dark=$dark)',
      (tester) async {
        Get.testMode = true;
        final api = StatusApi();
        Get.put(ThemeLanguageController());
        final controller = Get.put(DeviceSettingsController(api: api));
        addTearDown(Get.reset);
        tester.view.physicalSize = const Size(750, 2200);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          GetMaterialApp(
            theme: dark ? ThemeData.dark() : ThemeData.light(),
            home: const Scaffold(body: DeviceSettingsPage()),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('فقط Windows 10'), findsOneWidget);
        expect(find.text('الان همه روی Never هستند'), findsNothing);
        expect(find.text('ابتدا ویندوز را فعال کنید'), findsOneWidget);
        api.ready = true;
        await controller.refreshStatus();
        await tester.pumpAndSettle();
        expect(find.text('الان همه روی Never هستند'), findsOneWidget);
        expect(find.text('همهٔ Startup Apps خاموش هستند'), findsOneWidget);
        expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(5));
        expect(find.text('سه آیکن فعال هستند'), findsOneWidget);
        api.ready = false;
        await controller.refreshStatus();
        await tester.pumpAndSettle();
        expect(find.text('الان همه روی Never هستند'), findsNothing);
        expect(tester.takeException(), isNull);
        await Get.delete<DeviceSettingsController>();
      },
    );
  }
}
