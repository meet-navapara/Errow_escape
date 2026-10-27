import '../models/arrow_model.dart';
import '../models/board_model.dart';

class HintExplanation {
  final Arrow arrow;
  final String explanation;
  final List<Arrow> unblockedArrows;

  const HintExplanation({
    required this.arrow,
    required this.explanation,
    this.unblockedArrows = const [],
  });
}

class SolveResult {
  final bool isSolvable;
  final List<Arrow> solutionSteps;
  final int totalArrows;
  final List<Arrow> deadlockedArrows;

  const SolveResult({
    required this.isSolvable,
    required this.solutionSteps,
    required this.totalArrows,
    this.deadlockedArrows = const [],
  });
}

/// Difficulty metrics derived from the blocking graph of a board.
class PuzzleAnalysis {
  final bool isSolvable;

  /// Number of rounds needed when every free arrow is cleared each round.
  /// 1 means every arrow is free immediately; higher means longer chains.
  final int depth;

  /// Arrows that can escape on the very first move.
  final int initialMoves;

  /// Total "A is blocked by B" relationships on the board.
  final int blockingPairs;

  final int arrowCount;

  const PuzzleAnalysis({
    required this.isSolvable,
    required this.depth,
    required this.initialMoves,
    required this.blockingPairs,
    required this.arrowCount,
  });
}

class PuzzleSolver {
  /// Solves the puzzle by repeatedly removing an escapable arrow.
  ///
  /// Removing an arrow only ever frees cells, so it can never make another
  /// arrow blocked. That makes greedy removal complete: if any order clears
  /// the board, clearing escapable arrows in any order does too.
  static SolveResult solve(Board initialBoard) {
    Board currentBoard = initialBoard;
    final solutionSteps = <Arrow>[];
    final total = initialBoard.arrows.length;

    while (!currentBoard.isCompleted) {
      final escapable = currentBoard.getEscapableArrows();
      if (escapable.isEmpty) {
        return SolveResult(
          isSolvable: false,
          solutionSteps: solutionSteps,
          totalArrows: total,
          deadlockedArrows: currentBoard.arrows,
        );
      }

      for (final arrow in escapable) {
        solutionSteps.add(arrow);
      }
      currentBoard = Board(
        rows: currentBoard.rows,
        cols: currentBoard.cols,
        arrows: currentBoard.arrows
            .where((a) => !escapable.any((e) => e.id == a.id))
            .toList(),
      );
    }

    return SolveResult(
      isSolvable: true,
      solutionSteps: solutionSteps,
      totalArrows: total,
    );
  }

  /// Checks if a board is valid and completely solvable.
  static bool isSolvable(Board board) {
    if (board.arrows.isEmpty) return true;
    final result = solve(board);
    return result.isSolvable;
  }

  /// Builds the full blocking graph (every arrow on each escape ray, not just
  /// the first) and measures how deep the dependency chains go.
  static PuzzleAnalysis analyze(Board board) {
    final arrows = board.arrows;
    final indexById = {for (var i = 0; i < arrows.length; i++) arrows[i].id: i};
    final dependents = List.generate(arrows.length, (_) => <int>[]);
    final waitingOn = List.filled(arrows.length, 0);
    var pairs = 0;

    for (var i = 0; i < arrows.length; i++) {
      final arrow = arrows[i];
      final blockers = <int>{};
      var cell = arrow.headCell.step(arrow.exitDirection);
      while (board.isWithinBounds(cell)) {
        final occupant = board.arrowAt(cell);
        if (occupant != null && occupant.id != arrow.id) {
          blockers.add(indexById[occupant.id]!);
        }
        cell = cell.step(arrow.exitDirection);
      }
      for (final b in blockers) {
        dependents[b].add(i);
      }
      waitingOn[i] = blockers.length;
      pairs += blockers.length;
    }

    var frontier = [
      for (var i = 0; i < arrows.length; i++)
        if (waitingOn[i] == 0) i,
    ];
    final initialMoves = frontier.length;
    var cleared = 0;
    var depth = 0;
    while (frontier.isNotEmpty) {
      depth++;
      cleared += frontier.length;
      final next = <int>[];
      for (final f in frontier) {
        for (final d in dependents[f]) {
          if (--waitingOn[d] == 0) next.add(d);
        }
      }
      frontier = next;
    }

    return PuzzleAnalysis(
      isSolvable: cleared == arrows.length,
      depth: depth,
      initialMoves: initialMoves,
      blockingPairs: pairs,
      arrowCount: arrows.length,
    );
  }

  /// Evaluates which escapable arrow frees the most dependent arrows.
  static Arrow _pickBestEscapableArrow(Board board, List<Arrow> escapable) {
    if (escapable.length == 1) return escapable.first;

    Arrow bestArrow = escapable.first;
    int maxUnblocked = -1;

    for (final arrow in escapable) {
      final simulatedBoard = board.removeArrow(arrow.id);
      final newEscapable = simulatedBoard.getEscapableArrows();
      final unblockedCount = newEscapable
          .where((a) => !escapable.any((prev) => prev.id == a.id))
          .length;

      if (unblockedCount > maxUnblocked) {
        maxUnblocked = unblockedCount;
        bestArrow = arrow;
      }
    }

    return bestArrow;
  }

  /// Generates an intelligent hint with full explanation.
  /// Returns null only when no arrow can legally escape.
  static HintExplanation? getHint(Board board) {
    final escapable = board.getEscapableArrows();
    if (escapable.isEmpty) return null;

    final bestArrow = _pickBestEscapableArrow(board, escapable);

    final simulatedBoard = board.removeArrow(bestArrow.id);
    final newlyEscapable = simulatedBoard
        .getEscapableArrows()
        .where((a) => !escapable.any((prev) => prev.id == a.id))
        .toList();

    String explanation;
    if (newlyEscapable.isNotEmpty) {
      final freed = newlyEscapable.length;
      explanation =
          'Tap arrow pointing ${bestArrow.exitDirection.displayName} to escape! '
          'It frees $freed more arrow${freed == 1 ? '' : 's'}.';
    } else {
      explanation =
          'Tap arrow pointing ${bestArrow.exitDirection.displayName}. Its path is completely clear.';
    }

    return HintExplanation(
      arrow: bestArrow,
      explanation: explanation,
      unblockedArrows: newlyEscapable,
    );
  }
}
