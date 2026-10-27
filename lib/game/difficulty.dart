import '../models/board_model.dart';
import 'puzzle_solver.dart';

/// Difficulty badge derived from solver metrics of the actual board rather
/// than the level number.
///
/// Thresholds are calibrated on the generated levels (see
/// docs/level_validation_report.md): the preserved levels 1-100 score about
/// 8 (levels 1-10), 12-19 (11-50) and 23 (51-100); phone-sized 16x20 boards
/// reach about 65 at the top end.
enum Difficulty {
  beginner('Beginner', 0),
  easy('Easy', 10),
  normal('Normal', 20),
  intermediate('Intermediate', 26),
  hard('Hard', 31),
  veryHard('Very Hard', 37),
  expert('Expert', 43),
  master('Master', 50);

  final String label;

  /// Lowest [score] that earns this badge.
  final double minScore;

  const Difficulty(this.label, this.minScore);

  /// Upper bound of this band (exclusive); the top band is open-ended.
  double get maxScore =>
      index == values.length - 1 ? double.infinity : values[index + 1].minScore;

  static final Expando<Difficulty> _cache = Expando('difficulty');

  /// Score = dependency depth (rounds of forced ordering) plus board size
  /// (arrow count / 8) plus how tangled it is (blocking pairs per arrow).
  static double score(PuzzleAnalysis a) {
    if (a.arrowCount == 0) return 0;
    return a.depth + a.arrowCount / 8 + a.blockingPairs / a.arrowCount;
  }

  static Difficulty fromScore(double s) =>
      values.lastWhere((d) => s >= d.minScore);

  static Difficulty fromAnalysis(PuzzleAnalysis a) => fromScore(score(a));

  /// Cached per board instance; boards are immutable.
  static Difficulty of(Board board) =>
      _cache[board] ??= fromAnalysis(PuzzleSolver.analyze(board));

  /// Planned band for a campaign level (the table the generator targets for
  /// levels 101-1000). Levels 1-100 are preserved from the original game, so
  /// their badges come from the solver and may differ from this plan.
  static Difficulty plannedFor(int level) {
    if (level <= 10) return beginner;
    if (level <= 50) return easy;
    if (level <= 150) return normal;
    if (level <= 300) return intermediate;
    if (level <= 500) return hard;
    if (level <= 700) return veryHard;
    if (level <= 900) return expert;
    return master;
  }
}
