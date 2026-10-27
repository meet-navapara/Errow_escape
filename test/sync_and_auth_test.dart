import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_mocks/google_sign_in_mocks.dart';
import 'package:arrow_escape/core/auth/auth_service.dart';
import 'package:arrow_escape/core/storage/cloud_sync_service.dart';
import 'package:arrow_escape/core/storage/progress_snapshot.dart';
import 'package:arrow_escape/core/storage/storage_service.dart';
import 'package:arrow_escape/models/power_up.dart';

/// MockGoogleSignIn lacks these two methods.
class FakeGoogleSignIn extends MockGoogleSignIn {
  @override
  Future<GoogleSignInAccount?> signInSilently({
    bool suppressErrors = true,
    bool reAuthenticate = false,
  }) => signIn();

  @override
  Future<GoogleSignInAccount?> signOut() async => null;
}

void main() {
  late StorageService storage;
  late FakeFirebaseFirestore firestore;

  setUp(() {
    storage = StorageService(null);
    firestore = FakeFirebaseFirestore();
  });

  CloudSyncService syncFor(MockFirebaseAuth auth) => CloudSyncService(
    storage: storage,
    firebaseAuth: auth,
    firestore: firestore,
    debounce: const Duration(milliseconds: 10),
  );

  MockFirebaseAuth signedIn() =>
      MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'u1'));

  Future<Map<String, dynamic>> cloudDoc() async =>
      (await firestore.collection('users').doc('u1').get()).data()!;

  group('Cloud sync', () {
    test('first sync creates a versioned progress document', () async {
      await storage.markLevelCompleted(1);
      await storage.markLevelCompleted(2);
      final sync = syncFor(signedIn());
      expect(await sync.syncProgress(), isTrue);
      final doc = await cloudDoc();
      expect(doc['schemaVersion'], 2);
      expect(doc['highestUnlockedLevel'], 3);
      expect(doc['completedLevels'], [1, 2]);
      expect((doc['powerUps'] as Map).keys, containsAll(['hint', 'eraser']));
      expect(sync.status.value, SyncStatus.synced);
    });

    test(
      'an older local copy never overwrites more advanced cloud progress',
      () async {
        await firestore.collection('users').doc('u1').set({
          ...ProgressSnapshot.fromStorage(StorageService(null)).toFirestore(),
          'highestUnlockedLevel': 30,
          'completedLevels': [for (var i = 1; i < 30; i++) i],
          'achievements': ['ten_levels'],
        });
        await storage.markLevelCompleted(1); // local is behind
        await storage.recordDailyResult(
          '2026-10-01',
          const DailyResult(hearts: 2, moves: 10),
        );

        await syncFor(signedIn()).syncProgress();

        expect(storage.getHighestUnlockedLevel(), 30);
        expect(storage.getUnlockedAchievements(), contains('ten_levels'));
        final doc = await cloudDoc();
        expect(doc['highestUnlockedLevel'], 30);
        // Local-only data was merged up, not discarded.
        expect((doc['dailyResults'] as Map).keys, contains('2026-10-01'));
      },
    );

    test('upgrades v1 documents and keeps their hint balance', () async {
      await firestore.collection('users').doc('u1').set({
        'highestUnlockedLevel': 12,
        'completedLevels': [for (var i = 1; i < 12; i++) i],
        'hintsBalance': 9,
      });
      await syncFor(signedIn()).syncProgress();
      expect(storage.getHighestUnlockedLevel(), 12);
      expect(
        storage.getPowerUpGranted(PowerUpType.hint),
        greaterThanOrEqualTo(9),
      );
      expect((await cloudDoc())['schemaVersion'], 2);
    });

    test(
      'spent power-ups are not refunded and rewards are not duplicated',
      () async {
        // Cloud copy from another device: starter claimed, nothing used.
        final other = StorageService(null);
        await other.ensureStarterPowerUps();
        await firestore
            .collection('users')
            .doc('u1')
            .set(ProgressSnapshot.fromStorage(other).toFirestore());

        await storage.ensureStarterPowerUps();
        await storage.consumePowerUp(PowerUpType.eraser);
        await syncFor(signedIn()).syncProgress();

        expect(storage.getPowerUpBalance(PowerUpType.eraser), 1);
        expect(storage.getPowerUpGranted(PowerUpType.eraser), 2);
        final cloudEraser = ((await cloudDoc())['powerUps'] as Map)['eraser'];
        expect(cloudEraser, {'granted': 2, 'used': 1});
      },
    );

    test(
      'local changes are synced automatically after a short debounce',
      () async {
        final sync = syncFor(signedIn());
        await storage.markLevelCompleted(5);
        expect(sync.status.value, SyncStatus.pending);
        await Future.delayed(const Duration(milliseconds: 100));
        expect((await cloudDoc())['completedLevels'], contains(5));
        expect(sync.status.value, SyncStatus.synced);
      },
    );

    test('does nothing while signed out', () async {
      final sync = syncFor(MockFirebaseAuth());
      expect(await sync.syncProgress(), isFalse);
      expect(sync.status.value, SyncStatus.signedOut);
    });
  });

  group('ProgressSnapshot.merge', () {
    test('keeps the best daily result and highest weekly scores', () async {
      final a = StorageService(null);
      final b = StorageService(null);
      await a.recordDailyResult('d', const DailyResult(hearts: 2, moves: 5));
      await b.recordDailyResult('d', const DailyResult(hearts: 3, moves: 40));
      await a.recordWeeklyResult('W1', 0, 300);
      await b.recordWeeklyResult('W1', 0, 100);
      await b.recordWeeklyResult('W1', 1, 200);
      await a.setSoundEnabled(false);

      final merged = ProgressSnapshot.fromStorage(a)
          .merge(ProgressSnapshot.fromStorage(b));
      expect(merged.dailyResults['d']!.hearts, 3);
      expect(merged.weeklyResults['W1'], {0: 300, 1: 200});
      expect(merged.soundEnabled, isFalse); // local device setting wins
    });

    test('round-trips through the Firestore representation', () async {
      await storage.markLevelCompleted(7);
      await storage.markDailyCompleted('2026-10-20');
      await storage.unlockAchievement('first_level');
      await storage.markTutorialSeen('onboarding_home');
      final snap = ProgressSnapshot.fromStorage(storage);
      final back = ProgressSnapshot.fromFirestore(snap.toFirestore());
      expect(back.completedLevels, {7});
      expect(back.dailyCompleted, {'2026-10-20'});
      expect(back.achievements, {'first_level'});
      expect(back.tutorialsSeen, {'onboarding_home'});
      expect(back.highestUnlocked, 8);
    });
  });

  group('Auth', () {
    AuthService authFor(MockFirebaseAuth auth, {GoogleSignIn? google}) =>
        AuthService(
          storage: storage,
          firebaseAuth: auth,
          googleSignIn: google ?? FakeGoogleSignIn(),
          cloudSync: syncFor(auth),
        );

    test('without Firebase, sign-in explains guest mode still works', () async {
      final auth = AuthService(
        storage: storage,
        googleSignIn: FakeGoogleSignIn(),
      );
      expect(auth.isFirebaseAvailable, isFalse); // no Firebase app in tests
      expect(await auth.signInWithGoogle(), isFalse);
      expect(auth.errorMessage, contains('guest'));
    });

    test('cancelling sign-in is not an error', () async {
      final google = FakeGoogleSignIn()..setIsCancelled(true);
      final auth = authFor(MockFirebaseAuth(), google: google);
      await auth.init();
      expect(await auth.signInWithGoogle(), isFalse);
      expect(auth.errorMessage, isNull);
      expect(auth.isGuest, isTrue);
    });

    test(
      'guest progress is merged into the Google account on sign-in',
      () async {
        final auth = authFor(MockFirebaseAuth(mockUser: MockUser(uid: 'u1')));
        await auth.init();
        await auth.playAsGuest();
        expect(auth.isGuest, isTrue);
        expect(auth.guestId, isNotNull);
        await storage.markLevelCompleted(1);
        await storage.markLevelCompleted(2);

        expect(await auth.signInWithGoogle(), isTrue);
        expect(auth.isAuthenticated, isTrue);
        expect((await cloudDoc())['completedLevels'], [1, 2]);
        expect(storage.getCompletedLevels(), {1, 2}); // still on device
      },
    );

    test('signing out keeps local progress and returns to guest', () async {
      final auth = authFor(signedIn());
      await auth.init();
      await storage.markLevelCompleted(3);
      await auth.signOut();
      expect(auth.isGuest, isTrue);
      expect(storage.isLevelCompleted(3), isTrue);
      expect(auth.cloudSync.status.value, SyncStatus.signedOut);
    });

    test('deleting the account removes cloud and local data', () async {
      final auth = authFor(signedIn());
      await auth.init();
      await storage.markLevelCompleted(4);
      await auth.cloudSync.syncProgress();
      expect(
        (await firestore.collection('users').doc('u1').get()).exists,
        isTrue,
      );

      expect(await auth.deleteAccount(), isTrue);
      expect(
        (await firestore.collection('users').doc('u1').get()).exists,
        isFalse,
      );
      expect(storage.getCompletedLevels(), isEmpty);
      expect(auth.isGuest, isTrue);
    });

    test('maps platform errors to helpful messages', () {
      expect(
        AuthService.describeGoogleSignInError(
          'sign_in_failed',
          'com.google.android.gms.common.api.ApiException: 10: ',
        ),
        contains('not configured'),
      );
      expect(
        AuthService.describeGoogleSignInError('network_error', null),
        contains('internet'),
      );
      expect(
        AuthService.describeAuthError('network-request-failed'),
        contains('internet'),
      );
      expect(
        AuthService.describeAuthError(
          'account-exists-with-different-credential',
        ),
        contains('different sign-in'),
      );
    });
  });
}
