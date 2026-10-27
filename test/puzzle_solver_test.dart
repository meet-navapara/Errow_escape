import 'package:flutter_test/flutter_test.dart';

import 'support/level_pack_loader.dart';

import 'package:arrow_escape/models/arrow_model.dart';
import 'package:arrow_escape/models/board_model.dart';
import 'package:arrow_escape/game/puzzle_solver.dart';
import 'package:arrow_escape/game/levels_data.dart';

void main() {
  setUpAll(loadLevelPack);

  group('Puzzle Solver & Validation', () {
    test('Solves a valid 3-arrow dependency chain', () {
      const a3 = Arrow(
        id: 'a3',
        path: [GridPosition(2, 2)],
        exitDirection: ArrowDirection.down,
      );
      const a2 = Arrow(
        id: 'a2',
        path: [GridPosition(1, 2)],
        exitDirection: ArrowDirection.down,
      );
      const a1 = Arrow(
        id: 'a1',
        path: [GridPosition(1, 1)],
        exitDirection: ArrowDirection.right,
      );

      final board = Board(rows: 4, cols: 4, arrows: [a1, a2, a3]);
      final result = PuzzleSolver.solve(board);

      expect(result.isSolvable, isTrue);
      expect(
        result.solutionSteps.map((a) => a.id).toList(),
        equals(['a3', 'a2', 'a1']),
      );
    });

    test('Detects and rejects deadlocked unsolvable board', () {
      const a1 = Arrow(
        id: 'a1',
        path: [GridPosition(1, 1)],
        exitDirection: ArrowDirection.right,
      );
      const a2 = Arrow(
        id: 'a2',
        path: [GridPosition(1, 2)],
        exitDirection: ArrowDirection.left,
      );

      final deadlockedBoard = Board(rows: 3, cols: 3, arrows: [a1, a2]);
      final result = PuzzleSolver.solve(deadlockedBoard);

      expect(result.isSolvable, isFalse);
      expect(result.deadlockedArrows.length, equals(2));
      expect(PuzzleSolver.isSolvable(deadlockedBoard), isFalse);
    });

    test('Hint system suggests valid move with explanation', () {
      const a1 = Arrow(
        id: 'a1',
        path: [GridPosition(1, 1)],
        exitDirection: ArrowDirection.right,
      );
      const a2 = Arrow(
        id: 'a2',
        path: [GridPosition(1, 2)],
        exitDirection: ArrowDirection.down,
      );
      final board = Board(rows: 3, cols: 3, arrows: [a1, a2]);

      final hint = PuzzleSolver.getHint(board);
      expect(hint, isNotNull);
      expect(hint!.arrow.id, equals('a2'));
      expect(hint.explanation, contains('Tap arrow pointing Down'));
    });

    test('All 100 pre-generated levels are verified solvable and valid', () {
      for (int i = 1; i <= LevelsRepository.totalLevels; i++) {
        final level = LevelsRepository.getLevel(i);

        expect(
          level.board.arrows.isNotEmpty,
          isTrue,
          reason: 'Level $i has no arrows',
        );

        final escapableFirstMoves = level.board.getEscapableArrows();
        expect(
          escapableFirstMoves.isNotEmpty,
          isTrue,
          reason: 'Level $i has no valid first move',
        );

        final solveResult = PuzzleSolver.solve(level.board);
        expect(
          solveResult.isSolvable,
          isTrue,
          reason: 'Level $i could not be solved by PuzzleSolver',
        );
        expect(
          solveResult.solutionSteps.length,
          equals(level.board.arrows.length),
          reason: 'Level $i solution length mismatch',
        );
      }
    });
  });
}
