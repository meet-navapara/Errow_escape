import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/arrow_model.dart';
import '../models/board_model.dart';
import '../models/game_move.dart';
import '../models/level_model.dart';
import '../models/power_up.dart';
import '../core/audio/sound_service.dart';
import '../core/audio/haptic_service.dart';
import '../core/storage/storage_service.dart';
import '../core/ads/ad_service.dart';
import 'achievements.dart';
import 'daily_challenge_service.dart';
import 'play_context.dart';
import 'puzzle_solver.dart';
import 'weekly_challenge_service.dart';

/// Result of the Path Scanner on one arrow.
class ScanResult {
  final Arrow arrow;
  final List<Arrow> blockers;

  const ScanResult(this.arrow, this.blockers);

  bool get isClear => blockers.isEmpty;

  String get message => isClear
      ? 'Clear! This arrow can escape ${arrow.exitDirection.displayName.toLowerCase()} now.'
      : '${blockers.length} arrow${blockers.length == 1 ? '' : 's'} '
            'block${blockers.length == 1 ? 's' : ''} this path. Clear '
            '${blockers.length == 1 ? 'it' : 'them'} first.';
}

class GameController extends ChangeNotifier {
  final StorageService storage;
  final SoundService sound;
  final HapticService haptic;
  final Duration escapeDelay;

  /// Rewarded-ad provider; defaults to [AdService.rewarded].
  final RewardedAdProvider? ads;

  Level _currentLevel;
  Board _board;
  PlayContext _context;
  final List<GameMove> _moveHistory = [];

  // Heart Life System (Always starts at 3)
  static const int maxHearts = 3;
  int _hearts = maxHearts;
  bool _isGameOver = false;

  // Interaction feedback states & tap debouncing lock
  bool _isInteractionLocked = false;
  Timer? _unlockTimer;
  Arrow? _blockedArrow;
  Arrow? _blockerArrow;
  GridPosition? _blockedAtPosition;
  String? _feedbackMessage;
  Timer? _feedbackTimer;

  // Hint state
  Arrow? _hintedArrow;
  String? _hintText;
  Timer? _hintTimer;
  bool _hintInFlight = false;

  // Power-up state
  PowerUpType? _activeTool;
  ScanResult? _scan;
  Timer? _scanTimer;
  bool _usedPowerUp = false;
  bool _adInFlight = false;
  int _adClaimCounter = 0;
  List<Achievement> _newAchievements = const [];

  // Arrows already removed from [_board] that are still animating off-screen.
  final Map<String, Arrow> _escapingArrows = {};

  // Set once the last arrow leaves; the win is confirmed after its animation.
  bool _isCompleting = false;
  bool _isWon = false;
  int _movesCount = 0;

  GameController({
    required Level initialLevel,
    required this.storage,
    required this.sound,
    required this.haptic,
    bool isDaily = false,
    PlayContext? context,
    this.ads,
    this.escapeDelay = const Duration(milliseconds: 450),
  }) : _currentLevel = initialLevel,
       _board = initialLevel.board,
       _context =
           context ??
           (isDaily
               ? PlayContext.daily(DailyChallengeService.getDateKey())
               : const PlayContext.campaign()) {
    _hearts = maxHearts;
  }

  // Getters
  Level get currentLevel => _currentLevel;
  Board get board => _board;
  PlayContext get playContext => _context;
  int get hearts => _hearts;
  bool get isGameOver => _isGameOver;
  bool get isWon => _isWon;
  bool get isDaily => _context.isDaily;
  bool get isWeekly => _context.isWeekly;
  int get movesCount => _movesCount;
  int get remainingArrowsCount => _board.remainingArrowsCount;
  bool get canUndo =>
      _moveHistory.isNotEmpty && !_isWon && !_isGameOver && !_isCompleting;
  bool get isPlayable => !_isWon && !_isGameOver && !_isCompleting;

  Arrow? get blockedArrow => _blockedArrow;
  Arrow? get blockerArrow => _blockerArrow;
  GridPosition? get blockedAtPosition => _blockedAtPosition;
  String? get feedbackMessage => _feedbackMessage;

  Arrow? get hintedArrow => _hintedArrow;
  String? get hintText => _hintText;

  PowerUpType? get activeTool => _activeTool;
  ScanResult? get scanResult => _scan;

  /// Achievements unlocked by the most recent completion.
  List<Achievement> get newAchievements => _newAchievements;

