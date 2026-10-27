# Arrow Escape — Tap to Clear 🎯

A polished casual puzzle game built with Flutter for Android and iOS. See [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md) for what is verified and what remains before store submission.

The player is presented with a grid containing directional arrows of various lengths. Tapping an arrow attempts to launch it off the board in the direction it points. If an arrow's escape path is blocked by another arrow, the blocker is highlighted with clear explanatory feedback. Clear all arrows to solve the level!

---

## 🎮 Game Concept & Rules

1. **Movement & Escape**:
   - Each arrow points in one of 4 cardinal directions: **Up**, **Down**, **Left**, or **Right**.
   - Arrows are continuous snake-like paths (2–9 lattice points, with 90° bends) that densely fill a level silhouette.
   - An arrow can escape **only if the straight line from its arrowhead to the board edge** is clear of every other active arrow (the body follows the head out).
2. **Collision Detection**:
   - A single ray is traced from the arrowhead in its direction; the first other arrow it meets is the blocker.
   - If any ray encounters another arrow, collision is registered, the blocker is highlighted in red/orange with a warning badge, and explanatory feedback is shown.
   - Arrows never block themselves.
3. **Winning & Persistence**:
   - The level is complete when all arrows have escaped.
   - Progress (unlocked levels, completed levels, high streaks, hint balance) is saved locally for 100% offline gameplay.

---

## 🏗️ Architecture & Module Organization

The codebase follows clean, modular domain-driven architecture:

```
lib/
├── main.dart                          # App initialization, portrait orientation lock, theming
├── core/
│   ├── ads/
│   │   └── ad_service.dart            # AdMob preparation, official test IDs, frequency capping
│   ├── audio/
│   │   ├── haptic_service.dart        # Tactile haptic feedback (light, medium, heavy, success)
│   │   └── sound_service.dart         # Audio cues for taps, escapes, alerts, and victories
│   ├── storage/
│   │   └── storage_service.dart       # SharedPreferences persistence with memory test fallbacks
│   └── theme/
│       ├── app_colors.dart            # Slate modern dark palette, arrow gradients, glowing status colors
│       └── app_theme.dart             # Production Material 3 dark theme
├── models/
│   ├── arrow_model.dart               # ArrowDirection, GridPosition, Arrow (multi-cell support)
│   ├── board_model.dart               # Board representation, raycasting collision, escape check
│   ├── game_move.dart                 # Immutable move record for lossless Undo
│   └── level_model.dart               # Level data model & difficulty tiers
├── game/
│   ├── puzzle_solver.dart             # Topological DAG solver & intelligent hint generator
│   ├── level_generator.dart           # Validated level generator with solver verification
│   ├── levels_data.dart               # 100 pre-validated playable levels repository
│   ├── daily_challenge_service.dart   # Deterministic calendar-seeded daily puzzles & streak tracker
│   └── game_controller.dart           # Reactive ChangeNotifier managing gameplay state & actions
└── ui/
    ├── screens/
    │   ├── home_screen.dart           # Hero screen, progress stats, daily challenge preview, navigation
    │   ├── gameplay_screen.dart       # Responsive board, remaining count, undo, restart, hint triggers
    │   ├── level_select_screen.dart   # 100-level grid with tier tabs (Tutorial, Beginner, Easy, Medium, Hard, Expert)
    │   ├── daily_challenge_screen.dart# Calendar day challenge with streak tracking
    │   └── settings_screen.dart       # Sound & haptic toggles, how-to-play rules, reset progress
    └── widgets/
        ├── board_widget.dart          # Zoomable/pannable board, hit testing, escape & blocked animations
        ├── board_geometry.dart        # Single source of arrow geometry for rendering, hit testing & animation
        ├── board_painter.dart         # Rounded-path arrow renderer shared by gameplay and previews
        ├── level_complete_dialog.dart # Full-screen celebration with confetti and puzzle preview
        ├── coach_marks.dart           # Spotlight walkthroughs (onboarding)
        ├── power_up_bar.dart          # Power-up buttons and explanation/refill sheet
        └── game_logo_widget.dart      # Original emblem (also renders all icons)
```

---

## 🧩 1000 Solvable Levels & The Puzzle Solver

- **Difficulty plan** (badges are computed from solver metrics, not the level number):

  | Levels | Planned badge |
  | --- | --- |
  | 1–10 | Beginner |
  | 11–50 | Easy |
  | 51–150 | Normal |
  | 151–300 | Intermediate |
  | 301–500 | Hard |
  | 501–700 | Very Hard |
  | 701–900 | Expert |
  | 901–1000 | Master |

  Every 10th level from 105 on is a deliberate "breather" one band easier. Levels 1–100 are the original puzzles, kept byte-for-byte (`test/fixtures/first_100_levels.fnv`); their badges come from the solver.
