# Arrow Escape brand assets

Original artwork created for this project (no third-party logos or licensed art).

| File | Use |
| --- | --- |
| `logo.svg` | Vector master of the emblem |
| `play_store_icon_512.png` | Google Play high-res icon (512×512, no alpha) |
| `app_store_icon_1024.png` | App Store marketing icon (1024×1024, RGB, no alpha) |
| `feature_graphic_1024x500.png` | Google Play feature graphic |

Launcher icons are written directly into `android/app/src/main/res/mipmap-*`
(legacy + adaptive foreground) and `ios/Runner/Assets.xcassets/AppIcon.appiconset`.

## How they are produced

All PNGs are rendered from `ArrowEscapeEmblemPainter`
(`lib/ui/widgets/game_logo_widget.dart`) by:

```bash
flutter test tool/generate_brand_assets_test.dart
```

The script uses a small built-in PNG encoder (`tool/png_encoder.dart`) so iOS
icons are saved as RGB without an alpha channel, as Apple requires. The
feature-graphic wordmark uses Roboto (Apache 2.0), loaded from the Flutter
SDK's bundled fonts.

Store **screenshots** are not generated: capture them from the real app on
a device or emulator so they show actual gameplay (both stores require this).
