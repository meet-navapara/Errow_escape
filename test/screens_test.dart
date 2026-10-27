import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/level_pack_loader.dart';

import 'package:arrow_escape/core/ads/ad_service.dart';
import 'package:arrow_escape/core/audio/haptic_service.dart';
import 'package:arrow_escape/core/audio/sound_service.dart';
import 'package:arrow_escape/core/storage/storage_service.dart';
import 'package:arrow_escape/game/game_controller.dart';
import 'package:arrow_escape/game/levels_data.dart';
import 'package:arrow_escape/models/power_up.dart';
import 'package:arrow_escape/ui/app_services.dart';
import 'package:arrow_escape/ui/screens/daily_challenge_screen.dart';
import 'package:arrow_escape/ui/screens/gameplay_screen.dart';
import 'package:arrow_escape/ui/screens/home_screen.dart';
import 'package:arrow_escape/ui/screens/level_select_screen.dart';
import 'package:arrow_escape/ui/screens/privacy_policy_screen.dart';
import 'package:arrow_escape/ui/screens/profile_screen.dart';
import 'package:arrow_escape/ui/screens/welcome_screen.dart';
import 'package:arrow_escape/core/auth/auth_service.dart';
import 'package:arrow_escape/ui/widgets/board_geometry.dart';

void main() {
  setUpAll(loadLevelPack);

  late StorageService storage;

  setUp(() => storage = StorageService(null));

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget home() => MaterialApp(
    home: HomeScreen(
      storage: storage,
      sound: SoundService(storage),
      haptic: HapticService(storage),
    ),
  );

  group('Home', () {
    testWidgets('first visit shows a skippable walkthrough, then never again', (
      tester,
    ) async {
      phone(tester);
      await tester.pumpWidget(home());
      await tester.pumpAndSettle();
      expect(find.text('Continue Game'), findsWidgets); // step 1 title
      expect(find.text('1/5'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('2/5'), findsOneWidget);
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(find.text('1/5'), findsOneWidget);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(find.text('1/5'), findsNothing);
      expect(storage.isTutorialSeen(TutorialIds.homeOnboarding), isTrue);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(home());
      await tester.pumpAndSettle();
      expect(find.text('1/5'), findsNothing);
    });

    testWidgets('tabs navigate to Daily and Me; cards and buttons are real', (
      tester,
    ) async {
      phone(tester);
      await storage.markTutorialSeen(TutorialIds.homeOnboarding);
      await tester.pumpWidget(home());
      await tester.pumpAndSettle();

      expect(find.text('DAILY CHALLENGE'), findsOneWidget);
      expect(find.text('WEEKLY CHALLENGE'), findsOneWidget);
      expect(find.text('New Game'), findsOneWidget);
      expect(find.text('Level 1 of 1000'), findsOneWidget);
      expect(find.text('Restart Game'), findsOneWidget);
      expect(find.text('All Levels'), findsOneWidget);
      expect(find.text('Remove Ads'), findsNothing); // no purchase flow

      await tester.tap(find.text('Daily'));
      await tester.pumpAndSettle();
      expect(find.text('Daily Challenges'), findsOneWidget);

      await tester.tap(find.text('Me'));
      await tester.pumpAndSettle();
      for (final item in [
        'Awards',
        'Achievements',
        'Settings',
        'Help',
        'About Game',
        'Privacy Policy',
        'Terms of Service',
        'Privacy Preferences',
      ]) {
        expect(find.text(item), findsOneWidget, reason: item);
      }
    });

    for (final scale in [1.0, 1.15, 1.3, 1.5]) {
      testWidgets('home buttons fit at text scale $scale', (tester) async {
        phone(tester);
        await storage.markTutorialSeen(TutorialIds.homeOnboarding);
        await storage.markLevelCompleted(
          13,
        ); // shows "Continue Game / Level 14"
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData.fromView(tester.view)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: home(),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Continue Game'), findsOneWidget);
        expect(find.text('Level 14 of 1000'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Restart Game asks first and keeps unlocks', (tester) async {
      phone(tester);
      await storage.markTutorialSeen(TutorialIds.homeOnboarding);
      for (var i = 1; i <= 6; i++) {
        await storage.markLevelCompleted(i);
      }
      await tester.pumpWidget(home());
      await tester.pumpAndSettle();
      expect(find.text('Continue Game'), findsOneWidget);
      expect(find.text('Level 7 of 1000'), findsOneWidget);

      await tester.tap(find.text('Restart Game'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(storage.getCurrentLevel(), 7);

      await tester.tap(find.text('Restart Game'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restart'));
      await tester.pumpAndSettle();
      expect(storage.getCurrentLevel(), 1);
      expect(storage.getHighestUnlockedLevel(), 7);
      expect(find.text('Level 1 of 1000'), findsOneWidget);
    });
  });

  testWidgets('Continue Game opens the next level beyond the old cap', (
    tester,
  ) async {
    phone(tester);
    await storage.markTutorialSeen(TutorialIds.homeOnboarding);
    await storage.markTutorialSeen(TutorialIds.gameplayOnboarding);
    for (var i = 1; i <= 125; i++) {
      await storage.markLevelCompleted(i);
    }
    await tester.pumpWidget(home());
    await tester.pumpAndSettle();
    expect(find.text('Level 126 of 1000'), findsOneWidget);
    await tester.tap(find.text('Continue Game'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(GameplayScreen), findsOneWidget);
    expect(find.text('Level 126'), findsOneWidget);
  });

  group('Level select (1000 levels)', () {
    Future<void> pumpSelect(WidgetTester tester) async {
      phone(tester);
      await storage.markTutorialSeen(TutorialIds.gameplayOnboarding);
      for (var i = 1; i <= 60; i++) {
        await storage.markLevelCompleted(i);
      }
      await tester.pumpWidget(
        MaterialApp(
          home: LevelSelectScreen(
            storage: storage,
            sound: SoundService(storage),
            haptic: HapticService(storage),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Finder tile(String pattern) => find.bySemanticsLabel(RegExp(pattern));

    testWidgets('opens on the current chapter with clear tile states', (
      tester,
    ) async {
      await pumpSelect(tester);
      expect(find.text('Level 61 of 1000'), findsOneWidget);
      expect(find.textContaining('60 completed'), findsOneWidget);
      expect(tile(r'^Level 60, completed'), findsOneWidget);
      expect(tile(r'^Level 61, next to play'), findsOneWidget);
      expect(tile(r'^Level 62, locked'), findsOneWidget);
      expect(tile(r'^Level 70, locked'), findsOneWidget);
    });

    testWidgets('locked levels do not open; unlocked ones do', (tester) async {
      await pumpSelect(tester);
      await tester.tap(tile(r'^Level 62, locked'));
      await tester.pumpAndSettle();
      expect(find.byType(GameplayScreen), findsNothing);

      await tester.tap(tile(r'^Level 61, next to play'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(GameplayScreen), findsOneWidget);
      expect(find.text('Level 61'), findsOneWidget);
    });

    testWidgets('chapters cover all 1000 levels', (tester) async {
      await pumpSelect(tester);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('chapter-19')),
        400,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey('chapter-strip')),
          matching: find.byType(Scrollable),
        ),
      );
      final lastChip = find.byKey(const ValueKey('chapter-19'));
      await tester.ensureVisible(lastChip);
      await tester.pumpAndSettle();
      expect(find.text('951–1000'), findsOneWidget);
      await tester.tap(lastChip);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('chapter-grid-19')),
        findsOneWidget,
      );
      expect(tile(r'^Level 951, locked'), findsOneWidget);
      // The grid builds lazily; scroll to the last tile of the campaign.
      await tester.scrollUntilVisible(
        tile(r'^Level 1000, locked'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      expect(tile(r'^Level 1000, locked'), findsOneWidget);
    });

    testWidgets('jump to level opens unlocked levels and refuses locked ones', (
      tester,
    ) async {
      await pumpSelect(tester);
      await tester.tap(find.byTooltip('Go to level'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '500');
      await tester.tap(find.text('Play'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Level 500 is locked'), findsOneWidget);
      expect(find.byType(GameplayScreen), findsNothing);

      await tester.tap(find.byTooltip('Go to level'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '12');
      await tester.tap(find.text('Play'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(GameplayScreen), findsOneWidget);
      expect(find.text('Level 12'), findsOneWidget);
    });
  });

  group('Daily calendar', () {
    testWidgets('marks completed days, disables the future, shows results', (
      tester,
    ) async {
      phone(tester);
      await storage.markDailyCompleted('2026-10-03');
      await storage.recordDailyResult(
        '2026-10-03',
        const DailyResult(hearts: 2, moves: 31),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DailyChallengeScreen(
              services: AppServices(
                storage: storage,
                sound: SoundService(storage),
                haptic: HapticService(storage),
              ),
              today: DateTime(2026, 10, 27),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('October 2026'), findsOneWidget);
      expect(find.text('1/31'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^3, completed')), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp(r'^30, not available yet')),
        findsOneWidget,
      );
      expect(find.text('Play'), findsOneWidget);

      await tester.tap(find.text('30'));
      await tester.pump();
      expect(find.text('Play'), findsOneWidget); // selection unchanged

      await tester.tap(find.text('3'));
      await tester.pump();
      expect(find.text('Replay'), findsOneWidget);
      expect(
        find.textContaining('best 2/3 hearts in 31 moves'),
        findsOneWidget,
      );

      // Cannot browse into future months.
      final next = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.chevron_right_rounded),
      );
      expect(next.onPressed, isNull);
    });
  });

  group('Legal and privacy', () {
    testWidgets('welcome screen links open the real policy', (tester) async {
      phone(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: WelcomeScreen(
            auth: AuthService(storage: storage),
            sound: SoundService(storage),
            haptic: HapticService(storage),
          ),
        ),
      );
      expect(find.text('Continue as Guest'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      await tester.tap(find.text('Privacy Policy'));
      await tester.pumpAndSettle();
      expect(find.byType(PrivacyPolicyScreen), findsOneWidget);
      expect(find.text('Who we are'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Advertising'), 300);
      expect(find.text('Advertising'), findsOneWidget);
    });

    testWidgets('Me tab shows guest status and sign-in option', (tester) async {
      phone(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: ProfileScreen(
            services: AppServices(
              storage: storage,
              sound: SoundService(storage),
              haptic: HapticService(storage),
              auth: AuthService(storage: storage),
            ),
          ),
        ),
      );
      expect(find.text('Guest Player'), findsOneWidget);
      expect(find.textContaining('this device only'), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget);
    });
  });

  group('Gameplay tutorials and power-ups', () {
    Future<GameController> pumpLevel(WidgetTester tester, int id) async {
      phone(tester);
      final c = GameController(
        initialLevel: LevelsRepository.getLevel(id),
        storage: storage,
        sound: SoundService(storage),
        haptic: HapticService(storage),
        escapeDelay: Duration.zero,
        ads: const NoRewardedAds(),
      );
      await tester.pumpWidget(MaterialApp(home: GameplayScreen(controller: c)));
      await tester.pump();
      return c;
    }

    testWidgets('first game opens the gameplay walkthrough once', (
      tester,
    ) async {
      await pumpLevel(tester, 1);
      // The level-1 guide pulses forever, so pump fixed frames.
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('How arrows escape'), findsOneWidget);
      for (var i = 0; i < 5; i++) {
        await tester.tap(find.text('Next'));
        await tester.pump(const Duration(milliseconds: 500));
      }
      expect(find.text('Undo and restart'), findsOneWidget);
      await tester.tap(find.text('Finish'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(storage.isTutorialSeen(TutorialIds.gameplayOnboarding), isTrue);
    });

    testWidgets('level 1 guide demonstrates a move then lets the player try', (
      tester,
    ) async {
      await storage.markTutorialSeen(TutorialIds.gameplayOnboarding);
      final c = await pumpLevel(tester, 1);
      expect(find.textContaining('Tap the glowing arrow'), findsOneWidget);

      // Tap the guided (first free) arrow on screen.
      final guided = c.board.getEscapableArrows().first;
      final target = find.byKey(const ValueKey('board-tap-target'));
      final g = BoardGeometry.fit(
        board: c.board,
        available: tester.getSize(target),
      );
      await tester.tapAt(
        tester.getTopLeft(target) + g.cellCenter(guided.path.first),
      );
      await tester.pump();
      expect(c.board.arrowById(guided.id), isNull);
      expect(find.textContaining('Your turn'), findsOneWidget);
    });

    testWidgets('level 3 offers a free hint that does not use the balance', (
      tester,
    ) async {
      await storage.markTutorialSeen(TutorialIds.gameplayOnboarding);
      final c = await pumpLevel(tester, 3);
      expect(find.text('Show free hint'), findsOneWidget);
      await tester.tap(find.text('Show free hint'));
      await tester.pump();
      expect(c.hintedArrow, isNotNull);
      expect(storage.getHintCount(), 2);
      await tester.pump(const Duration(seconds: 7));
    });

    testWidgets('an empty power-up offers an optional ad, never a free use', (
      tester,
    ) async {
      await storage.markTutorialSeen(TutorialIds.gameplayOnboarding);
      await storage.markTutorialSeen(
        TutorialIds.powerUpIntro(PowerUpType.wand),
      );
      await storage.ensureStarterPowerUps();
      await storage.consumePowerUp(PowerUpType.wand);
      await storage.consumePowerUp(PowerUpType.wand);
      final c = await pumpLevel(tester, 12);
      final arrows = c.board.arrows.length;

      expect(find.text('Ad'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.auto_fix_high_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Watch ad'), findsOneWidget);
      await tester.tap(find.text('Watch ad'));
      await tester.pumpAndSettle();
      // No ads in tests: honest message, no reward, board untouched.
      expect(find.textContaining('not available'), findsOneWidget);
      expect(storage.getPowerUpBalance(PowerUpType.wand), 0);
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(c.board.arrows.length, arrows);
    });
  });
}
