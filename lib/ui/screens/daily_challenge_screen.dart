import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../game/daily_challenge_service.dart';
import '../../game/play_context.dart';
import '../app_services.dart';

const _months = [
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
];

/// Daily tab: pick any date up to today (device local date) and play its
/// deterministic, solver-validated puzzle.
class DailyChallengeScreen extends StatefulWidget {
  final AppServices services;

  /// Injectable "today" for tests.
  final DateTime? today;

  const DailyChallengeScreen({super.key, required this.services, this.today});

  /// Earliest month offered in the calendar.
  static final DateTime firstMonth = DateTime(2026, 1);

  @override
  State<DailyChallengeScreen> createState() => _DailyChallengeScreenState();
}

class _DailyChallengeScreenState extends State<DailyChallengeScreen> {
  late DateTime _today;
  late DateTime _month;
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    final now = widget.today ?? DateTime.now();
    _today = DateTime(now.year, now.month, now.day);
    _month = DateTime(_today.year, _today.month);
    _selected = _today;
  }

  bool get _canGoBack => _month.isAfter(DailyChallengeScreen.firstMonth);
  bool get _canGoForward =>
      _month.isBefore(DateTime(_today.year, _today.month));

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  Future<void> _play() async {
    final key = DailyChallengeService.getDateKey(_selected);
    await widget.services.play(
      context,
      DailyChallengeService.getDailyChallenge(_selected),
      playContext: PlayContext.daily(key),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final storage = widget.services.storage;
    final completed = storage.getDailyCompletedDates();
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final leading = DateTime(_month.year, _month.month, 1).weekday % 7; // Sun=0
    final monthDone = [
      for (var d = 1; d <= daysInMonth; d++)
        DailyChallengeService.getDateKey(
          DateTime(_month.year, _month.month, d),
        ),
    ].where(completed.contains).length;

    final selectedKey = DailyChallengeService.getDateKey(_selected);
    final result = storage.getDailyResults()[selectedKey];
    final selectedDone = completed.contains(selectedKey);

    return Column(
      children: [
        _Header(streak: storage.getDailyStreak(_today)),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Previous month',
                    onPressed: _canGoBack ? () => _shiftMonth(-1) : null,
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Expanded(
                    child: Text(
                      '${_months[_month.month - 1]} ${_month.year}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const Icon(Icons.stars_rounded, color: AppColors.accent),
                  const SizedBox(width: 4),
                  Text(
                    '$monthDone/$daysInMonth',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Next month',
                    onPressed: _canGoForward ? () => _shiftMonth(1) : null,
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final d in const ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
                    Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              GridView.count(
                crossAxisCount: 7,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (var i = 0; i < leading; i++) const SizedBox.shrink(),
                  for (var d = 1; d <= daysInMonth; d++)
                    _DayCell(
                      date: DateTime(_month.year, _month.month, d),
                      today: _today,
                      selected: _selected,
                      done: completed.contains(
                        DailyChallengeService.getDateKey(
                          DateTime(_month.year, _month.month, d),
                        ),
                      ),
                      onTap: (date) => setState(() => _selected = date),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                selectedDone
                    ? 'Completed${result == null ? '' : ' · best ${result.hearts}/3 hearts in ${result.moves} moves'}'
                    : _selected == _today
                    ? 'Today\'s puzzle: finish it for a bonus hint.'
                    : 'Not played yet. Catch up any time.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 0, 32, 16),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: _play,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: Text(
                selectedDone ? 'Replay' : 'Play',
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final int streak;

  const _Header({required this.streak});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.2),
          radius: 1.1,
          colors: [Color(0xFF4DB6FF), AppColors.dailyBlue],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            children: [
              const Text(
                'Daily Challenges',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0x26FFFFFF),
                  border: Border.all(color: const Color(0x55FFFFFF), width: 2),
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  size: 64,
                  color: Color(0xFFFFD54F),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                streak == 0 ? 'Start a streak today' : '$streak-day streak 🔥',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime date;
  final DateTime today;
  final DateTime selected;
  final bool done;
  final void Function(DateTime) onTap;

  const _DayCell({
    required this.date,
    required this.today,
    required this.selected,
    required this.done,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final future = date.isAfter(today);
    final isSelected = date == selected;
    final isToday = date == today;
    return Semantics(
      button: !future,
      selected: isSelected,
      label:
          '${date.day}${done ? ', completed' : ''}${future ? ', not available yet' : ''}',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: future ? null : () => onTap(date),
        child: Center(
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected
                  ? AppColors.primary
                  : done
                  ? AppColors.primary.withValues(alpha: 0.12)
                  : null,
              border: isToday && !isSelected
                  ? Border.all(color: AppColors.primary, width: 1.5)
                  : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  '${date.day}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? Colors.white
                        : future
                        ? AppColors.textMuted.withValues(alpha: 0.6)
                        : AppColors.textSecondary,
                  ),
                ),
                if (done)
                  Positioned(
                    bottom: 3,
                    child: Icon(
                      Icons.star_rounded,
                      size: 11,
                      color: isSelected ? Colors.white : AppColors.accent,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
