import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../game/levels_data.dart';
import '../../models/power_up.dart';

/// Best result recorded for one daily challenge date.
class DailyResult {
  final int hearts;
  final int moves;

  const DailyResult({required this.hearts, required this.moves});

  /// More hearts wins; ties go to fewer moves.
  bool isBetterThan(DailyResult other) =>
      hearts > other.hearts || (hearts == other.hearts && moves < other.moves);

  Map<String, dynamic> toJson() => {'hearts': hearts, 'moves': moves};

  factory DailyResult.fromJson(Map<String, dynamic> json) => DailyResult(
    hearts: (json['hearts'] as num?)?.toInt() ?? 0,
    moves: (json['moves'] as num?)?.toInt() ?? 0,
  );
}

class StorageService {
  static const String _keyHighestUnlocked = 'highest_unlocked_level';
  static const String _keyCompletedLevels = 'completed_levels_list';
  static const String _keySoundEnabled = 'sound_enabled';
  static const String _keyHapticEnabled = 'haptic_enabled';
  static const String _keyHintCount = 'hint_count';
  static const String _keyTutorialCompleted = 'tutorial_completed';
  static const String _keyDailyCompletedDates = 'daily_completed_dates';
  static const String _keyFirstLaunchCompleted = 'first_launch_completed';
  static const String _keyGuestId = 'guest_id';
  static const String _keyCurrentLevel = 'current_level';
  static const String _keyTutorialsSeen = 'tutorials_seen';
  static const String _keyDailyResults = 'daily_results';
  static const String _keyWeeklyResults = 'weekly_results';
  static const String _keyAchievements = 'achievements_unlocked';
  static const String _keyRewardClaims = 'reward_claims';
  static const String _keyLastPlayedAt = 'last_played_at';
  static const String _keyLevelCapMigration = 'migrated_level_cap_1000';
  static String _keyGranted(PowerUpType t) => 'powerup_${t.name}_granted';
  static String _keyUsed(PowerUpType t) => 'powerup_${t.name}_used';

  final SharedPreferences? _prefs;

  // In-memory fallback if SharedPreferences is null (for headless unit tests)
  final Map<String, dynamic> _memoryCache = {};

  /// Called after any change worth syncing to the cloud (progress, rewards,
  /// achievements). Settings-only changes are included so they roam too.
  void Function()? onProgressChanged;

  StorageService([this._prefs]) {
    _migrateLegacyHints();
    _migrateLevelCap();
  }

