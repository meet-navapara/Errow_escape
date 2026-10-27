import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Arrow Escape logo: the emblem plus an optional wordmark and tagline.
class GameLogoWidget extends StatelessWidget {
  final double size;
  final bool showWordmark;

  const GameLogoWidget({super.key, this.size = 96.0, this.showWordmark = true});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CustomPaint(painter: ArrowEscapeEmblemPainter()),
        ),
        if (showWordmark) ...[
          const SizedBox(height: 18),
          const Text(
            'ARROW ESCAPE',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Clear the path. Escape every arrow.',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ],
    );
  }
}

/// The Arrow Escape emblem: a bold lattice path that bends twice and escapes
/// through a gap in a maze frame, next to a smaller arrow still waiting its
/// turn. Original artwork; also used to render every app/store icon
/// (see tool/generate_brand_assets_test.dart and assets/branding/).
class ArrowEscapeEmblemPainter extends CustomPainter {
  /// Rounded tile corners. Off for iOS/App Store icons, which the system
  /// masks itself and which must be fully opaque squares.
  final bool roundedTile;

  /// Fraction of the canvas used as safe-zone padding around the artwork
  /// (Android adaptive icons crop the outer area).
  final double inset;

  /// Draw the blue tile. Off for Android adaptive-icon foregrounds, whose
  /// background layer is a separate colour.
  final bool drawTile;

  ArrowEscapeEmblemPainter({
    this.roundedTile = true,
    this.inset = 0,
    this.drawTile = true,
  });

  static const tileTop = Color(0xFF3EA2FF);
  static const tileBottom = Color(0xFF1A56DB);

  @override
  void paint(Canvas canvas, Size size) {
    final full = Offset.zero & size;
    final tile = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [tileTop, tileBottom],
      ).createShader(full);
    if (!drawTile) {
      // Foreground only.
    } else if (roundedTile) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(full, Radius.circular(size.width * 0.23)),
        tile,
      );
    } else {
      canvas.drawRect(full, tile);
    }

    // Artwork lives in a centred square shrunk by [inset].
    final s = size.shortestSide * (1 - inset * 2);
    final o = Offset((size.width - s) / 2, (size.height - s) / 2);
    Offset p(double x, double y) => o + Offset(x * s, y * s);

    Paint stroke(Color c, double w) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Maze frame with an exit gap on the upper right.
    final frame = Path()
      ..moveTo(p(0.84, 0.46).dx, p(0.84, 0.46).dy)
      ..lineTo(p(0.84, 0.84).dx, p(0.84, 0.84).dy)
      ..lineTo(p(0.16, 0.84).dx, p(0.16, 0.84).dy)
      ..lineTo(p(0.16, 0.16).dx, p(0.16, 0.16).dy)
      ..lineTo(p(0.62, 0.16).dx, p(0.62, 0.16).dy);
    canvas.drawPath(frame, stroke(const Color(0x59FFFFFF), 0.045));

    // Waiting arrow (pointing up, blocked by the main path).
    final waiting = Path()
      ..moveTo(p(0.66, 0.72).dx, p(0.66, 0.72).dy)
      ..lineTo(p(0.66, 0.58).dx, p(0.66, 0.58).dy);
    canvas.drawPath(waiting, stroke(const Color(0x8CFFFFFF), 0.06));
    _head(
      canvas,
      p(0.66, 0.53),
      const Offset(0, -1),
      s * 0.13,
      const Color(0x8CFFFFFF),
    );

    // Main escaping arrow.
    final main = Path()
      ..moveTo(p(0.30, 0.72).dx, p(0.30, 0.72).dy)
      ..lineTo(p(0.30, 0.48).dx, p(0.30, 0.48).dy)
      ..lineTo(p(0.50, 0.48).dx, p(0.50, 0.48).dy)
      ..lineTo(p(0.50, 0.32).dx, p(0.50, 0.32).dy)
      ..lineTo(p(0.80, 0.32).dx, p(0.80, 0.32).dy);
    canvas.drawPath(main, stroke(Colors.white, 0.095));
    _head(canvas, p(0.90, 0.32), const Offset(1, 0), s * 0.22, Colors.white);
  }

  void _head(Canvas canvas, Offset tip, Offset dir, double len, Color color) {
    final perp = Offset(-dir.dy, dir.dx);
    final base = tip - dir * len;
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo((base + perp * len * 0.55).dx, (base + perp * len * 0.55).dy)
      ..lineTo((base + dir * len * 0.25).dx, (base + dir * len * 0.25).dy)
      ..lineTo((base - perp * len * 0.55).dx, (base - perp * len * 0.55).dy)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant ArrowEscapeEmblemPainter old) =>
      old.roundedTile != roundedTile ||
      old.inset != inset ||
      old.drawTile != drawTile;
}