  bool isArrowEscaping(String arrowId) => _escapingArrows.containsKey(arrowId);

  /// Arrows that have left the board logically but are still animating out.
  List<Arrow> get escapingArrows => List.unmodifiable(_escapingArrows.values);

  int get availableHints => storage.getHintCount();

  int balanceOf(PowerUpType type) => type == PowerUpType.hint
      ? storage.getHintCount()
      : storage.getPowerUpBalance(type);

  /// Loads a new level and resets board state with 3 full hearts.
  void loadLevel(Level newLevel, {bool isDaily = false, PlayContext? context}) {
    _cancelTimers();
    _currentLevel = newLevel;
    _context =
        context ??
        (isDaily
            ? PlayContext.daily(DailyChallengeService.getDateKey())
            : const PlayContext.campaign());
    _resetAttempt();
    notifyListeners();
  }

  /// Retries the current level after losing all hearts (or on demand),
  /// restoring 3 hearts and resetting the move counter for this attempt.
  /// Overall saved progress is untouched.
  void retryLevel() {
    _cancelTimers();
    _resetAttempt();
    haptic.selectionClick();
    notifyListeners();
  }

  void _cancelTimers() {
    _feedbackTimer?.cancel();
    _hintTimer?.cancel();
    _unlockTimer?.cancel();
    _scanTimer?.cancel();
  }

  void _resetAttempt() {
    _board = _currentLevel.board;
    _moveHistory.clear();
    _escapingArrows.clear();
    _isCompleting = false;
    _hintInFlight = false;
    _clearFeedback();
    _hintedArrow = null;
    _hintText = null;
    _activeTool = null;
    _scan = null;
    _usedPowerUp = false;
    _newAchievements = const [];
    _isWon = false;
    _isGameOver = false;
    _hearts = maxHearts;
    _movesCount = 0;
    _isInteractionLocked = false;
  }

  /// Handles user tapping an arrow.
  Future<void> onArrowTapped(Arrow arrow) async {
    // Ignore taps after the level ended, during the mistake debounce, or on
    // an arrow that is no longer on the board (e.g. a stale reference).
    if (!isPlayable ||
        _isInteractionLocked ||
        _board.arrowById(arrow.id) == null) {
      return;
    }

    // A selected tool consumes the tap instead of a normal move.
    switch (_activeTool) {
      case PowerUpType.eraser:
        return _erase(arrow);
      case PowerUpType.scanner:
        return _runScan(arrow);
      default:
        break;
    }

    // Clear active hint state
    _hintedArrow = null;
    _hintText = null;
    _hintTimer?.cancel();
    _scan = null;

    final result = _board.checkEscape(arrow);

    if (result.canEscape) {
      // Valid Move: hearts are unaffected!
      sound.playEscape();
      haptic.mediumImpact();
      await _removeArrows([arrow]);
    } else {
      // Invalid Move: path is blocked!
      // Debounce: lock interaction briefly so rapid spam taps cannot burn multiple hearts
      _isInteractionLocked = true;

      // Deduct exactly 1 heart, never below 0
      if (_hearts > 0) {
        _hearts--;
      }

      sound.playBlocked();
      haptic.heavyImpact();

      _blockedArrow = arrow;
      _blockerArrow = result.blocker;
      _blockedAtPosition = result.blockedAt;
      _feedbackMessage = 'Path blocked!';

      // Check if player ran out of hearts
      if (_hearts <= 0) {
        _isGameOver = true;
      }

      notifyListeners();

      _unlockTimer?.cancel();
      _unlockTimer = Timer(const Duration(milliseconds: 600), () {
        _isInteractionLocked = false;
      });
      _feedbackTimer?.cancel();
      _feedbackTimer = Timer(const Duration(milliseconds: 1400), () {
        _clearFeedback();
        notifyListeners();
      });
    }
  }

  /// Removes [arrows] as one move, animates them out and completes the level
  /// once the board is empty.
  Future<void> _removeArrows(List<Arrow> arrows) async {
    _moveHistory.add(
      GameMove(
        arrow: arrows.first,
        removed: arrows,
        moveIndex: _movesCount,
        previousBoard: _board,
        timestamp: DateTime.now(),
      ),
    );
    _movesCount++;
    _clearFeedback();

    // Remove from the logical board right away so an escaping arrow can
    // never block another arrow; the UI animates it out separately.
    for (final a in arrows) {
      _board = _board.removeArrow(a.id);
      _escapingArrows[a.id] = a;
    }
    if (_board.isCompleted) _isCompleting = true;
    notifyListeners();

    if (escapeDelay > Duration.zero) {
      await Future.delayed(escapeDelay);
    }

    for (final a in arrows) {
      _escapingArrows.remove(a.id);
    }

    // Only the engine's confirmed empty board completes the level. A
    // restart or level change during the animation clears _isCompleting.
    if (_isCompleting && _board.isCompleted && _escapingArrows.isEmpty) {
      await _completeLevel();
    }

    notifyListeners();
  }

