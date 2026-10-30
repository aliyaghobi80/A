// frontend/test/widgets/custom_title_bar_test.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:markazi_system_checker/controllers/hardware_test_controller.dart';
import 'package:markazi_system_checker/widgets/common/app_frame.dart';
import 'package:markazi_system_checker/widgets/common/custom_title_bar.dart';

void main() {
  setUp(() {
    Get.reset();
  });

  tearDown(() {
    Get.reset();
  });

  group('CustomTitleBar Widget & Interaction Tests', () {
    testWidgets('renders title, logo, and window controls with correct keys', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CustomTitleBar(
              title: 'سامانه بررسی و نصب مرکزی',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('custom-title-bar-root')), findsOneWidget);
      expect(find.byKey(const ValueKey('custom-title-bar-title')), findsOneWidget);
      expect(find.byKey(const ValueKey('custom-title-bar-logo')), findsOneWidget);
      expect(find.byKey(const ValueKey('custom-title-bar-drag-region')), findsOneWidget);
      expect(find.byKey(const ValueKey('window-control-minimize')), findsOneWidget);
      expect(find.byKey(const ValueKey('window-control-maximize')), findsOneWidget);
      expect(find.byKey(const ValueKey('window-control-close')), findsOneWidget);
      expect(find.text('سامانه بررسی و نصب مرکزی'), findsOneWidget);
    });

    testWidgets('dispatches minimize, maximize, and close events on tap', (tester) async {
      bool minimized = false;
      bool maximized = false;
      bool closed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomTitleBar(
              onMinimize: () => minimized = true,
              onMaximize: () => maximized = true,
              onClose: () => closed = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('window-control-minimize')));
      expect(minimized, isTrue);

      await tester.tap(find.byKey(const ValueKey('window-control-maximize')));
      expect(maximized, isTrue);

      await tester.tap(find.byKey(const ValueKey('window-control-close')));
      expect(closed, isTrue);
    });

    testWidgets('double-tap on drag region toggles maximize', (tester) async {
      bool maximized = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomTitleBar(
              onMaximize: () => maximized = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('custom-title-bar-drag-region')));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byKey(const ValueKey('custom-title-bar-drag-region')));
      await tester.pumpAndSettle();

      expect(maximized, isTrue);
    });

    testWidgets('close button hover turns red (#E81123)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CustomTitleBar(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final closeFinder = find.byKey(const ValueKey('window-control-close'));
      expect(closeFinder, findsOneWidget);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);

      // Move mouse over close button
      await gesture.moveTo(tester.getCenter(closeFinder));
      await tester.pumpAndSettle();

      // Find the container inside the close button
      final containerFinder = find.descendant(
        of: closeFinder,
        matching: find.byType(Container),
      );
      expect(containerFinder, findsWidgets);

      final container = tester.widget<Container>(containerFinder.first);
      expect(container.color, const Color(0xFFE81123));
    });

    testWidgets('RTL layout alignment contract: logo/title right, controls left', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: CustomTitleBar(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final titleCenter = tester.getCenter(find.byKey(const ValueKey('custom-title-bar-title')));
      final controlsCenter = tester.getCenter(find.byKey(const ValueKey('window-control-close')));

      // In RTL, title is at the right and controls at the left
      expect(titleCenter.dx > controlsCenter.dx, isTrue);

      final layout = CustomTitleBar.getTitleBarLayout(isRtl: true);
      expect(layout['right'], 'branding_and_title');
      expect(layout['left'], 'caption_controls');
    });

    testWidgets('LTR layout alignment contract: logo/title left, controls right', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.ltr,
            child: Scaffold(
              body: CustomTitleBar(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final titleCenter = tester.getCenter(find.byKey(const ValueKey('custom-title-bar-title')));
      final controlsCenter = tester.getCenter(find.byKey(const ValueKey('window-control-close')));

      // In LTR, title is at the left and controls at the right
      expect(titleCenter.dx < controlsCenter.dx, isTrue);

      final layout = CustomTitleBar.getTitleBarLayout(isRtl: false);
      expect(layout['left'], 'branding_and_title');
      expect(layout['right'], 'caption_controls');
    });

    testWidgets('theme adaptation: matches dark and light themes', (tester) async {
      // Dark Theme test
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: CustomTitleBar(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      var rootContainer = tester.widget<Container>(find.byKey(const ValueKey('custom-title-bar-root')));
      var decoration = rootContainer.decoration as BoxDecoration;
      expect(decoration.color, const Color(0xFF0F172A));

      // Light Theme test
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: CustomTitleBar(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      rootContainer = tester.widget<Container>(find.byKey(const ValueKey('custom-title-bar-root')));
      decoration = rootContainer.decoration as BoxDecoration;
      expect(decoration.color, const Color(0xFFF8FAFC));
    });
  });

  group('AppFrame Fullscreen & Embedding Tests', () {
    testWidgets('AppFrame renders CustomTitleBar and child when not fullscreen', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppFrame(
              isFullscreen: false,
              child: Text('Main Content Area'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('app-frame-root')), findsOneWidget);
      expect(find.byKey(const ValueKey('app-frame-titlebar')), findsOneWidget);
      expect(find.byKey(const ValueKey('custom-title-bar-root')), findsOneWidget);
      expect(find.byKey(const ValueKey('app-frame-content')), findsOneWidget);
      expect(find.text('Main Content Area'), findsOneWidget);
    });

    testWidgets('AppFrame completely hides CustomTitleBar when isFullscreen is true', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppFrame(
              isFullscreen: true,
              child: Text('Fullscreen Diagnostic Test'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('app-frame-root')), findsOneWidget);
      expect(find.byKey(const ValueKey('app-frame-titlebar')), findsNothing);
      expect(find.byKey(const ValueKey('custom-title-bar-root')), findsNothing);
      expect(find.text('Fullscreen Diagnostic Test'), findsOneWidget);
    });

    testWidgets('AppFrame reactively toggles title bar with HardwareTestController', (tester) async {
      final hwCtrl = Get.put(HardwareTestController());
      hwCtrl.isMonitorFullScreen.value = false;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppFrame(
              child: Text('Reactive Frame Content'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially not fullscreen
      expect(find.byKey(const ValueKey('custom-title-bar-root')), findsOneWidget);

      // Enter fullscreen monitor test
      hwCtrl.toggleMonitorFullScreen(true);
      await tester.pumpAndSettle();

      // Title bar must be completely hidden
      expect(find.byKey(const ValueKey('custom-title-bar-root')), findsNothing);

      // Exit fullscreen monitor test
      hwCtrl.toggleMonitorFullScreen(false);
      await tester.pumpAndSettle();

      // Title bar restored
      expect(find.byKey(const ValueKey('custom-title-bar-root')), findsOneWidget);
    });

    test('isTitleBarVisible static contract method verification', () {
      expect(AppFrame.isTitleBarVisible(isFullscreenTest: false), isTrue);
      expect(AppFrame.isTitleBarVisible(isFullscreenTest: true), isFalse);
    });
  });
}
