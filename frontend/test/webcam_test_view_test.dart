// frontend/test/webcam_test_view_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:markazi_system_checker/controllers/hardware_test_controller.dart';
import 'package:markazi_system_checker/services/api_service.dart';
import 'package:markazi_system_checker/widgets/hardware_tests/webcam_test_view.dart';

class _MockWebcamApiService extends ApiService {
  bool fetchCameraCalled = false;
  List<Map<String, dynamic>> mockCams = [
    {'name': 'Integrated Camera', 'status': 'OK', 'manufacturer': 'Sunplus'},
  ];

  @override
  Future<List<Map<String, dynamic>>> fetchCameraDevices() async {
    fetchCameraCalled = true;
    return mockCams;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Get.reset();
  });

  tearDown(() {
    Get.reset();
  });

  group('Webcam Viewport Optimization Tests (R3)', () {
    testWidgets('Renders inside standard window (1280x800 and 1100x700) with ZERO vertical scrollbars', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockApi = _MockWebcamApiService();
      Get.put(HardwareTestController(apiService: mockApi));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WebcamTestView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify no SingleChildScrollView
      expect(find.byType(SingleChildScrollView), findsNothing);
      expect(tester.takeException(), isNull);

      // Verify compact header
      expect(find.text('بازگشت به لیست تست‌ها'), findsOneWidget);
      expect(find.text('تست وب‌کم، فوکوس و تصویر زنده'), findsOneWidget);
      expect(find.byType(DropdownButton<String>), findsWidgets);

      // Verify actions
      expect(find.text('ثبت فریم آزمایشی (Snapshot)'), findsOneWidget);
      expect(find.text('فعال‌سازی آینه (Mirror)'), findsOneWidget);
      expect(find.text('دسترسی وب‌کم در ویندوز'), findsOneWidget);

      // Test with minSize 1100x700
      tester.view.physicalSize = const Size(1100, 700);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Snapshot button captures test frame and displays toast notification', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockApi = _MockWebcamApiService();
      Get.put(HardwareTestController(apiService: mockApi));

      await tester.pumpWidget(
        const GetMaterialApp(
          home: Scaffold(
            body: WebcamTestView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Snapshot button
      final snapBtn = find.text('ثبت فریم آزمایشی (Snapshot)');
      expect(snapBtn, findsOneWidget);
      await tester.tap(snapBtn);
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));

      // Toast appears
      expect(find.textContaining('عکس ثبت شد'), findsOneWidget);
    });

    testWidgets('Mirror button toggles mirror transform state and badge label', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockApi = _MockWebcamApiService();
      Get.put(HardwareTestController(apiService: mockApi));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WebcamTestView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('حالت آینه‌ای: خاموش'), findsOneWidget);

      // Tap Mirror toggle button
      final mirrorBtn = find.text('فعال‌سازی آینه (Mirror)');
      await tester.tap(mirrorBtn);
      await tester.pumpAndSettle();

      // Mirror active
      expect(find.text('حالت آینه‌ای: فعال'), findsOneWidget);
      expect(find.text('غیرفعال کردن آینه'), findsOneWidget);

      // Tap again to toggle off
      await tester.tap(find.text('غیرفعال کردن آینه'));
      await tester.pumpAndSettle();

      expect(find.text('حالت آینه‌ای: خاموش'), findsOneWidget);
    });

    testWidgets('Detected cameras list displays enumerated devices from controller', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockApi = _MockWebcamApiService();
      final ctrl = Get.put(HardwareTestController(apiService: mockApi));
      await ctrl.fetchCameraDevices();

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WebcamTestView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Integrated Camera'), findsWidgets);
    });
  });
}
