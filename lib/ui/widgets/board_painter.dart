import 'dart:ui';

import 'package:flutter/widgets.dart';

import '../../core/theme/app_colors.dart';
import '../../models/arrow_model.dart';
import '../../models/board_model.dart';
import 'board_geometry.dart';

/// An arrow that has been removed from the board and is sliding out along
/// its own path. [progress] runs from 0 to 1.
class EscapingArrow {
  final Arrow arrow;
  final double progress;
  const EscapingArrow(this.arrow, this.progress);
}

/// Paints every active arrow as one continuous rounded path with an
/// arrowhead, plus optional state highlights and escape animations.
class BoardPainter extends CustomPainter {
  final Board board;
  final BoardGeometry geometry;
  final String? blockedId;
  final String? blockerId;
  final String? hintedId;

  /// Tutorial guidance: arrows to draw in the primary colour with a pulse.
  final Set<String> guideIds;
  final double pulse;

  /// Path Scanner: the inspected arrow and the arrows blocking it.
  final String? scanId;
  final Set<String> scanBlockerIds;

  /// Forward nudge of the blocked arrow towards its blocker, in cells.
  final double bump;
  final List<EscapingArrow> escaping;
  final Color arrowColor;

  BoardPainter({
    required this.board,
    required this.geometry,
    this.blockedId,
    this.blockerId,
    this.hintedId,
    this.guideIds = const {},
    this.pulse = 0,
    this.scanId,
    this.scanBlockerIds = const {},
    this.bump = 0,
    this.escaping = const [],
    this.arrowColor = AppColors.arrowNavy,
    super.repaint,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final hinted = hintedId == null ? null : board.arrowById(hintedId!);
    if (hinted != null) _paintRay(canvas, hinted, AppColors.hint);
    final scanned = scanId == null ? null : board.arrowById(scanId!);
    if (scanned != null) _paintRay(canvas, scanned, AppColors.scanner);

    for (final arrow in board.arrows) {
      final Color color;
      Color? glow;
      var offset = Offset.zero;
      if (arrow.id == blockedId) {
        color = AppColors.blocked;
        glow = AppColors.blocked.withValues(alpha: 0.28);
        offset =
            BoardGeometry.unit(arrow.exitDirection) *
            (bump * geometry.cellSize);
      } else if (arrow.id == blockerId) {
        color = AppColors.blockerAlert;
        glow = AppColors.blockerAlert.withValues(alpha: 0.28);
      } else if (arrow.id == scanId) {
        color = AppColors.scanner;
        glow = AppColors.scanner.withValues(alpha: 0.3);
      } else if (scanBlockerIds.contains(arrow.id)) {
        color = AppColors.blockerAlert;
        glow = AppColors.blockerAlert.withValues(alpha: 0.28);
      } else if (guideIds.contains(arrow.id)) {
        color = AppColors.primary;
        glow = AppColors.primary.withValues(alpha: 0.15 + 0.25 * pulse);
      } else if (arrow.id == hintedId) {
        color = AppColors.hint;
        glow = AppColors.hint.withValues(alpha: 0.35);
      } else {
        color = arrowColor;
      }
      _paintArrow(canvas, arrow, color, glow: glow, offset: offset);
    }

    final visible = Offset.zero & size;
    for (final e in escaping) {
      // Undo can bring an arrow back while its old ghost is still fading.
      if (board.arrowById(e.arrow.id) != null) continue;
      _paintEscaping(canvas, e, visible);
    }
  }

  Paint _stroke(Color color, double width) => Paint()
    ..color = color
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..style = PaintingStyle.stroke;

  void _paintArrow(
    Canvas canvas,
    Arrow arrow,
    Color color, {
    Color? glow,
    Offset offset = Offset.zero,
  }) {
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    final body = geometry.bodyPath(arrow);
    final head = geometry.headPath(
      geometry.cellCenter(arrow.headCell),
      BoardGeometry.unit(arrow.exitDirection),
    );
    if (glow != null) {
      canvas.drawPath(body, _stroke(glow, geometry.strokeWidth * 3));
      canvas.drawPath(head, _stroke(glow, geometry.strokeWidth * 1.5));
    }
    canvas.drawPath(body, _stroke(color, geometry.strokeWidth));
    canvas.drawPath(head, Paint()..color = color);
    canvas.restore();
  }

  /// Draws the arrow as a snake sliding forward along its own body and then
  /// straight out through its exit direction.
  void _paintEscaping(Canvas canvas, EscapingArrow e, Rect visible) {
    final arrow = e.arrow;
    final bodyMetric = _firstMetric(geometry.bodyPath(arrow));
    if (bodyMetric == null) return;
    final travel = geometry.escapeDistance(arrow, visible);
    final extended = _firstMetric(
      geometry.bodyPath(arrow, extendBy: travel + geometry.cellSize),
    );
    if (extended == null) return;

    final t = Curves.easeIn.transform(e.progress.clamp(0.0, 1.0));
    final start = t * travel;
    final end = start + bodyMetric.length;
    final opacity = (1 - (e.progress - 0.75) / 0.25).clamp(0.0, 1.0);
    final color = arrowColor.withValues(alpha: opacity);

    canvas.drawPath(
      extended.extractPath(start, end),
      _stroke(color, geometry.strokeWidth),
    );
    final tangent = extended.getTangentForOffset(end);
    if (tangent != null) {
      canvas.drawPath(
        geometry.headPath(tangent.position, tangent.vector),
        Paint()..color = color,
      );
    }
  }

  PathMetric? _firstMetric(Path path) {
    final it = path.computeMetrics().iterator;
    return it.moveNext() ? it.current : null;
  }

  void _paintRay(Canvas canvas, Arrow arrow, Color color) {
    final from = geometry.tipOf(arrow);
    final dir = BoardGeometry.unit(arrow.exitDirection);
    final edge = switch (arrow.exitDirection) {
      ArrowDirection.up => Offset(from.dx, geometry.origin.dy),
      ArrowDirection.down => Offset(
        from.dx,
        geometry.origin.dy + geometry.boardSize.height,
      ),
      ArrowDirection.left => Offset(geometry.origin.dx, from.dy),
      ArrowDirection.right => Offset(
        geometry.origin.dx + geometry.boardSize.width,
        from.dy,
      ),
    };
    final paint = _stroke(
      color.withValues(alpha: 0.6),
      geometry.strokeWidth * 0.6,
    );
    // Dotted guide showing the clear escape route.
    final step = geometry.cellSize * 0.35;
    final total = (edge - from).distance;
    for (var d = step; d < total; d += step * 2) {
      canvas.drawLine(from + dir * d, from + dir * (d + step * 0.5), paint);
    }
  }

  @override
  bool shouldRepaint(covariant BoardPainter old) =>
      old.board != board ||
      old.geometry.cellSize != geometry.cellSize ||
      old.geometry.origin != geometry.origin ||
      old.blockedId != blockedId ||
      old.blockerId != blockerId ||
      old.hintedId != hintedId ||
      old.bump != bump ||
      old.scanId != scanId ||
      old.guideIds != guideIds ||
      old.pulse != pulse ||
      old.escaping.isNotEmpty ||
      escaping.isNotEmpty;
}
