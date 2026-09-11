import 'package:flutter_test/flutter_test.dart';
import 'package:markazi_system_checker/controllers/driver_install_controller.dart';
import 'package:markazi_system_checker/controllers/theme_language_controller.dart';
import 'package:markazi_system_checker/models/system_info.dart';
import 'package:markazi_system_checker/utils/persian_date_time.dart';

void main() {
  test('seventh sidebar destination opens application settings', () {
    final controller = ThemeLanguageController();
    controller.setNavIndex(6);
    expect(controller.activeNavIndex.value, 6);
    controller.setNavIndex(7);
    expect(controller.activeNavIndex.value, 6);
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
}
