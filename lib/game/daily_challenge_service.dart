import '../models/level_model.dart';
import 'level_generator.dart';

class DailyChallengeService {
  /// Returns a formatted date key like "2026-10-24".
  static String getDateKey([DateTime? date]) {
    final d = date ?? DateTime.now();
    final year = d.year.toString().padLeft(4, '0');
    final month = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  /// Generates a validated solvable Daily Challenge level for the specified date.
  /// The date seeds both the silhouette and the layout, so everyone gets the
  /// same puzzle on the same day.
  static Level getDailyChallenge([DateTime? date]) {
    final d = date ?? DateTime.now();
    final seed = d.year * 10000 + d.month * 100 + d.day;

    // Medium-sized board borrowing the shape rotation of the main levels.
    final template = LevelGenerator.specForLevel(40 + seed % 10);
    final spec = LevelSpec(
      rows: template.rows,
      cols: template.cols,
      shape: template.shape,
      minPathLength: 2,
      maxPathLength: 7,
      turnChance: 0.35,
      minDepth: 4,
      hardeningSteps: 60,
    );
    final board = LevelGenerator.generateBoard(spec, seed: seed);

    final monthNames = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final displayDate = '${monthNames[d.month]} ${d.day}, ${d.year}';

    return Level(
      id: 999999,
      title: 'Daily: $displayDate',
      board: board,
      tier: LevelTier.daily,
      targetMoves: board.arrows.length,
      tutorialMessage: 'Solve today\'s daily puzzle to maintain your streak!',
    );
  }
}