  static Future<StorageService> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return StorageService(prefs);
    } catch (_) {
      // In tests or environments where SharedPreferences isn't mocked yet, fallback gracefully
      return StorageService(null);
    }
  }

  // --- Typed primitives ---
  int? _getInt(String k) =>
      _prefs != null ? _prefs.getInt(k) : _memoryCache[k] as int?;
  bool? _getBool(String k) =>
      _prefs != null ? _prefs.getBool(k) : _memoryCache[k] as bool?;
  String? _getString(String k) =>
      _prefs != null ? _prefs.getString(k) : _memoryCache[k] as String?;
  List<String>? _getList(String k) => _prefs != null
      ? _prefs.getStringList(k)
      : (_memoryCache[k] as List?)?.cast<String>();

  Future<void> _setInt(String k, int v) async =>
      _prefs != null ? await _prefs.setInt(k, v) : _memoryCache[k] = v;
  Future<void> _setBool(String k, bool v) async =>
      _prefs != null ? await _prefs.setBool(k, v) : _memoryCache[k] = v;
  Future<void> _setString(String k, String v) async =>
      _prefs != null ? await _prefs.setString(k, v) : _memoryCache[k] = v;
  Future<void> _setList(String k, List<String> v) async =>
      _prefs != null ? await _prefs.setStringList(k, v) : _memoryCache[k] = v;

  Map<String, dynamic> _getJson(String k) {
    final raw = _getString(k);
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as Map).cast<String, dynamic>();
    } catch (_) {
      return {};
    }
  }

  Future<void> _setJson(String k, Map<String, dynamic> v) =>
      _setString(k, jsonEncode(v));

  void _changed() => onProgressChanged?.call();

  // --- Highest Unlocked Level ---
  int getHighestUnlockedLevel() => _getInt(_keyHighestUnlocked) ?? 1;

  Future<void> setHighestUnlockedLevel(int level) async {
    await _setInt(_keyHighestUnlocked, level);
    _changed();
  }

  /// Next level for "Continue Game". Independent of unlocks so "Restart Game"
  /// can send the player back to level 1 without locking anything.
  int getCurrentLevel() =>
      (_getInt(_keyCurrentLevel) ?? getHighestUnlockedLevel()).clamp(
        1,
        LevelsRepository.totalLevels,
      );

  Future<void> setCurrentLevel(int level) => _setInt(_keyCurrentLevel, level);

  // --- Completed Levels ---
  Set<int> getCompletedLevels() {
    final list = _getList(_keyCompletedLevels);
    if (list == null) return {};
    return list.map((e) => int.tryParse(e) ?? 0).where((e) => e > 0).toSet();
  }

  Future<void> markLevelCompleted(int level) async {
    final current = getCompletedLevels();
    current.add(level);
    await _setList(
      _keyCompletedLevels,
      current.map((e) => e.toString()).toList(),
    );

    final nextLevel = level + 1;
    if (nextLevel > getHighestUnlockedLevel()) {
      await setHighestUnlockedLevel(nextLevel);
    }
    if (level >= getCurrentLevel()) {
      await setCurrentLevel(nextLevel.clamp(1, LevelsRepository.totalLevels));
    }
    await markPlayed();
    _changed();
  }

  bool isLevelCompleted(int level) {
    return getCompletedLevels().contains(level);
  }

  // --- Settings ---
  bool isSoundEnabled() => _getBool(_keySoundEnabled) ?? true;

  Future<void> setSoundEnabled(bool enabled) async {
    await _setBool(_keySoundEnabled, enabled);
    _changed();
  }

  bool isHapticEnabled() => _getBool(_keyHapticEnabled) ?? true;

  Future<void> setHapticEnabled(bool enabled) async {
    await _setBool(_keyHapticEnabled, enabled);
    _changed();
  }

  // --- Power-ups ---
  //
  // Balances are stored as two monotonic counters (total granted, total used)
  // so cloud merges can take the max of each without ever duplicating a
  // reward or refunding a spent use.

  /// Earlier versions stored a plain hint balance; convert it once.
  void _migrateLegacyHints() {
    final legacy = _getInt(_keyHintCount);
    if (legacy == null || _getInt(_keyGranted(PowerUpType.hint)) != null) {
      return;
    }
    _setInt(_keyGranted(PowerUpType.hint), legacy);
    _setInt(_keyUsed(PowerUpType.hint), 0);
    // Existing players already received their free hints.
    final claims = getRewardClaims()..add(_starterClaim(PowerUpType.hint));
    _setList(_keyRewardClaims, claims.toList());
  }

  /// Version 1 capped the game at 100 levels, so players who finished
  /// level 100 had "Continue" parked on 100. Move exactly those players on
  /// to level 101 once; all other progress is untouched.
  void _migrateLevelCap() {
    if (_getBool(_keyLevelCapMigration) ?? false) return;
    if (_getInt(_keyCurrentLevel) == 100 && isLevelCompleted(100)) {
      _setInt(_keyCurrentLevel, 101);
    }
    _setBool(_keyLevelCapMigration, true);
  }

  static String _starterClaim(PowerUpType t) => 'starter_v1_${t.name}';

  int getPowerUpGranted(PowerUpType t) => _getInt(_keyGranted(t)) ?? 0;
  int getPowerUpUsed(PowerUpType t) => _getInt(_keyUsed(t)) ?? 0;

  /// Uses left. Until the one-time starter allowance has been granted
  /// (see [ensureStarterPowerUps]) it is counted as pending, so a fresh
  /// install shows the same balance everywhere.
  int getPowerUpBalance(PowerUpType t) {
    final pending = isRewardClaimed(_starterClaim(t))
        ? 0
        : PowerUpType.starterAllowance;
    return (getPowerUpGranted(t) + pending - getPowerUpUsed(t)).clamp(
      0,
      1 << 30,
    );
  }

  /// Grants the one-time starter allowance for every power-up. Safe to call
  /// on every launch; each type is granted at most once.
  Future<void> ensureStarterPowerUps() async {
    for (final t in PowerUpType.values) {
      await grantPowerUp(
        t,
        PowerUpType.starterAllowance,
        claimId: _starterClaim(t),
      );
    }
  }

  /// Adds [amount] uses. With a [claimId] the grant is idempotent: a second
  /// call with the same id does nothing and returns false.
  Future<bool> grantPowerUp(
    PowerUpType t,
    int amount, {
    String? claimId,
  }) async {
    if (claimId != null) {
      final claims = getRewardClaims();
      if (claims.contains(claimId)) return false;
      claims.add(claimId);
      await _setList(_keyRewardClaims, claims.toList());
    }
    await _setInt(_keyGranted(t), getPowerUpGranted(t) + amount);
    _changed();
    return true;
  }

  Future<bool> consumePowerUp(PowerUpType t) async {
    await ensureStarterPowerUps();
    if (getPowerUpBalance(t) <= 0) return false;
    await _setInt(_keyUsed(t), getPowerUpUsed(t) + 1);
    _changed();
    return true;
  }

  Set<String> getRewardClaims() => (_getList(_keyRewardClaims) ?? []).toSet();

  bool isRewardClaimed(String claimId) => getRewardClaims().contains(claimId);

  /// Sets raw counters (used when applying merged cloud data).
  Future<void> setPowerUpCounters(PowerUpType t, int granted, int used) async {
    await _setInt(_keyGranted(t), granted);
    await _setInt(_keyUsed(t), used);
  }

  Future<void> setRewardClaims(Set<String> claims) =>
      _setList(_keyRewardClaims, claims.toList());

  // --- Hints (kept for existing callers) ---
  int getHintCount() => getPowerUpBalance(PowerUpType.hint);

  /// Sets the hint balance to [count] by adjusting the granted counter.
  Future<void> setHintCount(int count) async {
    await ensureStarterPowerUps();
    await _setInt(
      _keyGranted(PowerUpType.hint),
      getPowerUpUsed(PowerUpType.hint) + count,
    );
    _changed();
  }

  Future<bool> consumeHint() => consumePowerUp(PowerUpType.hint);

  Future<void> addHints(int amount) async {
    await grantPowerUp(PowerUpType.hint, amount);
  }

  // --- Tutorials ---
  bool isTutorialCompleted() => _getBool(_keyTutorialCompleted) ?? false;

  Future<void> setTutorialCompleted(bool completed) async {
    await _setBool(_keyTutorialCompleted, completed);
    _changed();
  }

  /// Individual tutorials (onboarding flows, per-level guides, power-up
  /// introductions) are tracked separately so each shows only once.
  Set<String> getTutorialsSeen() => (_getList(_keyTutorialsSeen) ?? []).toSet();

  bool isTutorialSeen(String id) => getTutorialsSeen().contains(id);

  Future<void> markTutorialSeen(String id) async {
    final seen = getTutorialsSeen();
    if (!seen.add(id)) return;
    await _setList(_keyTutorialsSeen, seen.toList());
    _changed();
  }

  Future<void> setTutorialsSeen(Set<String> ids) =>
      _setList(_keyTutorialsSeen, ids.toList());

  /// Makes every tutorial show again (Help > Replay tutorials).
  Future<void> resetTutorials() async {
    await _setList(_keyTutorialsSeen, []);
    await setTutorialCompleted(false);
  }

  // --- Daily Challenge ---
  Set<String> getDailyCompletedDates() =>
      (_getList(_keyDailyCompletedDates) ?? []).toSet();

  bool isDailyCompleted(String dateKey) {
    return getDailyCompletedDates().contains(dateKey);
  }

  /// Consecutive completed days ending today (or yesterday, so the streak
  /// survives until today's puzzle is played). Computed from the completion
  /// set, so playing past dates in any order stays consistent.
  int getDailyStreak([DateTime? today]) {
    final dates = getDailyCompletedDates();
    final now = today ?? DateTime.now();
    var day = DateTime(now.year, now.month, now.day);
    if (!dates.contains(_dateKey(day))) {
      day = day.subtract(const Duration(days: 1));
    }
    var streak = 0;
    while (dates.contains(_dateKey(day))) {
      streak++;
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return streak;
  }

  int getBestDailyStreak() {
    final days =
        getDailyCompletedDates()
            .map(DateTime.tryParse)
            .whereType<DateTime>()
            .map((d) => DateTime(d.year, d.month, d.day))
            .toSet()
            .toList()
          ..sort();
    var best = 0;
    var run = 0;
    DateTime? prev;
    for (final d in days) {
      run = prev != null && DateTime(prev.year, prev.month, prev.day + 1) == d
          ? run + 1
          : 1;
      if (run > best) best = run;
      prev = d;
    }
    return best;
  }

  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> markDailyCompleted(String dateKey) async {
    final completedSet = getDailyCompletedDates();
    if (!completedSet.add(dateKey)) return;
    await _setList(_keyDailyCompletedDates, completedSet.toList());
    await markPlayed();
    _changed();
  }

  Future<void> setDailyCompletedDates(Set<String> dates) =>
      _setList(_keyDailyCompletedDates, dates.toList());

  Map<String, DailyResult> getDailyResults() => _getJson(_keyDailyResults).map(
    (k, v) =>
        MapEntry(k, DailyResult.fromJson((v as Map).cast<String, dynamic>())),
  );

  /// Stores the result if it beats the previous best for that date.
  Future<void> recordDailyResult(String dateKey, DailyResult result) async {
    final results = getDailyResults();
    final previous = results[dateKey];
    if (previous != null && !result.isBetterThan(previous)) return;
    results[dateKey] = result;
    await setDailyResults(results);
    _changed();
  }

  Future<void> setDailyResults(Map<String, DailyResult> results) => _setJson(
    _keyDailyResults,
    results.map((k, v) => MapEntry(k, v.toJson())),
  );

  // --- Weekly Challenge ---
  /// weekKey -> (puzzle index -> best score).
  Map<String, Map<int, int>> getWeeklyResults() =>
      _getJson(_keyWeeklyResults).map(
        (week, v) => MapEntry(
          week,
          (v as Map).map(
            (i, s) => MapEntry(int.parse(i as String), (s as num).toInt()),
          ),
        ),
      );

  Future<void> recordWeeklyResult(String weekKey, int index, int score) async {
    final all = getWeeklyResults();
    final week = all.putIfAbsent(weekKey, () => {});
    if ((week[index] ?? -1) >= score) return;
    week[index] = score;
    await setWeeklyResults(all);
    await markPlayed();
    _changed();
  }

  Future<void> setWeeklyResults(Map<String, Map<int, int>> results) => _setJson(
    _keyWeeklyResults,
    results.map(
      (week, m) => MapEntry(week, m.map((i, s) => MapEntry(i.toString(), s))),
    ),
  );

  // --- Achievements ---
  Set<String> getUnlockedAchievements() =>
      (_getList(_keyAchievements) ?? []).toSet();

  /// Returns true only the first time [id] is unlocked.
  Future<bool> unlockAchievement(String id) async {
    final set = getUnlockedAchievements();
    if (!set.add(id)) return false;
    await _setList(_keyAchievements, set.toList());
    _changed();
    return true;
  }

  Future<void> setUnlockedAchievements(Set<String> ids) =>
      _setList(_keyAchievements, ids.toList());

  // --- Last played ---
  DateTime? getLastPlayedAt() {
    final raw = _getString(_keyLastPlayedAt);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> markPlayed() =>
      _setString(_keyLastPlayedAt, DateTime.now().toUtc().toIso8601String());

  // --- Reset All Progress ---
  /// Resets game progress (levels, daily/weekly history, achievements,
  /// tutorials). Power-up counters and reward claims are kept so resetting
  /// cannot be used to re-earn the one-time starter allowance; the guest id
  /// and first-launch choice are kept so the player isn't signed out.
  Future<void> resetAllProgress() async {
    final keep = <String, Object?>{
      _keyGuestId: getGuestId(),
      _keyFirstLaunchCompleted: isFirstLaunchCompleted(),
      _keyRewardClaims: getRewardClaims().toList(),
      for (final t in PowerUpType.values) ...{
        _keyGranted(t): _getInt(_keyGranted(t)),
        _keyUsed(t): _getInt(_keyUsed(t)),
      },
    };
    if (_prefs != null) {
      await _prefs.clear();
    }
    _memoryCache.clear();
    for (final e in keep.entries) {
      final v = e.value;
      if (v is int) await _setInt(e.key, v);
      if (v is bool) await _setBool(e.key, v);
      if (v is String) await _setString(e.key, v);
      if (v is List<String>) await _setList(e.key, v);
    }
    await setHighestUnlockedLevel(1);
    await setCurrentLevel(1);
    await setSoundEnabled(true);
    await setHapticEnabled(true);
    await setTutorialCompleted(false);
  }

  /// Clears everything on this device, including rewards (used after the
  /// player deletes their account).
  Future<void> wipeAllLocalData() async {
    if (_prefs != null) await _prefs.clear();
    _memoryCache.clear();
  }

  // --- First Launch & Guest ID ---
  bool isFirstLaunchCompleted() => _getBool(_keyFirstLaunchCompleted) ?? false;

  Future<void> setFirstLaunchCompleted(bool completed) =>
      _setBool(_keyFirstLaunchCompleted, completed);

  String? getGuestId() => _getString(_keyGuestId);

  Future<void> setGuestId(String id) => _setString(_keyGuestId, id);
}
