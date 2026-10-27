import 'package:flutter/material.dart';

import '../../core/audio/haptic_service.dart';
import '../../core/audio/sound_service.dart';
import '../../core/auth/auth_service.dart';
import '../../core/storage/storage_service.dart';
import '../../core/theme/app_colors.dart';
import '../../game/daily_challenge_service.dart';
import '../../game/levels_data.dart';
import '../../game/play_context.dart';
import '../../game/weekly_challenge_service.dart';
import '../app_services.dart';
import '../widgets/coach_marks.dart';
import '../widgets/game_logo_widget.dart';
import 'daily_challenge_screen.dart';
import 'gameplay_screen.dart';
import 'level_select_screen.dart';
import 'profile_screen.dart';
import 'weekly_challenge_screen.dart';

/// App shell with the Main, Daily and Me tabs.
class HomeScreen extends StatefulWidget {
  final StorageService storage;
  final SoundService sound;
  final HapticService haptic;
  final AuthService? auth;

  const HomeScreen({
    super.key,
    required this.storage,
    required this.sound,
    required this.haptic,
    this.auth,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  final _meTabKey = GlobalKey();

  late final AppServices services = AppServices(
    storage: widget.storage,
    sound: widget.sound,
    haptic: widget.haptic,
    auth: widget.auth,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _tab,
        children: [
          MainTab(
            services: services,
            meTabKey: _meTabKey,
            onChanged: () => setState(() {}),
          ),
          DailyChallengeScreen(services: services),
          ProfileScreen(services: services),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        backgroundColor: Colors.white,
        indicatorColor: AppColors.primary.withValues(alpha: 0.12),
        onDestinationSelected: (i) {
          services.tapFeedback();
          setState(() => _tab = i);
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded, color: AppColors.primary),
            label: 'Main',
          ),
          const NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(
              Icons.calendar_month_rounded,
              color: AppColors.primary,
            ),
            label: 'Daily',
          ),
          NavigationDestination(
            key: _meTabKey,
            icon: const Icon(Icons.person_outline_rounded),
            selectedIcon: const Icon(
              Icons.person_rounded,
              color: AppColors.primary,
            ),
            label: 'Me',
          ),
        ],
      ),
    );
  }
}

class MainTab extends StatefulWidget {
  final AppServices services;
  final GlobalKey? meTabKey;
  final VoidCallback? onChanged;

  const MainTab({
    super.key,
    required this.services,
    this.meTabKey,
    this.onChanged,
  });

  @override
  State<MainTab> createState() => _MainTabState();
}

class _MainTabState extends State<MainTab> {
  final _continueKey = GlobalKey();
  final _levelsKey = GlobalKey();
  final _dailyKey = GlobalKey();
  final _weeklyKey = GlobalKey();

  AppServices get s => widget.services;

