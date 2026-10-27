import 'package:flutter_test/flutter_test.dart';
import 'package:arrow_escape/models/arrow_model.dart';
import 'package:arrow_escape/models/board_model.dart';

void main() {
  group('Arrow and Board Mechanics with Continuous Paths', () {
    test('Single-point arrow escapes when exit ray to border is clear', () {
      const arrow = Arrow(
        id: 'a1',
        path: [GridPosition(0, 1)],
        exitDirection: ArrowDirection.up,
      );
      final board = Board(rows: 3, cols: 3, arrows: [arrow]);

      final check = board.checkEscape(arrow);
      expect(check.canEscape, isTrue);
      expect(check.blocker, isNull);
    });

    test('Arrow is blocked when another arrow lies in its exit path', () {
      const arrow1 = Arrow(
        id: 'a1',
        path: [GridPosition(1, 1)],
        exitDirection: ArrowDirection.right,
      );
      const arrow2 = Arrow(
        id: 'a2',
        path: [GridPosition(1, 2)],
        exitDirection: ArrowDirection.down,
      );
      final board = Board(rows: 4, cols: 4, arrows: [arrow1, arrow2]);

      final check1 = board.checkEscape(arrow1);
      expect(check1.canEscape, isFalse);
      expect(check1.blocker?.id, equals('a2'));
      expect(check1.blockedAt, equals(const GridPosition(1, 2)));

      final check2 = board.checkEscape(arrow2);
      expect(check2.canEscape, isTrue);
      expect(check2.blocker, isNull);
    });

    test(
      'Bent arrow with 90-degree turn detects obstruction ahead of its head',
      () {
        // Bent Arrow: (3, 1) -> (2, 1) -> (1, 1) -> (1, 2) pointing right
        const bentArrow = Arrow(
          id: 'bent_1',
          path: [
            GridPosition(3, 1),
            GridPosition(2, 1),
            GridPosition(1, 1),
            GridPosition(1, 2),
          ],
          exitDirection: ArrowDirection.right,
        );
        // Blocker at (1, 3) pointing down
        const blocker = Arrow(
          id: 'blocker',
          path: [GridPosition(1, 3)],
          exitDirection: ArrowDirection.down,
        );
        final board = Board(rows: 5, cols: 5, arrows: [bentArrow, blocker]);

        final check = board.checkEscape(bentArrow);
        expect(check.canEscape, isFalse);
        expect(check.blocker?.id, equals('blocker'));
        expect(check.blockedAt, equals(const GridPosition(1, 3)));
      },
    );

    test('Bent arrow escapes when its exit ray is clear', () {
      // Bent Arrow at (2, 0) -> (1, 0) -> (1, 1) pointing right
      const bentArrow = Arrow(
        id: 'bent_clear',
        path: [GridPosition(2, 0), GridPosition(1, 0), GridPosition(1, 1)],
        exitDirection: ArrowDirection.right,
      );
      final board = Board(rows: 4, cols: 4, arrows: [bentArrow]);

      final check = board.checkEscape(bentArrow);
      expect(check.canEscape, isTrue);
    });

    test('Board completion detected when arrows are empty', () {
      final board = Board(rows: 3, cols: 3, arrows: []);
      expect(board.isCompleted, isTrue);
      expect(board.remainingArrowsCount, equals(0));
    });

    test('Board removeArrow and addArrow for undo work immutably', () {
      const a1 = Arrow(
        id: 'a1',
        path: [GridPosition(0, 0)],
        exitDirection: ArrowDirection.up,
      );
      const a2 = Arrow(
        id: 'a2',
        path: [GridPosition(1, 1)],
        exitDirection: ArrowDirection.down,
      );
      final initialBoard = Board(rows: 3, cols: 3, arrows: [a1, a2]);

      final afterRemove = initialBoard.removeArrow('a1');
      expect(afterRemove.arrows.length, equals(1));
      expect(afterRemove.arrowById('a1'), isNull);
      expect(initialBoard.arrows.length, equals(2));

      final afterUndo = afterRemove.addArrow(a1);
      expect(afterUndo.arrows.length, equals(2));
      expect(afterUndo.arrowById('a1'), isNotNull);
    });
  });
}
