import 'package:flutter_test/flutter_test.dart';

import 'support/level_pack_loader.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:arrow_escape/core/ads/ad_service.dart';
import 'package:arrow_escape/core/audio/haptic_service.dart';
import 'package:arrow_escape/core/audio/sound_service.dart';
import 'package:arrow_escape/core/storage/storage_service.dart';
import 'package:arrow_escape/game/game_controller.dart';
import 'package:arrow_escape/game/levels_data.dart';
import 'package:arrow_escape/game/play_context.dart';
import 'package:arrow_escape/game/puzzle_solver.dart';
import 'package:arrow_escape/models/arrow_model.dart';
import 'package:arrow_escape/models/board_model.dart';
import 'package:arrow_escape/models/level_model.dart';
import 'package:arrow_escape/models/power_up.dart';

/// Scripted ad provider; counts how often an ad was requested.
class FakeAds implements RewardedAdProvider {
  RewardedAdOutcome outcome;
  int shown = 0;
  Duration delay;
  FakeAds(this.outcome, {this.delay = Duration.zero});

  @override
  Future<RewardedAdOutcome> showRewarded() async {
    shown++;
    await Future.delayed(delay);
    return outcome;
  }
}

void main() {
  setUpAll(loadLevelPack);

  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageService storage;

  // a2 blocks a1; `free` is independent.
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

  Level level([List<Arrow> arrows = const [a1, a2, free]]) => Level(
    id: 40,
    title: 'Test',
    board: Board(rows: 5, cols: 5, arrows: arrows),
    tier: LevelTier.medium,
    targetMoves: arrows.length,
  );

  GameController controllerFor(
    Level l, {
    RewardedAdProvider? ads,
    PlayContext? context,
  }) => GameController(
    initialLevel: l,
    storage: storage,
    sound: SoundService(storage),
    haptic: HapticService(storage),
    escapeDelay: Duration.zero,
    ads: ads ?? const NoRewardedAds(),
    context: context,
  );

  setUp(() => storage = StorageService(null));

  group('Starter allowance', () {
    test('new players get exactly two of each, granted once', () async {
      for (final t in PowerUpType.values) {
        expect(storage.getPowerUpBalance(t), PowerUpType.starterAllowance);
      }
      await storage.ensureStarterPowerUps();
      await storage.ensureStarterPowerUps();
      for (final t in PowerUpType.values) {
        expect(storage.getPowerUpBalance(t), 2, reason: t.name);
        expect(storage.getPowerUpGranted(t), 2, reason: t.name);
      }
    });

    test('resetting progress does not re-grant the allowance', () async {
      await storage.ensureStarterPowerUps();
      await storage.consumePowerUp(PowerUpType.eraser);
      await storage.consumePowerUp(PowerUpType.eraser);
      await storage.resetAllProgress();
      await storage.ensureStarterPowerUps();
      expect(storage.getPowerUpBalance(PowerUpType.eraser), 0);
      expect(storage.getHighestUnlockedLevel(), 1);
    });

    test('persists across app restarts (SharedPreferences)', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final first = StorageService(prefs);
      await first.ensureStarterPowerUps();
      await first.consumePowerUp(PowerUpType.wand);

      final restarted = StorageService(prefs);
      await restarted.ensureStarterPowerUps();
      expect(restarted.getPowerUpBalance(PowerUpType.wand), 1);
      expect(restarted.getPowerUpBalance(PowerUpType.hint), 2);
    });

    test('players from the old version keep their hint balance', () async {
      SharedPreferences.setMockInitialValues({'hint_count': 7});
      final migrated = StorageService(await SharedPreferences.getInstance());
      await migrated.ensureStarterPowerUps();
      expect(migrated.getHintCount(), 7);
      expect(migrated.getPowerUpBalance(PowerUpType.eraser), 2);
    });
  });

  group('Eraser', () {
    test(
      'arming it is free; removing a blocked arrow costs one use only',
      () async {
        final c = controllerFor(level());
        expect(c.activateTool(PowerUpType.eraser), isTrue);
        expect(c.activeTool, PowerUpType.eraser);
        expect(storage.getPowerUpBalance(PowerUpType.eraser), 2);

        await c.onArrowTapped(a1); // blocked, but erased
        expect(c.board.arrowById('a1'), isNull);
        expect(c.hearts, 3);
        expect(c.activeTool, isNull);
        expect(storage.getPowerUpBalance(PowerUpType.eraser), 1);

        c.undo();
        expect(c.board.arrowById('a1'), isNotNull);
        expect(storage.getPowerUpBalance(PowerUpType.eraser), 1);
      },
    );

    test('tapping the button again disarms without using it', () {
      final c = controllerFor(level());
      c.activateTool(PowerUpType.eraser);
      c.activateTool(PowerUpType.eraser);
      expect(c.activeTool, isNull);
      expect(storage.getPowerUpBalance(PowerUpType.eraser), 2);
    });

    test('erasing the last arrow completes the level normally', () async {
      final c = controllerFor(level([a1]));
      c.activateTool(PowerUpType.eraser);
      await c.onArrowTapped(a1);
      expect(c.isWon, isTrue);
      expect(storage.isLevelCompleted(40), isTrue);
    });

    test('cannot be armed with no uses left', () async {
      await storage.ensureStarterPowerUps();
      await storage.consumePowerUp(PowerUpType.eraser);
      await storage.consumePowerUp(PowerUpType.eraser);
      final c = controllerFor(level());
      expect(c.activateTool(PowerUpType.eraser), isFalse);
      expect(c.activeTool, isNull);
    });
  });

  group('Magic Wand', () {
    test('launches only free arrows, as one undoable move', () async {
      final c = controllerFor(level());
      expect(await c.useWand(), isTrue);
      // a2 and free were free; a1 was blocked by a2.
      expect(c.board.arrows.map((a) => a.id), ['a1']);
      expect(c.hearts, 3);
      expect(storage.getPowerUpBalance(PowerUpType.wand), 1);
      c.undo();
      expect(c.board.arrows.length, 3);
    });

    test('never removes more than the wand limit', () async {
      final board = LevelsRepository.getLevel(60).board;
      final freeCount = board.getEscapableArrows().length;
      final c = controllerFor(
        Level(
          id: 60,
          title: 'L60',
          board: board,
          tier: LevelTier.hard,
          targetMoves: 0,
        ),
      );
      await c.useWand();
      expect(
        board.arrows.length - c.board.arrows.length,
        freeCount < PowerUpType.wandLimit ? freeCount : PowerUpType.wandLimit,
      );
      expect(PuzzleSolver.isSolvable(c.board), isTrue);
    });
  });

  group('Path Scanner', () {
    test(
      'reports blockers without moving anything or costing hearts',
      () async {
        final c = controllerFor(level());
        c.activateTool(PowerUpType.scanner);
        await c.onArrowTapped(a1);
        expect(c.scanResult!.arrow.id, 'a1');
        expect(c.scanResult!.blockers.map((a) => a.id), ['a2']);
        expect(c.scanResult!.isClear, isFalse);
        expect(c.board.arrows.length, 3);
        expect(c.hearts, 3);
        expect(storage.getPowerUpBalance(PowerUpType.scanner), 1);

        c.activateTool(PowerUpType.scanner);
        await c.onArrowTapped(free);
        expect(c.scanResult!.isClear, isTrue);
        c.dispose();
      },
    );
  });

  group('Rewarded ads', () {
    test('grant one use only when the SDK confirms the reward', () async {
      final ads = FakeAds(RewardedAdOutcome.rewarded);
      final c = controllerFor(level(), ads: ads);
      final before = storage.getPowerUpBalance(PowerUpType.eraser);
      expect(
        await c.earnWithAd(PowerUpType.eraser),
        RewardedAdOutcome.rewarded,
      );
      expect(storage.getPowerUpBalance(PowerUpType.eraser), before + 1);
      c.dispose();
    });

    for (final outcome in [
      RewardedAdOutcome.dismissed,
      RewardedAdOutcome.failed,
      RewardedAdOutcome.unavailable,
    ]) {
      test('no reward when the ad is ${outcome.name}', () async {
        final c = controllerFor(level(), ads: FakeAds(outcome));
        final before = storage.getPowerUpBalance(PowerUpType.hint);
        expect(await c.earnWithAd(PowerUpType.hint), outcome);
        expect(storage.getPowerUpBalance(PowerUpType.hint), before);
      });
    }

    test('repeated taps while an ad is showing cannot double-reward', () async {
      final ads = FakeAds(
        RewardedAdOutcome.rewarded,
        delay: const Duration(milliseconds: 20),
      );
      final c = controllerFor(level(), ads: ads);
      final before = storage.getPowerUpBalance(PowerUpType.wand);
      await Future.wait([
        c.earnWithAd(PowerUpType.wand),
        c.earnWithAd(PowerUpType.wand),
        c.earnWithAd(PowerUpType.wand),
      ]);
      expect(ads.shown, 1);
      expect(storage.getPowerUpBalance(PowerUpType.wand), before + 1);
      c.dispose();
    });

    test('the default provider (no ads configured) never rewards', () async {
      expect(
        await const NoRewardedAds().showRewarded(),
        RewardedAdOutcome.unavailable,
      );
    });
  });

  group('Free tutorial hint', () {
    test('does not consume a hint', () async {
      final c = controllerFor(level());
      expect(await c.requestHint(free: true), isTrue);
      expect(c.hintedArrow, isNotNull);
      expect(storage.getHintCount(), 2);
      c.dispose();
    });
  });

  group('Daily reward', () {
    test(
      'a date pays its bonus hint once, however often it is replayed',
      () async {
        const key = '2026-10-27';
        for (var i = 0; i < 3; i++) {
          final c = controllerFor(
            level([free]),
            context: const PlayContext.daily(key),
          );
          await c.onArrowTapped(free);
          expect(c.isWon, isTrue);
        }
        expect(storage.getHintCount(), 3); // 2 starter + 1 daily bonus
        expect(storage.isDailyCompleted(key), isTrue);
        expect(storage.getDailyResults()[key]!.hearts, 3);
      },
    );
  });
}