  @override
  void initState() {
    super.initState();
    s.storage.ensureStarterPowerUps();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeOnboard());
  }

  Future<void> _maybeOnboard() async {
    if (!mounted || s.storage.isTutorialSeen(TutorialIds.homeOnboarding)) {
      return;
    }
    await s.storage.markTutorialSeen(TutorialIds.homeOnboarding);
    if (!mounted) return;
    await CoachMarks.show(context, [
      CoachStep(
        target: _continueKey,
        icon: Icons.play_arrow_rounded,
        title: 'Continue Game',
        body:
            'Jump straight into your next level. Levels 1 to 3 teach you '
            'how to play step by step.',
      ),
      CoachStep(
        target: _levelsKey,
        icon: Icons.grid_view_rounded,
        title: 'Levels and difficulty',
        body:
            'Replay any unlocked level. Each one shows a difficulty badge '
            '(Easy, Normal, Hard, Expert) measured from the puzzle itself.',
      ),
      CoachStep(
        target: _dailyKey,
        icon: Icons.calendar_today_rounded,
        title: 'Daily Challenge',
        body:
            'A new puzzle every day. Finish it to grow your streak and earn '
            'a bonus hint.',
      ),
      CoachStep(
        target: _weeklyKey,
        icon: Icons.emoji_events_rounded,
        title: 'Weekly Challenge',
        body:
            'Five tougher puzzles each week. Hearts left become points. '
            'Scores are personal; there is no public leaderboard.',
      ),
      CoachStep(
        target: widget.meTabKey,
        icon: Icons.person_rounded,
        title: 'Your profile',
        body:
            'Achievements, settings, help and privacy live here. Guest '
            'progress is saved on this device; sign in with Google to back '
            'it up and play on other devices.',
      ),
    ]);
  }

  Future<void> _play(Future<void> Function() action) async {
    await action();
    if (mounted) setState(() {});
    widget.onChanged?.call();
  }

  Future<void> _continue() => _play(
    () =>
        s.play(context, LevelsRepository.getLevel(s.storage.getCurrentLevel())),
  );

  Future<void> _confirmRestart() async {
    s.tapFeedback();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restart from Level 1?'),
        content: const Text(
          'Continue Game will start again from level 1. Unlocked levels, '
          'achievements and daily history are kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Restart'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await s.storage.setCurrentLevel(1);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final storage = s.storage;
    final today = DateTime.now();
    final todayKey = DailyChallengeService.getDateKey(today);
    final weekKey = WeeklyChallengeService.weekKey(today);
    final weekScores = storage.getWeeklyResults()[weekKey] ?? const {};
    final weekScore = weekScores.values.fold<int>(0, (a, b) => a + b);
    final remaining = WeeklyChallengeService.timeRemaining(today);
    final current = storage.getCurrentLevel();
    final completed = storage.getCompletedLevels().length;

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 36),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  // Equal-height cards even when one grows with large text.
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _ChallengeCard(
                            key: _dailyKey,
                            colors: const [
                              Color(0xFF6CB8FF),
                              AppColors.dailyBlue,
                            ],
                            icon: Icons.calendar_today_rounded,
                            label: 'DAILY CHALLENGE',
                            value: formatDateKey(todayKey),
                            badge: storage.isDailyCompleted(todayKey)
                                ? 'Done ✓'
                                : null,
                            onPlay: () => _play(
                              () => s.play(
                                context,
                                DailyChallengeService.getDailyChallenge(today),
                                playContext: PlayContext.daily(todayKey),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ChallengeCard(
                            key: _weeklyKey,
                            colors: const [
                              Color(0xFFFFB15C),
                              AppColors.weeklyOrange,
                            ],
                            icon: Icons.emoji_events_rounded,
                            label: 'WEEKLY CHALLENGE',
                            value:
                                '$weekScore / ${WeeklyChallengeService.maxScore()}',
                            badge:
                                '${remaining.inDays}d ${(remaining.inHours % 24).toString().padLeft(2, '0')}h',
                            onPlay: () => _play(
                              () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      WeeklyChallengeScreen(services: s),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(height: 24),
                  const GameLogoWidget(size: 84),
                  const SizedBox(height: 14),
                  Text(
                    'Completed $completed / ${LevelsRepository.totalLevels}'
                    '  ·  Daily streak ${storage.getDailyStreak()}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(height: 24),
                  _PillButton(
                    key: _continueKey,
                    filled: true,
                    title: current == 1 && completed == 0
                        ? 'New Game'
                        : 'Continue Game',
                    subtitle:
                        'Level $current of ${LevelsRepository.totalLevels}',
                    onTap: _continue,
                  ),
                  const SizedBox(height: 12),
                  _PillButton(
                    filled: false,
                    title: 'Restart Game',
                    onTap: _confirmRestart,
                  ),
                  const SizedBox(height: 4),
                  TextButton.icon(
                    key: _levelsKey,
                    onPressed: () => _play(
                      () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => LevelSelectScreen(
                            storage: storage,
                            sound: s.sound,
                            haptic: s.haptic,
                          ),
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.grid_view_rounded),
                    label: const Text('All Levels'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  final List<Color> colors;
  final IconData icon;
  final String label;
  final String value;
  final String? badge;
  final VoidCallback onPlay;

  const _ChallengeCard({
    super.key,
    required this.colors,
    required this.icon,
    required this.label,
    required this.value,
    required this.onPlay,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // Minimum, not fixed: the card grows with larger system text sizes.
      constraints: const BoxConstraints(minHeight: 190),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.card),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
        boxShadow: AppShadows.card,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (badge != null)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0x33000000),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          Padding(
            // Top inset keeps the content clear of the corner badge.
            padding: const EdgeInsets.fromLTRB(12, 24, 12, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 36),
                const SizedBox(height: 10),
                FittedBox(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xCCFFFFFF),
                      fontSize: 12,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  child: Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Material(
                  color: const Color(0x33FFFFFF),
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: onPlay,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 8,
                      ),
                      child: Text(
                        'Play',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  final bool filled;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _PillButton({
    super.key,
    required this.filled,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final fg = filled ? Colors.white : AppColors.primary;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: filled ? AppColors.primary : Colors.white,
          foregroundColor: fg,
          elevation: filled ? 3 : 1,
          // Minimum height only: the button grows with the device font size
          // instead of clipping the "Level N" subtitle.
          minimumSize: Size.fromHeight(subtitle == null ? 56 : 64),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.button + 6),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: fg,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 13,
                  color: fg.withValues(alpha: 0.75),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
