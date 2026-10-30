// frontend/test/custom_title_bar_test.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:markazi_system_checker/services/install_state_service.dart';
import 'package:markazi_system_checker/theme/app_theme.dart';
import 'package:markazi_system_checker/widgets/common/app_frame.dart';
import 'package:markazi_system_checker/widgets/common/custom_title_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Get.reset();
  });

  tearDown(() {
    Get.reset();
  });

  group('CustomTitleBar UI & Control Tests (R2)', () {
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

    testWidgets('title bar height is 32.0 and control buttons width is 46.0', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CustomTitleBar(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final barSize = tester.getSize(find.byKey(const ValueKey('custom-title-bar-root')));
      expect(barSize.height, 32.0);

      final minSize = tester.getSize(find.byKey(const ValueKey('window-control-minimize')));
      final maxSize = tester.getSize(find.byKey(const ValueKey('window-control-maximize')));
      final closeSize = tester.getSize(find.byKey(const ValueKey('window-control-close')));
      expect(minSize.width, 46.0);
      expect(maxSize.width, 46.0);
      expect(closeSize.width, 46.0);
    });

    testWidgets('controls row is wrapped in Directionality(textDirection: TextDirection.ltr)', (tester) async {
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

      // Controls row must be explicitly LTR
      final controlsRowFinder = find.byKey(const ValueKey('custom-title-bar-controls-row'));
      expect(controlsRowFinder, findsOneWidget);

      final directionalityFinder = find.ancestor(
        of: controlsRowFinder,
        matching: find.byType(Directionality),
      );
      expect(directionalityFinder, findsWidgets);

      final directionalityWidget = tester.widget<Directionality>(directionalityFinder.first);
      expect(directionalityWidget.textDirection, TextDirection.ltr);

      // Verify physical positioning: minimize (left) < maximize (middle) < close (right)
      final minCenter = tester.getCenter(find.byKey(const ValueKey('window-control-minimize')));
      final maxCenter = tester.getCenter(find.byKey(const ValueKey('window-control-maximize')));
      final closeCenter = tester.getCenter(find.byKey(const ValueKey('window-control-close')));

      expect(minCenter.dx < maxCenter.dx, isTrue);
      expect(maxCenter.dx < closeCenter.dx, isTrue);

      // And branding is on the top-left, controls on the top-right
      final titleCenter = tester.getCenter(find.byKey(const ValueKey('custom-title-bar-title')));
      expect(titleCenter.dx < closeCenter.dx, isTrue);
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
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);

      // Move mouse over close button
      await gesture.moveTo(tester.getCenter(closeFinder));
      await tester.pumpAndSettle();

      final containerFinder = find.descendant(
        of: closeFinder,
        matching: find.byType(Container),
      );
      final container = tester.widget<Container>(containerFinder.first);
      expect(container.color, const Color(0xFFE81123));
    });

    testWidgets('double-tap on drag region toggles maximize/restore', (tester) async {
      bool toggleCalled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomTitleBar(
              onMaximize: () => toggleCalled = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('custom-title-bar-drag-region')));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byKey(const ValueKey('custom-title-bar-drag-region')));
      await tester.pumpAndSettle();

      expect(toggleCalled, isTrue);
    });

    testWidgets('instant drag triggers startDragging without delay on pointer down', (tester) async {
      final List<String> channelCalls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('markazi/window'), (call) async {
        channelCalls.add(call.method);
        return null;
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CustomTitleBar(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final dragRegion = find.byKey(const ValueKey('custom-title-bar-drag-region'));
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: tester.getCenter(dragRegion));
      await gesture.down(tester.getCenter(dragRegion));
      await tester.pump();

      expect(channelCalls.contains('startDragging'), isTrue);
      await gesture.up();
      await tester.pumpAndSettle();

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('markazi/window'), null);
    });

    testWidgets('displays build timestamp identifier in title tooltip', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CustomTitleBar(
              title: 'سامانه مرکزی',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tooltipFinder = find.byKey(const ValueKey('custom-title-bar-build-tooltip'));
      expect(tooltipFinder, findsOneWidget);

      final tooltip = tester.widget<Tooltip>(tooltipFinder);
      expect(tooltip.message, 'Build: ${CustomTitleBar.buildTimestamp}');
    });

    testWidgets('unfocused window dims title and logo opacity to 0.55', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CustomTitleBar(isFocused: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final opacityWidget = tester.widget<Opacity>(
        find.byKey(const ValueKey('custom-title-bar-branding-opacity')),
      );
      expect(opacityWidget.opacity, 0.55);
    });

    testWidgets('close button presents ExitDialog guard when installation queue is active', (tester) async {
      final installService = Get.put(InstallStateService());
      installService.isDriverRunning.value = true;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CustomTitleBar(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('window-control-close')));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('خروج و بستن برنامه'), findsOneWidget);

      // Dismiss dialog
      await tester.tap(find.text('انصراف'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);

      // Test software running
      installService.isDriverRunning.value = false;
      installService.isSoftwareRunning.value = true;

      await tester.tap(find.byKey(const ValueKey('window-control-close')));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('theme adaptation: matches dark and light themes without crashing', (tester) async {
      // Dark Theme test
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: CustomTitleBar(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      var rootContainer = tester.widget<Container>(find.byKey(const ValueKey('custom-title-bar-root')));
      var decoration = rootContainer.decoration as BoxDecoration;
      expect(decoration.color, AppTheme.darkSurface);

      // Light Theme test
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: const Scaffold(
            body: CustomTitleBar(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      rootContainer = tester.widget<Container>(find.byKey(const ValueKey('custom-title-bar-root')));
      decoration = rootContainer.decoration as BoxDecoration;
      expect(decoration.color, AppTheme.lightSurface);
    });
  });

  group('AppFrame Title Bar Integration', () {
    testWidgets('AppFrame renders CustomTitleBar when not fullscreen', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppFrame(
              isFullscreen: false,
              child: Text('Content'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('app-frame-titlebar')), findsOneWidget);
      expect(find.byType(CustomTitleBar), findsOneWidget);
      expect(find.text('Content'), findsOneWidget);
    });

    testWidgets('AppFrame hides CustomTitleBar completely in fullscreen test mode', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppFrame(
              isFullscreen: true,
              child: Text('Fullscreen Content'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('app-frame-titlebar')), findsNothing);
      expect(find.byType(CustomTitleBar), findsNothing);
      expect(find.text('Fullscreen Content'), findsOneWidget);
    });
  });
}
