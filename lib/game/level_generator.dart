import 'dart:math' as math;

import '../models/arrow_model.dart';
import '../models/board_model.dart';
import '../models/level_model.dart';
import 'difficulty.dart';
import 'puzzle_solver.dart';

/// Silhouettes that give levels visibly different outlines.
enum BoardShape {
  rectangle,
  tall,
  wide,
  heart,
  diamond,
  circle,
  ring,
  cross,
  hourglass,
  stairs,
}

/// Everything needed to generate one puzzle. Dimensions are lattice points,
/// independent of screen pixels; the renderer derives its size from them.
class LevelSpec {
  final int rows;
  final int cols;
  final BoardShape shape;
  final int minPathLength;
  final int maxPathLength;
  final double turnChance;

  /// Minimum dependency depth (see [PuzzleAnalysis.depth]).
  final int minDepth;

  /// Number of hill-climbing passes used to deepen dependency chains.
  final int hardeningSteps;

  const LevelSpec({
    required this.rows,
    required this.cols,
    required this.shape,
    required this.minPathLength,
    required this.maxPathLength,
    required this.turnChance,
    required this.minDepth,
    required this.hardeningSteps,
  });
}

class LevelGenerator {
  static const int _maxCols = 16;
  static const int _maxRows = 20;

  /// Generates a validated solvable level for a given level number.
  /// Generation is deterministic: the same level number always yields the
  /// same board, so levels behave like a fixed, curated set.
  static Level generateLevel(int levelNumber) {
    if (levelNumber == 1) return _createTutorialLevel1();
    if (levelNumber == 2) return _createTutorialLevel2();
    if (levelNumber == 3) return _createTutorialLevel3();

    final seed = levelNumber * 7919 + 104729;
    final board = levelNumber <= legacyLevelCount
        ? generateBoard(specForLevel(levelNumber), seed: seed)
        : _generateTargetedBoard(levelNumber, seed);

    return Level(
      id: levelNumber,
      title: 'Level $levelNumber',
      board: board,
      tier: LevelTier.fromLevelNumber(levelNumber),
      targetMoves: board.arrows.length,
    );
  }

  /// Levels 1-100 shipped first; they are generated exactly as before so
  /// existing players see the same puzzles (test/fixtures/first_100_levels.fnv).
  static const int legacyLevelCount = 100;

  /// Every 10th level from 105 on is a deliberately easier "breather".
  static bool isBreather(int level) =>
      level > legacyLevelCount && level % 10 == 5;

  static const _bandRanges = <Difficulty, (int, int)>{
    Difficulty.normal: (101, 150),
    Difficulty.intermediate: (151, 300),
    Difficulty.hard: (301, 500),
    Difficulty.veryHard: (501, 700),
    Difficulty.expert: (701, 900),
    Difficulty.master: (901, 1000),
  };

  /// Band a level > 100 is generated for: the planned band, one lower for
  /// breathers.
  static Difficulty targetBandFor(int level) {
    final planned = Difficulty.plannedFor(level);
    return isBreather(level) ? Difficulty.values[planned.index - 1] : planned;
  }

  /// Solver-score window for a level > 100. Within each band the target
  /// rises steadily from the band's floor to its ceiling across the band's
  /// level range, so difficulty grows gradually without jumps.
  static (double, double) targetScoreFor(int level) {
    final planned = Difficulty.plannedFor(level);
    final (start, end) = _bandRanges[planned]!;
    final frac = ((level - start) / (end - start)).clamp(0.0, 1.0);
    final band = targetBandFor(level);
    final lo = band.minScore;
    final hi = band.maxScore.isFinite ? band.maxScore : 62.0;
    final center = lo + 0.75 + frac * (hi - lo - 1.5);
    return ((center - 1.5).clamp(lo, hi), (center + 1.5).clamp(lo, hi - 0.01));
  }

  /// Shapes whose masks keep enough cells to reach any target.
  static const _denseShapes = [
    BoardShape.rectangle,
    BoardShape.tall,
    BoardShape.circle,
    BoardShape.stairs,
    BoardShape.wide,
  ];

