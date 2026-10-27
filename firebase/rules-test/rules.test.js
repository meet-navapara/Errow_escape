// Firestore security-rules tests. Run with: npm install && npm test
// (starts the local emulator; no real Firebase project is used).
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, deleteDoc, serverTimestamp } from 'firebase/firestore';

let env;

const powerUps = (used = 0) => ({
  hint: { granted: 2, used },
  eraser: { granted: 2, used: 0 },
  wand: { granted: 2, used: 0 },
  scanner: { granted: 2, used: 0 },
});

const progress = (overrides = {}) => ({
  schemaVersion: 2,
  highestUnlockedLevel: 5,
  completedLevels: [1, 2, 3, 4],
  tutorialCompleted: true,
  tutorialsSeen: ['onboarding_home'],
  dailyCompleted: ['2026-10-27'],
  dailyResults: { '2026-10-27': { hearts: 3, moves: 20 } },
  weeklyResults: {},
  achievements: ['first_level'],
  rewardClaims: ['starter_v1_hint'],
  powerUps: powerUps(),
  settings: { sound: true, haptics: true },
  createdAt: serverTimestamp(),
  updatedAt: serverTimestamp(),
  lastPlayedAt: null,
  ...overrides,
});

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-arrow-escape',
    firestore: { rules: readFileSync('../../firestore.rules', 'utf8') },
  });
});
beforeEach(() => env.clearFirestore());
after(() => env.cleanup());

const db = (uid) => env.authenticatedContext(uid).firestore();

test('owner can create, read and delete their progress', async () => {
  const ref = doc(db('alice'), 'users/alice');
  await assertSucceeds(setDoc(ref, progress()));
  await assertSucceeds(getDoc(ref));
  await assertSucceeds(deleteDoc(ref));
});

test('other users and signed-out clients are denied', async () => {
  await assertSucceeds(setDoc(doc(db('alice'), 'users/alice'), progress()));
  await assertFails(getDoc(doc(db('mallory'), 'users/alice')));
  await assertFails(setDoc(doc(db('mallory'), 'users/alice'), progress()));
  await assertFails(deleteDoc(doc(db('mallory'), 'users/alice')));
  const anon = env.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(anon, 'users/alice')));
});

test('malformed or unexpected fields are rejected', async () => {
  const ref = doc(db('alice'), 'users/alice');
  await assertFails(setDoc(ref, progress({ isAdmin: true })));
  await assertFails(setDoc(ref, progress({ highestUnlockedLevel: 'ten' })));
  await assertFails(setDoc(ref, progress({ highestUnlockedLevel: 5000 })));
  await assertFails(setDoc(ref, progress({ schemaVersion: 3 })));
  await assertFails(
    setDoc(ref, progress({ powerUps: { ...powerUps(), hint: { granted: 1, used: 5 } } })),
  );
});

test('progress and spent power-ups cannot go backwards', async () => {
  const ref = doc(db('alice'), 'users/alice');
  await assertSucceeds(setDoc(ref, progress({ powerUps: powerUps(1) })));
  await assertFails(setDoc(ref, progress({ highestUnlockedLevel: 2 })));
  await assertFails(setDoc(ref, progress({ completedLevels: [1] })));
  await assertFails(setDoc(ref, progress({ powerUps: powerUps(0) }))); // refund
  await assertSucceeds(
    setDoc(ref, progress({ highestUnlockedLevel: 6, completedLevels: [1, 2, 3, 4, 5], powerUps: powerUps(2) })),
  );
});

test('v1 documents can be upgraded once to schema v2', async () => {
  await env.withSecurityRulesDisabled((ctx) =>
    setDoc(doc(ctx.firestore(), 'users/alice'), {
      highestUnlockedLevel: 9,
      completedLevels: [1, 2],
      hintsBalance: 4,
    }),
  );
  await assertSucceeds(setDoc(doc(db('alice'), 'users/alice'), progress({ highestUnlockedLevel: 9 })));
});

test('every other collection is closed', async () => {
  await assertFails(setDoc(doc(db('alice'), 'leaderboard/alice'), { score: 1 }));
});

test('progress up to level 1000 is accepted; beyond the campaign is rejected', async () => {
  const ref = doc(db('alice'), 'users/alice');
  const all = Array.from({ length: 1000 }, (_, i) => i + 1);
  await assertSucceeds(setDoc(ref, progress({ highestUnlockedLevel: 1001, completedLevels: all })));
  await assertFails(setDoc(ref, progress({ highestUnlockedLevel: 1002, completedLevels: all })));
  await assertFails(
    setDoc(ref, progress({ highestUnlockedLevel: 1001, completedLevels: [...all, 1001] })),
  );
});

test('players past level 100 from app v1 can keep syncing', async () => {
  const ref = doc(db('alice'), 'users/alice');
  await assertSucceeds(setDoc(ref, progress({ highestUnlockedLevel: 101, completedLevels: Array.from({ length: 100 }, (_, i) => i + 1) })));
  await assertSucceeds(setDoc(ref, progress({ highestUnlockedLevel: 102, completedLevels: Array.from({ length: 101 }, (_, i) => i + 1) })));
});
