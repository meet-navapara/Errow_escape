import 'dart:math' as math;

import '../../models/power_up.dart';
import 'storage_service.dart';

/// Versioned, serializable copy of everything that syncs to the cloud.
///
/// Conflict policy ([merge]) — chosen so a merge never loses progress and
/// never duplicates a reward, regardless of which copy is older:
/// - Levels: highest unlocked = max; completed levels = union.
/// - Daily/weekly: completed dates = union; best result per date/puzzle.
/// - Achievements, tutorials seen, reward claim ids: union.
/// - Power-ups: "granted" and "used" are monotonic counters; each takes the
///   max. A starter or daily reward has a claim id, so it is counted once.
///   Limitation: if two offline devices each earn or spend uses before
///   syncing, max() keeps only the larger of the two, so balances can be
///   slightly under-counted, but never inflated.
/// - Settings (sound, haptics): the local device's choice wins.
class ProgressSnapshot {
  static const int schemaVersion = 2;

  final int highestUnlocked;
  final Set<int> completedLevels;
  final bool tutorialCompleted;
  final Set<String> tutorialsSeen;
  final Set<String> dailyCompleted;
  final Map<String, DailyResult> dailyResults;
  final Map<String, Map<int, int>> weeklyResults;
  final Set<String> achievements;
  final Set<String> rewardClaims;
  final Map<PowerUpType, int> granted;
  final Map<PowerUpType, int> used;
  final bool soundEnabled;
  final bool hapticEnabled;

  const ProgressSnapshot({
    required this.highestUnlocked,
    required this.completedLevels,
    required this.tutorialCompleted,
    required this.tutorialsSeen,
    required this.dailyCompleted,
    required this.dailyResults,
    required this.weeklyResults,
    required this.achievements,
    required this.rewardClaims,
    required this.granted,
    required this.used,
    required this.soundEnabled,
    required this.hapticEnabled,
  });

  factory ProgressSnapshot.fromStorage(StorageService s) => ProgressSnapshot(
    highestUnlocked: s.getHighestUnlockedLevel(),
    completedLevels: s.getCompletedLevels(),
    tutorialCompleted: s.isTutorialCompleted(),
    tutorialsSeen: s.getTutorialsSeen(),
    dailyCompleted: s.getDailyCompletedDates(),
    dailyResults: s.getDailyResults(),
    weeklyResults: s.getWeeklyResults(),
    achievements: s.getUnlockedAchievements(),
    rewardClaims: s.getRewardClaims(),
    granted: {for (final t in PowerUpType.values) t: s.getPowerUpGranted(t)},
    used: {for (final t in PowerUpType.values) t: s.getPowerUpUsed(t)},
    soundEnabled: s.isSoundEnabled(),
    hapticEnabled: s.isHapticEnabled(),
  );

  Future<void> applyTo(StorageService s) async {
    if (highestUnlocked > s.getHighestUnlockedLevel()) {
      await s.setHighestUnlockedLevel(highestUnlocked);
    }
    for (final l in completedLevels.difference(s.getCompletedLevels())) {
      await s.markLevelCompleted(l);
    }
    if (tutorialCompleted) await s.setTutorialCompleted(true);
    await s.setTutorialsSeen(tutorialsSeen);
    await s.setDailyCompletedDates(dailyCompleted);
    await s.setDailyResults(dailyResults);
    await s.setWeeklyResults(weeklyResults);
    await s.setUnlockedAchievements(achievements);
    await s.setRewardClaims(rewardClaims);
    for (final t in PowerUpType.values) {
      await s.setPowerUpCounters(t, granted[t] ?? 0, used[t] ?? 0);
    }
  }