  /// Board parameters for a target score: larger boards, shorter paths
  /// (more arrows) and more bends as the target rises. Capped at 16x20 so
  /// boards stay usable on phones (with pinch-to-zoom).
  static LevelSpec _targetedSpec(
    int level,
    double target, {
    bool dense = false,
    bool fallback = false,
    double grow = 0,
  }) {
    final q = ((target - 20) / 40 + grow).clamp(0.0, 1.0);
    var shape = shapeForLevel(level);
    if (target >= Difficulty.hard.minScore && !_denseShapes.contains(shape)) {
      shape = _denseShapes[level % _denseShapes.length];
    }
    // Escalation steps use fully filled boards.
    if (dense) shape = level.isEven ? BoardShape.rectangle : BoardShape.tall;
    if (fallback) shape = BoardShape.tall;

    var cols = 11 + (5 * q).round();
    var rows = 13 + (7 * q).round();
    switch (shape) {
      case BoardShape.tall:
        rows += 2;
        cols -= 1;
      case BoardShape.wide:
        cols += 2;
        rows = cols - 3;
      case BoardShape.rectangle:
      case BoardShape.stairs:
        break;
      case BoardShape.heart:
      case BoardShape.diamond:
      case BoardShape.circle:
      case BoardShape.ring:
      case BoardShape.cross:
      case BoardShape.hourglass:
        cols += 2;
        rows = cols;
    }
    if (fallback) {
      cols = _maxCols;
      rows = _maxRows;
    }
    return LevelSpec(
      rows: rows.clamp(8, _maxRows),
      cols: cols.clamp(8, _maxCols),
      shape: shape,
      minPathLength: 2,
      maxPathLength: fallback ? 3 : (7 - 3 * q).round(),
      turnChance: 0.35 + 0.25 * q,
      minDepth: 2,
      hardeningSteps: 0,
    );
  }

  static double _scoreOf(Board board) =>
      Difficulty.score(PuzzleSolver.analyze(board));

  /// Generates a solvable board whose solver score falls in the level's
  /// target window: fill + repair as usual, then harden in small steps until
  /// the score reaches the window. Tries several seeds and keeps the closest.
  static Board _generateTargetedBoard(int level, int seed) {
    final (lo, hi) = targetScoreFor(level);
    final random = math.Random(seed);
    Board? best;
    var bestDistance = double.infinity;

    void consider(LevelSpec spec, int maxSteps) {
      final mask = buildMask(spec.shape, spec.rows, spec.cols);
      final grid = _PathGrid(spec.rows, spec.cols, random)
        ..fill(mask, spec)
        ..repair();
      var board = grid.toBoard();
      var score = _scoreOf(board);
      for (var steps = 0; score < lo && steps < maxSteps; steps += 60) {
        grid.harden(60);
        board = grid.toBoard();
        score = _scoreOf(board);
      }
      final distance = score < lo
          ? lo - score
          : (score > hi ? score - hi : 0.0);
      if (distance < bestDistance && board.arrows.length >= 2) {
        best = board;
        bestDistance = distance;
      }
    }

    final target = (lo + hi) / 2;
    for (var attempt = 0; attempt < 6 && bestDistance > 0; attempt++) {
      consider(_targetedSpec(level, target), 3000);
    }
    // Sparse silhouettes sometimes can't get hard enough: escalate gently
    // (dense shape, then slightly larger boards) rather than jumping to the
    // largest board, which can overshoot the window before any hardening.
    for (final grow in const [0.0, 0.08, 0.16, 0.25, 0.35, 0.5]) {
      for (var attempt = 0; attempt < 2 && bestDistance > 0; attempt++) {
        consider(_targetedSpec(level, target, dense: true, grow: grow), 3000);
      }
    }
    for (var attempt = 0; attempt < 2 && bestDistance > 0; attempt++) {
      consider(_targetedSpec(level, target, fallback: true), 5000);
    }
    return best ?? _createMinimalSolvableBoard(10, 10);
  }

