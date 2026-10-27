import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'support/level_pack_loader.dart';

import 'package:arrow_escape/game/daily_challenge_service.dart';
import 'package:arrow_escape/game/level_generator.dart';
import 'package:arrow_escape/game/levels_data.dart';
import 'package:arrow_escape/game/puzzle_solver.dart';
import 'package:arrow_escape/models/arrow_model.dart';
import 'package:arrow_escape/models/board_model.dart';
import 'package:arrow_escape/models/level_model.dart';

/// Structural checks every playable board must pass.
void expectWellFormed(Board board, String label, {bool allowSingles = false}) {
  final seen = <GridPosition>{};
  for (final arrow in board.arrows) {
    expect(arrow.path, isNotEmpty, reason: '$label ${arrow.id} empty');
    if (!allowSingles) {
      expect(
        arrow.length,
        greaterThanOrEqualTo(2),
        reason: '$label ${arrow.id} is a single point',
      );
    }
    for (var i = 0; i < arrow.path.length; i++) {
      final p = arrow.path[i];
      expect(board.isWithinBounds(p), isTrue, reason: '$label $p outside');
      expect(seen.add(p), isTrue, reason: '$label overlapping cell $p');
      if (i > 0) {
        final q = arrow.path[i - 1];
        expect(
          (p.row - q.row).abs() + (p.col - q.col).abs(),
          equals(1),
          reason: '$label ${arrow.id} has a gap between $q and $p',
        );
      }
    }
    if (arrow.length >= 2) {
      final prev = arrow.path[arrow.length - 2];
      final head = arrow.headCell;
      expect(
        (head.row - prev.row, head.col - prev.col),
        equals((arrow.exitDirection.dRow, arrow.exitDirection.dCol)),
        reason: '$label ${arrow.id} head does not continue its last segment',
      );
    }
  }
}

void main() {
  setUpAll(loadLevelPack);

  group('All campaign levels', () {
    late final List<Level> levels;
    // The original 100 levels (legacy tiers and silhouette masks apply).
    late final List<Level> legacy;
    setUpAll(() {
      levels = [
        for (var i = 1; i <= LevelsRepository.totalLevels; i++)
          LevelsRepository.getLevel(i),
      ];
      legacy = levels.take(LevelGenerator.legacyLevelCount).toList();
    });

    test('are solvable under the real game rules', () {
      for (final level in levels) {
        final result = PuzzleSolver.solve(level.board);
        expect(result.isSolvable, isTrue, reason: 'Level ${level.id}');
        expect(
          result.solutionSteps.length,
          equals(level.board.arrows.length),
          reason: 'Level ${level.id}',
        );
        expect(PuzzleSolver.analyze(level.board).isSolvable, isTrue);
      }
    });

    test('have well-formed, continuous, non-overlapping arrows', () {
      for (final level in levels) {
        expectWellFormed(level.board, 'Level ${level.id}');
      }
    });

    test('are never all-free: every non-intro level has dependencies', () {
      for (final level in levels.where((l) => l.id >= 2)) {
        final analysis = PuzzleSolver.analyze(level.board);
        expect(
          analysis.depth,
          greaterThanOrEqualTo(2),
          reason: 'Level ${level.id} has every arrow free immediately',
        );
        expect(
          analysis.initialMoves,
          lessThan(analysis.arrowCount),
          reason: 'Level ${level.id}',
        );
      }
    });

    test('fill their silhouettes densely', () {
      for (final level in legacy.where((l) => l.id >= 4)) {
        final spec = LevelGenerator.specForLevel(level.id);
        final mask = LevelGenerator.buildMask(spec.shape, spec.rows, spec.cols);
        final used = level.board.arrows.fold<int>(0, (s, a) => s + a.length);
        expect(
          used / mask.length,
          greaterThanOrEqualTo(0.85),
          reason: 'Level ${level.id} covers too little of its shape',
        );
      }
    });

    test('difficulty grows across tiers', () {
      double avg(LevelTier tier, num Function(Level) f) {
        final tierLevels = legacy.where((l) => l.tier == tier).toList();
        return tierLevels.map(f).reduce((a, b) => a + b) / tierLevels.length;
      }

      const order = [
        LevelTier.beginner,
        LevelTier.easy,
        LevelTier.medium,
        LevelTier.hard,
        LevelTier.expert,
      ];
      for (var i = 1; i < order.length; i++) {
        final prev = order[i - 1];
        final cur = order[i];
        expect(
          avg(cur, (l) => l.board.arrows.length),
          greaterThanOrEqualTo(avg(prev, (l) => l.board.arrows.length)),
          reason: '${cur.name} should have at least as many arrows',
        );
        expect(
          avg(cur, (l) => PuzzleSolver.analyze(l.board).blockingPairs),
          greaterThan(
            avg(prev, (l) => PuzzleSolver.analyze(l.board).blockingPairs),
          ),
          reason: '${cur.name} should have more blocking relationships',
        );
        expect(
          avg(cur, (l) => l.board.rows * l.board.cols),
          greaterThan(avg(prev, (l) => l.board.rows * l.board.cols)),
          reason: '${cur.name} should use larger boards',
        );
      }
    });

    test('use many different shapes and footprints', () {
      final shapes = {
        for (var i = 4; i <= 100; i++) LevelGenerator.shapeForLevel(i),
      };
      expect(shapes.length, equals(BoardShape.values.length));

      String footprint(Board b) {
        final cells = b.arrows.expand((a) => a.path).toSet();
        return '${b.rows}x${b.cols}:${cells.length}';
      }

      // Original levels change size or fill every level. Levels 101+ are
      // checked for true duplicates (rotation/reflection aware) instead.
      for (var i = 4; i < legacy.length; i++) {
        expect(
          footprint(legacy[i].board),
          isNot(equals(footprint(legacy[i - 1].board))),
          reason: 'Levels $i and ${i + 1} look identical',
        );
      }
    });

    test('are deterministic across regenerations', () {
      for (final id in [4, 6, 37, 99]) {
        final a = jsonEncode(LevelGenerator.generateLevel(id).board.toJson());
        final b = jsonEncode(LevelGenerator.generateLevel(id).board.toJson());
        expect(a, equals(b), reason: 'Level $id changed between generations');
      }
    });

    test('survive a JSON round trip unchanged', () {
      final level = levels[40];
      final restored = Level.fromJson(
        jsonDecode(jsonEncode(level.toJson())) as Map<String, dynamic>,
      );
      expect(
        jsonEncode(restored.board.toJson()),
        equals(jsonEncode(level.board.toJson())),
      );
    });
  });

  test('Heart mask has two lobes separated by a notch', () {
    final mask = LevelGenerator.buildMask(BoardShape.heart, 13, 14);
    final topRow = [
      for (var c = 0; c < 14; c++) mask.contains(GridPosition(0, c)),
    ];
    // Lobes on both sides, gap in the middle.
    expect(topRow.sublist(0, 7).contains(true), isTrue);
    expect(topRow.sublist(7).contains(true), isTrue);
    expect(topRow[6] || topRow[7], isFalse);
  });

  test('Daily challenges for a month are dense and solvable', () {
    for (var day = 1; day <= 30; day++) {
      final level = DailyChallengeService.getDailyChallenge(
        DateTime(2026, 11, day),
      );
      expectWellFormed(level.board, 'Daily $day');
      final analysis = PuzzleSolver.analyze(level.board);
      expect(analysis.isSolvable, isTrue, reason: 'Daily $day');
      expect(analysis.depth, greaterThanOrEqualTo(2), reason: 'Daily $day');
    }
  });
}
