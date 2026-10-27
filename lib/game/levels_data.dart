import 'dart:collection';

import '../models/level_model.dart';
import 'difficulty.dart';
import 'level_generator.dart';
import 'level_pack.dart';
import 'puzzle_solver.dart';

class LevelsRepository {
  static const int totalLevels = 1000;

  /// Levels are grouped into chapters for level select.
  static const int chapterSize = 50;
  static int get chapterCount => (totalLevels / chapterSize).ceil();
  static int chapterOf(int level) => (level - 1) ~/ chapterSize;

  static LevelPack? _pack;

  // Small LRU: only recently played levels stay decoded in memory.
  static const int _cacheSize = 24;
  static final LinkedHashMap<int, Level> _cachedLevels = LinkedHashMap();

  /// Installs the precomputed pack (assets/levels/levels_v1.txt). Without it
  /// levels are generated on demand with the same deterministic generator,
  /// which produces identical boards (verified by test/level_pack_test.dart).
  static void usePack(String text) {
    _pack = LevelPack.parse(text);
    _cachedLevels.clear();
  }

  static bool get hasPack => _pack != null;

  static bool isValidLevel(int levelNumber) =>
      levelNumber >= 1 && levelNumber <= totalLevels;

  /// Retrieves a level by its 1-based index (1 to [totalLevels]).
  static Level getLevel(int levelNumber) {
    assert(
      isValidLevel(levelNumber),
      'Level number must be between 1 and $totalLevels',
    );

    final cached = _cachedLevels.remove(levelNumber);
    if (cached != null) {
      _cachedLevels[levelNumber] = cached;
      return cached;
    }

    // Tutorial levels are handcrafted (and carry tutorial text).
    final board = levelNumber > 3 ? _pack?.board(levelNumber) : null;
    final level = board == null
        ? LevelGenerator.generateLevel(levelNumber)
        : Level(
            id: levelNumber,
            title: 'Level $levelNumber',
            board: board,
            tier: LevelTier.fromLevelNumber(levelNumber),
            targetMoves: board.arrows.length,
          );

    _cachedLevels[levelNumber] = level;
    if (_cachedLevels.length > _cacheSize) {
      _cachedLevels.remove(_cachedLevels.keys.first);
    }
    return level;
  }

  /// Size and difficulty of a level without decoding its board (from the
  /// pack header); falls back to generating and analysing it.
  static LevelInfo info(int levelNumber) {
    final fromPack = _pack?.info(levelNumber);
    if (fromPack != null) return fromPack;
    final board = getLevel(levelNumber).board;
    final a = PuzzleSolver.analyze(board);
    return LevelInfo(
      id: levelNumber,
      rows: board.rows,
      cols: board.cols,
      difficulty: Difficulty.fromAnalysis(a),
      score: Difficulty.score(a),
      depth: a.depth,
      arrows: a.arrowCount,
      initialMoves: a.initialMoves,
      blockingPairs: a.blockingPairs,
    );
  }

  /// Warm up a batch of levels (e.g. for smooth level select scrolling).
  static void preloadLevels(int start, int end) {
    for (int i = start; i <= end && i <= totalLevels; i++) {
      getLevel(i);
    }
  }

  /// Clears cache if needed.
  static void clearCache() {
    _cachedLevels.clear();
  }
}
