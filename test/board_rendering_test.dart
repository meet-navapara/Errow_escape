import 'dart:ui';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/level_pack_loader.dart';

import 'package:arrow_escape/game/levels_data.dart';
import 'package:arrow_escape/models/arrow_model.dart';
import 'package:arrow_escape/models/board_model.dart';
import 'package:arrow_escape/ui/widgets/board_geometry.dart';
import 'package:arrow_escape/ui/widgets/board_painter.dart';

/// Records draw calls so tests can count what the painter renders.
class _RecordingCanvas implements Canvas {
  final List<Paint> strokes = [];
  final List<Paint> fills = [];

  @override
  void drawPath(Path path, Paint paint) {
    (paint.style == PaintingStyle.stroke ? strokes : fills).add(paint);
  }

  @override
  void save() {}

  @override
  void restore() {}

  @override
  void translate(double dx, double dy) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  setUpAll(loadLevelPack);

  const geometry = BoardGeometry(rows: 6, cols: 6, cellSize: 40);

  group('Arrow geometry', () {
    test('keeps every bend and drops collinear points', () {
      const arrow = Arrow(
        id: 'snake',
        path: [
          GridPosition(4, 1),
          GridPosition(3, 1),
          GridPosition(2, 1),
          GridPosition(2, 2),
          GridPosition(2, 3),
          GridPosition(1, 3),
        ],
        exitDirection: ArrowDirection.up,
      );
      final corners = geometry.corners(arrow);
      expect(corners, [
        geometry.cellCenter(const GridPosition(4, 1)),
        geometry.cellCenter(const GridPosition(2, 1)),
        geometry.cellCenter(const GridPosition(2, 3)),
        geometry.cellCenter(const GridPosition(1, 3)),
      ]);
    });

    test('body is a single continuous contour covering all segments', () {
      for (final id in [1, 4, 6, 50, 100]) {
        final board = LevelsRepository.getLevel(id).board;
        final g = BoardGeometry(
          rows: board.rows,
          cols: board.cols,
          cellSize: 30,
        );
        for (final arrow in board.arrows) {
          final metrics = g.bodyPath(arrow).computeMetrics().toList();
          expect(metrics.length, 1, reason: 'Level $id ${arrow.id} is broken');
          // Each rounded bend trims ~0.11 cells (2r of corner vs. ~1.62r of
          // quadratic curve), so the length matches the segments minus that.
          final straight = (arrow.length - 1) * g.cellSize;
          final bends = g.corners(arrow).length - 2;
          expect(
            metrics.first.length,
            closeTo(
              straight - bends * 0.113 * g.cellSize,
              0.05 * g.cellSize * (bends + 1),
            ),
          );
        }
      }
    });

    test('arrowhead tip points along the exit direction', () {
      for (final dir in ArrowDirection.values) {
        final arrow = Arrow(
          id: dir.name,
          path: [
            GridPosition(3 - dir.dRow, 3 - dir.dCol),
            const GridPosition(3, 3),
          ],
          exitDirection: dir,
        );
        final head = geometry.cellCenter(arrow.headCell);
        final tip = geometry.tipOf(arrow);
        final delta = tip - head;
        expect(delta.dx.sign, dir.dCol.toDouble().sign, reason: dir.name);
        expect(delta.dy.sign, dir.dRow.toDouble().sign, reason: dir.name);
        // The head polygon's furthest point is the tip.
        final bounds = geometry
            .headPath(head, BoardGeometry.unit(dir))
            .getBounds();
        expect(bounds.inflate(0.01).contains(tip), isTrue);
      }
    });

    test('fit() centres the board and never exceeds the available area', () {
      final board = LevelsRepository.getLevel(60).board;
      for (final size in const [
        Size(360, 520),
        Size(412, 700),
        Size(800, 1000),
      ]) {
        final g = BoardGeometry.fit(board: board, available: size);
        expect(g.boardSize.width, lessThanOrEqualTo(size.width));
        expect(g.boardSize.height, lessThanOrEqualTo(size.height));
        // One dimension is filled (minus padding) -> no wasted space.
        final fillsWidth = g.boardSize.width >= size.width - 24 - 0.01;
        final fillsHeight = g.boardSize.height >= size.height - 24 - 0.01;
        expect(fillsWidth || fillsHeight, isTrue, reason: '$size');
        expect(
          g.origin.dx,
          closeTo((size.width - g.boardSize.width) / 2, 0.001),
        );
      }
    });
  });

