import 'package:flutter/material.dart';

import '../../core/storage/storage_service.dart';
import '../../core/theme/app_colors.dart';
import '../../game/achievements.dart';

/// All achievements with live progress; unlocked ones are highlighted.
class AchievementsScreen extends StatelessWidget {
  final StorageService storage;

  const AchievementsScreen({super.key, required this.storage});

  @override
  Widget build(BuildContext context) {
    final unlocked = storage.getUnlockedAchievements();
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        title: Text(
          'Achievements ${unlocked.length}/${AchievementService.all.length}',
        ),
        backgroundColor: AppColors.pageBackground,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final a in AchievementService.all)
            _AchievementTile(
              achievement: a,
              unlocked: unlocked.contains(a.id),
              progress: a.progress(storage).clamp(0, a.goal),
            ),
        ],
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  final Achievement achievement;
  final bool unlocked;
  final int progress;

  const _AchievementTile({
    required this.achievement,
    required this.unlocked,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: unlocked
              ? const Color(0xFFFFF3C4)
              : AppColors.surfaceSubtle,
          child: Icon(
            unlocked ? Icons.emoji_events_rounded : Icons.lock_outline_rounded,
            color: unlocked ? AppColors.accent : AppColors.textMuted,
          ),
        ),
        title: Text(
          achievement.title,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: unlocked ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(achievement.description),
            if (!unlocked && achievement.goal > 1) ...[
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: progress / achievement.goal,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 2),
              Text('$progress / ${achievement.goal}'),
            ],
          ],
        ),
        trailing: unlocked
            ? const Icon(Icons.check_circle_rounded, color: AppColors.success)
            : null,
      ),
    );
  }
}

/// Monthly daily-challenge trophies: bronze at 10 days, silver at 20, gold
/// when every day of the month is completed.
class AwardsScreen extends StatelessWidget {
  final StorageService storage;

  const AwardsScreen({super.key, required this.storage});

  static ({String label, Color color})? trophyFor(int done, int days) {
    if (done >= days) return (label: 'Gold', color: const Color(0xFFF5B301));
    if (done >= 20) return (label: 'Silver', color: const Color(0xFF94A3B8));
    if (done >= 10) return (label: 'Bronze', color: const Color(0xFFB7793F));
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final byMonth = <DateTime, int>{};
    for (final key in storage.getDailyCompletedDates()) {
      final d = DateTime.tryParse(key);
      if (d == null) continue;
      final m = DateTime(d.year, d.month);
      byMonth[m] = (byMonth[m] ?? 0) + 1;
    }
    final months = byMonth.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        title: const Text('Awards'),
        backgroundColor: AppColors.pageBackground,
      ),
      body: months.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Complete daily challenges to earn monthly trophies:\n'
                  'Bronze for 10 days, Silver for 20, Gold for every day.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final m in months)
                  Builder(
                    builder: (context) {
                      final days = DateTime(m.year, m.month + 1, 0).day;
                      final done = byMonth[m]!;
                      final trophy = trophyFor(done, days);
                      return Card(
                        elevation: 0,
                        color: Colors.white,
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: Icon(
                            Icons.emoji_events_rounded,
                            size: 36,
                            color: trophy?.color ?? AppColors.border,
                          ),
                          title: Text('${_month(m.month)} ${m.year}'),
                          subtitle: Text(
                            '$done/$days daily challenges'
                            '${trophy == null ? '' : ' · ${trophy.label} trophy'}',
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
    );
  }

  static String _month(int m) => const [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ][m - 1];
}