  /// Difficulty curve: boards grow, paths lengthen and required dependency
  /// depth increases across the 100 levels.
  static LevelSpec specForLevel(int levelNumber) {
    final tier = LevelTier.fromLevelNumber(levelNumber);
    final progress = ((levelNumber - 4) / 96).clamp(0.0, 1.0);
    final base = (6 + 11 * math.pow(progress, 0.7)).round();
    final shape = shapeForLevel(levelNumber);

    int rows;
    int cols;
    switch (shape) {
      case BoardShape.rectangle:
        rows = base;
        cols = base;
      case BoardShape.tall:
        rows = base + 3;
        cols = math.max(5, base - 1);
      case BoardShape.wide:
        rows = math.max(5, base - 2);
        cols = base + 1;
      case BoardShape.heart:
        rows = base + 5;
        cols = base + 6;
      case BoardShape.diamond:
        rows = base + 3;
        cols = base + 3;
      case BoardShape.circle:
      case BoardShape.cross:
      case BoardShape.hourglass:
        rows = base + 2;
        cols = base + 2;
      case BoardShape.ring:
        rows = base + 4;
        cols = base + 4;
      case BoardShape.stairs:
        rows = base + 1;
        cols = base + 1;
    }
    cols = math.min(cols, _maxCols);
    rows = math.min(rows, _maxRows);
    // Silhouettes must keep their proportions when the column cap applies.
    const proportional = {
      BoardShape.heart,
      BoardShape.diamond,
      BoardShape.circle,
      BoardShape.ring,
      BoardShape.cross,
      BoardShape.hourglass,
    };
    if (proportional.contains(shape)) rows = math.min(rows, cols);

    final (minLen, maxLen, minDepth) = switch (tier) {
      LevelTier.tutorial || LevelTier.beginner => (3, 5, 2),
      LevelTier.easy => (3, 6, 3),
      LevelTier.medium => (3, 7, 4),
      LevelTier.hard => (3, 8, 5),
      LevelTier.expert || LevelTier.daily => (3, 9, 6),
    };

    return LevelSpec(
      rows: rows,
      cols: cols,
      shape: shape,
      minPathLength: minLen,
      maxPathLength: maxLen,
      turnChance: 0.25 + 0.2 * progress,
      minDepth: minDepth,
      hardeningSteps: (progress * 160).round(),
    );
  }

  static BoardShape shapeForLevel(int levelNumber) {
    const early = {
      4: BoardShape.rectangle,
      5: BoardShape.tall,
      6: BoardShape.heart,
      7: BoardShape.diamond,
      8: BoardShape.circle,
      9: BoardShape.wide,
      10: BoardShape.cross,
    };
    const cycle = [
      BoardShape.rectangle,
      BoardShape.heart,
      BoardShape.tall,
      BoardShape.diamond,
      BoardShape.circle,
      BoardShape.wide,
      BoardShape.cross,
      BoardShape.ring,
      BoardShape.hourglass,
      BoardShape.stairs,
    ];
    return early[levelNumber] ?? cycle[levelNumber % cycle.length];
  }

  /// Generates a dense, solver-validated board for [spec].
  ///
  /// 1. Cut the shape mask into a set of lattice points.
  /// 2. Cover it with snake-like paths (heads point along their last segment).
  /// 3. Repair circular blockages by reversing, splitting or, as a last
  ///    resort, removing arrows until the solver can clear the board.
  /// 4. Hill-climb with reversals to deepen dependency chains.
  /// Several seeds are tried and the board closest to the target is kept.
  static Board generateBoard(LevelSpec spec, {required int seed}) {
    final mask = buildMask(spec.shape, spec.rows, spec.cols);
    final random = math.Random(seed);

    _Candidate? best;
    for (var attempt = 0; attempt < 4; attempt++) {
      final grid = _PathGrid(spec.rows, spec.cols, random);
      grid.fill(mask, spec);
      grid.repair();
      grid.harden(spec.hardeningSteps);

      final board = grid.toBoard();
      final analysis = PuzzleSolver.analyze(board);
      if (!analysis.isSolvable || board.arrows.isEmpty) continue;

      final coverage = grid.occupiedCount / mask.length;
      final candidate = _Candidate(board, analysis, coverage);
      if (best == null || candidate.score(spec) > best.score(spec)) {
        best = candidate;
      }
      if (analysis.depth >= spec.minDepth && coverage >= 0.9) break;
    }

    // Repair always ends solvable, so this is a defensive fallback only.
    return best?.board ?? _createMinimalSolvableBoard(spec.rows, spec.cols);
  }

