import 'dart:math' as math;

/// 4 Cardinal Directions for arrows in the game.
enum ArrowDirection {
  up,
  down,
  left,
  right;

  int get dRow {
    switch (this) {
      case ArrowDirection.up:
        return -1;
      case ArrowDirection.down:
        return 1;
      case ArrowDirection.left:
      case ArrowDirection.right:
        return 0;
    }
  }

  int get dCol {
    switch (this) {
      case ArrowDirection.left:
        return -1;
      case ArrowDirection.right:
        return 1;
      case ArrowDirection.up:
      case ArrowDirection.down:
        return 0;
    }
  }

  /// Angle in radians for rotating arrow icons/canvases.
  /// 0 radians points right.
  double get angleInRadians {
    switch (this) {
      case ArrowDirection.right:
        return 0.0;
      case ArrowDirection.down:
        return math.pi / 2;
      case ArrowDirection.left:
        return math.pi;
      case ArrowDirection.up:
        return -math.pi / 2;
    }
  }

  String get displayName {
    switch (this) {
      case ArrowDirection.up:
        return 'Up';
      case ArrowDirection.down:
        return 'Down';
      case ArrowDirection.left:
        return 'Left';
      case ArrowDirection.right:
        return 'Right';
    }
  }
}

/// A 2D grid position on the board.
class GridPosition {
  final int row;
  final int col;

  const GridPosition(this.row, this.col);

  GridPosition step(ArrowDirection direction) {
    return GridPosition(row + direction.dRow, col + direction.dCol);
  }

  Map<String, dynamic> toJson() => {'row': row, 'col': col};

  factory GridPosition.fromJson(Map<String, dynamic> json) {
    return GridPosition(json['row'] as int, json['col'] as int);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GridPosition &&
          runtimeType == other.runtimeType &&
          row == other.row &&
          col == other.col;

  @override
  int get hashCode => Object.hash(row, col);

  @override
  String toString() => '($row, $col)';
}

/// Represents an arrow on the board.
/// An arrow can be a straight line or bend at 90-degree right angles,
/// rendered as a continuous, thin, colorful path with an arrowhead at the exit tip.
class Arrow {
  final String id;
  final List<GridPosition> path;
  final ArrowDirection exitDirection;
  final int colorIndex;

  const Arrow({
    required this.id,
    required this.path,
    required this.exitDirection,
    this.colorIndex = 0,
  });

  /// Backward-compatibility constructor supporting `cells` and `direction`.
  Arrow.legacy({
    required String id,
    required List<GridPosition> cells,
    required ArrowDirection direction,
    int colorIndex = 0,
  }) : this(
         id: id,
         path: cells,
         exitDirection: direction,
         colorIndex: colorIndex,
       );

  /// The leading tip where the arrowhead is placed and where escape starts.
  GridPosition get headCell => path.last;

  /// The tail (starting point of the line).
  GridPosition get tailCell => path.first;

  /// All grid points occupied by the arrow path.
  List<GridPosition> get cells => path;

  /// Direction at the arrowhead tip.
  ArrowDirection get direction => exitDirection;

  int get length => path.length;

  bool occupies(GridPosition pos) => path.contains(pos);

  Arrow copyWith({
    String? id,
    List<GridPosition>? path,
    ArrowDirection? exitDirection,
    int? colorIndex,
  }) {
    return Arrow(
      id: id ?? this.id,
      path: path ?? List.unmodifiable(this.path),
      exitDirection: exitDirection ?? this.exitDirection,
      colorIndex: colorIndex ?? this.colorIndex,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'path': path.map((c) => c.toJson()).toList(),
    'exitDirection': exitDirection.name,
    'colorIndex': colorIndex,
  };

  factory Arrow.fromJson(Map<String, dynamic> json) {
    final rawPath = json['path'] ?? json['cells'];
    final pathList = (rawPath as List)
        .map((c) => GridPosition.fromJson(c as Map<String, dynamic>))
        .toList();
    final dirName = json['exitDirection'] ?? json['direction'];
    final dir = ArrowDirection.values.firstWhere(
      (d) => d.name == dirName,
      orElse: () => ArrowDirection.up,
    );
    return Arrow(
      id: json['id'] as String,
      path: pathList,
      exitDirection: dir,
      colorIndex: (json['colorIndex'] as int?) ?? 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Arrow && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Arrow($id, dir: ${exitDirection.name}, path: $path)';
}
