import '../models/arrow_model.dart';
import '../models/board_model.dart';
import 'puzzle_solver.dart';

/// Structural and rules checks shared by the level-pack tool and tests.
class LevelValidation {
  /// Largest board allowed so puzzles stay usable on phones.
  static const int maxRows = 20;
  static const int maxCols = 16;

  /// Returns problems found; empty means the level is valid and verified
  /// solvable under the game's escape rules.
  static List<String> problems(Board board, {bool allowSinglePoints = false}) {
    final issues = <String>[];
    if (board.arrows.isEmpty) issues.add('no arrows');
    if (board.rows > maxRows || board.cols > maxCols) {
      issues.add(
        'board ${board.rows}x${board.cols} exceeds $maxRows x $maxCols',
      );
    }
    final seen = <GridPosition>{};
    final ids = <String>{};
    for (final a in board.arrows) {
      if (!ids.add(a.id)) issues.add('duplicate arrow id ${a.id}');
      if (a.path.length < 2 && !allowSinglePoints) {
        issues.add('${a.id} is a single point');
      }
      for (var i = 0; i < a.path.length; i++) {
        final p = a.path[i];
        if (!board.isWithinBounds(p)) issues.add('${a.id} leaves board at $p');
        if (!seen.add(p)) issues.add('cell $p used twice');
        if (i > 0) {
          final q = a.path[i - 1];
          if ((p.row - q.row).abs() + (p.col - q.col).abs() != 1) {
            issues.add('${a.id} has a gap between $q and $p');
          }
        }
      }
      if (a.path.length >= 2) {
        final prev = a.path[a.path.length - 2];
        if (prev.step(a.exitDirection) != a.headCell) {
          issues.add('${a.id} head does not continue its last segment');
        }
      }
    }
    if (issues.isNotEmpty) return issues;

    if (board.getEscapableArrows().isEmpty) issues.add('no legal first move');
    final solve = PuzzleSolver.solve(board);
    if (!solve.isSolvable ||
        solve.solutionSteps.length != board.arrows.length) {
      issues.add('not solvable');
    }
    return issues;
  }

  /// Identity of a puzzle up to rotation and reflection (arrow ids ignored).
  /// Two levels with the same key are the same puzzle.
  static String canonicalKey(Board board) {
    String? best;
    for (var t = 0; t < 8; t++) {
      final swap = t >= 4;
      final rows = swap ? board.cols : board.rows;
      final cols = swap ? board.rows : board.cols;
      GridPosition map(GridPosition p) {
        var r = swap ? p.col : p.row;
        var c = swap ? p.row : p.col;
        if (t & 1 != 0) r = rows - 1 - r;
        if (t & 2 != 0) c = cols - 1 - c;
        return GridPosition(r, c);
      }

      final arrows = [
        for (final a in board.arrows)
          a.path
              .map((p) {
                final m = map(p);
                return m.row * cols + m.col;
              })
              .join(','),
      ]..sort();
      final key = '${rows}x$cols;${arrows.join(' ')}';
      if (best == null || key.compareTo(best) < 0) best = key;
    }
    return best!;
  }
}
