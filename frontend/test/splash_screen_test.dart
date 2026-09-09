import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:central_system_checker/controllers/theme_language_controller.dart';
import 'package:central_system_checker/screens/splash_screen.dart';
import 'package:central_system_checker/widgets/splash/splash_assembly.dart';
import 'package:central_system_checker/widgets/splash/splash_brand_text.dart';
import 'package:central_system_checker/widgets/splash/splash_component.dart';
import 'package:central_system_checker/widgets/splash/splash_logo.dart';

void main() {
  setUp(() {
    Get.reset();
    final themeLangCtrl = Get.put(ThemeLanguageController());
    themeLangCtrl.currentLocale.value = const Locale('fa');
  });

  tearDown(() {
    Get.reset();
  });

  group('Animated Splash Screen Tests', () {
    testWidgets('SplashScreen renders properly with initial assembly phase',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 768));

      await tester.pumpWidget(
        const GetMaterialApp(
          home: SplashScreen(),
        ),
      );

      // Verify that SplashScreen is mounted
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.byType(SplashAssemblyWidget), findsOneWidget);
      expect(find.byType(SplashLogoWidget), findsOneWidget);
      expect(find.byType(SplashBrandTextWidget), findsOneWidget);

      // Verify skip button is present
      expect(find.text('رد کردن'), findsOneWidget);

      // Initial progress has assembly components
      expect(find.byType(SplashComponentWidget), findsAtLeastNWidgets(1));

      // Advance animation partially
      await tester.pump(const Duration(milliseconds: 1500));
      expect(find.byType(SplashAssemblyWidget), findsOneWidget);
    });

    testWidgets('SplashBrandTextWidget renders Persian and English brand titles',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SplashBrandTextWidget(progress: 0.85),
          ),
        ),
      );

      expect(find.text('مرکزی سیستم چکر'), findsOneWidget);
      expect(find.text('Markazi System Checker'), findsOneWidget);
    });

    testWidgets('SplashComponentWidget renders all hardware component types',
        (tester) async {
      for (final type in SplashComponentType.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SplashComponentWidget(type: type),
            ),
          ),
        );
        expect(find.byType(SplashComponentWidget), findsOneWidget);
      }
    });

    testWidgets('SplashLogoWidget renders properly during logo phase',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SplashLogoWidget(progress: 0.70),
          ),
        ),
      );

      expect(find.byType(SplashLogoWidget), findsOneWidget);
    });
  });
}
