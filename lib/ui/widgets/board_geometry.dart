import 'dart:math' as math;
import 'dart:ui';

import '../../models/arrow_model.dart';
import '../../models/board_model.dart';

/// Maps lattice coordinates to pixels. The renderer, hit testing and escape
/// animation all derive arrow geometry from here, so what the player sees is
/// exactly what they can tap and what the game logic uses.
class BoardGeometry {
  final int rows;
  final int cols;
  final double cellSize;

  /// Top-left corner of the board inside the painted area.
  final Offset origin;

  const BoardGeometry({
    required this.rows,
    required this.cols,
    required this.cellSize,
    this.origin = Offset.zero,
  });

  /// Largest cell size that fits the whole board into [available] while
  /// keeping [padding] around it.
  factory BoardGeometry.fit({
    required Board board,
    required Size available,
    double padding = 12,
    double maxCellSize = 72,
  }) {
    final usableW = math.max(1.0, available.width - padding * 2);
    final usableH = math.max(1.0, available.height - padding * 2);
    final cell = math.min(
      maxCellSize,
      math.min(usableW / board.cols, usableH / board.rows),
    );
    final size = Size(cell * board.cols, cell * board.rows);
    return BoardGeometry(
      rows: board.rows,
      cols: board.cols,
      cellSize: cell,
      origin: Offset(
        (available.width - size.width) / 2,
        (available.height - size.height) / 2,
      ),
    );
  }

  Size get boardSize => Size(cols * cellSize, rows * cellSize);

  double get strokeWidth => math.max(2.0, cellSize * 0.15);
  double get headLength => math.max(6.0, cellSize * 0.42);
  double get headWidth => math.max(6.0, cellSize * 0.46);
  double get cornerRadius => cellSize * 0.3;

  Offset cellCenter(GridPosition pos) =>
      origin + Offset((pos.col + 0.5) * cellSize, (pos.row + 0.5) * cellSize);

  static Offset unit(ArrowDirection dir) =>
      Offset(dir.dCol.toDouble(), dir.dRow.toDouble());

  /// Corner points of the arrow body from tail to head centre, with
  /// collinear points removed. A single-point arrow gets a short tail stub so
  /// it still reads as a line with a head.
  List<Offset> corners(Arrow arrow) {
    final points = arrow.path.map(cellCenter).toList();
    if (points.length == 1) {
      return [
        points.first - unit(arrow.exitDirection) * (cellSize * 0.5),
        points.first,
      ];
    }
    final result = <Offset>[points.first];
    for (var i = 1; i < points.length - 1; i++) {
      final dIn = points[i] - points[i - 1];
      final dOut = points[i + 1] - points[i];
      final turns = (dIn.dx * dOut.dy - dIn.dy * dOut.dx).abs() > 1e-6;
      if (turns) result.add(points[i]);
    }
    result.add(points.last);
    return result;
  }

  /// Arrow body with rounded bends. [extendBy] lengthens the final segment
  /// along the exit direction, used for the escape animation.
  Path bodyPath(Arrow arrow, {double extendBy = 0}) {
    final pts = corners(arrow);
    if (extendBy > 0) {
      pts.add(pts.last + unit(arrow.exitDirection) * extendBy);
      // Keep the head-centre point only if it is a real bend.
      if (pts.length >= 3) {
        final a = pts[pts.length - 3];
        final b = pts[pts.length - 2];
        final c = pts[pts.length - 1];
        final dIn = b - a;
        final dOut = c - b;
        if ((dIn.dx * dOut.dy - dIn.dy * dOut.dx).abs() < 1e-6) {
          pts.removeAt(pts.length - 2);
        }
      }
    }

    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length - 1; i++) {
      final prev = pts[i - 1];
      final cur = pts[i];
      final next = pts[i + 1];
      final inLen = (cur - prev).distance;
      final outLen = (next - cur).distance;
      final r = math.min(cornerRadius, math.min(inLen, outLen) / 2);
      final before = cur - (cur - prev) / inLen * r;
      final after = cur + (next - cur) / outLen * r;
      path
        ..lineTo(before.dx, before.dy)
        ..quadraticBezierTo(cur.dx, cur.dy, after.dx, after.dy);
    }
    path.lineTo(pts.last.dx, pts.last.dy);
    return path;
  }

  /// Arrowhead triangle whose base sits on the line and whose tip extends
  /// past the head point in [direction].
  Path headPath(Offset headPoint, Offset direction) {
    final len = direction.distance;
    final d = len == 0 ? const Offset(1, 0) : direction / len;
    final perp = Offset(-d.dy, d.dx);
    final tip = headPoint + d * (headLength * 0.55);
    final base = tip - d * headLength;
    final notch = base + d * (headLength * 0.18);
    final left = base + perp * (headWidth / 2);
    final right = base - perp * (headWidth / 2);
    return Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(left.dx, left.dy)
      ..lineTo(notch.dx, notch.dy)
      ..lineTo(right.dx, right.dy)
      ..close();
  }

  /// Point where the arrowhead tip ends.
  Offset tipOf(Arrow arrow) =>
      cellCenter(arrow.headCell) +
      unit(arrow.exitDirection) * (headLength * 0.55);

  /// Distance an escaping arrow must travel to fully leave [visible].
  double escapeDistance(Arrow arrow, Rect visible) {
    final head = cellCenter(arrow.headCell);
    final dir = arrow.exitDirection;
    final toEdge = switch (dir) {
      ArrowDirection.up => head.dy - visible.top,
      ArrowDirection.down => visible.bottom - head.dy,
      ArrowDirection.left => head.dx - visible.left,
      ArrowDirection.right => visible.right - head.dx,
    };
    final bodyLength = (arrow.path.length + 1) * cellSize;
    return math.max(0.0, toEdge) + bodyLength + headLength;
  }

  /// Finds the arrow whose drawn line (body or head) is nearest to [point],
  /// within [tolerance] (defaults to half a cell, which never overlaps a
  /// neighbouring parallel line).
  Arrow? hitTest(Board board, Offset point, {double? tolerance}) {
    final maxDist = tolerance ?? cellSize * 0.5;
    Arrow? best;
    var bestDist = double.infinity;
    for (final arrow in board.arrows) {
      final pts = [...corners(arrow), tipOf(arrow)];
      for (var i = 0; i < pts.length - 1; i++) {
        final d = _distanceToSegment(point, pts[i], pts[i + 1]);
        if (d < bestDist) {
          bestDist = d;
          best = arrow;
        }
      }
    }
    return bestDist <= maxDist ? best : null;
  }

  static double _distanceToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final lenSq = ab.dx * ab.dx + ab.dy * ab.dy;
    if (lenSq == 0) return (p - a).distance;
    final t = (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / lenSq).clamp(
      0.0,
      1.0,
    );
    return (p - (a + ab * t)).distance;
  }
}