  ProgressSnapshot merge(ProgressSnapshot other) {
    Map<PowerUpType, int> maxCounters(
      Map<PowerUpType, int> a,
      Map<PowerUpType, int> b,
    ) => {
      for (final t in PowerUpType.values) t: math.max(a[t] ?? 0, b[t] ?? 0),
    };

    final daily = {...other.dailyResults};
    dailyResults.forEach((k, v) {
      final o = daily[k];
      if (o == null || v.isBetterThan(o)) daily[k] = v;
    });

    final weekly = <String, Map<int, int>>{
      for (final e in other.weeklyResults.entries) e.key: {...e.value},
    };
    weeklyResults.forEach((week, scores) {
      final target = weekly.putIfAbsent(week, () => {});
      scores.forEach((i, s) => target[i] = math.max(target[i] ?? 0, s));
    });

    return ProgressSnapshot(
      highestUnlocked: math.max(highestUnlocked, other.highestUnlocked),
      completedLevels: completedLevels.union(other.completedLevels),
      tutorialCompleted: tutorialCompleted || other.tutorialCompleted,
      tutorialsSeen: tutorialsSeen.union(other.tutorialsSeen),
      dailyCompleted: dailyCompleted.union(other.dailyCompleted),
      dailyResults: daily,
      weeklyResults: weekly,
      achievements: achievements.union(other.achievements),
      rewardClaims: rewardClaims.union(other.rewardClaims),
      granted: maxCounters(granted, other.granted),
      used: maxCounters(used, other.used),
      // `this` is the local copy by convention.
      soundEnabled: soundEnabled,
      hapticEnabled: hapticEnabled,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'schemaVersion': schemaVersion,
    'highestUnlockedLevel': highestUnlocked,
    'completedLevels': (completedLevels.toList()..sort()),
    'tutorialCompleted': tutorialCompleted,
    'tutorialsSeen': tutorialsSeen.toList(),
    'dailyCompleted': dailyCompleted.toList()..sort(),
    'dailyResults': dailyResults.map((k, v) => MapEntry(k, v.toJson())),
    'weeklyResults': weeklyResults.map(
      (w, m) => MapEntry(w, m.map((i, s) => MapEntry(i.toString(), s))),
    ),
    'achievements': achievements.toList(),
    'rewardClaims': rewardClaims.toList(),
    'powerUps': {
      for (final t in PowerUpType.values)
        t.name: {'granted': granted[t] ?? 0, 'used': used[t] ?? 0},
    },
    'settings': {'sound': soundEnabled, 'haptics': hapticEnabled},
  };

  /// Reads schema v2 documents and upgrades v1 documents (which stored a
  /// plain `hintsBalance`).
  factory ProgressSnapshot.fromFirestore(Map<String, dynamic> d) {
    List<T> list<T>(Object? v) => (v as List?)?.cast<T>() ?? <T>[];
    Map<String, dynamic> map(Object? v) =>
        (v as Map?)?.cast<String, dynamic>() ?? {};

    final powerUps = map(d['powerUps']);
    final granted = <PowerUpType, int>{};
    final used = <PowerUpType, int>{};
    for (final t in PowerUpType.values) {
      final p = map(powerUps[t.name]);
      granted[t] = (p['granted'] as num?)?.toInt() ?? 0;
      used[t] = (p['used'] as num?)?.toInt() ?? 0;
    }
    final legacyHints = (d['hintsBalance'] as num?)?.toInt();
    if (powerUps.isEmpty && legacyHints != null) {
      granted[PowerUpType.hint] = legacyHints;
    }
    final settings = map(d['settings']);

    return ProgressSnapshot(
      highestUnlocked: (d['highestUnlockedLevel'] as num?)?.toInt() ?? 1,
      completedLevels: list<num>(d['completedLevels'])
          .map((e) => e.toInt())
          .toSet(),
      tutorialCompleted: d['tutorialCompleted'] as bool? ?? false,
      tutorialsSeen: list<String>(d['tutorialsSeen']).toSet(),
      dailyCompleted: list<String>(d['dailyCompleted']).toSet(),
      dailyResults: map(d['dailyResults'])
          .map((k, v) => MapEntry(k, DailyResult.fromJson(map(v)))),
      weeklyResults: map(d['weeklyResults']).map(
        (w, v) => MapEntry(
          w,
          map(v).map((i, s) => MapEntry(int.parse(i), (s as num).toInt())),
        ),
      ),
      achievements: list<String>(d['achievements']).toSet(),
      rewardClaims: list<String>(d['rewardClaims']).toSet(),
      granted: granted,
      used: used,
      soundEnabled: settings['sound'] as bool? ?? true,
      hapticEnabled: settings['haptics'] as bool? ?? true,
    );
  }
}