  /// Lattice points belonging to [shape] inside a rows x cols box.
  static Set<GridPosition> buildMask(BoardShape shape, int rows, int cols) {
    final cells = <GridPosition>{};
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        // Normalised coordinates in (-1, 1), y grows downwards.
        final x = (c + 0.5) / cols * 2 - 1;
        final y = (r + 0.5) / rows * 2 - 1;
        if (_inShape(shape, x, y, r, c, rows, cols)) {
          cells.add(GridPosition(r, c));
        }
      }
    }
    // Drop isolated points; they could never form a path.
    cells.removeWhere(
      (p) => !ArrowDirection.values.any((d) => cells.contains(p.step(d))),
    );
    return cells;
  }

  static bool _inShape(
    BoardShape shape,
    double x,
    double y,
    int r,
    int c,
    int rows,
    int cols,
  ) {
    switch (shape) {
      case BoardShape.rectangle:
      case BoardShape.tall:
      case BoardShape.wide:
        return true;
      case BoardShape.heart:
        // Two round lobes on top of a body tapering to a point at the bottom.
        final lobeY = y + 0.42;
        final inLobe =
            (x - 0.48) * (x - 0.48) + lobeY * lobeY <= 0.27 ||
            (x + 0.48) * (x + 0.48) + lobeY * lobeY <= 0.27;
        final inBody = lobeY >= 0 && x.abs() <= 1.0 - lobeY / 1.42;
        return inLobe || inBody;
      case BoardShape.diamond:
        return x.abs() + y.abs() <= 1.05;
      case BoardShape.circle:
        return x * x + y * y <= 1.05;
      case BoardShape.ring:
        final d = x * x + y * y;
        return d <= 1.05 && d >= 0.18;
      case BoardShape.cross:
        return x.abs() <= 0.4 || y.abs() <= 0.4;
      case BoardShape.hourglass:
        return x.abs() <= y.abs() + 0.25;
      case BoardShape.stairs:
        const steps = 4;
        final band = (r * steps) ~/ rows;
        return c < ((band + 2) * cols) ~/ (steps + 1);
    }
  }

  static Board _createMinimalSolvableBoard(int rows, int cols) {
    final arrows = <Arrow>[
      const Arrow(
        id: 'min_1',
        path: [GridPosition(1, 0), GridPosition(0, 0)],
        exitDirection: ArrowDirection.up,
      ),
      Arrow(
        id: 'min_2',
        path: [
          GridPosition(rows - 2, cols - 1),
          GridPosition(rows - 1, cols - 1),
        ],
        exitDirection: ArrowDirection.down,
      ),
    ];
    return Board(rows: rows, cols: cols, arrows: arrows);
  }

  /// Tutorial Level 1: three bent arrows, all free to escape.
  static Level _createTutorialLevel1() {
    final arrows = [
      const Arrow(
        id: 't1_1',
        path: [GridPosition(3, 1), GridPosition(2, 1), GridPosition(1, 1)],
        exitDirection: ArrowDirection.up,
      ),
      const Arrow(
        id: 't1_2',
        path: [GridPosition(1, 3), GridPosition(2, 3), GridPosition(3, 3)],
        exitDirection: ArrowDirection.down,
      ),
      const Arrow(
        id: 't1_3',
        path: [GridPosition(4, 2), GridPosition(4, 1), GridPosition(4, 0)],
        exitDirection: ArrowDirection.left,
      ),
    ];

    return Level(
      id: 1,
      title: 'Level 1',
      board: Board(rows: 5, cols: 5, arrows: arrows),
      tier: LevelTier.tutorial,
      targetMoves: 3,
      tutorialMessage: 'Tap any arrow to make it escape the board in the direction it points!',
    );
  }

  /// Tutorial Level 2: a bent arrow is blocked until its blocker leaves.
  static Level _createTutorialLevel2() {
    final arrows = [
      const Arrow(
        id: 't2_bent_blocked',
        path: [GridPosition(3, 1), GridPosition(2, 1), GridPosition(2, 2)],
        exitDirection: ArrowDirection.right,
      ),
      const Arrow(
        id: 't2_blocker',
        path: [GridPosition(1, 3), GridPosition(2, 3), GridPosition(3, 3)],
        exitDirection: ArrowDirection.down,
      ),
      const Arrow(
        id: 't2_3',
        path: [GridPosition(0, 2), GridPosition(0, 1), GridPosition(0, 0)],
        exitDirection: ArrowDirection.left,
      ),
      const Arrow(
        id: 't2_4',
        path: [GridPosition(4, 1), GridPosition(4, 2)],
        exitDirection: ArrowDirection.right,
      ),
    ];

    return Level(
      id: 2,
      title: 'Level 2',
      board: Board(rows: 5, cols: 5, arrows: arrows),
      tier: LevelTier.tutorial,
      targetMoves: 4,
      tutorialMessage: 'Arrows cannot escape if blocked! Tap the blocking arrow first to clear the way.',
    );
  }

  /// Tutorial Level 3: a three-step chain and the 3-heart system.
  static Level _createTutorialLevel3() {
    final arrows = [
      // Blocked by t3_middle, which is blocked by t3_free.
      const Arrow(
        id: 't3_bent',
        path: [
          GridPosition(4, 1),
          GridPosition(3, 1),
          GridPosition(2, 1),
          GridPosition(2, 2),
        ],
        exitDirection: ArrowDirection.right,
      ),
      const Arrow(
        id: 't3_middle',
        path: [GridPosition(0, 3), GridPosition(1, 3), GridPosition(2, 3)],
        exitDirection: ArrowDirection.down,
      ),
      const Arrow(
        id: 't3_free',
        path: [GridPosition(4, 2), GridPosition(4, 3), GridPosition(4, 4)],
        exitDirection: ArrowDirection.right,
      ),
      const Arrow(
        id: 't3_4',
        path: [GridPosition(0, 1), GridPosition(0, 0)],
        exitDirection: ArrowDirection.left,
      ),
    ];

    return Level(
      id: 3,
      title: 'Level 3',
      board: Board(rows: 5, cols: 5, arrows: arrows),
      tier: LevelTier.tutorial,
      targetMoves: 4,
      tutorialMessage: 'Careful! Tapping a blocked arrow costs 1 heart ❤️. Clear blockers first!',
    );
  }
}

