// Generates every launcher/store icon and the Play feature graphic from
// ArrowEscapeEmblemPainter. Run from the project root:
//
//   flutter test tool/generate_brand_assets_test.dart
//
// Outputs are committed; re-run after changing the emblem.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arrow_escape/ui/widgets/game_logo_widget.dart';

import 'png_encoder.dart';

typedef Painter = void Function(Canvas canvas, Size size);

Future<void> render(
  WidgetTester tester,
  String path,
  int width,
  int height,
  Painter paint, {
  required bool alpha,
}) async {
  await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    paint(canvas, Size(width.toDouble(), height.toDouble()));
    final image = await recorder.endRecording().toImage(width, height);
    final data = await image.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    );
    final file = File(path)..createSync(recursive: true);
    file.writeAsBytesSync(
      PngEncoder.encode(
        data!.buffer.asUint8List(),
        width,
        height,
        alpha: alpha,
      ),
    );
  });
}

/// Roboto ships with the Flutter SDK (Apache 2.0); load it so the feature
/// graphic wordmark renders real glyphs instead of the test font.
Future<void> loadRoboto() async {
  var dir = File(Platform.resolvedExecutable).parent;
  while (!Directory('${dir.path}/artifacts/material_fonts').existsSync()) {
    if (dir.parent.path == dir.path) throw StateError('Roboto not found');
    dir = dir.parent;
  }
  final loader = FontLoader('Roboto');
  for (final f in ['roboto-black.ttf', 'roboto-bold.ttf']) {
    final bytes = File('${dir.path}/artifacts/material_fonts/$f')
        .readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

void main() {
  testWidgets('generate brand assets', (tester) async {
    // Android legacy launcher icons (rounded tile, transparent corners).
    const android = {
      'mdpi': 48,
      'hdpi': 72,
      'xhdpi': 96,
      'xxhdpi': 144,
      'xxxhdpi': 192,
    };
    for (final e in android.entries) {
      await render(
        tester,
        'android/app/src/main/res/mipmap-${e.key}/ic_launcher.png',
        e.value,
        e.value,
        ArrowEscapeEmblemPainter().paint,
        alpha: true,
      );
      // Adaptive icon foreground: 108dp canvas, artwork kept inside the
      // central 66dp safe zone.
      final fg = (e.value * 108 / 48).round();
      await render(
        tester,
        'android/app/src/main/res/mipmap-${e.key}/ic_launcher_foreground.png',
        fg,
        fg,
        ArrowEscapeEmblemPainter(drawTile: false, inset: 0.19).paint,
        alpha: true,
      );
    }

    // iOS app icons: opaque squares, no alpha channel.
    const ios = {
      'Icon-App-20x20@1x.png': 20,
      'Icon-App-20x20@2x.png': 40,
      'Icon-App-20x20@3x.png': 60,
      'Icon-App-29x29@1x.png': 29,
      'Icon-App-29x29@2x.png': 58,
      'Icon-App-29x29@3x.png': 87,
      'Icon-App-40x40@1x.png': 40,
      'Icon-App-40x40@2x.png': 80,
      'Icon-App-40x40@3x.png': 120,
      'Icon-App-60x60@2x.png': 120,
      'Icon-App-60x60@3x.png': 180,
      'Icon-App-76x76@1x.png': 76,
      'Icon-App-76x76@2x.png': 152,
      'Icon-App-83.5x83.5@2x.png': 167,
      'Icon-App-1024x1024@1x.png': 1024,
    };
    for (final e in ios.entries) {
      await render(
        tester,
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/${e.key}',
        e.value,
        e.value,
        ArrowEscapeEmblemPainter(roundedTile: false).paint,
        alpha: false,
      );
    }

    // Store listing icons.
    await render(
      tester,
      'assets/branding/play_store_icon_512.png',
      512,
      512,
      ArrowEscapeEmblemPainter(roundedTile: false).paint,
      alpha: false,
    );
    await render(
      tester,
      'assets/branding/app_store_icon_1024.png',
      1024,
      1024,
      ArrowEscapeEmblemPainter(roundedTile: false).paint,
      alpha: false,
    );

    // Google Play feature graphic 1024x500.
    await loadRoboto();
    await render(
      tester,
      'assets/branding/feature_graphic_1024x500.png',
      1024,
      500,
      (canvas, size) {
        final rect = Offset.zero & size;
        canvas.drawRect(
          rect,
          Paint()
            ..shader = const LinearGradient(
              colors: [Color(0xFFF8FAFC), Color(0xFFE3EEFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(rect),
        );
        canvas.save();
        canvas.translate(90, 90);
        ArrowEscapeEmblemPainter().paint(canvas, const Size(320, 320));
        canvas.restore();
        void text(String s, double y, double size, Color c, FontWeight w) {
          final tp = TextPainter(
            text: TextSpan(
              text: s,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: size,
                fontWeight: w,
                color: c,
                letterSpacing: size * 0.02,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(canvas, Offset(470, y));
        }

        text('ARROW', 140, 88, const Color(0xFF0B192C), FontWeight.w900);
        text('ESCAPE', 228, 88, const Color(0xFF1A56DB), FontWeight.w900);
        text(
          'Clear the path. Escape every arrow.',
          340,
          30,
          const Color(0xFF475569),
          FontWeight.w700,
        );
      },
      alpha: false,
    );

    expect(
      File('assets/branding/feature_graphic_1024x500.png').existsSync(),
      isTrue,
    );
  });
}
