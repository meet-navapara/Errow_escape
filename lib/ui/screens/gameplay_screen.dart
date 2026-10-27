import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../game/difficulty.dart';
import '../../game/game_controller.dart';
import '../../game/levels_data.dart';
import '../../game/play_context.dart';
import '../../game/weekly_challenge_service.dart';
import '../../models/power_up.dart';
import '../widgets/board_widget.dart';
import '../widgets/coach_marks.dart';
import '../widgets/level_complete_dialog.dart';
import '../widgets/out_of_hearts_dialog.dart';
import '../widgets/power_up_bar.dart';
import 'settings_screen.dart';

enum _CompletionAction { next, replay, home }

/// Tutorial ids persisted in storage.
class TutorialIds {
  static const gameplayOnboarding = 'onboarding_gameplay';
  static const homeOnboarding = 'onboarding_home';
  static String levelGuide(int level) => 'level_guide_$level';
  static String powerUpIntro(PowerUpType t) => 'powerup_intro_${t.name}';
}

const _monthNames = [
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

String formatDateKey(String dateKey) {
  final d = DateTime.tryParse(dateKey);
  return d == null ? dateKey : '${_monthNames[d.month - 1]} ${d.day}';
}

class GameplayScreen extends StatefulWidget {
  final GameController controller;

  const GameplayScreen({super.key, required this.controller});

  @override
  State<GameplayScreen> createState() => _GameplayScreenState();
}

class _GameplayScreenState extends State<GameplayScreen> {
  bool _completionDialogShowing = false;
  bool _gameOverDialogShowing = false;
  bool _busy = false;
  bool _guideDismissed = false;
  bool _freeHintGiven = false;

  final _boardKey = GlobalKey();
  final _heartsKey = GlobalKey();
  final _powerBarKey = GlobalKey();
  final _undoKey = GlobalKey();

  GameController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    controller.addListener(_onControllerUpdate);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeOnboard());
  }

  @override
  void dispose() {
    controller.removeListener(_onControllerUpdate);
    super.dispose();
  }

  Future<void> _maybeOnboard() async {
    final storage = controller.storage;
    if (!mounted || storage.isTutorialSeen(TutorialIds.gameplayOnboarding)) {
      return;
    }
    await storage.markTutorialSeen(TutorialIds.gameplayOnboarding);
    if (!mounted) return;
    await CoachMarks.show(context, [
      CoachStep(
        target: _boardKey,
        icon: Icons.near_me_rounded,
        title: 'How arrows escape',
        body:
            'Tap an arrow to launch it. It escapes only if nothing is in the '
            'way of its arrowhead, all the way to the edge.',
      ),
      CoachStep(
        target: _heartsKey,
        icon: Icons.favorite_rounded,
        title: 'Three hearts',
        body:
            'Tapping a blocked arrow costs one heart. Lose all three and you '
            'retry the level. Good moves never cost hearts.',
      ),
      CoachStep(
        target: _boardKey,
        icon: Icons.zoom_in_rounded,
        title: 'Zoom and pan',
        body:
            'Pinch with two fingers to zoom into busy boards and drag to move '
            'around. Tap "Reset View" to fit the whole board again.',
      ),
      CoachStep(
        target: _powerBarKey,
        icon: Icons.auto_fix_high_rounded,
        title: 'Power-ups',
        body:
            'Hint, Eraser, Magic Wand and Path Scanner. Tap one to use it, or '
            'press and hold to see exactly what it does.',
      ),
      CoachStep(
        target: _powerBarKey,
        icon: Icons.card_giftcard_rounded,
        title: '${PowerUpType.starterAllowance} free uses each',
        body:
            'Every player starts with ${PowerUpType.starterAllowance} free uses '
            'of each tool. When one runs out you may choose to watch a short ad '
            'for another. Ads are optional and never needed to win.',
      ),
      CoachStep(
        target: _undoKey,
        icon: Icons.undo_rounded,
        title: 'Undo and restart',
        body:
            'Undo takes back your last move (hearts are not refunded). '
            'Restart begins the level again with three hearts.',
      ),
    ]);
  }

  void _onControllerUpdate() {
    if (!mounted) return;

    if (controller.isWon && !_completionDialogShowing) {
      _completionDialogShowing = true;
      final id = controller.currentLevel.id;
      if (controller.playContext.isCampaign && id <= 3) {
        controller.storage.markTutorialSeen(TutorialIds.levelGuide(id));
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showCompletionScreen();
      });
    } else if (controller.isGameOver && !_gameOverDialogShowing) {
      _gameOverDialogShowing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showGameOverDialog();
      });
    }
    setState(() {});
  }

  String get _title {
    final ctx = controller.playContext;
    return switch (ctx.mode) {
      PlayMode.daily => formatDateKey(ctx.key!),
      PlayMode.weekly => controller.currentLevel.title,
      PlayMode.campaign => 'Level ${controller.currentLevel.id}',
    };
  }

  bool get _hasNext {
    final ctx = controller.playContext;
    return switch (ctx.mode) {
      PlayMode.daily => false,
      PlayMode.weekly => ctx.index < WeeklyChallengeService.puzzlesPerWeek - 1,
      PlayMode.campaign =>
        controller.currentLevel.id < LevelsRepository.totalLevels,
    };
  }

  String get _nextLabel {
    final ctx = controller.playContext;
    return ctx.isWeekly
        ? 'Puzzle ${ctx.index + 2}/${WeeklyChallengeService.puzzlesPerWeek}'
        : 'Level ${controller.currentLevel.id + 1}';
  }

  Future<void> _showCompletionScreen() async {
    if (!mounted) return;
    final level = controller.currentLevel;
    final ctx = controller.playContext;

    final action = await Navigator.of(context).push<_CompletionAction>(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (routeContext, _, _) => LevelCompleteDialog(
          levelId: level.id,
          isDaily: ctx.isDaily,
          title: ctx.isWeekly ? 'Puzzle Completed!' : null,
          subtitle: switch (ctx.mode) {
            PlayMode.daily => '${formatDateKey(ctx.key!)} challenge solved!',
            PlayMode.weekly =>
              '+${WeeklyChallengeService.scoreFor(controller.hearts)} weekly points',
            PlayMode.campaign => null,
          },
          movesTaken: controller.movesCount,
          targetMoves: level.targetMoves,
          remainingHearts: controller.hearts,
          previewBoard: level.board,
          hasNextLevel: _hasNext,
          nextLabel: _nextLabel,
          achievements: [for (final a in controller.newAchievements) a.title],
          onNextLevel: () =>
              Navigator.of(routeContext).pop(_CompletionAction.next),
          onReplay: () =>
              Navigator.of(routeContext).pop(_CompletionAction.replay),
          onHome: () => Navigator.of(routeContext).pop(_CompletionAction.home),
        ),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );

    _completionDialogShowing = false;
    if (!mounted) return;
    switch (action) {
      case _CompletionAction.next:
        _loadNext();
      case _CompletionAction.replay:
        controller.restart();
      case _CompletionAction.home:
      case null:
        Navigator.of(context).pop();
    }
  }

  void _showGameOverDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => OutOfHeartsDialog(
        onRetry: () {
          Navigator.of(ctx).pop();
          _gameOverDialogShowing = false;
          controller.retryLevel();
        },
        onHome: () {
          Navigator.of(ctx).pop();
          _gameOverDialogShowing = false;
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _loadNext() {
    final ctx = controller.playContext;
    _guideDismissed = false;
    _freeHintGiven = false;
    if (ctx.isWeekly) {
      final next = ctx.index + 1;
      final weekStart = DateTime.parse(ctx.key!.substring(1));
      controller.loadLevel(
        WeeklyChallengeService.getPuzzle(next, weekStart),
        context: PlayContext.weekly(ctx.key!, next),
      );
      return;
    }
    final nextId = controller.currentLevel.id + 1;
    if (nextId <= LevelsRepository.totalLevels) {
      controller.loadLevel(LevelsRepository.getLevel(nextId));
    }
  }

  // ------------------------------------------------------------ power-ups

  Future<void> _onPowerUp(PowerUpType type) async {
    if (_busy) return;
    final storage = controller.storage;
    final introKey = TutorialIds.powerUpIntro(type);
    final firstTime = !storage.isTutorialSeen(introKey);

    // Introduce a tool the first time it's touched, and explain the optional
    // ad refill when it is empty. Neither consumes anything.
    if (firstTime || controller.balanceOf(type) <= 0) {
      await storage.markTutorialSeen(introKey);
      if (!mounted) return;
      final use = await PowerUpSheet.show(
        context,
        controller,
        type,
        introduction: firstTime,
      );
      if (!use || !mounted) return;
    }

    setState(() => _busy = true);
    try {
      switch (type) {
        case PowerUpType.hint:
          await controller.requestHint();
        case PowerUpType.eraser:
        case PowerUpType.scanner:
          controller.activateTool(type);
        case PowerUpType.wand:
          await controller.useWand();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // --------------------------------------------------------- level guides

  /// Interactive guidance for tutorial levels 1-3, derived from the live
  /// board so it always matches what the player sees.
  ({String text, Set<String> ids, bool offerHint})? _guide() {
    final id = controller.currentLevel.id;
    if (!controller.playContext.isCampaign ||
        id > 3 ||
        _guideDismissed ||
        controller.isWon ||
        controller.storage.isTutorialSeen(TutorialIds.levelGuide(id))) {
      return null;
    }
    final board = controller.board;
    if (controller.blockedArrow != null) {
      return (
        text:
            'Blocked! The orange arrow is in the red arrow\'s way. Clear the '
            'blocker first.',
        ids: <String>{},
        offerHint: false,
      );
    }
    switch (id) {
      case 1:
        if (controller.movesCount == 0) {
          final free = board.getEscapableArrows();
          return (
            text:
                'Arrows fly off the board in the direction they point. Tap '
                'the glowing arrow.',
            ids: {if (free.isNotEmpty) free.first.id},
            offerHint: false,
          );
        }
        return (
          text: 'Nice! Your turn: tap another arrow with a clear path.',
          ids: <String>{},
          offerHint: false,
        );
      case 2:
        final bent = board.arrowById('t2_bent_blocked');
        final blocker = board.arrowById('t2_blocker');
        if (bent != null && blocker != null) {
          return (
            text:
                'The bent arrow can\'t escape: the glowing arrow sits in its '
                'path. Tap the blocker first.',
            ids: {blocker.id},
            offerHint: false,
          );
        }
        if (bent != null) {
          return (
            text: 'Path clear! Now the bent arrow can escape.',
            ids: {bent.id},
            offerHint: false,
          );
        }
        return (
          text: 'Great. Clear the rest on your own.',
          ids: <String>{},
          offerHint: false,
        );
      default:
        if (controller.movesCount == 0 && controller.hintedArrow == null) {
          return (
            text:
                'Each mistake costs a heart. Not sure? This first hint is free '
                'and won\'t use your hint count.',
            ids: <String>{},
            offerHint: !_freeHintGiven,
          );
        }
        if (controller.movesCount == 0) {
          return (
            text: 'The hint lights up an arrow that can escape. Tap it!',
            ids: <String>{},
            offerHint: false,
          );
        }
        return (
          text: 'Practise: solve the rest yourself and protect your hearts.',
          ids: <String>{},
          offerHint: false,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final level = controller.currentLevel;
    final message = controller.hintText ?? controller.feedbackMessage;
    final isHintMessage = controller.hintText != null;
    final guide = _guide();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar: back, undo, title, restart, settings.
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 2, 4, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 20,
                    ),
                    color: AppColors.primary,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  IconButton(
                    key: _undoKey,
                    tooltip: 'Undo',
                    icon: const Icon(Icons.undo_rounded),
                    color: AppColors.textPrimary,
                    onPressed: controller.canUndo ? controller.undo : null,
                  ),
                  Expanded(
                    child: Text(
                      _title,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Restart',
                    icon: const Icon(Icons.refresh_rounded),
                    color: AppColors.textPrimary,
                    onPressed: controller.isWon || controller.isGameOver
                        ? null
                        : controller.restart,
                  ),
                  IconButton(
                    tooltip: 'Settings',
                    icon: const Icon(Icons.settings_outlined, size: 22),
                    color: AppColors.primary,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => SettingsScreen(
                          storage: controller.storage,
                          sound: controller.sound,
                          haptic: controller.haptic,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Arrow count, hearts, difficulty.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _InfoPill(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.near_me_rounded,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${controller.remainingArrowsCount}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  _HeartsRow(key: _heartsKey, hearts: controller.hearts),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _InfoPill(
                        child: Text(
                          Difficulty.of(level.board).label,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Board takes all remaining space; messages float above it so
            // the board never resizes when one appears.
            Expanded(
              key: _boardKey,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: BoardWidget(
                      key: ValueKey(
                        '${controller.playContext.mode.name}-'
                        '${controller.playContext.key}-${level.id}',
                      ),
                      controller: controller,
                      guideIds: guide?.ids ?? const {},
                    ),
                  ),
                  Positioned(
                    top: 6,
                    left: 16,
                    right: 16,
                    child: IgnorePointer(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: message == null
                            ? const SizedBox.shrink()
                            : Center(
                                key: ValueKey(message),
                                child: _FeedbackPill(
                                  message: message,
                                  isHint: isHintMessage,
                                ),
                              ),
                      ),
                    ),
                  ),
                  if (guide != null)
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 8,
                      child: _GuideBanner(
                        text: guide.text,
                        actionLabel: guide.offerHint ? 'Show free hint' : null,
                        onAction: () async {
                          setState(() => _freeHintGiven = true);
                          await controller.requestHint(free: true);
                        },
                        onDismiss: () => setState(() => _guideDismissed = true),
                      ),
                    ),
                ],
              ),
            ),

            Padding(
              key: _powerBarKey,
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
              child: PowerUpBar(
                controller: controller,
                busy: _busy,
                onPressed: _onPowerUp,
                onInfo: (t) =>
                    PowerUpSheet.show(context, controller, t).then((use) {
                      if (use) _onPowerUp(t);
                    }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideBanner extends StatelessWidget {
  final String text;
  final String? actionLabel;
  final VoidCallback onAction;
  final VoidCallback onDismiss;

  const _GuideBanner({
    required this.text,
    required this.actionLabel,
    required this.onAction,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFEFF6FF),
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
        child: Row(
          children: [
            const Icon(Icons.school_rounded, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    text,
                    style: const TextStyle(
                      fontSize: 13.5,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (actionLabel != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: FilledButton.tonal(
                        onPressed: onAction,
                        child: Text(actionLabel!),
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Hide tutorial',
              icon: const Icon(Icons.close_rounded, size: 18),
              onPressed: onDismiss,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final Widget child;

  const _InfoPill({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

/// Three hearts; the one just lost pops and shakes briefly.
class _HeartsRow extends StatefulWidget {
  final int hearts;

  const _HeartsRow({super.key, required this.hearts});

  @override
  State<_HeartsRow> createState() => _HeartsRowState();
}

class _HeartsRowState extends State<_HeartsRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );

  @override
  void didUpdateWidget(covariant _HeartsRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hearts < oldWidget.hearts) _pulse.forward(from: 0);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final t = _pulse.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(GameController.maxHearts, (index) {
            final isFilled = index < widget.hearts;
            final justLost = index == widget.hearts && _pulse.isAnimating;
            final scale = justLost ? 1 + 0.35 * math.sin(t * math.pi) : 1.0;
            final shake = justLost
                ? math.sin(t * math.pi * 6) * 3 * (1 - t)
                : 0.0;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Transform.translate(
                offset: Offset(shake, 0),
                child: Transform.scale(
                  scale: scale,
                  child: Icon(
                    isFilled
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: isFilled || justLost
                        ? AppColors.heartActive
                        : AppColors.heartEmpty,
                    size: 28,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _FeedbackPill extends StatelessWidget {
  final String message;
  final bool isHint;

  const _FeedbackPill({required this.message, required this.isHint});

  @override
  Widget build(BuildContext context) {
    final color = isHint ? AppColors.hint : AppColors.blocked;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Color.alphaBlend(color.withValues(alpha: 0.12), Colors.white),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isHint ? Icons.lightbulb_rounded : Icons.info_outline_rounded,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isHint ? const Color(0xFFB45309) : AppColors.blocked,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