  Future<void> _completeLevel() async {
    _isCompleting = false;
    _isWon = true;
    sound.playWin();
    haptic.successVibrate();

    switch (_context.mode) {
      case PlayMode.daily:
        final dateKey = _context.key!;
        await storage.markDailyCompleted(dateKey);
        await storage.recordDailyResult(
          dateKey,
          DailyResult(hearts: _hearts, moves: _movesCount),
        );
        // One bonus hint per challenge date, however often it is replayed.
        await storage.grantPowerUp(
          PowerUpType.hint,
          1,
          claimId: 'daily_reward_$dateKey',
        );
      case PlayMode.weekly:
        await storage.recordWeeklyResult(
          _context.key!,
          _context.index,
          WeeklyChallengeService.scoreFor(_hearts),
        );
      case PlayMode.campaign:
        await storage.markLevelCompleted(_currentLevel.id);
        if (_currentLevel.id == 3) {
          await storage.setTutorialCompleted(true);
        }
        await AdService.showInterstitialBetweenLevels(_currentLevel.id);
    }

    _newAchievements = await AchievementService.evaluate(
      storage,
      PlayEvent(flawless: _hearts == maxHearts, usedPowerUp: _usedPowerUp),
    );
  }

  void _clearFeedback() {
    _blockedArrow = null;
    _blockerArrow = null;
    _blockedAtPosition = null;
    _feedbackMessage = null;
  }

  void _flash(
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    _feedbackMessage = message;
    notifyListeners();
    _feedbackTimer?.cancel();
    _feedbackTimer = Timer(duration, () {
      _clearFeedback();
      notifyListeners();
    });
  }

  /// Cancels any active feedback timers and unlocks interaction immediately.
  void clearFeedbackAndUnlock() {
    _feedbackTimer?.cancel();
    _unlockTimer?.cancel();
    _clearFeedback();
    _isInteractionLocked = false;
  }

  /// Reverses the last successful move WITHOUT restoring lost hearts.
  /// Power-up uses are not refunded.
  void undo() {
    if (!canUndo) return;

    final lastMove = _moveHistory.removeLast();
    _board = lastMove.previousBoard;
    for (final a in lastMove.removed) {
      _escapingArrows.remove(a.id);
    }
    _movesCount++;
    _clearFeedback();
    _hintedArrow = null;
    _hintText = null;
    _scan = null;

    sound.playUndo();
    haptic.lightImpact();
    notifyListeners();
  }

  /// Restores board to starting layout and restores 3 hearts.
  void restart() {
    retryLevel();
  }

  // ---------------------------------------------------------------- hints

  /// Requests a solver-backed hint (never deducts hearts, never moves).
  /// With [free] (tutorial demonstrations) no hint is consumed.
  Future<bool> requestHint({bool free = false}) async {
    if (!isPlayable || _board.isCompleted) return false;
    // Repeated taps while a hint is being issued must not consume twice.
    if (_hintInFlight) return false;
    _activeTool = null;

    // A hint that is still showing (and still on the board) is re-shown free.
    final active = _hintedArrow;
    if (active != null && _board.arrowById(active.id) != null) {
      _restartHintTimer();
      return true;
    }

    if (!free && storage.getHintCount() <= 0) {
      _flash('No hints left. Watch an optional ad to earn one.');
      return false;
    }

    final hint = PuzzleSolver.getHint(_board);
    if (hint == null) {
      _reportValidationError();
      return false;
    }

    if (!free) {
      _hintInFlight = true;
      try {
        final consumed = await storage.consumeHint();
        if (!consumed) return false;
      } finally {
        _hintInFlight = false;
      }
      _usedPowerUp = true;
    }

    // The board may have changed while the hint was being saved.
    if (_board.arrowById(hint.arrow.id) == null ||
        !_board.checkEscape(hint.arrow).canEscape) {
      return false;
    }

    sound.playTap();
    haptic.selectionClick();

    _hintedArrow = hint.arrow;
    _hintText = hint.explanation;
    _clearFeedback();
    notifyListeners();
    _restartHintTimer();

    return true;
  }

