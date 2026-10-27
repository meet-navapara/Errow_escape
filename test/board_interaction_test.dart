import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/level_pack_loader.dart';

import 'package:arrow_escape/core/audio/haptic_service.dart';
import 'package:arrow_escape/core/audio/sound_service.dart';
import 'package:arrow_escape/core/storage/storage_service.dart';
import 'package:arrow_escape/game/game_controller.dart';
import 'package:arrow_escape/game/levels_data.dart';
import 'package:arrow_escape/game/puzzle_solver.dart';
import 'package:arrow_escape/ui/screens/gameplay_screen.dart';
import 'package:arrow_escape/ui/widgets/board_geometry.dart';
import 'package:arrow_escape/ui/widgets/board_widget.dart';

void main() {
  setUpAll(loadLevelPack);

  final tapTarget = find.byKey(const ValueKey('board-tap-target'));

  Future<GameController> pumpGame(
    WidgetTester tester,
    int levelId, {
    Size screen = const Size(412, 892),
  }) async {
    tester.view.physicalSize = screen * 2;
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final storage = StorageService(null);
    await storage.setTutorialCompleted(true);
    await storage.markTutorialSeen(TutorialIds.gameplayOnboarding);
    final controller = GameController(
      initialLevel: LevelsRepository.getLevel(levelId),
      storage: storage,
      sound: SoundService(storage),
      haptic: HapticService(storage),
      escapeDelay: Duration.zero,
    );
    await tester.pumpWidget(
      MaterialApp(home: GameplayScreen(controller: controller)),
    );
    await tester.pump();
    return controller;
  }

  BoardGeometry geometryOf(WidgetTester tester, GameController c) =>
      BoardGeometry.fit(board: c.board, available: tester.getSize(tapTarget));

  /// Global position of a board-space point, honouring the current zoom/pan.
  Offset toGlobal(WidgetTester tester, Offset boardPoint) {
    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    final matrix = viewer.transformationController!.value;
    final viewerOrigin = tester.getTopLeft(find.byType(InteractiveViewer));
    return viewerOrigin + MatrixUtils.transformPoint(matrix, boardPoint);
  }

  Matrix4 currentMatrix(WidgetTester tester) => tester
      .widget<InteractiveViewer>(find.byType(InteractiveViewer))
      .transformationController!
      .value;

  testWidgets('tapping an escapable arrow on screen removes exactly it', (
    tester,
  ) async {
    final c = await pumpGame(tester, 12);
    final target = c.board.getEscapableArrows().first;
    final g = geometryOf(tester, c);

    await tester.tapAt(toGlobal(tester, g.cellCenter(target.path.first)));
    await tester.pump();

    expect(c.board.arrowById(target.id), isNull);
    expect(c.hearts, 3);
    expect(find.text('${c.board.arrows.length}'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('tapping a blocked arrow costs one heart and keeps it', (
    tester,
  ) async {
    final c = await pumpGame(tester, 12);
    final blocked = c.board.arrows.firstWhere(
      (a) => !c.board.checkEscape(a).canEscape,
    );
    final g = geometryOf(tester, c);

    await tester.tapAt(toGlobal(tester, g.cellCenter(blocked.headCell)));
    await tester.pump();

    expect(c.hearts, 2);
    expect(c.board.arrowById(blocked.id), isNotNull);
    expect(find.text('Path blocked!'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('pinch zooms in, pan moves the board, neither removes arrows', (
    tester,
  ) async {
    final c = await pumpGame(tester, 80);
    final count = c.board.arrows.length;
    final center = tester.getCenter(find.byType(InteractiveViewer));

    // Two-finger pinch outwards.
    final f1 = await tester.startGesture(center - const Offset(30, 0));
    final f2 = await tester.startGesture(center + const Offset(30, 0));
    await tester.pump();
    for (var i = 1; i <= 10; i++) {
      await f1.moveTo(center - Offset(30.0 + i * 12, 0));
      await f2.moveTo(center + Offset(30.0 + i * 12, 0));
      await tester.pump();
    }
    await f1.up();
    await f2.up();
    await tester.pumpAndSettle();

    final scale = currentMatrix(tester).getMaxScaleOnAxis();
    expect(scale, greaterThan(1.5));
    expect(find.text('Reset View'), findsOneWidget);
    expect(c.board.arrows.length, count);

    // One-finger pan while zoomed.
    final before = currentMatrix(tester).getTranslation();
    await tester.dragFrom(center, const Offset(-80, -60));
    await tester.pumpAndSettle();
    final after = currentMatrix(tester).getTranslation();
    expect((after - before).length, greaterThan(10));
    expect(c.board.arrows.length, count);
    expect(c.hearts, 3);
  });

  testWidgets('taps stay accurate while zoomed and reset restores the fit', (
    tester,
  ) async {
    final c = await pumpGame(tester, 80);
    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    final g = geometryOf(tester, c);

    // Zoom 2.5x around the first escapable arrow so it stays on screen.
    final target = c.board.getEscapableArrows().first;
    final focus = g.cellCenter(target.path.first);
    final viewport = tester.getSize(find.byType(InteractiveViewer));
    var tx = viewport.width / 2 - focus.dx * 2.5;
    var ty = viewport.height / 2 - focus.dy * 2.5;
    // Respect the zero boundary margin like a real gesture would.
    tx = tx.clamp(viewport.width - viewport.width * 2.5, 0.0);
    ty = ty.clamp(viewport.height - viewport.height * 2.5, 0.0);
    viewer.transformationController!.value = Matrix4.identity()
      ..translateByDouble(tx, ty, 0, 1)
      ..scaleByDouble(2.5, 2.5, 1, 1);
    await tester.pump();

    final point = toGlobal(tester, focus);
    expect(
      tester.getRect(find.byType(InteractiveViewer)).contains(point),
      isTrue,
    );
    await tester.tapAt(point);
    await tester.pump();
    expect(c.board.arrowById(target.id), isNull);
    expect(c.hearts, 3);

    await tester.tap(find.text('Reset View'));
    await tester.pumpAndSettle();
    expect(currentMatrix(tester).isIdentity(), isTrue);
    expect(find.text('Reset View'), findsNothing);
  });

  testWidgets('zoom limits: cannot shrink below the fitted view', (
    tester,
  ) async {
    await pumpGame(tester, 30);
    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    expect(viewer.minScale, 1.0);
    expect(viewer.maxScale, greaterThanOrEqualTo(3.0));
    expect(viewer.boundaryMargin, EdgeInsets.zero);
    expect(viewer.clipBehavior, Clip.hardEdge);
  });

  for (final screen in const [
    Size(320, 568), // small phone
    Size(360, 640),
    Size(412, 915), // tall modern phone
    Size(800, 1280), // tablet
  ]) {
    testWidgets('board fills the play area without overflow on $screen', (
      tester,
    ) async {
      final c = await pumpGame(tester, 95, screen: screen);
      expect(tester.takeException(), isNull);

      final area = tester.getSize(find.byType(BoardWidget));
      final g = geometryOf(tester, c);
      // Board takes most of the screen height and fills one dimension.
      expect(area.height, greaterThan(screen.height * 0.6));
      final fillsW = g.boardSize.width >= area.width - 25;
      final fillsH = g.boardSize.height >= area.height - 25;
      expect(fillsW || fillsH, isTrue);
      // Every arrow lies inside the visible board area.
      for (final arrow in c.board.arrows) {
        for (final cell in arrow.path) {
          final p = g.cellCenter(cell);
          expect((Offset.zero & area).contains(p), isTrue, reason: "$cell");
        }
      }
      // Controls remain on screen.
      expect(tester.getRect(find.text('Hint')).bottom, lessThan(screen.height));
    });
  }

  testWidgets('completing a level opens the celebration with a preview', (
    tester,
  ) async {
    final c = await pumpGame(tester, 4);
    for (final arrow in PuzzleSolver.solve(c.board).solutionSteps) {
      await c.onArrowTapped(arrow);
    }
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    // HeroController keeps a new route offstage for its first frame.
    await tester.pump();

    expect(c.isWon, isTrue);
    expect(find.text('Level Completed!'), findsOneWidget);
    expect(find.text('Next Level'), findsOneWidget);
    expect(find.text('Level 5'), findsOneWidget);

    await tester.tap(find.text('Next Level'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(c.currentLevel.id, 5);
    expect(c.isWon, isFalse);
    expect(find.text('Level 5'), findsOneWidget);
    expect(currentMatrix(tester).isIdentity(), isTrue);
  });

  testWidgets('hint button highlights a free arrow and keeps hearts', (
    tester,
  ) async {
    final c = await pumpGame(tester, 20);
    final count = c.board.arrows.length;
    await tester.tap(find.byIcon(Icons.lightbulb_rounded).first);
    await tester.pumpAndSettle();
    // First use introduces the tool without consuming anything.
    expect(find.text('New tool: Hint'), findsOneWidget);
    expect(c.storage.getHintCount(), 2);
    await tester.tap(find.text('Use it now'));
    await tester.pumpAndSettle();

    final hinted = c.hintedArrow;
    expect(hinted, isNotNull);
    expect(c.board.checkEscape(hinted!).canEscape, isTrue);
    expect(c.board.arrows.length, count);
    expect(c.hearts, 3);
    expect(c.storage.getHintCount(), 1); // 2 free hints - 1
    expect(find.text('1'), findsOneWidget);
    await tester.pump(const Duration(seconds: 7));
  });
}
