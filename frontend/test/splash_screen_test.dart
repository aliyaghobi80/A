import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markazi_system_checker/screens/splash_screen.dart';

void main() {
  testWidgets('logo drops from above into a rounded cover composition', (
    tester,
  ) async {
    final backend = Completer<bool>();
    await tester.pumpWidget(
      MaterialApp(home: SplashScreen(connect: () => backend.future)),
    );

    final logoFinder = find.byKey(const ValueKey('splash-logo-drop'));
    final initialTransform = tester.widget<Transform>(logoFinder);
    expect(initialTransform.transform.storage[13], lessThan(-100));
    expect(find.byType(ClipOval), findsNothing);
    expect(
      find.byKey(const ValueKey('splash-logo-rounded-cover')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('splash-rgb-loader')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1400));
    final landedTransform = tester.widget<Transform>(logoFinder);
    expect(landedTransform.transform.storage[13].abs(), lessThan(0.01));

    await tester.pumpWidget(const SizedBox());
    backend.complete(true);
    await tester.pump();
  });

  testWidgets('ready backend proceeds without a fixed four-second delay', (
    tester,
  ) async {
    var transitions = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: SplashScreen(
          connect: () async => true,
          onReady: () => transitions++,
        ),
      ),
    );
    await tester.pump();
    expect(transitions, 1);
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
    await tester.pump();
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
    await tester.pump(const Duration(seconds: 91));
    expect(find.text('ورود برای بررسی'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    backend.complete(true);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'reduced motion and large text fit narrow view without fixed delay',
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
      await tester.pump();
      expect(transitions, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