class _Candidate {
  final Board board;
  final PuzzleAnalysis analysis;
  final double coverage;

  _Candidate(this.board, this.analysis, this.coverage);

  double score(LevelSpec spec) {
    final depthScore = math.min(analysis.depth, spec.minDepth + 4).toDouble();
    return depthScore + coverage * 10;
  }
}

/// Result of evaluating the blocking graph of a [_PathGrid].
class _Eval {
  final List<int> stuck;
  final int depth;
  const _Eval(this.stuck, this.depth);
}

/// Mutable working state for generation: oriented paths (last point is the
/// head) plus a cell -> path index lookup.
class _PathGrid {
  final int rows;
  final int cols;
  final math.Random random;
  final List<List<GridPosition>?> paths = [];
  late final List<int> _owner = List.filled(rows * cols, -1);

  _PathGrid(this.rows, this.cols, this.random);

  int get occupiedCount => _owner.where((o) => o >= 0).length;

  int _index(GridPosition p) => p.row * cols + p.col;

  bool _inBounds(GridPosition p) =>
      p.row >= 0 && p.row < rows && p.col >= 0 && p.col < cols;

  int _ownerAt(GridPosition p) => _inBounds(p) ? _owner[_index(p)] : -1;

  static ArrowDirection _dirBetween(GridPosition from, GridPosition to) {
    if (to.row < from.row) return ArrowDirection.up;
    if (to.row > from.row) return ArrowDirection.down;
    if (to.col < from.col) return ArrowDirection.left;
    return ArrowDirection.right;
  }

  ArrowDirection _headDir(List<GridPosition> path) =>
      _dirBetween(path[path.length - 2], path.last);

  void _setOwner(List<GridPosition> path, int owner) {
    for (final p in path) {
      _owner[_index(p)] = owner;
    }
  }

  /// True when the head's escape ray crosses the arrow's own body, which
  /// would look like an arrow pointing into itself.
  bool _pointsIntoItself(List<GridPosition> path) {
    final dir = _headDir(path);
    final body = path.toSet();
    var cell = path.last.step(dir);
    while (_inBounds(cell)) {
      if (body.contains(cell)) return true;
      cell = cell.step(dir);
    }
    return false;
  }