  void _reportValidationError() {
    // Every level is solver-validated, so this means corrupted level data.
    debugPrint(
      '[GameController] Level validation error: no escapable arrow on '
      'level ${_currentLevel.id} with ${_board.arrows.length} arrows left.',
    );
    _flash('Level error: no arrow can escape. Please restart.');
  }

  void _restartHintTimer() {
    _hintTimer?.cancel();
    _hintTimer = Timer(const Duration(seconds: 6), () {
      _hintedArrow = null;
      _hintText = null;
      notifyListeners();
    });
  }

  // ------------------------------------------------------------- power-ups

  /// Arms the Eraser or Path Scanner: the next arrow tap uses the tool.
  /// Nothing is consumed until the tool is actually applied.
  bool activateTool(PowerUpType type) {
    assert(type.needsTarget);
    if (!isPlayable || balanceOf(type) <= 0) return false;
    _activeTool = _activeTool == type ? null : type;
    _hintedArrow = null;
    _hintText = null;
    _scan = null;
    if (_activeTool != null) {
      _feedbackMessage = type == PowerUpType.eraser
          ? 'Eraser ready: tap the arrow to remove.'
          : 'Scanner ready: tap an arrow to inspect its path.';
    } else {
      _clearFeedback();
    }
    notifyListeners();
    return true;
  }

  void cancelTool() {
    if (_activeTool == null) return;
    _activeTool = null;
    _clearFeedback();
    notifyListeners();
  }

  Future<void> _erase(Arrow arrow) async {
    _activeTool = null;
    if (!await storage.consumePowerUp(PowerUpType.eraser)) {
      _flash('No erasers left.');
      return;
    }
    _usedPowerUp = true;
    _hintedArrow = null;
    _hintText = null;
    _scan = null;
    sound.playEscape();
    haptic.mediumImpact();
    await _removeArrows([arrow]);
  }

  Future<void> _runScan(Arrow arrow) async {
    _activeTool = null;
    if (!await storage.consumePowerUp(PowerUpType.scanner)) {
      _flash('No scans left.');
      return;
    }
    _usedPowerUp = true;
    _scan = ScanResult(arrow, _board.blockersOf(arrow));
    _feedbackMessage = _scan!.message;
    sound.playTap();
    haptic.selectionClick();
    notifyListeners();
    _scanTimer?.cancel();
    _scanTimer = Timer(const Duration(seconds: 6), () {
      _scan = null;
      _clearFeedback();
      notifyListeners();
    });
  }

  /// Magic Wand: launches up to [PowerUpType.wandLimit] arrows that are free
  /// right now, as one undoable move.
  Future<bool> useWand() async {
    if (!isPlayable || _isInteractionLocked) return false;
    final free = _board.getEscapableArrows();
    if (free.isEmpty) {
      _reportValidationError();
      return false;
    }
    if (!await storage.consumePowerUp(PowerUpType.wand)) {
      _flash('No wands left.');
      return false;
    }
    _usedPowerUp = true;
    _activeTool = null;
    _hintedArrow = null;
    _hintText = null;
    _scan = null;
    sound.playEscape();
    haptic.mediumImpact();
    await _removeArrows(free.take(PowerUpType.wandLimit).toList());
    return true;
  }

  /// Plays an optional rewarded ad and grants one use of [type] only if the
  /// ad SDK confirms the reward. Concurrent requests are ignored.
  Future<RewardedAdOutcome> earnWithAd(PowerUpType type) async {
    if (_adInFlight) return RewardedAdOutcome.unavailable;
    _adInFlight = true;
    try {
      final outcome = await (ads ?? AdService.rewarded).showRewarded();
      if (outcome == RewardedAdOutcome.rewarded) {
        await storage.grantPowerUp(
          type,
          1,
          claimId:
              'ad_${type.name}_${DateTime.now().microsecondsSinceEpoch}_${_adClaimCounter++}',
        );
        _flash('+1 ${type.label} earned!');
        sound.playWin();
        haptic.successVibrate();
      }
      notifyListeners();
      return outcome;
    } finally {
      _adInFlight = false;
    }
  }

  @override
  void dispose() {
    _cancelTimers();
    super.dispose();
  }
}
