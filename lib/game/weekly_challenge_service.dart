import '../models/level_model.dart';
import 'daily_challenge_service.dart';
import 'level_generator.dart';

/// A local (on-device) weekly challenge: five fixed puzzles per calendar week
/// (Monday 00:00 to next Monday 00:00, device local time). Scores are personal
/// only; there is no online leaderboard.
class WeeklyChallengeService {
  static const int puzzlesPerWeek = 5;

  /// Points per puzzle: 100 per heart left, so a flawless week scores 1500.
  static const int pointsPerHeart = 100;

  static DateTime weekStart([DateTime? now]) {
    final d = now ?? DateTime.now();
    final day = DateTime(d.year, d.month, d.day);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  static DateTime weekEnd([DateTime? now]) => DateTime(
    weekStart(now).year,
    weekStart(now).month,
    weekStart(now).day + 7,
  );

  static String weekKey([DateTime? now]) =>
      'W${DailyChallengeService.getDateKey(weekStart(now))}';

  static Duration timeRemaining([DateTime? now]) =>
      weekEnd(now).difference(now ?? DateTime.now());

  static int scoreFor(int heartsLeft) => heartsLeft * pointsPerHeart;

  static int maxScore() => puzzlesPerWeek * 3 * pointsPerHeart;

  /// Deterministic puzzle [index] for the week containing [now]. Difficulty
  /// ramps from Normal to Expert across the five puzzles.
  static Level getPuzzle(int index, [DateTime? now]) {
    final start = weekStart(now);
    final seed = start.year * 10000 + start.month * 100 + start.day;
    const templateLevels = [22, 38, 54, 70, 86];
    final template = LevelGenerator.specForLevel(
      templateLevels[index] + seed % 7,
    );
    final board = LevelGenerator.generateBoard(
      template,
      seed: seed * 31 + index * 977,
    );
    return Level(
      id: 900000 + index,
      title: 'Weekly ${index + 1}/$puzzlesPerWeek',
      board: board,
      tier: LevelTier.daily,
      targetMoves: board.arrows.length,
    );
  }
}
