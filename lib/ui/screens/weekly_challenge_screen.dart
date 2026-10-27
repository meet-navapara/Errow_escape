import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../game/play_context.dart';
import '../../game/weekly_challenge_service.dart';
import '../app_services.dart';

/// Five puzzles per week with a personal score. Local only: there is no
/// online leaderboard and no other players are shown.
class WeeklyChallengeScreen extends StatefulWidget {
  final AppServices services;
  final DateTime? now;

  const WeeklyChallengeScreen({super.key, required this.services, this.now});

  @override
  State<WeeklyChallengeScreen> createState() => _WeeklyChallengeScreenState();
}

class _WeeklyChallengeScreenState extends State<WeeklyChallengeScreen> {
  DateTime get _now => widget.now ?? DateTime.now();

  Future<void> _play(int index) async {
    final weekKey = WeeklyChallengeService.weekKey(_now);
    await widget.services.play(
      context,
      WeeklyChallengeService.getPuzzle(index, _now),
      playContext: PlayContext.weekly(weekKey, index),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final weekKey = WeeklyChallengeService.weekKey(_now);
    final scores =
        widget.services.storage.getWeeklyResults()[weekKey] ?? const {};
    final total = scores.values.fold<int>(0, (a, b) => a + b);
    final left = WeeklyChallengeService.timeRemaining(_now);
    final finished = scores.length >= WeeklyChallengeService.puzzlesPerWeek;
    final next = List.generate(
      WeeklyChallengeService.puzzlesPerWeek,
      (i) => i,
    ).where((i) => !scores.containsKey(i)).firstOrNull;

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        title: const Text('Weekly Challenge'),
        backgroundColor: AppColors.pageBackground,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFB15C), AppColors.weeklyOrange],
              ),
              borderRadius: BorderRadius.circular(AppRadii.card),
              boxShadow: AppShadows.card,
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.emoji_events_rounded,
                  color: Colors.white,
                  size: 44,
                ),
                const SizedBox(height: 8),
                Text(
                  finished ? 'Week complete!' : 'Your score',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                Text(
                  '$total / ${WeeklyChallengeService.maxScore()}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Resets in ${left.inDays}d ${left.inHours % 24}h '
                  '${left.inMinutes % 60}m',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Each puzzle scores 100 points per heart left. Replays keep your '
            'best score. This is a personal challenge: scores are saved on '
            'this device (and your account if signed in) and are not ranked '
            'against other players.',
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < WeeklyChallengeService.puzzlesPerWeek; i++)
            Card(
              color: Colors.white,
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: scores.containsKey(i)
                      ? AppColors.success
                      : AppColors.weeklyOrange.withValues(alpha: 0.15),
                  child: scores.containsKey(i)
                      ? const Icon(Icons.check_rounded, color: Colors.white)
                      : Text(
                          '${i + 1}',
                          style: const TextStyle(
                            color: AppColors.weeklyOrange,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
                title: Text('Puzzle ${i + 1}'),
                subtitle: Text(
                  scores.containsKey(i)
                      ? 'Best: ${scores[i]} points'
                      : 'Not played yet',
                ),
                trailing: FilledButton.tonal(
                  onPressed: () => _play(i),
                  child: Text(scores.containsKey(i) ? 'Replay' : 'Play'),
                ),
              ),
            ),
          if (next != null)
            FilledButton(
              onPressed: () => _play(next),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: AppColors.weeklyOrange,
              ),
              child: Text('Play puzzle ${next + 1}'),
            ),
        ],
      ),
    );
  }
}