  /// Picks a head end at random, avoiding self-pointing heads when possible.
  List<GridPosition>? _orient(List<GridPosition> path) {
    final options = [path, path.reversed.toList()];
    if (random.nextBool()) options.insert(0, options.removeLast());
    for (final o in options) {
      if (!_pointsIntoItself(o)) return o;
    }
    return null;
  }

  // ---------------------------------------------------------------- filling

  void fill(Set<GridPosition> mask, LevelSpec spec) {
    final free = <GridPosition>{...mask};
    final raw = <List<GridPosition>>[];

    int freeDegree(GridPosition p) =>
        ArrowDirection.values.where((d) => free.contains(p.step(d))).length;

    while (free.isNotEmpty) {
      // Start from the most constrained point so corners don't get orphaned.
      GridPosition start = free.first;
      var bestDegree = 5;
      var ties = 0;
      for (final p in free) {
        final d = freeDegree(p);
        if (d < bestDegree) {
          bestDegree = d;
          start = p;
          ties = 1;
        } else if (d == bestDegree && random.nextInt(++ties) == 0) {
          start = p;
        }
      }

      final target =
          spec.minPathLength +
          random.nextInt(spec.maxPathLength - spec.minPathLength + 1);
      final path = [start];
      free.remove(start);
      ArrowDirection? dir;

      while (path.length < target) {
        final options = ArrowDirection.values
            .where((d) => free.contains(path.last.step(d)))
            .toList();
        if (options.isEmpty) break;

        ArrowDirection next;
        if (dir != null &&
            options.contains(dir) &&
            random.nextDouble() >= spec.turnChance) {
          next = dir;
        } else {
          final turns = options.where((d) => d != dir).toList();
          final pool = turns.isNotEmpty ? turns : options;
          next = pool[random.nextInt(pool.length)];
        }
        dir = next;
        final cell = path.last.step(next);
        path.add(cell);
        free.remove(cell);
      }
      raw.add(path);
    }

    for (final p in raw) {
      if (p.length >= 2) _addPath(p);
    }
    for (final p in raw) {
      if (p.length == 1) _absorbSingleton(p.first, spec.maxPathLength + 2);
    }
  }

  void _addPath(List<GridPosition> path) {
    final oriented = _orient(path);
    if (oriented == null) {
      // Both ends point into the body (a tight spiral); split it instead.
      if (path.length >= 4) {
        final mid = path.length ~/ 2;
        _addPath(path.sublist(0, mid));
        _addPath(path.sublist(mid));
      }
      return;
    }
    paths.add(oriented);
    _setOwner(oriented, paths.length - 1);
  }

  /// Attaches a leftover single point to a neighbouring path so the board
  /// stays dense without single-point "arrows".
  void _absorbSingleton(GridPosition cell, int maxLength) {
    for (final d in ArrowDirection.values) {
      final owner = _ownerAt(cell.step(d));
      if (owner < 0) continue;
      final path = paths[owner]!;
      final neighbour = cell.step(d);

      List<GridPosition>? extended;
      List<GridPosition>? remainder;
      if (path.length < maxLength && path.first == neighbour) {
        extended = [cell, ...path];
      } else if (path.length < maxLength && path.last == neighbour) {
        extended = [...path, cell];
      } else {
        final i = path.indexOf(neighbour);
        if (path.length - i - 1 >= 2) {
          extended = [...path.sublist(0, i + 1), cell];
          remainder = path.sublist(i + 1);
        } else if (i >= 2) {
          extended = [cell, ...path.sublist(i)];
          remainder = path.sublist(0, i);
        }
      }
      if (extended == null) continue;

      final oriented = _orient(extended);
      final orientedRest = remainder == null ? null : _orient(remainder);
      if (oriented == null || (remainder != null && orientedRest == null)) {
        continue;
      }
      paths[owner] = oriented;
      _setOwner(oriented, owner);
      if (orientedRest != null) {
        paths.add(orientedRest);
        _setOwner(orientedRest, paths.length - 1);
      }
      return;
    }
  }

  // ------------------------------------------------------------- evaluation

