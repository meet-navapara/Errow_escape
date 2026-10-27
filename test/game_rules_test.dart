import 'package:flutter_test/flutter_test.dart';

import 'support/level_pack_loader.dart';

import 'package:arrow_escape/core/audio/haptic_service.dart';
import 'package:arrow_escape/core/audio/sound_service.dart';
import 'package:arrow_escape/core/storage/storage_service.dart';
import 'package:arrow_escape/game/game_controller.dart';
import 'package:arrow_escape/game/levels_data.dart';
import 'package:arrow_escape/game/puzzle_solver.dart';
import 'package:arrow_escape/models/arrow_model.dart';
import 'package:arrow_escape/models/board_model.dart';
import 'package:arrow_escape/models/level_model.dart';

void main() {
  setUpAll(loadLevelPack);

  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageService storage;

  GameController controllerFor(
    Level level, {
    Duration escapeDelay = Duration.zero,
  }) => GameController(
    initialLevel: level,
    storage: storage,
    sound: SoundService(storage),
    haptic: HapticService(storage),
    escapeDelay: escapeDelay,
  );

  Level levelOf(
    List<Arrow> arrows, {
    int id = 50,
    int rows = 5,
    int cols = 5,
  }) => Level(
    id: id,
    title: 'Test',
    board: Board(rows: rows, cols: cols, arrows: arrows),
    tier: LevelTier.medium,
    targetMoves: arrows.length,
  );

  // a2 blocks a1 (a1 points right into a2's column).
  const a1 = Arrow(
    id: 'a1',
    path: [GridPosition(2, 0), GridPosition(2, 1)],
    exitDirection: ArrowDirection.right,
  );
  const a2 = Arrow(
    id: 'a2',
    path: [GridPosition(1, 3), GridPosition(2, 3)],
    exitDirection: ArrowDirection.down,
  );
  const free = Arrow(
    id: 'free',
    path: [GridPosition(0, 1), GridPosition(0, 0)],
    exitDirection: ArrowDirection.left,
  );

  setUp(() => storage = StorageService(null));

  group('Escape rules', () {
    test('the whole ray is checked, not just the adjacent cell', () {
      // Blocker sits three cells ahead of the head.
      const far = Arrow(
        id: 'far',
        path: [GridPosition(0, 4), GridPosition(1, 4)],
        exitDirection: ArrowDirection.down,
      );
      const shooter = Arrow(
        id: 'shooter',
        path: [GridPosition(1, 0), GridPosition(1, 1)],
        exitDirection: ArrowDirection.right,
      );
      final board = Board(rows: 5, cols: 5, arrows: [far, shooter]);
      final check = board.checkEscape(shooter);
      expect(check.canEscape, isFalse);
      expect(check.blocker?.id, 'far');
    });

    test('a valid move removes exactly the selected arrow', () async {
      final c = controllerFor(levelOf([a1, a2, free]));
      await c.onArrowTapped(free);
      expect(c.board.arrows.map((a) => a.id), unorderedEquals(['a1', 'a2']));
      expect(c.hearts, 3);
    });

    test(
      'a blocked move removes nothing and costs exactly one heart',
      () async {
        final c = controllerFor(levelOf([a1, a2, free]));
        await c.onArrowTapped(a1);
        expect(c.board.arrows.length, 3);
        expect(c.hearts, 2);
        expect(c.blockerArrow?.id, 'a2');
      },
    );

    test('rapid repeated blocked taps only cost one heart', () async {
      final c = controllerFor(levelOf([a1, a2, free]));
      await c.onArrowTapped(a1);
      await c.onArrowTapped(a1);
      await c.onArrowTapped(a1);
      expect(c.hearts, 2);
      c.clearFeedbackAndUnlock();
    });

    test('an arrow that is animating out no longer blocks others', () async {
      final c = controllerFor(
        levelOf([a1, a2, free]),
        escapeDelay: const Duration(milliseconds: 80),
      );
      final first = c.onArrowTapped(a2);
      expect(c.isArrowEscaping('a2'), isTrue);
      // a1 was blocked by a2, which is mid-animation: must be a valid move.
      final second = c.onArrowTapped(a1);
      await Future.wait([first, second]);
      expect(c.hearts, 3);
      expect(c.board.arrows.map((a) => a.id), ['free']);
    });

    test('taps on stale arrows that already left are ignored', () async {
      final c = controllerFor(levelOf([a1, a2, free]));
      await c.onArrowTapped(free);
      await c.onArrowTapped(free);
      expect(c.hearts, 3);
      expect(c.movesCount, 1);
    });

    test(
      'undo restores the arrow but not lost hearts; restart restores both',
      () async {
        final c = controllerFor(levelOf([a1, a2, free]));
        await c.onArrowTapped(a1); // mistake
        c.clearFeedbackAndUnlock();
        await c.onArrowTapped(free);
        c.undo();
        expect(c.board.arrowById('free'), isNotNull);
        expect(c.hearts, 2);

        await storage.markLevelCompleted(10);
        c.restart();
        expect(c.hearts, 3);
        expect(c.board.arrows.length, 3);
        expect(c.canUndo, isFalse);
        // Restarting a level never touches overall progress.
        expect(storage.isLevelCompleted(10), isTrue);
        expect(storage.getHighestUnlockedLevel(), 11);
      },
    );
  });

  group('Level completion', () {
    test('completes only after the last arrow, then saves progress', () async {
      final level = LevelsRepository.getLevel(4);
      final c = controllerFor(level);
      final order = PuzzleSolver.solve(level.board).solutionSteps;

      for (var i = 0; i < order.length; i++) {
        expect(c.isWon, isFalse, reason: 'won before clearing every arrow');
        await c.onArrowTapped(order[i]);
      }
      expect(c.board.isCompleted, isTrue);
      expect(c.isWon, isTrue);
      expect(c.hearts, 3);
      expect(storage.isLevelCompleted(4), isTrue);
      expect(storage.getHighestUnlockedLevel(), 5);
    });

    test('win waits for the final escape animation', () async {
      final c = controllerFor(
        levelOf([free]),
        escapeDelay: const Duration(milliseconds: 60),
      );
      final pending = c.onArrowTapped(free);
      expect(c.board.isCompleted, isTrue);
      expect(c.isWon, isFalse);
      expect(c.canUndo, isFalse);
      await pending;
      expect(c.isWon, isTrue);
    });

    test('restart during the final animation cancels the win', () async {
      final c = controllerFor(
        levelOf([free]),
        escapeDelay: const Duration(milliseconds: 60),
      );
      final pending = c.onArrowTapped(free);
      c.restart();
      await pending;
      expect(c.isWon, isFalse);
      expect(c.board.arrows.length, 1);
      expect(storage.isLevelCompleted(50), isFalse);
    });

    test('finishing level 3 marks the tutorial as complete', () async {
      final level = LevelsRepository.getLevel(3);
      final c = controllerFor(level);
      for (final a in PuzzleSolver.solve(level.board).solutionSteps) {
        await c.onArrowTapped(a);
      }
      expect(storage.isTutorialCompleted(), isTrue);
    });
  });

  group('Hints', () {
    test('highlight a legal move without moving or costing hearts', () async {
      final c = controllerFor(levelOf([a1, a2, free]));
      final before = storage.getHintCount();
      expect(await c.requestHint(), isTrue);
      final hinted = c.hintedArrow!;
      expect(c.board.checkEscape(hinted).canEscape, isTrue);
      expect(c.board.arrows.length, 3);
      expect(c.hearts, 3);
      expect(storage.getHintCount(), before - 1);
      expect(c.hintText, contains(hinted.exitDirection.displayName));
    });

    test('repeated or concurrent taps consume only one hint', () async {
      final c = controllerFor(levelOf([a1, a2, free]));
      final before = storage.getHintCount();
      await Future.wait([c.requestHint(), c.requestHint(), c.requestHint()]);
      expect(storage.getHintCount(), before - 1);
      await c.requestHint(); // hint still showing -> re-shown for free
      expect(storage.getHintCount(), before - 1);
    });

    test('with no hints left nothing is consumed or highlighted', () async {
      await storage.setHintCount(0);
      final c = controllerFor(levelOf([a1, a2, free]));
      expect(await c.requestHint(), isFalse);
      expect(c.hintedArrow, isNull);
      expect(storage.getHintCount(), 0);
    });

    test(
      'a deadlocked board reports a validation error, not a fake hint',
      () async {
        const left = Arrow(
          id: 'l',
          path: [GridPosition(1, 0), GridPosition(1, 1)],
          exitDirection: ArrowDirection.right,
        );
        const right = Arrow(
          id: 'r',
          path: [GridPosition(1, 3), GridPosition(1, 2)],
          exitDirection: ArrowDirection.left,
        );
        final c = controllerFor(levelOf([left, right], rows: 3, cols: 4));
        final before = storage.getHintCount();
        expect(await c.requestHint(), isFalse);
        expect(c.hintedArrow, isNull);
        expect(c.feedbackMessage, contains('Level error'));
        expect(storage.getHintCount(), before);
      },
    );

    test(
      'following hints alone clears whole levels without a mistake',
      () async {
        await storage.setHintCount(100000);
        for (final id in [4, 9, 23, 47, 66, 91, 100]) {
          final c = controllerFor(LevelsRepository.getLevel(id));
          var guard = 0;
          while (!c.isWon) {
            expect(await c.requestHint(), isTrue, reason: 'Level $id');
            final hinted = c.hintedArrow!;
            expect(c.board.checkEscape(hinted).canEscape, isTrue);
            await c.onArrowTapped(hinted);
            expect(c.hearts, 3, reason: 'Level $id hint led to a blocked move');
            expect(++guard, lessThan(500));
          }
        }
      },
    );
  });
}
