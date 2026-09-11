import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markazi_system_checker/screens/splash_screen.dart';

void main() {
  testWidgets('splash light and dark visual artifacts', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final font = FontLoader('Vazirmatn')
      ..addFont(rootBundle.load('assets/fonts/Vazirmatn-Regular.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    for (final brightness in [Brightness.light, Brightness.dark]) {
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(brightness: brightness, fontFamily: 'Vazirmatn'),
            home: SplashScreen(connect: () async => false),
          ),
        ),
      );
      await tester.runAsync(
        () => precacheImage(
          const AssetImage('assets/logo/camputermarkazi.png'),
          tester.element(find.byType(SplashScreen)),
        ),
      );
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
      expect(tester.takeException(), isNull);
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final picture = await boundary.toImage();
        final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
        final file = File('build/qa/splash-${brightness.name}.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        picture.dispose();
      });
      await tester.pumpWidget(const SizedBox());
    }
  });
}