  _Eval evaluate() {
    final waitingOn = List.filled(paths.length, 0);
    final dependents = List.generate(paths.length, (_) => <int>[]);
    final seen = <int>{};

    for (var i = 0; i < paths.length; i++) {
      final path = paths[i];
      if (path == null) continue;
      final dir = _headDir(path);
      seen.clear();
      var cell = path.last.step(dir);
      while (_inBounds(cell)) {
        final o = _owner[_index(cell)];
        if (o >= 0 && o != i && seen.add(o)) {
          dependents[o].add(i);
          waitingOn[i]++;
        }
        cell = cell.step(dir);
      }
    }

    var frontier = [
      for (var i = 0; i < paths.length; i++)
        if (paths[i] != null && waitingOn[i] == 0) i,
    ];
    final cleared = <int>{};
    var depth = 0;
    while (frontier.isNotEmpty) {
      depth++;
      cleared.addAll(frontier);
      final next = <int>[];
      for (final f in frontier) {
        for (final d in dependents[f]) {
          if (--waitingOn[d] == 0) next.add(d);
        }
      }
      frontier = next;
    }

    final stuck = [
      for (var i = 0; i < paths.length; i++)
        if (paths[i] != null && !cleared.contains(i)) i,
    ];
    return _Eval(stuck, depth);
  }

  // ----------------------------------------------------------------- repair

  /// Breaks every blocking cycle. Each pass either strictly reduces the
  /// number of stuck arrows or removes one, so the loop always terminates
  /// with a solvable board.
  void repair() {
    var current = evaluate();
    while (current.stuck.isNotEmpty) {
      final sample = [...current.stuck]..shuffle(random);
      final candidates = sample.take(6).toList();

      _Eval? bestEval;
      void Function()? bestApply;

      for (final i in candidates) {
        final path = paths[i]!;

        final reversed = path.reversed.toList();
        if (!_pointsIntoItself(reversed)) {
          paths[i] = reversed;
          final e = evaluate();
          paths[i] = path;
          if (bestEval == null || e.stuck.length < bestEval.stuck.length) {
            bestEval = e;
            bestApply = () => paths[i] = reversed;
          }
        }

        if (path.length >= 4) {
          final cut = 2 + random.nextInt(path.length - 3);
          final a = _orient(path.sublist(0, cut));
          final b = _orient(path.sublist(cut));
          if (a != null && b != null) {
            final newIndex = paths.length;
            paths[i] = a;
            paths.add(b);
            _setOwner(b, newIndex);
            final e = evaluate();
            paths.removeLast();
            paths[i] = path;
            _setOwner(path, i);
            if (bestEval == null || e.stuck.length < bestEval.stuck.length) {
              bestEval = e;
              bestApply = () {
                paths[i] = a;
                paths.add(b);
                _setOwner(b, paths.length - 1);
              };
            }
          }
        }
      }

      if (bestEval != null && bestEval.stuck.length < current.stuck.length) {
        bestApply!();
      } else {
        final victim = candidates.first;
        _setOwner(paths[victim]!, -1);
        paths[victim] = null;
      }
      current = evaluate();
    }
  }

  // --------------------------------------------------------------- hardening

  /// Randomly reverses arrows, keeping changes that stay solvable and do not
  /// reduce the dependency depth. Raises difficulty without changing shape.
  void harden(int steps) {
    if (steps <= 0) return;
    var depth = evaluate().depth;
    final live = [
      for (var i = 0; i < paths.length; i++)
        if (paths[i] != null) i,
    ];
    if (live.isEmpty) return;

    for (var s = 0; s < steps; s++) {
      final i = live[random.nextInt(live.length)];
      final path = paths[i]!;
      final reversed = path.reversed.toList();
      if (_pointsIntoItself(reversed)) continue;
      paths[i] = reversed;
      final e = evaluate();
      if (e.stuck.isEmpty && e.depth >= depth) {
        depth = e.depth;
      } else {
        paths[i] = path;
      }
    }
  }

  Board toBoard() {
    final arrows = <Arrow>[];
    for (final path in paths) {
      if (path == null) continue;
      arrows.add(
        Arrow(
          id: 'a_${arrows.length + 1}',
          path: List.unmodifiable(path),
          exitDirection: _headDir(path),
        ),
      );
    }
    return Board(rows: rows, cols: cols, arrows: arrows);
  }
}
