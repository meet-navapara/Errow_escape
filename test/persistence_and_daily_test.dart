import 'package:flutter_test/flutter_test.dart';
import 'package:arrow_escape/core/storage/storage_service.dart';
import 'package:arrow_escape/core/audio/sound_service.dart';
import 'package:arrow_escape/core/audio/haptic_service.dart';
import 'package:arrow_escape/game/daily_challenge_service.dart';
import 'package:arrow_escape/game/puzzle_solver.dart';
import 'package:arrow_escape/game/game_controller.dart';
import 'package:arrow_escape/models/arrow_model.dart';
import 'package:arrow_escape/models/board_model.dart';
import 'package:arrow_escape/models/level_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Heart Life System', () {
    late StorageService storage;
    late SoundService sound;
    late HapticService haptic;

    setUp(() {
      storage = StorageService(null);
      sound = SoundService(storage);
      haptic = HapticService(storage);
    });

    test('Level starts with exactly 3 hearts', () {
      final board = Board(rows: 3, cols: 3, arrows: []);
      final level = Level(
        id: 1,
        title: 'Test',
        board: board,
        tier: LevelTier.beginner,
        targetMoves: 0,
      );
      final controller = GameController(
        initialLevel: level,
        storage: storage,
        sound: sound,
        haptic: haptic,
      );

      expect(controller.hearts, equals(3));
      expect(controller.isGameOver, isFalse);
    });

    test('Valid move does not deduct hearts', () async {
      const escapable = Arrow(
        id: 'esc',
        path: [GridPosition(0, 0)],
        exitDirection: ArrowDirection.up,
      );
      final board = Board(rows: 3, cols: 3, arrows: [escapable]);
      final level = Level(
        id: 1,
        title: 'Test',
        board: board,
        tier: LevelTier.beginner,
        targetMoves: 1,
      );
      final controller = GameController(
        initialLevel: level,
        storage: storage,
        sound: sound,
        haptic: haptic,
        escapeDelay: Duration.zero,
      );

      await controller.onArrowTapped(escapable);
      expect(controller.hearts, equals(3));
      expect(controller.isGameOver, isFalse);
    });

    test('Invalid move deducts exactly one heart', () async {
      const blocked = Arrow(
        id: 'blk',
        path: [GridPosition(1, 1)],
        exitDirection: ArrowDirection.right,
      );
      const blocker = Arrow(
        id: 'obs',
        path: [GridPosition(1, 2)],
        exitDirection: ArrowDirection.down,
      );
      final board = Board(rows: 4, cols: 4, arrows: [blocked, blocker]);
      final level = Level(
        id: 1,
        title: 'Test',
        board: board,
        tier: LevelTier.beginner,
        targetMoves: 2,
      );
      final controller = GameController(
        initialLevel: level,
        storage: storage,
        sound: sound,
        haptic: haptic,
        escapeDelay: Duration.zero,
      );

      expect(controller.hearts, equals(3));

      // Tap blocked arrow
      await controller.onArrowTapped(blocked);
      expect(controller.hearts, equals(2));
      expect(controller.isGameOver, isFalse);
      expect(controller.feedbackMessage, equals('Path blocked!'));
    });

    test('Game over occurs when all 3 hearts are lost', () async {
      const blocked = Arrow(
        id: 'blk',
        path: [GridPosition(1, 1)],
        exitDirection: ArrowDirection.right,
      );
      const blocker = Arrow(
        id: 'obs',
        path: [GridPosition(1, 2)],
        exitDirection: ArrowDirection.down,
      );
      final board = Board(rows: 4, cols: 4, arrows: [blocked, blocker]);
      final level = Level(
        id: 1,
        title: 'Test',
        board: board,
        tier: LevelTier.beginner,
        targetMoves: 2,
      );
      final controller = GameController(
        initialLevel: level,
        storage: storage,
        sound: sound,
        haptic: haptic,
        escapeDelay: Duration.zero,
      );

      // Miss 1
      await controller.onArrowTapped(blocked);
      expect(controller.hearts, equals(2));
      controller.clearFeedbackAndUnlock();

      // Miss 2
      await controller.onArrowTapped(blocked);
      expect(controller.hearts, equals(1));
      controller.clearFeedbackAndUnlock();

      // Miss 3 -> Game Over
      await controller.onArrowTapped(blocked);
      expect(controller.hearts, equals(0));
      expect(controller.isGameOver, isTrue);

      // Subsequent taps are blocked while game over
      await controller.onArrowTapped(blocker);
      expect(controller.hearts, equals(0)); // Never negative
    });

    test(
      'Retrying level restores 3 full hearts and resets move counter',
      () async {
        const blocked = Arrow(
          id: 'blk',
          path: [GridPosition(1, 1)],
          exitDirection: ArrowDirection.right,
        );
        const blocker = Arrow(
          id: 'obs',
          path: [GridPosition(1, 2)],
          exitDirection: ArrowDirection.down,
        );
        final board = Board(rows: 4, cols: 4, arrows: [blocked, blocker]);
        final level = Level(
          id: 1,
          title: 'Test',
          board: board,
          tier: LevelTier.beginner,
          targetMoves: 2,
        );
        final controller = GameController(
          initialLevel: level,
          storage: storage,
          sound: sound,
          haptic: haptic,
          escapeDelay: Duration.zero,
        );

        await controller.onArrowTapped(blocked);
        expect(controller.hearts, equals(2));

        controller.retryLevel();
        expect(controller.hearts, equals(3));
        expect(controller.movesCount, equals(0));
        expect(controller.isGameOver, isFalse);
      },
    );

    test(
      'Undo reverses move without restoring hearts lost on mistakes',
      () async {
        const a1 = Arrow(
          id: 'a1',
          path: [GridPosition(0, 0)],
          exitDirection: ArrowDirection.up,
        );
        const blocked = Arrow(
          id: 'blk',
          path: [GridPosition(1, 1)],
          exitDirection: ArrowDirection.right,
        );
        const blocker = Arrow(
          id: 'obs',
          path: [GridPosition(1, 2)],
          exitDirection: ArrowDirection.down,
        );
        final board = Board(rows: 4, cols: 4, arrows: [a1, blocked, blocker]);
        final level = Level(
          id: 1,
          title: 'Test',
          board: board,
          tier: LevelTier.beginner,
          targetMoves: 3,
        );
        final controller = GameController(
          initialLevel: level,
          storage: storage,
          sound: sound,
          haptic: haptic,
          escapeDelay: Duration.zero,
        );

        // 1. Make an invalid tap -> lose 1 heart
        await controller.onArrowTapped(blocked);
        expect(controller.hearts, equals(2));
        controller.clearFeedbackAndUnlock();

        // 2. Make a valid move with a1
        await controller.onArrowTapped(a1);
        expect(controller.remainingArrowsCount, equals(2));
        expect(controller.hearts, equals(2));

        // 3. Undo valid move
        controller.undo();
        expect(controller.remainingArrowsCount, equals(3));
        // Heart remains 2 (undo does not forgive invalid move penalty)
        expect(controller.hearts, equals(2));
      },
    );
  });

  group('Storage & Persistence', () {
    late StorageService storage;

    setUp(() {
      storage = StorageService(null);
    });

    test('Default values on fresh install', () {
      expect(storage.getHighestUnlockedLevel(), equals(1));
      expect(storage.getCompletedLevels(), isEmpty);
      expect(storage.isSoundEnabled(), isTrue);
      expect(storage.isHapticEnabled(), isTrue);
      expect(storage.getHintCount(), equals(2)); // starter allowance
      expect(storage.isTutorialCompleted(), isFalse);
      expect(storage.getDailyStreak(), equals(0));
      expect(storage.isFirstLaunchCompleted(), isFalse);
    });

    test('Marking level completed unlocks next level', () async {
      await storage.markLevelCompleted(1);
      expect(storage.isLevelCompleted(1), isTrue);
      expect(storage.getHighestUnlockedLevel(), equals(2));

      await storage.markLevelCompleted(2);
      expect(storage.isLevelCompleted(2), isTrue);
      expect(storage.getHighestUnlockedLevel(), equals(3));
    });

    test('Guest ID and First Launch persistence', () async {
      expect(storage.getGuestId(), isNull);
      await storage.setGuestId('guest_12345');
      expect(storage.getGuestId(), equals('guest_12345'));

      expect(storage.isFirstLaunchCompleted(), isFalse);
      await storage.setFirstLaunchCompleted(true);
      expect(storage.isFirstLaunchCompleted(), isTrue);
    });
  });

  group('Daily Challenge', () {
    test('Deterministic puzzle generation for identical dates', () {
      final dateA = DateTime(2026, 10, 24);
      final dateB = DateTime(2026, 10, 24);

      final levelA = DailyChallengeService.getDailyChallenge(dateA);
      final levelB = DailyChallengeService.getDailyChallenge(dateB);

      expect(levelA.board.arrows.length, equals(levelB.board.arrows.length));
      for (int i = 0; i < levelA.board.arrows.length; i++) {
        expect(levelA.board.arrows[i].id, equals(levelB.board.arrows[i].id));
        expect(
          levelA.board.arrows[i].exitDirection,
          equals(levelB.board.arrows[i].exitDirection),
        );
      }
    });

    test('Daily challenge is verified solvable by PuzzleSolver', () {
      final dates = [
        DateTime(2026, 1, 1),
        DateTime(2026, 6, 15),
        DateTime(2026, 10, 24),
        DateTime(2026, 12, 31),
      ];

      for (final date in dates) {
        final level = DailyChallengeService.getDailyChallenge(date);
        final solveResult = PuzzleSolver.solve(level.board);
        expect(
          solveResult.isSolvable,
          isTrue,
          reason: 'Daily challenge on $date is not solvable',
        );
        expect(
          level.board.getEscapableArrows().isNotEmpty,
          isTrue,
          reason: 'Daily challenge on $date has no valid first move',
        );
      }
    });
  });
}
