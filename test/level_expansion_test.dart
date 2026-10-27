import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:arrow_escape/core/audio/haptic_service.dart';
import 'package:arrow_escape/core/audio/sound_service.dart';
import 'package:arrow_escape/core/storage/progress_snapshot.dart';
import 'package:arrow_escape/core/storage/storage_service.dart';
import 'package:arrow_escape/game/difficulty.dart';
import 'package:arrow_escape/game/game_controller.dart';
import 'package:arrow_escape/game/level_generator.dart';
import 'package:arrow_escape/game/level_pack.dart';
import 'package:arrow_escape/game/level_validation.dart';
import 'package:arrow_escape/game/levels_data.dart';
import 'package:arrow_escape/game/puzzle_solver.dart';
import 'package:arrow_escape/models/board_model.dart';

int _fnv(String s) {
  var h = 0xcbf29ce484222325;
  for (final c in utf8.encode(s)) {
    h ^= c;
    h = (h * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
  }
  return h;
}

String _fingerprint(Board b) =>
    _fnv(jsonEncode(b.toJson())).toUnsigned(64).toRadixString(16);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LevelPack pack;
  const total = LevelsRepository.totalLevels;

  setUpAll(() {
    final text = File(LevelPack.assetPath).readAsStringSync();
    pack = LevelPack.parse(text);
    LevelsRepository.usePack(text);
  });

  group('Level catalogue', () {
    test('has exactly levels 1..1000 with no gaps', () {
      expect(total, 1000);
      expect(pack.length, total);
      expect(pack.ids.toSet(), {for (var i = 1; i <= total; i++) i});
      expect(LevelsRepository.chapterCount, 20);
      expect(LevelsRepository.chapterOf(1), 0);
      expect(LevelsRepository.chapterOf(50), 0);
      expect(LevelsRepository.chapterOf(51), 1);
      expect(LevelsRepository.chapterOf(1000), 19);
    });

    test('the original first 100 levels are unchanged', () {
      final expected = {
        for (final line in File(
          'test/fixtures/first_100_levels.fnv',
        ).readAsLinesSync().where((l) => !l.startsWith('#')))
          int.parse(line.split(' ')[0]): line.split(' ')[1],
      };
      expect(expected.length, 100);
      for (var id = 1; id <= 100; id++) {
        expect(
          _fingerprint(LevelGenerator.generateLevel(id).board),
          expected[id],
          reason: 'generator changed level $id',
        );
        expect(
          _fingerprint(LevelsRepository.getLevel(id).board),
          expected[id],
          reason: 'pack/repository changed level $id',
        );
      }
    });

    test('every level is valid, solvable and has a legal first hint', () {
      for (var id = 1; id <= total; id++) {
        final board = pack.board(id)!;
        expect(LevelValidation.problems(board), isEmpty, reason: 'Level $id');
        final hint = PuzzleSolver.getHint(board);
        expect(hint, isNotNull, reason: 'Level $id');
        expect(board.checkEscape(hint!.arrow).canEscape, isTrue);
      }
    });

    test('no duplicates, even rotated or mirrored', () {
      final seen = <String, int>{};
      for (var id = 1; id <= total; id++) {
        final key = LevelValidation.canonicalKey(pack.board(id)!);
        expect(seen[key], isNull, reason: 'Level $id duplicates ${seen[key]}');
        seen[key] = id;
      }
    });

    test('pack metadata matches the solver for every level', () {
      for (var id = 1; id <= total; id++) {
        final info = pack.info(id)!;
        final board = pack.board(id)!;
        final a = PuzzleSolver.analyze(board);
        expect(info.arrows, a.arrowCount, reason: 'Level $id');
        expect(info.depth, a.depth, reason: 'Level $id');
        expect(info.rows, board.rows);
        expect(info.cols, board.cols);
        expect(info.difficulty, Difficulty.of(board), reason: 'Level $id');
      }
    });

    test('pack reproduces the deterministic generator', () {
      final sample = [
        for (var id = 4; id <= total; id += 37) id,
        for (var id = 101; id <= 110; id++) id,
        for (var id = 990; id <= total; id++) id,
      ];
      for (final id in sample) {
        expect(
          jsonEncode(pack.board(id)!.toJson()),
          jsonEncode(LevelGenerator.generateLevel(id).board.toJson()),
          reason: 'Level $id differs from generator: regenerate the pack',
        );
      }
    });

    test('tutorial levels keep their handcrafted ids and messages', () {
      expect(
        LevelsRepository.getLevel(2).board.arrowById('t2_blocker'),
        isNotNull,
      );
      expect(LevelsRepository.getLevel(1).tutorialMessage, isNotNull);
    });
  });

  group('Difficulty progression', () {
    test('levels 101-1000 match their configured band', () {
      for (var id = 101; id <= total; id++) {
        final band = pack.info(id)!.difficulty;
        expect(band, LevelGenerator.targetBandFor(id), reason: 'Level $id');
      }
    });

    test('breathers are exactly one band easier than planned', () {
      for (var id = 105; id <= total; id += 10) {
        expect(LevelGenerator.isBreather(id), isTrue);
        expect(
          pack.info(id)!.difficulty.index,
          Difficulty.plannedFor(id).index - 1,
          reason: 'Level $id',
        );
      }
    });

    test('difficulty rises chapter by chapter without big jumps', () {
      double chapterScore(int c) {
        final ids = [
          for (var id = c * 50 + 1; id <= c * 50 + 50; id++)
            if (!LevelGenerator.isBreather(id)) id,
        ];
        return ids.map((id) => pack.info(id)!.score).reduce((a, b) => a + b) /
            ids.length;
      }

      var previous = chapterScore(2); // levels 101-150
      for (var c = 3; c < LevelsRepository.chapterCount; c++) {
        final s = chapterScore(c);
        expect(s, greaterThanOrEqualTo(previous - 0.5), reason: 'chapter $c');
        expect(s - previous, lessThan(6), reason: 'jump into chapter $c');
        previous = s;
      }
      expect(pack.info(1000)!.score, greaterThan(pack.info(101)!.score + 25));
    });

    test('boards stay phone-sized and vary in size and arrow count', () {
      final sizes = <String>{};
      final arrowCounts = <int>{};
      for (var id = 101; id <= total; id++) {
        final info = pack.info(id)!;
        expect(info.rows, lessThanOrEqualTo(LevelValidation.maxRows));
        expect(info.cols, lessThanOrEqualTo(LevelValidation.maxCols));
        sizes.add('${info.rows}x${info.cols}');
        arrowCounts.add(info.arrows);
      }
      expect(sizes.length, greaterThan(15));
      expect(arrowCounts.length, greaterThan(50));
    });
  });

  group('Gameplay on new levels', () {
    test('following hints clears new levels without a mistake', () async {
      final storage = StorageService(null);
      await storage.setHintCount(100000);
      for (final id in [150, 333, 777, 1000]) {
        final c = GameController(
          initialLevel: LevelsRepository.getLevel(id),
          storage: storage,
          sound: SoundService(storage),
          haptic: HapticService(storage),
          escapeDelay: Duration.zero,
        );
        var guard = 0;
        while (!c.isWon) {
          expect(await c.requestHint(), isTrue, reason: 'Level $id');
          await c.onArrowTapped(c.hintedArrow!);
          expect(c.hearts, 3, reason: 'Level $id');
          expect(++guard, lessThan(500));
        }
        c.dispose();
      }
    });

    test('completing level 1000 finishes the campaign cleanly', () async {
      final storage = StorageService(null);
      final level = LevelsRepository.getLevel(1000);
      final c = GameController(
        initialLevel: level,
        storage: storage,
        sound: SoundService(storage),
        haptic: HapticService(storage),
        escapeDelay: Duration.zero,
      );
      for (final a in PuzzleSolver.solve(level.board).solutionSteps) {
        await c.onArrowTapped(a);
      }
      expect(c.isWon, isTrue);
      expect(storage.isLevelCompleted(1000), isTrue);
      expect(storage.getHighestUnlockedLevel(), 1001);
      expect(storage.getCurrentLevel(), 1000);
    });
  });

  group('Saved progress', () {
    test('players who finished the old level 100 continue at 101', () async {
      SharedPreferences.setMockInitialValues({
        'current_level': 100,
        'highest_unlocked_level': 101,
        'completed_levels_list': [for (var i = 1; i <= 100; i++) '$i'],
      });
      final prefs = await SharedPreferences.getInstance();
      final storage = StorageService(prefs);
      expect(storage.getCurrentLevel(), 101);
      expect(storage.getCompletedLevels().length, 100);
      // Runs once: a later "Restart Game" is not undone.
      await storage.setCurrentLevel(100);
      expect(StorageService(prefs).getCurrentLevel(), 100);
    });

    test('other players keep exactly where they were', () async {
      SharedPreferences.setMockInitialValues({
        'current_level': 37,
        'highest_unlocked_level': 52,
        'completed_levels_list': [for (var i = 1; i <= 51; i++) '$i'],
      });
      final storage = StorageService(await SharedPreferences.getInstance());
      expect(storage.getCurrentLevel(), 37);
      expect(storage.getHighestUnlockedLevel(), 52);
    });

    test(
      'progress beyond level 100 round-trips through the cloud format',
      () async {
        final storage = StorageService(null);
        for (var i = 1; i <= 640; i++) {
          await storage.markLevelCompleted(i);
        }
        final restored = ProgressSnapshot.fromFirestore(
          ProgressSnapshot.fromStorage(storage).toFirestore(),
        );
        expect(restored.highestUnlocked, 641);
        expect(restored.completedLevels.length, 640);

        // An older cloud copy (stuck at 100) never lowers newer local progress.
        final old = StorageService(null);
        for (var i = 1; i <= 100; i++) {
          await old.markLevelCompleted(i);
        }
        final merged = ProgressSnapshot.fromStorage(storage)
            .merge(ProgressSnapshot.fromStorage(old));
        expect(merged.highestUnlocked, 641);
        expect(merged.completedLevels.length, 640);
      },
    );
  });
}
