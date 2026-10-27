import '../models/arrow_model.dart';
import '../models/board_model.dart';
import 'difficulty.dart';

/// Lightweight per-level metadata, read from a pack line's header without
/// decoding or solving the board (used by level select).
class LevelInfo {
  final int id;
  final int rows;
  final int cols;
  final Difficulty difficulty;
  final double score;
  final int depth;
  final int arrows;
  final int initialMoves;
  final int blockingPairs;

  const LevelInfo({
    required this.id,
    required this.rows,
    required this.cols,
    required this.difficulty,
    required this.score,
    required this.depth,
    required this.arrows,
    required this.initialMoves,
    required this.blockingPairs,
  });
}

/// Versioned text format for precomputed levels (assets/levels/levels_v1.txt).
///
/// One level per line:
///   `id|rows|cols|difficulty|score*10|depth|arrows|initialMoves|pairs|arrows...`
/// Each arrow is `<tail cell index, base 36>:<steps>` where steps are U/D/L/R
/// moves from the tail; the head points along the last step. A single-point
/// arrow adds `!<dir>`. Arrow ids default to `a_<n>` (1-based order) and are
/// written as `@id` only when different. Lines starting with `#` are comments.
///
/// Packs are produced by tool/generate_level_pack_test.dart and validated by
/// test/level_pack_test.dart; bump [version] (and the file name) whenever the
/// generated levels change so old and new data never mix.
class LevelPack {
  static const int version = 1;
  static const String assetPath = 'assets/levels/levels_v$version.txt';

  static const _dirChars = {
    ArrowDirection.up: 'U',
    ArrowDirection.down: 'D',
    ArrowDirection.left: 'L',
    ArrowDirection.right: 'R',
  };
  static final _charDirs = {for (final e in _dirChars.entries) e.value: e.key};

  final Map<int, String> _lines;

  LevelPack._(this._lines);

  /// Indexes the pack text; boards are decoded lazily per level.
  factory LevelPack.parse(String text) {
    final lines = <int, String>{};
    for (final line in text.split('\n')) {
      if (line.isEmpty || line.startsWith('#')) continue;
      final sep = line.indexOf('|');
      lines[int.parse(line.substring(0, sep))] = line.trimRight();
    }
    return LevelPack._(lines);
  }

  int get length => _lines.length;
  Iterable<int> get ids => _lines.keys;
  bool contains(int id) => _lines.containsKey(id);

  LevelInfo? info(int id) {
    final line = _lines[id];
    if (line == null) return null;
    final f = line.split('|');
    return LevelInfo(
      id: int.parse(f[0]),
      rows: int.parse(f[1]),
      cols: int.parse(f[2]),
      difficulty: Difficulty.values.byName(f[3]),
      score: int.parse(f[4]) / 10,
      depth: int.parse(f[5]),
      arrows: int.parse(f[6]),
      initialMoves: int.parse(f[7]),
      blockingPairs: int.parse(f[8]),
    );
  }

  Board? board(int id) {
    final line = _lines[id];
    if (line == null) return null;
    final f = line.split('|');
    final rows = int.parse(f[1]);
    final cols = int.parse(f[2]);
    final data = f.length > 9 ? f[9] : '';
    final arrows = <Arrow>[];
    for (final token in data.split(' ')) {
      if (token.isEmpty) continue;
      arrows.add(_decodeArrow(token, cols, arrows.length + 1));
    }
    return Board(rows: rows, cols: cols, arrows: arrows);
  }

  static Arrow _decodeArrow(String token, int cols, int ordinal) {
    var body = token;
    var id = 'a_$ordinal';
    final at = body.indexOf('@');
    if (at >= 0) {
      id = body.substring(at + 1);
      body = body.substring(0, at);
    }
    ArrowDirection? explicit;
    final bang = body.indexOf('!');
    if (bang >= 0) {
      explicit = _charDirs[body.substring(bang + 1)];
      body = body.substring(0, bang);
    }
    final colon = body.indexOf(':');
    final start = int.parse(body.substring(0, colon), radix: 36);
    var cell = GridPosition(start ~/ cols, start % cols);
    final path = [cell];
    ArrowDirection? last;
    for (final c in body.substring(colon + 1).split('')) {
      if (c.isEmpty) continue;
      last = _charDirs[c]!;
      cell = cell.step(last);
      path.add(cell);
    }
    return Arrow(
      id: id,
      path: List.unmodifiable(path),
      exitDirection: explicit ?? last ?? ArrowDirection.up,
    );
  }

  static String _stepChar(GridPosition a, GridPosition b) {
    for (final d in ArrowDirection.values) {
      if (a.step(d) == b) return _dirChars[d]!;
    }
    throw ArgumentError('Path cells $a and $b are not adjacent');
  }

  /// Serializes one level. [info] values come from the solver.
  static String encode(Board board, LevelInfo info) {
    final tokens = <String>[];
    for (var i = 0; i < board.arrows.length; i++) {
      final a = board.arrows[i];
      final b = StringBuffer(
        (a.path.first.row * board.cols + a.path.first.col).toRadixString(36),
      )..write(':');
      for (var j = 1; j < a.path.length; j++) {
        b.write(_stepChar(a.path[j - 1], a.path[j]));
      }
      final impliedExit =
          a.path.length >= 2 &&
          _stepChar(a.path[a.path.length - 2], a.path.last) ==
              _dirChars[a.exitDirection];
      if (!impliedExit) b.write('!${_dirChars[a.exitDirection]}');
      if (a.id != 'a_${i + 1}') b.write('@${a.id}');
      tokens.add(b.toString());
    }
    return [
      info.id,
      board.rows,
      board.cols,
      info.difficulty.name,
      (info.score * 10).round(),
      info.depth,
      info.arrows,
      info.initialMoves,
      info.blockingPairs,
      tokens.join(' '),
    ].join('|');
  }
}
