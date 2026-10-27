import 'arrow_model.dart';

/// Result of checking whether an arrow has a clear escape path.
class EscapeCheckResult {
  final bool canEscape;
  final Arrow arrow;
  final Arrow? blocker;
  final GridPosition? blockedAt;
  final List<GridPosition> path;
  final String explanation;

  const EscapeCheckResult({
    required this.canEscape,
    required this.arrow,
    this.blocker,
    this.blockedAt,
    this.path = const [],
    required this.explanation,
  });

  factory EscapeCheckResult.clear({
    required Arrow arrow,
    required List<GridPosition> path,
  }) {
    return EscapeCheckResult(
      canEscape: true,
      arrow: arrow,
      path: path,
      explanation:
          'Path clear! Arrow escaped pointing ${arrow.exitDirection.displayName}.',
    );
  }

  factory EscapeCheckResult.blocked({
    required Arrow arrow,
    required Arrow blocker,
    required GridPosition blockedAt,
    required List<GridPosition> path,
  }) {
    return EscapeCheckResult(
      canEscape: false,
      arrow: arrow,
      blocker: blocker,
      blockedAt: blockedAt,
      path: path,
      explanation:
          'Path blocked at row ${blockedAt.row + 1}, col ${blockedAt.col + 1} by another arrow pointing ${blocker.exitDirection.displayName}.',
    );
  }
}

/// Represents the board state containing grid dimensions and active arrows.
class Board {
  final int rows;
  final int cols;
  final List<Arrow> arrows;

  late final Map<GridPosition, Arrow> _cellMap = _buildCellMap();

  Board({required this.rows, required this.cols, required List<Arrow> arrows})
    : arrows = List.unmodifiable(arrows);

  Map<GridPosition, Arrow> _buildCellMap() {
    final map = <GridPosition, Arrow>{};
    for (final arrow in arrows) {
      for (final cell in arrow.path) {
        map[cell] = arrow;
      }
    }
    return map;
  }

  bool isWithinBounds(GridPosition pos) {
    return pos.row >= 0 && pos.row < rows && pos.col >= 0 && pos.col < cols;
  }

  Arrow? arrowAt(GridPosition pos) => _cellMap[pos];

  Arrow? arrowById(String id) {
    for (final a in arrows) {
      if (a.id == id) return a;
    }
    return null;
  }

  bool get isCompleted => arrows.isEmpty;

  int get remainingArrowsCount => arrows.length;

  /// Checks if an arrow can escape by tracing forward from its head in exitDirection.
  /// If any other active arrow is encountered along the ray before leaving the grid,
  /// the move is blocked.
  EscapeCheckResult checkEscape(Arrow arrow) {
    final dir = arrow.exitDirection;
    final sweptRay = <GridPosition>[];

    GridPosition curr = arrow.headCell.step(dir);

    while (isWithinBounds(curr)) {
      sweptRay.add(curr);
      final occupant = arrowAt(curr);

      if (occupant != null && occupant.id != arrow.id) {
        return EscapeCheckResult.blocked(
          arrow: arrow,
          blocker: occupant,
          blockedAt: curr,
          path: sweptRay,
        );
      }
      curr = curr.step(dir);
    }

    return EscapeCheckResult.clear(arrow: arrow, path: sweptRay);
  }

  /// Every other arrow on [arrow]'s escape ray, nearest first.
  List<Arrow> blockersOf(Arrow arrow) {
    final found = <Arrow>[];
    var curr = arrow.headCell.step(arrow.exitDirection);
    while (isWithinBounds(curr)) {
      final occupant = arrowAt(curr);
      if (occupant != null &&
          occupant.id != arrow.id &&
          !found.any((a) => a.id == occupant.id)) {
        found.add(occupant);
      }
      curr = curr.step(arrow.exitDirection);
    }
    return found;
  }

  /// Returns all arrows that can currently escape without hitting obstacles.
  List<Arrow> getEscapableArrows() {
    final escapable = <Arrow>[];
    for (final arrow in arrows) {
      if (checkEscape(arrow).canEscape) {
        escapable.add(arrow);
      }
    }
    return escapable;
  }

  /// Returns a new Board with the given arrow removed.
  Board removeArrow(String arrowId) {
    final updatedArrows = arrows.where((a) => a.id != arrowId).toList();
    return Board(rows: rows, cols: cols, arrows: updatedArrows);
  }

  /// Returns a new Board with the given arrow added (used for Undo).
  Board addArrow(Arrow arrow) {
    final updatedArrows = List<Arrow>.from(arrows)..add(arrow);
    return Board(rows: rows, cols: cols, arrows: updatedArrows);
  }

  Map<String, dynamic> toJson() => {
    'rows': rows,
    'cols': cols,
    'arrows': arrows.map((a) => a.toJson()).toList(),
  };

  factory Board.fromJson(Map<String, dynamic> json) {
    return Board(
      rows: json['rows'] as int,
      cols: json['cols'] as int,
      arrows: (json['arrows'] as List)
          .map((a) => Arrow.fromJson(a as Map<String, dynamic>))
          .toList(),
    );
  }
}
