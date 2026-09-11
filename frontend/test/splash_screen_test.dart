import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markazi_system_checker/screens/splash_screen.dart';

void main() {
  testWidgets('ready backend still waits four seconds', (tester) async {
    var transitions = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: SplashScreen(
          connect: () async => true,
          onReady: () => transitions++,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 3999));
    expect(transitions, 0);
    await tester.pump(const Duration(milliseconds: 1));
    expect(transitions, 1);
    expect(find.text('Markazi System Checker'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('failed backend offers retry and can recover', (tester) async {
    var attempts = 0;
    var transitions = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: SplashScreen(
          connect: () async => ++attempts > 1,
          onReady: () => transitions++,
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('تلاش مجدد'), findsOneWidget);
    expect(transitions, 0);
    await tester.tap(find.text('تلاش مجدد'));
    await tester.pump();
    expect(transitions, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('timeout is actionable and dispose ignores late completion', (
    tester,
  ) async {
    final backend = Completer<bool>();
    await tester.pumpWidget(
      MaterialApp(home: SplashScreen(connect: () => backend.future)),
    );
    await tester.pump(const Duration(seconds: 46));
    expect(find.text('ورود برای بررسی'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    backend.complete(true);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'reduced motion respects minimum and large text fits narrow view',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(375, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var transitions = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              disableAnimations: true,
              textScaler: TextScaler.linear(2),
            ),
            child: SplashScreen(
              connect: () async => true,
              onReady: () => transitions++,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 3));
      expect(transitions, 0);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 1));
      expect(transitions, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