  group('Hit testing', () {
    test('every cell of every arrow selects that arrow', () {
      for (final id in [2, 6, 30, 75, 100]) {
        final board = LevelsRepository.getLevel(id).board;
        final g = BoardGeometry.fit(
          board: board,
          available: const Size(380, 560),
        );
        for (final arrow in board.arrows) {
          for (final cell in arrow.path) {
            expect(
              g.hitTest(board, g.cellCenter(cell))?.id,
              arrow.id,
              reason: 'Level $id cell $cell',
            );
          }
          // Tapping the arrowhead tip also selects it.
          expect(g.hitTest(board, g.tipOf(arrow))?.id, arrow.id);
        }
      }
    });

    test('taps along a segment between points select the same arrow', () {
      const arrow = Arrow(
        id: 'a',
        path: [GridPosition(1, 1), GridPosition(1, 2), GridPosition(1, 3)],
        exitDirection: ArrowDirection.right,
      );
      final board = Board(rows: 4, cols: 5, arrows: [arrow]);
      final mid =
          (geometry.cellCenter(const GridPosition(1, 1)) +
              geometry.cellCenter(const GridPosition(1, 2))) /
          2;
      expect(geometry.hitTest(board, mid)?.id, 'a');
      expect(geometry.hitTest(board, mid + const Offset(0, 12))?.id, 'a');
    });

    test('taps on empty space select nothing', () {
      const arrow = Arrow(
        id: 'a',
        path: [GridPosition(0, 0), GridPosition(0, 1)],
        exitDirection: ArrowDirection.right,
      );
      final board = Board(rows: 6, cols: 6, arrows: [arrow]);
      expect(
        geometry.hitTest(board, geometry.cellCenter(const GridPosition(4, 4))),
        isNull,
      );
    });
  });

  group('BoardPainter', () {
    test('renders exactly one body and one head per active arrow', () {
      for (final id in [1, 6, 42, 88]) {
        final board = LevelsRepository.getLevel(id).board;
        final g = BoardGeometry.fit(
          board: board,
          available: const Size(400, 600),
        );
        final canvas = _RecordingCanvas();
        BoardPainter(
          board: board,
          geometry: g,
        ).paint(canvas, const Size(400, 600));
        expect(canvas.strokes.length, board.arrows.length, reason: 'Level $id');
        expect(canvas.fills.length, board.arrows.length, reason: 'Level $id');
        final widths = canvas.strokes.map((p) => p.strokeWidth).toSet();
        expect(widths.length, 1, reason: 'Stroke width must be consistent');
      }
    });

    test('removed arrows are drawn only as escaping ghosts', () {
      final board = LevelsRepository.getLevel(4).board;
      final removed = board.arrows.first;
      final after = board.removeArrow(removed.id);
      final g = BoardGeometry.fit(
        board: board,
        available: const Size(400, 600),
      );

      final canvas = _RecordingCanvas();
      BoardPainter(
        board: after,
        geometry: g,
        escaping: [EscapingArrow(removed, 0.5)],
      ).paint(canvas, const Size(400, 600));
      expect(canvas.fills.length, after.arrows.length + 1);

      // A ghost for an arrow that is back on the board (undo) is skipped.
      final undone = _RecordingCanvas();
      BoardPainter(
        board: board,
        geometry: g,
        escaping: [EscapingArrow(removed, 0.5)],
      ).paint(undone, const Size(400, 600));
      expect(undone.fills.length, board.arrows.length);
    });
  });
}
