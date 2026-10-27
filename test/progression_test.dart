import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/level_pack_loader.dart';

import 'package:arrow_escape/core/app_info.dart';
import 'package:arrow_escape/core/legal/legal_content.dart';
import 'package:arrow_escape/core/storage/storage_service.dart';
import 'package:arrow_escape/game/achievements.dart';
import 'package:arrow_escape/game/daily_challenge_service.dart';
import 'package:arrow_escape/game/difficulty.dart';
import 'package:arrow_escape/game/levels_data.dart';
import 'package:arrow_escape/game/puzzle_solver.dart';
import 'package:arrow_escape/game/weekly_challenge_service.dart';

void main() {
  setUpAll(loadLevelPack);

  late StorageService storage;
  setUp(() => storage = StorageService(null));

  group('Achievements', () {
    test('each unlocks exactly once', () async {
      await storage.markLevelCompleted(1);
      final first = await AchievementService.evaluate(storage);
      expect(first.map((a) => a.id), ['first_level']);
      expect(await AchievementService.evaluate(storage), isEmpty);
      expect(storage.getUnlockedAchievements(), {'first_level'});
    });

    test('event achievements need the event', () async {
      await AchievementService.evaluate(storage);
      expect(storage.getUnlockedAchievements(), isEmpty);
      final got = await AchievementService.evaluate(
        storage,
        const PlayEvent(flawless: true, usedPowerUp: true),
      );
      expect(
        got.map((a) => a.id),
        containsAll([
          AchievementService.flawlessId,
          AchievementService.powerUpId,
        ]),
      );
    });

    test('streak and weekly achievements follow stored history', () async {
      for (final d in ['2026-10-01', '2026-10-02', '2026-10-03']) {
        await storage.markDailyCompleted(d);
      }
      for (var i = 0; i < WeeklyChallengeService.puzzlesPerWeek; i++) {
        await storage.recordWeeklyResult('W2026-10-26', i, 300);
      }
      final ids = (await AchievementService.evaluate(storage)).map((a) => a.id);
      expect(
        ids,
        containsAll(['daily_first', 'daily_streak_3', 'weekly_complete']),
      );
      expect(ids, isNot(contains('daily_streak_7')));
    });

    test('every achievement is reachable (goal within game limits)', () {
      for (final a in AchievementService.all) {
        expect(a.goal, inInclusiveRange(1, LevelsRepository.totalLevels));
      }
      expect(
        AchievementService.all.map((a) => a.id).toSet().length,
        AchievementService.all.length,
      );
    });
  });

  group('Daily challenge', () {
    test('streak is computed from dates, in any completion order', () async {
      await storage.markDailyCompleted('2026-10-27');
      await storage.markDailyCompleted('2026-10-25');
      await storage.markDailyCompleted('2026-10-26');
      expect(storage.getDailyStreak(DateTime(2026, 10, 27)), 3);
      // Streak survives until today's puzzle is played...
      expect(storage.getDailyStreak(DateTime(2026, 10, 28)), 3);
      // ...and breaks after a missed day.
      expect(storage.getDailyStreak(DateTime(2026, 10, 30)), 0);
      expect(storage.getBestDailyStreak(), 3);
    });

    test('completing a date twice is recorded once', () async {
      await storage.markDailyCompleted('2026-10-27');
      await storage.markDailyCompleted('2026-10-27');
      expect(storage.getDailyCompletedDates(), {'2026-10-27'});
    });

    test('only better results replace the best result', () async {
      await storage.recordDailyResult(
        'd',
        const DailyResult(hearts: 2, moves: 9),
      );
      await storage.recordDailyResult(
        'd',
        const DailyResult(hearts: 1, moves: 3),
      );
      expect(storage.getDailyResults()['d']!.hearts, 2);
      await storage.recordDailyResult(
        'd',
        const DailyResult(hearts: 2, moves: 7),
      );
      expect(storage.getDailyResults()['d']!.moves, 7);
    });

    test('the same date always gives the same puzzle', () {
      final a = DailyChallengeService.getDailyChallenge(DateTime(2026, 10, 27));
      final b = DailyChallengeService.getDailyChallenge(
        DateTime(2026, 10, 27, 23),
      );
      expect(a.board.toJson(), b.board.toJson());
    });
  });

  group('Weekly challenge', () {
    test('weeks run Monday to Monday in local time', () {
      final wed = DateTime(2026, 10, 28, 15);
      expect(WeeklyChallengeService.weekStart(wed), DateTime(2026, 10, 26));
      expect(WeeklyChallengeService.weekEnd(wed), DateTime(2026, 11, 2));
      expect(
        WeeklyChallengeService.weekKey(DateTime(2026, 11, 1, 23)),
        WeeklyChallengeService.weekKey(DateTime(2026, 10, 26)),
      );
      expect(
        WeeklyChallengeService.timeRemaining(DateTime(2026, 11, 1, 12)),
        const Duration(hours: 12),
      );
    });

    test('all five puzzles are deterministic, solvable and get harder', () {
      final now = DateTime(2026, 10, 27);
      final areas = <int>[];
      for (var i = 0; i < WeeklyChallengeService.puzzlesPerWeek; i++) {
        final p = WeeklyChallengeService.getPuzzle(i, now);
        expect(
          p.board.toJson(),
          WeeklyChallengeService.getPuzzle(i, now).board.toJson(),
        );
        final analysis = PuzzleSolver.analyze(p.board);
        expect(analysis.isSolvable, isTrue, reason: 'puzzle $i');
        areas.add(p.board.rows * p.board.cols);
      }
      expect(areas.last, greaterThan(areas.first));
    });

    test('replays keep the best score', () async {
      await storage.recordWeeklyResult('W', 0, 300);
      await storage.recordWeeklyResult('W', 0, 100);
      expect(storage.getWeeklyResults()['W'], {0: 300});
      expect(WeeklyChallengeService.maxScore(), 1500);
    });
  });

  group('Difficulty badge', () {
    test('comes from solver metrics and rises across the campaign', () {
      final early = Difficulty.of(LevelsRepository.getLevel(4).board);
      final late = Difficulty.of(LevelsRepository.getLevel(98).board);
      expect(early.index, lessThan(late.index));
      expect(
        Difficulty.of(LevelsRepository.getLevel(1).board),
        Difficulty.beginner,
      );
      final labels = {
        for (var i = 1; i <= 100; i++)
          Difficulty.of(LevelsRepository.getLevel(i).board),
      };
      expect(labels.length, greaterThanOrEqualTo(3));
    });
  });

  group('Release metadata', () {
    test('AppInfo version matches pubspec.yaml', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(
        pubspec,
        contains('version: ${AppInfo.version}+${AppInfo.buildNumber}'),
      );
    });

    test('hosted legal pages are generated from the in-app text', () {
      for (final doc in LegalContent.all) {
        final html = File('hosting/public/${doc.slug}.html').readAsStringSync();
        for (final s in doc.sections) {
          expect(
            html,
            contains(s.heading.replaceAll("'", '&#39;')),
            reason:
                '${doc.slug} is stale: re-run tool/generate_legal_pages_test.dart',
          );
        }
      }
    });

    test('privacy policy discloses every SDK the app uses', () {
      final text = LegalContent.privacy.sections
          .expand((s) => s.paragraphs)
          .join(' ');
      for (final sdk in [
        'Firebase Authentication',
        'Firestore',
        'Google Sign-In',
        'AdMob',
      ]) {
        expect(text, contains(sdk));
      }
      expect(text, contains(AppInfo.deleteAccountUrl));
    });
  });
}
