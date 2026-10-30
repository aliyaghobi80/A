// frontend/test/widgets/custom_title_bar_test.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:markazi_system_checker/controllers/hardware_test_controller.dart';
import 'package:markazi_system_checker/controllers/theme_language_controller.dart';
import 'package:markazi_system_checker/main.dart';
import 'package:markazi_system_checker/services/install_state_service.dart';
import 'package:markazi_system_checker/services/settings_service.dart';
import 'package:markazi_system_checker/theme/app_theme.dart';
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

    testWidgets('title bar height is 32.0 by default', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CustomTitleBar(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final size = tester.getSize(find.byKey(const ValueKey('custom-title-bar-root')));
      expect(size.height, 32.0);
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

    testWidgets('RTL layout alignment contract: logo/title left, controls right (Windows convention)', (tester) async {
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

      // In Windows convention, title is at the left and controls at the right even in RTL
      expect(titleCenter.dx < controlsCenter.dx, isTrue);

      final layout = CustomTitleBar.getTitleBarLayout(isRtl: true);
      expect(layout['left'], 'branding_and_title');
      expect(layout['right'], 'caption_controls');
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

    testWidgets('theme adaptation: matches dark and light themes without crashing', (tester) async {
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
      expect(decoration.color, AppTheme.darkSurface);

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
      expect(decoration.color, AppTheme.lightSurface);
    });

    testWidgets('maximize/restore icon toggles between single square and restore icon painter', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CustomTitleBar(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially normal windowed mode: square maximize icon is present, restore painter is not
      expect(find.byKey(const ValueKey('window-control-maximize-icon')), findsOneWidget);
      expect(find.byKey(const ValueKey('window-control-restore-icon')), findsNothing);

      // Tap maximize button to toggle to maximized
      await tester.tap(find.byKey(const ValueKey('window-control-maximize')));
      await tester.pumpAndSettle();

      // In maximized mode: restore icon painter is present, square maximize icon is not
      expect(find.byKey(const ValueKey('window-control-restore-icon')), findsOneWidget);
      expect(find.byKey(const ValueKey('window-control-maximize-icon')), findsNothing);

      // Tap maximize button again to toggle back to normal
      await tester.tap(find.byKey(const ValueKey('window-control-maximize')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('window-control-maximize-icon')), findsOneWidget);
      expect(find.byKey(const ValueKey('window-control-restore-icon')), findsNothing);
    });

    testWidgets('clicking close when InstallStateService has active installations triggers ExitDialog', (tester) async {
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

      // Tap close button while driver installation is running
      await tester.tap(find.byKey(const ValueKey('window-control-close')));
      await tester.pumpAndSettle();

      // ExitDialog must be presented to prompt the technician
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('خروج و بستن برنامه'), findsOneWidget);

      // Dismiss dialog
      await tester.tap(find.text('انصراف'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);

      // Now reset driver running and test software running
      installService.isDriverRunning.value = false;
      installService.isSoftwareRunning.value = true;

      await tester.tap(find.byKey(const ValueKey('window-control-close')));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('خروج و بستن برنامه'), findsOneWidget);
    });

    testWidgets('window blur dims title text and logo opacity', (tester) async {
      // 1. Focused state (opacity == 1.0)
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CustomTitleBar(isFocused: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      var opacityWidget = tester.widget<Opacity>(find.byKey(const ValueKey('custom-title-bar-branding-opacity')));
      expect(opacityWidget.opacity, 1.0);

      // 2. Unfocused (blurred) state (opacity == 0.55)
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CustomTitleBar(isFocused: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      opacityWidget = tester.widget<Opacity>(find.byKey(const ValueKey('custom-title-bar-branding-opacity')));
      expect(opacityWidget.opacity, 0.55);
    });

    testWidgets('title bar presence in top-level app widget tree (AppFrame in main.dart)', (tester) async {
      final themeCtrl = Get.put(ThemeLanguageController());
      themeCtrl.loadFromSettings(const AppSettings());
      Get.put(HardwareTestController());

      await tester.pumpWidget(
        const MarkaziSystemCheckerApp(),
      );
      await tester.pump();

      // Verify AppFrame and CustomTitleBar are mounted in the top-level app tree
      expect(find.byType(AppFrame), findsOneWidget);
      expect(find.byType(CustomTitleBar), findsOneWidget);
      expect(find.byKey(const ValueKey('custom-title-bar-root')), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
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

  group('Bi-Directional Window State Synchronization Tests', () {
    testWidgets(
        'Receiving onWindowMaximize method call updates icon to RestoreIconPainter and onWindowRestore reverts to square',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CustomTitleBar(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially windowed: maximize box present, restore icon absent
      expect(find.byKey(const ValueKey('window-control-maximize-icon')), findsOneWidget);
      expect(find.byKey(const ValueKey('window-control-restore-icon')), findsNothing);

      // Simulate native Win32 dispatching onWindowMaximize via markazi/window
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'markazi/window',
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('onWindowMaximize'),
        ),
        (data) {},
      );
      await tester.pumpAndSettle();

      // State updated to maximized: restore icon present, maximize box absent
      expect(find.byKey(const ValueKey('window-control-restore-icon')), findsOneWidget);
      expect(find.byKey(const ValueKey('window-control-maximize-icon')), findsNothing);

      // Simulate native Win32 dispatching onWindowRestore
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'markazi/window',
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('onWindowRestore'),
        ),
        (data) {},
      );
      await tester.pumpAndSettle();

      // State restored to windowed: maximize box present, restore icon absent
      expect(find.byKey(const ValueKey('window-control-maximize-icon')), findsOneWidget);
      expect(find.byKey(const ValueKey('window-control-restore-icon')), findsNothing);
    });

    testWidgets(
        'Receiving window_manager channel notifications synchronizes state identically',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CustomTitleBar(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Simulate window_manager channel sending onWindowMaximize
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'window_manager',
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('onWindowMaximize'),
        ),
        (data) {},
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('window-control-restore-icon')), findsOneWidget);
      expect(find.byKey(const ValueKey('window-control-maximize-icon')), findsNothing);

      // Simulate window_manager channel sending onWindowUnmaximize
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'window_manager',
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('onWindowUnmaximize'),
        ),
        (data) {},
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('window-control-maximize-icon')), findsOneWidget);
      expect(find.byKey(const ValueKey('window-control-restore-icon')), findsNothing);
    });

    testWidgets(
        'initState asynchronously synchronizes with native isMaximized query',
        (tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('markazi/window'),
        (call) async {
          if (call.method == 'isMaximized') return true;
          return null;
        },
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CustomTitleBar(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Because mock returned true, title bar immediately renders restore icon
      expect(find.byKey(const ValueKey('window-control-restore-icon')), findsOneWidget);
      expect(find.byKey(const ValueKey('window-control-maximize-icon')), findsNothing);
    });

    testWidgets(
        'didUpdateWidget updates overrideMaximized and isFocused dynamically',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CustomTitleBar(
              isMaximized: false,
              isFocused: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('window-control-maximize-icon')), findsOneWidget);
      var opacity = tester.widget<Opacity>(find.byKey(const ValueKey('custom-title-bar-branding-opacity')));
      expect(opacity.opacity, 1.0);

      // Re-pump with isMaximized = true and isFocused = false
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CustomTitleBar(
              isMaximized: true,
              isFocused: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('window-control-restore-icon')), findsOneWidget);
      opacity = tester.widget<Opacity>(find.byKey(const ValueKey('custom-title-bar-branding-opacity')));
      expect(opacity.opacity, 0.55);
    });

    test('CustomTitleBar.isMaximized queries markazi/window and falls back to window_manager', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('markazi/window'),
        (call) async {
          throw PlatformException(code: 'UNAVAILABLE');
        },
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('window_manager'),
        (call) async {
          if (call.method == 'isMaximized') return true;
          return null;
        },
      );

      final result = await CustomTitleBar.isMaximized();
      expect(result, isTrue);
    });
  });
}
