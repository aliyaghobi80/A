import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:markazi_system_checker/widgets/common/custom_title_bar.dart';

void main() {
  setUp(() {
    Get.reset();
  });

  tearDown(() {
    Get.reset();
  });

  group('Challenger 1: Empirical Bi-Directional Window State Synchronization', () {
    testWidgets(
        'Dual-channel simultaneous onWindowMaximize burst renders RestoreIconPainter without error',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CustomTitleBar(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially windowed
      expect(find.byKey(const ValueKey('window-control-maximize-icon')), findsOneWidget);
      expect(find.byKey(const ValueKey('window-control-restore-icon')), findsNothing);

      // Simultaneous dispatch on both markazi/window AND window_manager (mirroring flutter_window.cpp)
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'markazi/window',
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('onWindowMaximize'),
        ),
        (data) {},
      );
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'window_manager',
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('onWindowMaximize'),
        ),
        (data) {},
      );
      await tester.pumpAndSettle();

      // Verified: restores icon painter is rendered
      expect(find.byKey(const ValueKey('window-control-restore-icon')), findsOneWidget);
      expect(find.byKey(const ValueKey('window-control-maximize-icon')), findsNothing);
    });

    testWidgets(
        'Dual-channel simultaneous onWindowRestore burst reverts back to maximize box',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CustomTitleBar(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Maximize via channel
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'markazi/window',
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('onWindowMaximize'),
        ),
        (data) {},
      );
      await tester.pumpAndSettle();

      // Initially maximized
      expect(find.byKey(const ValueKey('window-control-restore-icon')), findsOneWidget);
      expect(find.byKey(const ValueKey('window-control-maximize-icon')), findsNothing);

      // Simultaneous dispatch of onWindowRestore on both channels
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'markazi/window',
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('onWindowRestore'),
        ),
        (data) {},
      );
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'window_manager',
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('onWindowRestore'),
        ),
        (data) {},
      );
      await tester.pumpAndSettle();

      // Verified: switches back to maximize box
      expect(find.byKey(const ValueKey('window-control-maximize-icon')), findsOneWidget);
      expect(find.byKey(const ValueKey('window-control-restore-icon')), findsNothing);
    });

    testWidgets(
        'Rapid alternating IPC stress harness: 100 iterations maintain state integrity',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CustomTitleBar(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final codec = const StandardMethodCodec();
      for (int i = 0; i < 100; i++) {
        final bool shouldMaximize = i.isEven;
        final String method = shouldMaximize ? 'onWindowMaximize' : 'onWindowRestore';

        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          'markazi/window',
          codec.encodeMethodCall(MethodCall(method)),
          (data) {},
        );
        await tester.pump(const Duration(milliseconds: 5));
      }
      await tester.pumpAndSettle();

      // Final iteration was i=99 (odd) -> onWindowRestore
      expect(find.byKey(const ValueKey('window-control-maximize-icon')), findsOneWidget);
      expect(find.byKey(const ValueKey('window-control-restore-icon')), findsNothing);

      // Send one final maximize
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'markazi/window',
        codec.encodeMethodCall(const MethodCall('onWindowMaximize')),
        (data) {},
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('window-control-restore-icon')), findsOneWidget);
      expect(find.byKey(const ValueKey('window-control-maximize-icon')), findsNothing);
    });

    testWidgets(
        'initState asynchronously queries native isMaximized and accurately renders state',
        (tester) async {
      // 1. Native reports isMaximized == true
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

      expect(find.byKey(const ValueKey('window-control-restore-icon')), findsOneWidget);
      expect(find.byKey(const ValueKey('window-control-maximize-icon')), findsNothing);

      // Unmount
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      // 2. Native reports isMaximized == false
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('markazi/window'),
        (call) async {
          if (call.method == 'isMaximized') return false;
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

      expect(find.byKey(const ValueKey('window-control-maximize-icon')), findsOneWidget);
      expect(find.byKey(const ValueKey('window-control-restore-icon')), findsNothing);
    });

    testWidgets(
        'didChangeMetrics triggers window state sync when OS changes window geometry',
        (tester) async {
      bool nativeMaximized = false;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('markazi/window'),
        (call) async {
          if (call.method == 'isMaximized') return nativeMaximized;
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

      expect(find.byKey(const ValueKey('window-control-maximize-icon')), findsOneWidget);

      // Change native state and simulate window resize / display change
      nativeMaximized = true;
      tester.binding.handleMetricsChanged();
      await tester.pumpAndSettle();

      // Verified: didChangeMetrics invoked _syncWindowState() which picked up nativeMaximized == true
      expect(find.byKey(const ValueKey('window-control-restore-icon')), findsOneWidget);
      expect(find.byKey(const ValueKey('window-control-maximize-icon')), findsNothing);
    });

    testWidgets(
        'IPC calls arriving after CustomTitleBar unmount do not throw setState after dispose',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CustomTitleBar(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Unmount CustomTitleBar
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      // Dispatch events to disconnected channels
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'markazi/window',
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('onWindowMaximize'),
        ),
        (data) {},
      );
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'window_manager',
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('onWindowRestore'),
        ),
        (data) {},
      );
      await tester.pumpAndSettle();
      // Zero exceptions thrown
    });

    testWidgets(
        'Toggle maximize button correctly passes isMaximizedHint without inversion',
        (tester) async {
      final List<MethodCall> calls = [];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('markazi/window'),
        (call) async {
          calls.add(call);
          // Return null for isMaximized to force toggleMaximize to use isMaximizedHint
          if (call.method == 'isMaximized') return null;
          return true;
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

      // Initial state is windowed (_isMaximized = false)
      // Tap maximize button: wasMaximized = false, hint = false -> should call 'maximize'
      await tester.tap(find.byKey(const ValueKey('window-control-maximize')));
      await tester.pumpAndSettle();

      expect(calls.any((c) => c.method == 'maximize'), isTrue,
          reason: 'Expected toggleMaximize to invoke maximize when initially windowed');
      expect(calls.any((c) => c.method == 'unmaximize'), isFalse);

      calls.clear();

      // Now _isMaximized is true. Tap again: wasMaximized = true, hint = true -> should call 'unmaximize'
      await tester.tap(find.byKey(const ValueKey('window-control-maximize')));
      await tester.pumpAndSettle();

      expect(calls.any((c) => c.method == 'unmaximize'), isTrue,
          reason: 'Expected toggleMaximize to invoke unmaximize when maximized');
    });
  });
}