- **Score** (`Difficulty.score`): dependency depth + arrows / 8 + blocking pairs per arrow. Levels 101–1000 are generated to hit a score window that rises steadily through each band: fill a shape with snake paths, repair circular blockages, then harden (reverse arrows) in small steps until the score lands in the window; several seeds are tried and the closest is kept. Boards are capped at 16×20 so they stay usable on phones (with pinch-to-zoom).
- **Level pack**: all 1000 levels are precomputed into `assets/levels/levels_v1.txt` (versioned, one compact line per level with solver metadata). The game decodes only the level being played; level select reads difficulty from the line header. Without the pack the same deterministic generator produces identical boards.
- **Solver**: `PuzzleSolver.solve` is polynomial and complete (removing an arrow never blocks another, so greedy clearing finds a solution whenever one exists); `analyze` measures depth, initial moves and blocking pairs.
- **Validation**: `flutter test tool/generate_level_pack_test.dart` regenerates the pack and fails if any level is malformed, unsolvable, has an illegal first hint, or duplicates another level up to rotation/reflection. Report: [docs/level_validation_report.md](docs/level_validation_report.md) (per-level CSV alongside).
- **Level select**: 20 chapters of 50, completed / next / unlocked / locked tiles with a difficulty stripe, and "Go to level" for any unlocked level.

---

## 🧰 Power-ups

Four tools in the bottom bar, each with one distinct effect (`lib/models/power_up.dart`):

| Tool | Effect |
| --- | --- |
| Hint | Solver picks an arrow that can escape now and highlights it with its route. Never moves anything. |
| Eraser | Select any arrow (even a blocked one) to remove it. |
| Magic Wand | Launches up to 5 arrows that are currently free, as one undoable move. |
| Path Scanner | Select an arrow to see its escape route and every arrow blocking it. No heart cost. |

- Every player gets **2 free uses of each**, granted once (claim ids make it idempotent; resetting progress does not re-grant).
- When a tool is empty the player may choose to watch a rewarded ad for one more use. The reward is granted only on the SDK's reward callback; failures, early closes and repeated taps grant nothing.
- Removing arrows can never make a solvable board unsolvable, so Eraser and Wand always leave a valid puzzle.
- First touch of each tool shows an explanation sheet; long-press any tool to read it again.

---

## 📅 Daily and Weekly Challenges

- **Daily**: deterministic date seed; any date up to today (device local date) can be played from the calendar. Completed days are starred, best result per day is kept, streaks are computed from completed dates, and the first completion of each date grants one bonus hint (once).
- **Weekly**: five solver-validated puzzles per Monday-to-Monday week, 100 points per heart left, best score per puzzle. It is a personal challenge: there is no online leaderboard and no fake competitors.
- **Achievements and Awards**: ten earnable achievements, each unlocked once; monthly daily-challenge trophies (bronze 10 days, silver 20, gold all).

---

## 🎓 Tutorials

- First visit to Home and to gameplay: spotlight walkthroughs (Back/Next/Skip/Finish) highlighting the real controls, covering rules, hearts, zoom, power-ups, the free allowance and optional ads, daily/weekly and the profile.
- Levels 1-3: interactive guides that follow the live board (demonstrated move, blocker explanation, a free tutorial hint that does not use the balance).
- Each tutorial is stored separately and shown once; **Help > Replay tutorials** or **Settings > Replay Tutorials** resets them.

---

## ☁️ Accounts, sync and privacy

- Guest mode works fully offline; Google sign-in (Firebase Auth) merges guest progress into the account.
- Cloud progress lives in `users/{uid}` (schema v2, `ProgressSnapshot`); sync is a Firestore transaction with a documented no-regression merge policy, debounced and retried offline.
- Security rules: `firestore.rules`, tested in the emulator (`firebase/rules-test`).
- Legal pages: one source (`lib/core/legal/legal_content.dart`) shown in the app and generated to `hosting/public` for Firebase Hosting (`hosting/README.md`).
- Rewarded ads use Google AdMob behind `RewardedAdProvider`, gated by Google UMP consent (`lib/core/ads/ad_service.dart`). Debug builds use Google's test ids; release builds need real ids via `--dart-define`.

Setup guides: [FIREBASE_SETUP.md](FIREBASE_SETUP.md), [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md), [hosting/README.md](hosting/README.md), [assets/branding/README.md](assets/branding/README.md).

---

## 🧪 Testing & Verification

```bash
flutter analyze
flutter test                                   # unit + widget tests
cd firebase/rules-test && npm install && npm test   # Firestore rules (emulator, needs Java)
```

Regenerate assets after changing the logo or legal text:

```bash
flutter test tool/generate_brand_assets_test.dart
flutter test tool/generate_legal_pages_test.dart
```

---

## 🚀 Running the Game Locally

```bash
flutter pub get
flutter run            # Android or iOS device/emulator
```
