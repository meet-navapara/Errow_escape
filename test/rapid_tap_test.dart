import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/level_pack_loader.dart';

import 'package:arrow_escape/core/audio/haptic_service.dart';
import 'package:arrow_escape/core/audio/sound_service.dart';
import 'package:arrow_escape/core/storage/storage_service.dart';
import 'package:arrow_escape/game/game_controller.dart';
import 'package:arrow_escape/game/levels_data.dart';
import 'package:arrow_escape/models/arrow_model.dart';
import 'package:arrow_escape/ui/widgets/board_painter.dart';
import 'package:arrow_escape/ui/widgets/board_widget.dart';

void main() {
  setUpAll(loadLevelPack);

  const frame = Duration(milliseconds: 16);

  Future<GameController> pumpBoard(WidgetTester tester, int levelId) async {
    final storage = StorageService(null);
    await storage.setTutorialCompleted(true);
    final controller = GameController(
      initialLevel: LevelsRepository.getLevel(levelId),
      storage: storage,
      sound: SoundService(storage),
      haptic: HapticService(storage),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 600,
            child: BoardWidget(controller: controller),
          ),
        ),
      ),
    );
    return controller;
  }

  BoardPainter painterOf(WidgetTester tester) => tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((p) => p.painter)
      .whereType<BoardPainter>()
      .single;

  Map<String, double> ghosts(WidgetTester tester) => {
    for (final e in painterOf(tester).escaping) e.arrow.id: e.progress,
  };

  /// Pumps [frames] frames, failing if any escaping arrow's animation ever
  /// goes backwards or an arrow comes back after its animation finished.
  Future<void> watch(
    WidgetTester tester,
    Map<String, double> last,
    Set<String> finished,
    int frames,
  ) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(frame);
      final now = ghosts(tester);
      for (final MapEntry(:key, :value) in now.entries) {
        expect(finished, isNot(contains(key)), reason: '$key restarted');
        expect(
          value,
          greaterThanOrEqualTo(last[key] ?? 0),
          reason: '$key jumped back from ${last[key]} to $value',
        );
      }
      for (final id in last.keys) {
        if (!now.containsKey(id)) finished.add(id);
      }
      last
        ..clear()
        ..addAll(now);
    }
  }

  for (final gapMs in [16, 80, 200, 430, 440]) {
    testWidgets('a second tap ${gapMs}ms later never restarts the first '
        'arrow\'s escape', (tester) async {
      final c = await pumpBoard(tester, 12);
      final [a, b, ...] = c.board.getEscapableArrows();

      final last = <String, double>{};
      final finished = <String>{};
      c.onArrowTapped(a);
      await watch(tester, last, finished, gapMs ~/ 16);
      c.onArrowTapped(b);
      await watch(tester, last, finished, 60);

      expect(finished, containsAll([a.id, b.id]));
      expect(ghosts(tester), isEmpty);
      expect(c.board.arrowById(a.id), isNull);
      expect(c.board.arrowById(b.id), isNull);
    });
  }

  testWidgets('a burst of rapid taps animates every arrow independently and '
      'leaves the rest of the board untouched', (tester) async {
    final c = await pumpBoard(tester, 40);
    final tapped = c.board.getEscapableArrows().take(4).toList();
    final untouched = {
      for (final a in c.board.arrows)
        if (!tapped.contains(a)) a.id: a,
    };

    final last = <String, double>{};
    final finished = <String>{};
    for (final a in tapped) {
      c.onArrowTapped(a);
      await watch(tester, last, finished, 2);
    }
    // All four are mid-flight at different stages.
    final progress = ghosts(tester);
    expect(progress.keys, containsAll(tapped.map((a) => a.id)));
    expect(progress.values.toSet(), hasLength(tapped.length));

    await watch(tester, last, finished, 60);
    expect(finished, containsAll(tapped.map((a) => a.id)));
    for (final a in painterOf(tester).board.arrows) {
      expect(a, untouched[a.id], reason: 'arrow ${a.id} changed');
    }
    expect(painterOf(tester).board.arrows, hasLength(untouched.length));
  });

  testWidgets('tapping the same blocked arrow again shakes it again', (
    tester,
  ) async {
    final c = await pumpBoard(tester, 40);
    final Arrow blocked = c.board.arrows.firstWhere(
      (a) => !c.board.checkEscape(a).canEscape,
    );

    c.onArrowTapped(blocked);
    await tester.pump(frame);
    await tester.pump(const Duration(milliseconds: 100));
    expect(painterOf(tester).bump, greaterThan(0));

    // Wait out the mistake debounce, but stay inside the feedback window.
    await tester.pump(const Duration(milliseconds: 600));
    expect(painterOf(tester).bump, closeTo(0, 1e-9));
    c.onArrowTapped(blocked);
    await tester.pump(frame);
    await tester.pump(const Duration(milliseconds: 100));
    expect(painterOf(tester).bump, greaterThan(0));
    expect(c.hearts, 1);

    await tester.pump(const Duration(seconds: 2));
  });
}
