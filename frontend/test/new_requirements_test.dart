import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:markazi_system_checker/controllers/driver_install_controller.dart';
import 'package:markazi_system_checker/controllers/software_controller.dart';
import 'package:markazi_system_checker/controllers/theme_language_controller.dart';
import 'package:markazi_system_checker/models/system_info.dart';
import 'package:markazi_system_checker/utils/persian_date_time.dart';
import 'package:markazi_system_checker/widgets/pages/calculations_page.dart';

void main() {
  test('seventh sidebar destination opens application settings', () {
    final controller = ThemeLanguageController();
    controller.setNavIndex(6);
    expect(controller.activeNavIndex.value, 6);
    controller.setNavIndex(7);
    expect(controller.activeNavIndex.value, 7);
    controller.setNavIndex(8);
    expect(controller.activeNavIndex.value, 7);
  });

  test('Gregorian new year converts to Jalali new year', () {
    final value = gregorianToJalali(DateTime(2024, 3, 20));
    expect((value.year, value.month, value.day), (1403, 1, 1));
    expect(
      formatPersianDateTime(DateTime(2024, 3, 20, 9, 5)),
      contains('۱۴۰۳'),
    );
  });

  test('select all toggles the same selectable set on and off', () {
    expect(toggledSelectAll({}, {'a', 'b'}), {'a', 'b'});
    expect(toggledSelectAll({'a', 'b'}, {'a', 'b'}), isEmpty);
    expect(toggledSelectAll({'a'}, {'a', 'b'}), {'a', 'b'});
  });

  test('numeric calculator input keeps sequential digits LTR', () {
    final formatter = ThousandsSeparatorInputFormatter();
    var value = const TextEditingValue();
    for (final digit in ['1', '0', '0']) {
      final next = TextEditingValue(
        text: '${value.text}$digit',
        selection: TextSelection.collapsed(offset: value.text.length + 1),
      );
      value = formatter.formatEditUpdate(value, next);
    }
    expect(value.text, '100');

    final thousand = formatter.formatEditUpdate(
      value,
      const TextEditingValue(
        text: '1000',
        selection: TextSelection.collapsed(offset: 4),
      ),
    );
    expect(thousand.text, '1,000');
    expect(thousand.selection.extentOffset, thousand.text.length);
  });

  testWidgets(
    'calculator stays usable at narrow width and keeps 100 in order',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(375, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: CalculationsPage(),
          ),
        ),
      );
      await tester.tap(find.text('محاسبه قیمت بازی'));
      await tester.pumpAndSettle();

      final firstInput = find.byType(TextField).first;
      await tester.enterText(firstInput, '100');
      await tester.pump();

      expect(tester.widget<TextField>(firstInput).controller?.text, '100');
      expect(tester.takeException(), isNull);
    },
  );

  test('Windows 10 and 11 Home editions use the original-home label rule', () {
    WindowsInfo windows(String edition) => WindowsInfo(
      edition: edition,
      version: '',
      build: '',
      architecture: '64-bit',
    );

    expect(windows('Windows 10 Home').isHomeEdition, isTrue);
    expect(windows('Windows 11 Home Single Language').isHomeEdition, isTrue);
    expect(windows('Windows 11 Pro').isHomeEdition, isFalse);
  });

  test('Microsoft Basic Display Adapter is detected from raw GPU name', () {
    final gpu = GpuInfo(
      name: 'Microsoft Graphics Adapter',
      rawName: 'Microsoft Basic Display Adapter',
      manufacturer: 'Microsoft',
      vramDisplay: 'Shared',
      driverVersion: 'Not available',
    );
    expect(gpu.isMicrosoftBasicDisplayAdapter, isTrue);
  });

  test('physical storage keeps mounted usage and volume mapping', () {
    final storage = StorageInfo.fromJson({
      'model': 'Test SSD',
      'type': 'SSD',
      'bus_type': 'NVMe',
      'capacity_display': '477 GB',
      'mounted_capacity_bytes': 500000000000,
      'free_bytes': 125000000000,
      'used_bytes': 375000000000,
      'percent_used': 75.0,
      'volumes': ['C:', 'D:'],
      'serial': 'TEST123',
      'health_status': 'Healthy',
    });

    expect(storage.freeBytes, 125000000000);
    expect(storage.usedBytes, 375000000000);
    expect(storage.percentUsed, 75.0);
    expect(storage.volumes, ['C:', 'D:']);
  });

  test('Office deployment is disabled for Windows 10 and 11 Home', () {
    final office = SoftwarePackage.fromJson({
      'id': 'office_2024_pro_plus',
      'name': 'Microsoft Office 2024 (Pro Plus)',
      'filename': 'Setup_Office 2024.cmd',
      'is_valid': true,
      'is_installed': false,
    });

    expect(
      officeInstallBlockedForWindows(
        office,
        WindowsInfo(
          edition: 'Windows 11 Home',
          version: '23H2',
          build: '22631',
          architecture: '64-bit',
        ),
      ),
      isTrue,
    );
    expect(
      officeInstallBlockedForWindows(
        office,
        WindowsInfo(
          edition: 'Windows 11 Enterprise',
          version: '25H2',
          build: '26200',
          architecture: '64-bit',
        ),
      ),
      isFalse,
    );
  });
}
