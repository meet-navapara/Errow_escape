import '../core/storage/storage_service.dart';
import 'weekly_challenge_service.dart';

class Achievement {
  final String id;
  final String title;
  final String description;

  /// Current progress toward [goal], read from stored state.
  final int Function(StorageService storage) progress;
  final int goal;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.progress,
    this.goal = 1,
  });
}

/// Facts about a just-finished puzzle that stored state can't reconstruct.
class PlayEvent {
  final bool flawless;
  final bool usedPowerUp;

  const PlayEvent({this.flawless = false, this.usedPowerUp = false});
}

class AchievementService {
  static const String flawlessId = 'flawless_level';
  static const String powerUpId = 'first_power_up';

  static int _weeklyFullWeeks(StorageService s) => s
      .getWeeklyResults()
      .values
      .where((w) => w.length >= WeeklyChallengeService.puzzlesPerWeek)
      .length;

  static int _flag(StorageService s, String id) =>
      s.getUnlockedAchievements().contains(id) ? 1 : 0;

  static final List<Achievement> all = [
    Achievement(
      id: 'first_level',
      title: 'First Escape',
      description: 'Complete your first level.',
      progress: (s) => s.getCompletedLevels().length,
    ),
    Achievement(
      id: 'ten_levels',
      title: 'Getting the Hang of It',
      description: 'Complete 10 levels.',
      progress: (s) => s.getCompletedLevels().length,
      goal: 10,
    ),
    Achievement(
      id: 'fifty_levels',
      title: 'Path Finder',
      description: 'Complete 50 levels.',
      progress: (s) => s.getCompletedLevels().length,
      goal: 50,
    ),
    // Id kept from v1 (when the game had 100 levels) so it stays unlocked.
    Achievement(
      id: 'all_levels',
      title: 'Century',
      description: 'Complete 100 levels.',
      progress: (s) => s.getCompletedLevels().length,
      goal: 100,
    ),
    Achievement(
      id: 'levels_250',
      title: 'Seasoned Solver',
      description: 'Complete 250 levels.',
      progress: (s) => s.getCompletedLevels().length,
      goal: 250,
    ),
    Achievement(
      id: 'levels_500',
      title: 'Halfway Hero',
      description: 'Complete 500 levels.',
      progress: (s) => s.getCompletedLevels().length,
      goal: 500,
    ),
    Achievement(
      id: 'levels_1000',
      title: 'Grand Escape',
      description: 'Complete all 1000 levels.',
      progress: (s) => s.getCompletedLevels().length,
      goal: 1000,
    ),
    Achievement(
      id: flawlessId,
      title: 'Flawless',
      description: 'Complete a level without losing a heart.',
      progress: (s) => _flag(s, flawlessId),
    ),
    Achievement(
      id: 'daily_first',
      title: 'Daily Player',
      description: 'Complete a daily challenge.',
      progress: (s) => s.getDailyCompletedDates().length,
    ),
    Achievement(
      id: 'daily_streak_3',
      title: 'On a Roll',
      description: 'Complete daily challenges 3 days in a row.',
      progress: (s) => s.getBestDailyStreak(),
      goal: 3,
    ),
    Achievement(
      id: 'daily_streak_7',
      title: 'Week Warrior',
      description: 'Complete daily challenges 7 days in a row.',
      progress: (s) => s.getBestDailyStreak(),
      goal: 7,
    ),
    Achievement(
      id: 'weekly_complete',
      title: 'Weekly Champion',
      description: 'Finish all 5 puzzles of a weekly challenge.',
      progress: _weeklyFullWeeks,
    ),
    Achievement(
      id: powerUpId,
      title: 'Tool Time',
      description: 'Use a power-up for the first time.',
      progress: (s) => _flag(s, powerUpId),
    ),
  ];

  /// Unlocks every achievement whose goal is now met and returns only the
  /// newly unlocked ones (each achievement unlocks once).
  static Future<List<Achievement>> evaluate(
    StorageService storage, [
    PlayEvent event = const PlayEvent(),
  ]) async {
    final unlocked = <Achievement>[];
    for (final a in all) {
      final earned = switch (a.id) {
        flawlessId => event.flawless,
        powerUpId => event.usedPowerUp,
        _ => a.progress(storage) >= a.goal,
      };
      if (earned && await storage.unlockAchievement(a.id)) unlocked.add(a);
    }
    return unlocked;
  }
}
