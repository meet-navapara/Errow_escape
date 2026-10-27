import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/level_pack_loader.dart';

import 'package:arrow_escape/core/storage/storage_service.dart';
import 'package:arrow_escape/core/audio/sound_service.dart';
import 'package:arrow_escape/core/audio/haptic_service.dart';
import 'package:arrow_escape/core/auth/auth_service.dart';
import 'package:arrow_escape/game/game_controller.dart';
import 'package:arrow_escape/game/difficulty.dart';
import 'package:arrow_escape/game/level_generator.dart';
import 'package:arrow_escape/models/power_up.dart';
import 'package:arrow_escape/game/levels_data.dart';
import 'package:arrow_escape/models/arrow_model.dart';
import 'package:arrow_escape/models/board_model.dart';
import 'package:arrow_escape/models/level_model.dart';
import 'package:arrow_escape/ui/screens/gameplay_screen.dart';
import 'package:arrow_escape/ui/screens/welcome_screen.dart';
import 'package:arrow_escape/ui/widgets/board_widget.dart';
import 'package:arrow_escape/ui/widgets/level_complete_dialog.dart';

void main() {
  setUpAll(loadLevelPack);

  testWidgets('App renders Welcome Screen on first launch', (
    WidgetTester tester,
  ) async {
    final storage = StorageService(null);
    final sound = SoundService(storage);
    final haptic = HapticService(storage);
    final auth = AuthService(storage: storage);

    await tester.pumpWidget(
      TickerMode(
        enabled: false,
        child: MaterialApp(
          home: WelcomeScreen(auth: auth, sound: sound, haptic: haptic),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('ARROW ESCAPE'), findsOneWidget);
    expect(find.text('Clear the path. Escape every arrow.'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue as Guest'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'Gameplay Screen renders clean header with 3 hearts, count pill, and action controls',
    (WidgetTester tester) async {
      final storage = StorageService(null);
      await storage.markTutorialSeen(TutorialIds.gameplayOnboarding);
      final sound = SoundService(storage);
      final haptic = HapticService(storage);
      final level1 = LevelsRepository.getLevel(1);

      final controller = GameController(
        initialLevel: level1,
        storage: storage,
        sound: sound,
        haptic: haptic,
        escapeDelay: Duration.zero,
      );

      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        TickerMode(
          enabled: false,
          child: MaterialApp(home: GameplayScreen(controller: controller)),
        ),
      );
      await tester.pump();

      // Verify header title and 3 hearts
      expect(find.text('Level 1'), findsOneWidget);
      expect(find.byIcon(Icons.favorite_rounded), findsNWidgets(3));

      // Verify stats pills: arrow count and difficulty tier
      expect(find.text('3'), findsOneWidget);
      expect(find.text(Difficulty.of(level1.board).label), findsOneWidget);

      // Verify bottom action controls
      expect(find.byTooltip('Undo'), findsOneWidget);
      expect(find.byTooltip('Restart'), findsOneWidget);
      for (final t in PowerUpType.values) {
        expect(find.text(t.label), findsOneWidget);
      }
      expect(find.text('Ad'), findsNothing); // starter uses available

      // Verify InteractiveViewer is present for zoom and pan
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.byType(BoardWidget), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Gameplay deducts exactly 1 heart on blocked move and displays 2 hearts',
    (WidgetTester tester) async {
      final storage = StorageService(null);
      await storage.markTutorialSeen(TutorialIds.gameplayOnboarding);
      final sound = SoundService(storage);
      final haptic = HapticService(storage);

      // Board with 1 blocked arrow and 1 blocker
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
        id: 2,
        title: 'Level 2',
        board: board,
        tier: LevelTier.tutorial,
        targetMoves: 2,
      );

      final controller = GameController(
        initialLevel: level,
        storage: storage,
        sound: sound,
        haptic: haptic,
        escapeDelay: Duration.zero,
      );

      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        TickerMode(
          enabled: false,
          child: MaterialApp(home: GameplayScreen(controller: controller)),
        ),
      );
      await tester.pump();

      // Initially 3 full hearts
      expect(find.byIcon(Icons.favorite_rounded), findsNWidgets(3));
      expect(find.byIcon(Icons.favorite_border_rounded), findsNothing);

      // Tap blocked arrow
      await controller.onArrowTapped(blocked);
      await tester.pump();

      // Exactly 1 heart lost: 2 full hearts and 1 empty heart icon
      expect(controller.hearts, equals(2));
      expect(find.byIcon(Icons.favorite_rounded), findsNWidgets(2));
      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
      expect(find.text('Path blocked!'), findsOneWidget);

      controller.clearFeedbackAndUnlock();
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('Level 6 heart-shaped board loads as a dense lattice', (
    WidgetTester tester,
  ) async {
    final storage = StorageService(null);
    await storage.markTutorialSeen(TutorialIds.gameplayOnboarding);
    final sound = SoundService(storage);
    final haptic = HapticService(storage);
    final level6 = LevelsRepository.getLevel(6);

    final controller = GameController(
      initialLevel: level6,
      storage: storage,
      sound: sound,
      haptic: haptic,
      escapeDelay: Duration.zero,
    );

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      TickerMode(
        enabled: false,
        child: MaterialApp(home: GameplayScreen(controller: controller)),
      ),
    );
    await tester.pump();

    // Verify Level 6 header and difficulty badge
    expect(find.text('Level 6'), findsOneWidget);
    expect(find.text(Difficulty.of(level6.board).label), findsOneWidget);
    final spec = LevelGenerator.specForLevel(6);
    expect(spec.shape, equals(BoardShape.heart));
    expect(controller.board.rows, equals(spec.rows));
    expect(controller.board.cols, equals(spec.cols));
    expect(controller.board.arrows.length, greaterThan(15));
    expect(controller.board.arrows.isNotEmpty, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('LevelCompleteDialog displays celebration, stars, and actions', (
    WidgetTester tester,
  ) async {
    bool nextLevelCalled = false;
    bool replayCalled = false;
    bool homeCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LevelCompleteDialog(
            levelId: 5,
            isDaily: false,
            movesTaken: 14,
            targetMoves: 14,
            remainingHearts: 3,
            onNextLevel: () => nextLevelCalled = true,
            onReplay: () => replayCalled = true,
            onHome: () => homeCalled = true,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Level Completed!'), findsOneWidget);
    expect(find.text('Level 5 cleared with flying colors!'), findsOneWidget);
    expect(find.text('Next Level'), findsOneWidget);
    expect(find.text('Replay Level'), findsOneWidget);
    expect(find.text('Main'), findsOneWidget);

    // 3 stars for 3 remaining hearts
    expect(find.byIcon(Icons.star_rounded), findsNWidgets(3));

    // Tap Next Level button
    await tester.tap(find.text('Next Level'));
    expect(nextLevelCalled, isTrue);

    // Tap Replay Level button
    await tester.tap(find.text('Replay Level'));
    expect(replayCalled, isTrue);

    // Tap Main button
    await tester.tap(find.text('Main'));
    expect(homeCalled, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final scale in [1.0, 1.3, 1.6, 2.0]) {
    testWidgets(
      'Next Level button fits on a small phone at text scale $scale',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(360, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(360, 740),
                textScaler: TextScaler.linear(scale),
              ),
              child: Scaffold(
                body: LevelCompleteDialog(
                  levelId: 245,
                  isDaily: false,
                  movesTaken: 38,
                  targetMoves: 38,
                  remainingHearts: 3,
                  onNextLevel: () {},
                  onReplay: () {},
                  onHome: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 2));

        expect(find.text('Next Level'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
