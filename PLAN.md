# UpSudoku — Detailed Development Plan (Flutter, Offline Sudoku with 4 Difficulty Levels)

> Goal: build **UpSudoku**, a classic 9×9 Sudoku game that runs **fully offline** on Android/iOS (Web/Desktop optional), written in Flutter/Dart, with four difficulty levels: **Easy, Medium, Hard, Very Hard**. Puzzles are generated and **graded by a human-technique solver** (not just by counting clues), so difficulty means something to the player. Everything — puzzle pool, hints, daily puzzle — works without internet.

---

## TABLE OF CONTENTS

1. [Product Overview](#1-product-overview)
2. [Sudoku Rules & Terminology](#2-sudoku-rules--terminology)
3. [Difficulty System (Easy / Medium / Hard / Very Hard)](#3-difficulty-system-easy--medium--hard--very-hard)
4. [Feature Scope (MVP → Extensions)](#4-feature-scope-mvp--extensions)
5. [Rules for Staying 100% Offline](#5-rules-for-staying-100-offline)
6. [Tech Stack & Packages](#6-tech-stack--packages)
7. [Architecture & Folder Structure](#7-architecture--folder-structure)
8. [Data Models](#8-data-models)
9. [Core Domain: Constants, Grid & Backtracking Solver](#9-core-domain-constants-grid--backtracking-solver)
10. [Puzzle Generation & the Offline Puzzle Pool](#10-puzzle-generation--the-offline-puzzle-pool)
11. [Logic Solver, Techniques & Grader](#11-logic-solver-techniques--grader)
12. [Difficulty Config in Code](#12-difficulty-config-in-code)
13. [State Management & GameController](#13-state-management--gamecontroller)
14. [UI/UX & Screens](#14-uiux--screens)
15. [Board Rendering & Input](#15-board-rendering--input)
16. [Hints, Checks & Assists](#16-hints-checks--assists)
17. [Local Persistence](#17-local-persistence)
18. [Audio & Haptics](#18-audio--haptics)
19. [Scoring, Stats & Daily Puzzle](#19-scoring-stats--daily-puzzle)
20. [Edge Cases](#20-edge-cases)
21. [Testing](#21-testing)
22. [Calibration & Validation Workflow](#22-calibration--validation-workflow)
23. [Performance & Quality](#23-performance--quality)
24. [Phased Roadmap](#24-phased-roadmap)
25. [Configuration, Build & Release](#25-configuration-build--release)
26. [Risks & Mitigations](#26-risks--mitigations)
27. [Completion Checklist](#27-completion-checklist)

---

## 1. Product Overview

| Item | Details |
|---|---|
| Project / app name | **UpSudoku** |
| Dart package name | `up_sudoku` |
| Genre | Logic puzzle, 2D, single player |
| Platforms | Android, iOS (primary). Web/Desktop optional |
| Mode | Fully offline |
| Core interaction | Select a cell → tap a digit (or toggle notes mode and tap candidates) |
| Difficulty levels | Easy, Medium, Hard, Very Hard |
| Puzzle supply | Pre-generated, pre-graded pool bundled in assets (+ optional runtime variants, see section 10.5) |
| UI languages | English (default) + Vietnamese (optional) |
| Differentiators | Technique-based difficulty grading, logical hints that explain *why*, four distinct assist rule-sets, daily puzzle, per-difficulty stats |

**Target audience:** beginners (Easy) through experienced solvers (Hard, Very Hard). A session lasts 5–60 minutes depending on difficulty.

---

## 2. Sudoku Rules & Terminology

### 2.1 Rules

- The board is a 9×9 grid divided into nine 3×3 **boxes**.
- Some cells are pre-filled (**givens**). The player fills the remaining cells with digits 1–9.
- Each **row**, each **column** and each **box** must contain every digit 1–9 exactly once.
- A valid puzzle has **exactly one solution** (this is a hard requirement of this project; see section 3.5).

### 2.2 Terminology used in this plan

| Term | Meaning |
|---|---|
| Cell | One of the 81 positions, indexed `0..80` in row-major order |
| Unit | A row, column or box (27 units in total) |
| Peers | The 20 other cells that share a unit with a given cell |
| Candidate | A digit that can still legally go in a cell |
| Notes (pencil marks) | Candidates the **player** writes in a cell |
| Single | A cell/digit that is forced (see techniques in section 3.2) |

---

## 3. Difficulty System (Easy / Medium / Hard / Very Hard)

Difficulty is the heart of this plan. It has **three independent layers**, all driven by one config object per level (section 12):

1. **Puzzle hardness** — *which logical techniques are required to solve the puzzle* (the authoritative measure), guided by the number of givens.
2. **Assist rules** — how much help and feedback the game gives (mistake feedback, hints, notes helpers).
3. **Scoring targets** — par time and base score per level.

### 3.1 Why not just count givens?

The number of givens is a weak proxy: a puzzle with few givens can be easy (solved by simple singles) and one with many givens can be hard. Therefore:

- **Givens range** is used as a *target for the generator* and a *sanity filter*.
- **Technique tier** (computed by a human-style solver, section 11) is the **authoritative classifier**. A puzzle is accepted for a difficulty only if its tier matches.

### 3.2 Technique Tiers

The grader solves each puzzle the way a human would, always applying the **simplest available technique first**. The puzzle's tier is the **hardest tier it ever needed**.

| Tier | Level | Techniques (in order of application) |
|---|---|---|
| 1 | Easy | Naked Single, Hidden Single |
| 2 | Medium | Naked Pair, Hidden Pair, Naked Triple, Hidden Triple, Pointing Pair/Triple, Box/Line Reduction |
| 3 | Hard | Naked Quad, Hidden Quad, X-Wing, Swordfish, XY-Wing, XYZ-Wing |
| 4 | Very Hard | **Everything the grader cannot solve with tiers 1–3**: typically Jellyfish, W-Wing, XY-Chains, coloring/X-cycles, Unique Rectangles, ALS-XZ, forcing chains, or trial-and-error |

Plain-language definitions of the main techniques:

| Technique | Idea |
|---|---|
| Naked Single | A cell has only one candidate left → place it |
| Hidden Single | A digit has only one possible cell in a unit → place it there |
| Naked Pair/Triple/Quad | N cells in a unit share exactly the same N candidates → remove those candidates from the rest of the unit |
| Hidden Pair/Triple/Quad | N digits appear only in the same N cells of a unit → remove all other candidates from those cells |
| Pointing Pair/Triple | A digit's candidates in a box all lie in one row/column → remove it from the rest of that row/column |
| Box/Line Reduction | A digit's candidates in a row/column all lie in one box → remove it from the rest of that box |
| X-Wing | A digit appears in exactly two cells in each of two rows, and those cells share two columns → remove it from the rest of those columns (and the row version) |
| Swordfish | Three-row/three-column generalization of X-Wing |
| XY-Wing | A pivot cell {A,B} plus two pincers {A,C} and {B,C} → any cell that sees both pincers cannot be C |
| XYZ-Wing | Like XY-Wing with a pivot {A,B,C} |

> **Practical note:** Tier 4 techniques are *not* implemented in version 1.0. Very Hard is defined as "the tier 1–3 grader gets stuck, yet the puzzle has a unique solution". That is a valid and conservative definition: such puzzles genuinely need something beyond the implemented techniques. Hints on these puzzles use a fallback (section 16.2).

### 3.3 Difficulty Table (initial values)

| Parameter | Easy | Medium | Hard | Very Hard |
|---|---|---|---|---|
| Required tier (grader) | 1 | 2 | 3 | 4 (grader stuck after tiers 1–3) |
| Givens (generator target) | 38–45 | 32–37 | 27–31 | 22–26 |
| Mistake feedback | **Instant** (wrong digit shown in red) | **Instant** | **Conflicts only** (duplicate digits highlighted; wrong-but-legal digits not flagged) | **None** (no live feedback) |
| Mistake limit | Unlimited | 5 | — (no instant check) | — (no instant check) |
| "Check board" uses | — | — | 3 | 1 |
| Hints per game | 5 | 3 | 2 | 1 |
| Auto-fill notes button | Yes | Yes | No | No |
| Auto-remove notes when placing a digit | Yes | Yes | Yes | No |
| Par time | 10 min | 20 min | 35 min | 60 min |
| Base score | 500 | 1000 | 2000 | 4000 |

> **Important:** every number above is a **starting hypothesis**, not a measured result. Section 22 describes how to validate and tune them (grader tier distribution, solver-bot checks, and human playtests). Givens ranges deliberately do not overlap, but tier is what finally decides.

### 3.4 Level-by-Level Design

**Easy — "Relax"**
- Solvable with **singles only**; every step is visible without notes if the player scans carefully.
- Wrong digits turn red immediately and there is no mistake limit, so beginners learn without fear.
- Generous help: 5 hints, auto-fill notes, auto-remove notes.

**Medium — "Think"**
- Needs at least one **pair/triple or pointing/box-line** step; players who only look for singles will get stuck and learn to use notes.
- Instant feedback with a 5-mistake limit — errors matter but are forgiving.
- 3 hints, notes helpers still available.

**Hard — "Challenge"**
- Needs at least one **fish (X-Wing/Swordfish), wing (XY/XYZ) or quad**.
- The game no longer tells the player when a digit is wrong unless it creates a duplicate; mistakes can hide for a long time.
- A limited **Check board** (3 uses) reveals incorrect cells. 2 hints. No auto-fill notes.

**Very Hard — "Master"**
- The grader cannot finish it with tiers 1–3; the player needs chains, advanced patterns, or careful trial-and-error with notes.
- **No live feedback of any kind**, 1 Check, 1 hint, no auto-fill and no auto-remove of notes (the player maintains candidates by hand).
- Tightest givens range (22–26) and a 60-minute par.

### 3.5 Acceptance Criteria for a Bundled Puzzle (quality gates)

A puzzle enters the asset pool **only if all gates pass** (enforced by `tool/validate_puzzles.dart`, section 22):

1. **Unique solution:** `countSolutions(puzzle, limit: 2) == 1` (non-negotiable).
2. **Solution consistent:** the stored solution is a valid complete grid that matches all givens.
3. **Tier matches:** `Grader.grade(puzzle).tier == difficulty.tier`.
4. **Givens in range** for the difficulty (section 3.3).
5. **No duplicates** within the pool (compare puzzle strings; optionally compare canonical forms to catch relabeled/rotated copies).
6. **Format:** 81 characters, digits `0–9` only (`0` = empty).

### 3.6 Selection, Unlocking & Pool Size

- Default: **all four levels are unlocked** from the start. (Optional flag `kGateDifficulties`: Hard unlocks after one Medium win; Very Hard after one Hard win.)
- Each difficulty has its **own pool**, its own saved game, completed-puzzle list, best times and stats.
- "New game" picks a **random puzzle not yet completed**; when the pool is exhausted, the app offers a replay or uses the transformer (section 10.5) to create fresh-looking variants.
- Pool size targets (starting values): **200 each** for Easy/Medium/Hard and **as many as the generator yields** for Very Hard (aim for 100+).

### 3.7 Where Each Layer Is Implemented

| Mechanic | Where it lives |
|---|---|
| Givens range, tier acceptance | `PuzzleGenerator.generate()` + `Grader` |
| Instant / conflicts / none feedback | `GameController` + `SudokuPainter` |
| Mistake limit, check limit, hint limit | Counters in `GameController`, initialized from the config |
| Auto-fill / auto-remove notes | `GameController` (`fillAllNotes`, `_setValue`) |
| Par time, base score | `ScoreCalculator` (section 19) |

---

## 4. Feature Scope (MVP → Extensions)

### 4.1 MVP (required – version 1.0)

- [ ] 9×9 board with selection, highlighting of row/column/box and same digits.
- [ ] Digit entry, erase, notes (pencil marks), number pad with remaining counts.
- [ ] Undo/redo.
- [ ] Four difficulties with the assist rules from section 3.3.
- [ ] Bundled, validated puzzle pools (all four levels).
- [ ] Timer with pause, win and lose dialogs.
- [ ] Per-difficulty autosave and basic stats.
- [ ] Sound effects with an on/off toggle.

### 4.2 Enhancements (version 1.1)

- [ ] Logical hints with explanations (tiers 1–3).
- [ ] Check board.
- [ ] Daily puzzle (offline, deterministic by date).
- [ ] Runtime puzzle variants via the transformer.
- [ ] Light/dark theme, haptics, large-digit option, color-blind-safe highlights.
- [ ] Localization (en/vi).

### 4.3 Extensions (version 2.0, optional)

- [ ] Tier 4 techniques in the grader (chains, ALS) with explained hints.
- [ ] "Learn" mode: short interactive lessons for each technique.
- [ ] Practice mode (free assists), custom puzzle entry (type in a puzzle and let the app solve/grade it).
- [ ] Killer/diagonal/6×6 variants.
- [ ] Achievements, statistics charts.

---

## 5. Rules for Staying 100% Offline

1. **No network packages:** no `http`, `dio`, Firebase, AdMob, or `google_fonts` (it downloads fonts at runtime).
2. **Bundle fonts** in `assets/fonts/` and declare them in `pubspec.yaml`.
3. **Puzzles** are JSON files in `assets/puzzles/`, generated ahead of time by Dart scripts in `tool/`.
4. **Audio and images** live in `assets/`.
5. **Player data** (saves, stats, settings, completed puzzle IDs) lives in `shared_preferences`.
6. **Daily puzzle** is derived from the device date and the bundled pool (no server).
7. **Do not declare the `INTERNET` permission** in the release `AndroidManifest.xml` (Flutter adds it automatically only to debug/profile builds for hot reload).
8. Testing: turn on **airplane mode** and run every screen and mode.

---

## 6. Tech Stack & Packages

| Purpose | Choice | Notes |
|---|---|---|
| Framework | Flutter (latest stable), Dart 3.x | |
| State management | `provider` + `ChangeNotifier` | Simple and sufficient |
| Storage | `shared_preferences` | JSON blobs |
| Audio | `audioplayers` | Local files via `AssetSource` |
| Haptics | `HapticFeedback` (built in) | |
| Rendering | `CustomPainter` for the board | One canvas, 81 cells, precise hit-testing |
| Background work | `compute()` (Isolates) | Hints, runtime generation |
| App icon | `flutter_launcher_icons` (dev) | |
| Lints | `flutter_lints` | |

**Sample `pubspec.yaml`:**

```yaml
name: up_sudoku
description: UpSudoku - an offline Sudoku game with four difficulty levels
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: ">=3.3.0 <4.0.0"

dependencies:
  flutter:
    sdk: flutter
  provider: ^6.1.2
  shared_preferences: ^2.2.3
  audioplayers: ^6.0.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
  flutter_launcher_icons: ^0.13.1

flutter:
  uses-material-design: true
  assets:
    - assets/puzzles/
    - assets/audio/
    - assets/images/
  fonts:
    - family: Baloo2
      fonts:
        - asset: assets/fonts/Baloo2-Regular.ttf
        - asset: assets/fonts/Baloo2-Bold.ttf
          weight: 700
```

> Run `flutter pub outdated` before starting; the versions above may be out of date.

**Resolved in Phase 0 (Flutter 3.47.8 / Dart 3.13.7):** `provider ^6.1.5`,
`shared_preferences ^2.5.6`, `audioplayers ^6.8.1`, `flutter_lints ^6.0.0`,
`flutter_launcher_icons ^0.14.4`. `cupertino_icons` was removed (unused).

> **Offline note:** `audioplayers` transitively depends on `http` because it
> supports `UrlSource`. UpSudoku only ever uses `AssetSource`, so no request is
> ever made. Keep `http` out of *direct* dependencies and keep `INTERNET` out of
> the release manifest. Verified in Phase 0: the release APK's merged manifest
> declares no network permission.

---

## 7. Architecture & Folder Structure

### 7.1 Layers

```
┌──────────────────────────────────────────────┐
│ UI (Screens, Widgets, SudokuPainter)         │  ← renders state + sends events
├──────────────────────────────────────────────┤
│ Controllers (ChangeNotifier)                 │  ← GameController, StatsController, SettingsController
├──────────────────────────────────────────────┤
│ Domain (pure Dart, no Flutter imports)       │  ← grid, solver, generator, logic solver, grader, config
├──────────────────────────────────────────────┤
│ Data/Services                                │  ← StorageService, AudioService, PuzzleRepository
└──────────────────────────────────────────────┘
```

**Golden rule:** the Domain layer **must not** import `flutter/*`. That keeps unit tests fast and lets the generator/validator scripts run with plain `dart run`.

### 7.2 Folder Structure

```
up_sudoku/
├─ pubspec.yaml
├─ analysis_options.yaml
├─ assets/
│  ├─ puzzles/
│  │  ├─ easy.json
│  │  ├─ medium.json
│  │  ├─ hard.json
│  │  └─ very_hard.json
│  ├─ audio/
│  │  ├─ tap.mp3
│  │  ├─ place.mp3
│  │  ├─ error.mp3
│  │  ├─ unit_complete.mp3
│  │  └─ win.mp3
│  ├─ images/
│  └─ fonts/
├─ tool/
│  ├─ generate_puzzles.dart        # builds + grades the puzzle pools
│  └─ validate_puzzles.dart        # enforces the quality gates (section 3.5)
├─ lib/
│  ├─ main.dart
│  ├─ app.dart
│  ├─ core/
│  │  ├─ constants.dart
│  │  └─ theme.dart
│  ├─ domain/
│  │  ├─ sudoku_constants.dart     # units, peers, bit helpers
│  │  ├─ models/
│  │  │  ├─ difficulty.dart        # Difficulty, FeedbackMode, DifficultyConfig, kDifficulties
│  │  │  ├─ puzzle_entry.dart
│  │  │  └─ save_data.dart
│  │  ├─ solver.dart               # backtracking (count solutions / solve)
│  │  ├─ generator.dart            # full grid + dig holes + generate()
│  │  ├─ transformer.dart          # isomorphic puzzle variants
│  │  ├─ logic/
│  │  │  ├─ logic_state.dart
│  │  │  ├─ logic_step.dart
│  │  │  ├─ technique.dart         # Technique enum + SolveTechnique interface
│  │  │  ├─ singles.dart
│  │  │  ├─ subsets.dart           # naked/hidden pairs, triples, quads
│  │  │  ├─ intersections.dart     # pointing, box/line
│  │  │  ├─ fish.dart              # X-Wing, Swordfish
│  │  │  ├─ wings.dart             # XY-Wing, XYZ-Wing
│  │  │  └─ grader.dart
│  │  └─ score_calculator.dart
│  ├─ data/
│  │  ├─ storage_service.dart
│  │  ├─ audio_service.dart
│  │  └─ puzzle_repository.dart
│  ├─ controllers/
│  │  ├─ game_controller.dart
│  │  ├─ stats_controller.dart
│  │  └─ settings_controller.dart
│  └─ ui/
│     ├─ screens/
│     │  ├─ splash_screen.dart
│     │  ├─ home_screen.dart
│     │  ├─ game_screen.dart
│     │  ├─ stats_screen.dart
│     │  ├─ settings_screen.dart
│     │  └─ how_to_play_screen.dart
│     └─ widgets/
│        ├─ sudoku_board.dart       # gesture handling + CustomPaint
│        ├─ sudoku_painter.dart
│        ├─ number_pad.dart
│        ├─ game_toolbar.dart
│        ├─ difficulty_card.dart
│        ├─ hint_panel.dart
│        └─ result_dialog.dart
└─ test/
   ├─ constants_test.dart
   ├─ solver_test.dart
   ├─ generator_test.dart
   ├─ techniques_test.dart
   ├─ grader_test.dart
   ├─ transformer_test.dart
   └─ game_controller_test.dart
```

---

## 8. Data Models

### 8.1 Puzzle Pool Format (`assets/puzzles/<difficulty>.json`)

```json
{
  "version": 1,
  "difficulty": "hard",
  "puzzles": [
    {
      "id": 1,
      "p": "<81 chars: puzzle, 0 = empty>",
      "s": "<81 chars: full solution>",
      "g": 28,
      "score": 143
    }
  ]
}
```

`g` = number of givens, `score` = weighted technique score from the grader (used only to sort/diagnose; see 11.5).

### 8.2 Puzzle Entry

```dart
// lib/domain/models/puzzle_entry.dart
import 'difficulty.dart';

class PuzzleEntry {
  final int id;
  final Difficulty difficulty;
  final List<int> puzzle;    // 81 ints, 0 = empty
  final List<int> solution;  // 81 ints, 1..9
  final int givens;
  final int score;

  const PuzzleEntry({
    required this.id,
    required this.difficulty,
    required this.puzzle,
    required this.solution,
    required this.givens,
    required this.score,
  });

  static List<int> decode(String s) =>
      [for (var i = 0; i < s.length; i++) s.codeUnitAt(i) - 48];

  static String encode(List<int> cells) => cells.join();

  factory PuzzleEntry.fromJson(Map<String, dynamic> j, Difficulty d) => PuzzleEntry(
        id: j['id'] as int,
        difficulty: d,
        puzzle: decode(j['p'] as String),
        solution: decode(j['s'] as String),
        givens: j['g'] as int,
        score: j['score'] as int,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'p': encode(puzzle),
        's': encode(solution),
        'g': givens,
        'score': score,
      };
}
```

### 8.3 Saved Game, Stats, Settings

```dart
// lib/domain/models/save_data.dart
import 'difficulty.dart';

class SavedGame {
  final Difficulty difficulty;
  final int puzzleId;
  final List<int> values;     // current digits (0 = empty), includes givens
  final List<int> notes;      // 81 bitmasks (bit d-1 = note for digit d)
  final int elapsedSeconds;
  final int mistakes;
  final int hintsUsed;
  final int checksUsed;

  const SavedGame({
    required this.difficulty,
    required this.puzzleId,
    required this.values,
    required this.notes,
    required this.elapsedSeconds,
    required this.mistakes,
    required this.hintsUsed,
    required this.checksUsed,
  });

  Map<String, dynamic> toJson() => {
        'd': difficulty.name,
        'id': puzzleId,
        'v': values.join(),
        'n': notes,
        't': elapsedSeconds,
        'm': mistakes,
        'h': hintsUsed,
        'c': checksUsed,
      };

  factory SavedGame.fromJson(Map<String, dynamic> j) => SavedGame(
        difficulty: Difficulty.values.byName(j['d'] as String),
        puzzleId: j['id'] as int,
        values: [for (final ch in (j['v'] as String).codeUnits) ch - 48],
        notes: (j['n'] as List).cast<int>().toList(),
        elapsedSeconds: j['t'] as int,
        mistakes: j['m'] as int,
        hintsUsed: j['h'] as int,
        checksUsed: j['c'] as int,
      );
}

class DifficultyStats {
  int started;
  int completed;
  int bestSeconds;        // 0 = none yet
  int totalSeconds;
  int flawlessWins;       // no mistakes, no hints, no checks
  int currentStreak;
  int bestStreak;
  Set<int> completedIds;  // puzzle ids already solved in this difficulty

  DifficultyStats({
    this.started = 0,
    this.completed = 0,
    this.bestSeconds = 0,
    this.totalSeconds = 0,
    this.flawlessWins = 0,
    this.currentStreak = 0,
    this.bestStreak = 0,
    Set<int>? completedIds,
  }) : completedIds = completedIds ?? {};

  Map<String, dynamic> toJson() => {
        'started': started,
        'completed': completed,
        'best': bestSeconds,
        'total': totalSeconds,
        'flawless': flawlessWins,
        'streak': currentStreak,
        'bestStreak': bestStreak,
        'ids': completedIds.toList(),
      };

  factory DifficultyStats.fromJson(Map<String, dynamic> j) => DifficultyStats(
        started: j['started'] ?? 0,
        completed: j['completed'] ?? 0,
        bestSeconds: j['best'] ?? 0,
        totalSeconds: j['total'] ?? 0,
        flawlessWins: j['flawless'] ?? 0,
        currentStreak: j['streak'] ?? 0,
        bestStreak: j['bestStreak'] ?? 0,
        completedIds: ((j['ids'] as List?) ?? const []).cast<int>().toSet(),
      );
}

class Settings {
  bool sound;
  bool vibration;
  bool darkMode;
  bool highlightPeers;     // highlight row/column/box of the selected cell
  bool highlightSameDigit;
  bool largeDigits;
  String locale;           // 'en' | 'vi'

  Settings({
    this.sound = true,
    this.vibration = true,
    this.darkMode = false,
    this.highlightPeers = true,
    this.highlightSameDigit = true,
    this.largeDigits = false,
    this.locale = 'en',
  });

  Map<String, dynamic> toJson() => {
        'sound': sound,
        'vibration': vibration,
        'darkMode': darkMode,
        'peers': highlightPeers,
        'same': highlightSameDigit,
        'large': largeDigits,
        'locale': locale,
      };

  factory Settings.fromJson(Map<String, dynamic> j) => Settings(
        sound: j['sound'] ?? true,
        vibration: j['vibration'] ?? true,
        darkMode: j['darkMode'] ?? false,
        highlightPeers: j['peers'] ?? true,
        highlightSameDigit: j['same'] ?? true,
        largeDigits: j['large'] ?? false,
        locale: j['locale'] ?? 'en',
      );
}
```

---

## 9. Core Domain: Constants, Grid & Backtracking Solver

### 9.1 Constants and Helpers

```dart
// lib/domain/sudoku_constants.dart
const int kAll = 0x1FF; // bits 0..8 → candidates 1..9

int rowOf(int i) => i ~/ 9;
int colOf(int i) => i % 9;
int boxOf(int i) => (i ~/ 27) * 3 + (i % 9) ~/ 3;

/// Bit for digit d (1..9).
int bit(int d) => 1 << (d - 1);

int popCount(int x) {
  var n = 0;
  while (x != 0) {
    x &= x - 1;
    n++;
  }
  return n;
}

/// Digits (1..9) contained in a candidate mask.
List<int> digitsOf(int mask) =>
    [for (var d = 1; d <= 9; d++) if ((mask & bit(d)) != 0) d];

final List<List<int>> kRows = [
  for (var r = 0; r < 9; r++) [for (var c = 0; c < 9; c++) r * 9 + c],
];

final List<List<int>> kCols = [
  for (var c = 0; c < 9; c++) [for (var r = 0; r < 9; r++) r * 9 + c],
];

final List<List<int>> kBoxes = [
  for (var b = 0; b < 9; b++)
    [
      for (var k = 0; k < 9; k++)
        ((b ~/ 3) * 3 + k ~/ 3) * 9 + (b % 3) * 3 + k % 3,
    ],
];

/// 27 units: 9 rows, 9 columns, 9 boxes.
final List<List<int>> kUnits = [...kRows, ...kCols, ...kBoxes];

/// The 20 peers of each cell.
final List<List<int>> kPeers = [
  for (var i = 0; i < 81; i++)
    {...kRows[rowOf(i)], ...kCols[colOf(i)], ...kBoxes[boxOf(i)]}
        .where((j) => j != i)
        .toList(),
];
```

### 9.2 Backtracking Solver (counts solutions)

Used for **uniqueness checks** (the generator calls it thousands of times, so it must be fast) and for producing full solutions. It uses bitmasks per row/column/box and the **minimum remaining values** heuristic (always branch on the cell with the fewest candidates).

```dart
// lib/domain/solver.dart
import 'dart:math';
import 'sudoku_constants.dart';

class SudokuSolver {
  /// Number of solutions, stopping once [limit] is reached.
  /// Use limit = 2 to test uniqueness. Returns 0 for contradictory givens.
  static int countSolutions(List<int> puzzle, {int limit = 2}) {
    final s = _Search(puzzle, limit, null)..run();
    return s.found;
  }

  /// One solution (random if [rng] is given), or null if none exists.
  static List<int>? solve(List<int> puzzle, {Random? rng}) {
    final s = _Search(puzzle, 1, rng)..run();
    return s.first;
  }
}

class _Search {
  final List<int> cells;
  final int limit;
  final Random? rng;
  final List<int> rows = List.filled(9, 0);
  final List<int> cols = List.filled(9, 0);
  final List<int> boxes = List.filled(9, 0);
  int found = 0;
  List<int>? first;

  _Search(List<int> puzzle, this.limit, this.rng) : cells = List<int>.of(puzzle);

  void run() {
    for (var i = 0; i < 81; i++) {
      final v = cells[i];
      if (v == 0) continue;
      final b = bit(v);
      final r = rowOf(i), c = colOf(i), x = boxOf(i);
      if ((rows[r] & b) != 0 || (cols[c] & b) != 0 || (boxes[x] & b) != 0) {
        return; // contradictory givens → 0 solutions
      }
      rows[r] |= b;
      cols[c] |= b;
      boxes[x] |= b;
    }
    _dfs();
  }

  void _dfs() {
    // Pick the empty cell with the fewest candidates (MRV).
    var best = -1;
    var bestMask = 0;
    var bestCount = 10;
    for (var i = 0; i < 81; i++) {
      if (cells[i] != 0) continue;
      final mask = kAll & ~(rows[rowOf(i)] | cols[colOf(i)] | boxes[boxOf(i)]);
      final n = popCount(mask);
      if (n < bestCount) {
        best = i;
        bestMask = mask;
        bestCount = n;
        if (n <= 1) break;
      }
    }

    if (best == -1) {            // no empty cell: a full valid grid
      found++;
      first ??= List<int>.of(cells);
      return;
    }
    if (bestCount == 0) return;  // dead end

    final r = rowOf(best), c = colOf(best), x = boxOf(best);
    final digits = digitsOf(bestMask);
    if (rng != null) digits.shuffle(rng);

    for (final d in digits) {
      if (found >= limit) return;
      final b = bit(d);
      cells[best] = d;
      rows[r] |= b;
      cols[c] |= b;
      boxes[x] |= b;
      _dfs();
      rows[r] &= ~b;
      cols[c] &= ~b;
      boxes[x] &= ~b;
      cells[best] = 0;
    }
  }
}
```

**Notes**

- `solve(List.filled(81, 0), rng: rng)` returns a random complete grid (used as the generator's starting point).
- With `limit: 2` the search stops as soon as a second solution is found, so uniqueness checks on typical puzzles are very fast.

---

## 10. Puzzle Generation & the Offline Puzzle Pool

### 10.1 Algorithm

1. **Random full grid:** `SudokuSolver.solve(emptyGrid, rng: rng)`.
2. **Dig holes:** visit cells in random order and remove a cell (and optionally its 180° rotational partner) only if the puzzle **still has exactly one solution**.
3. Pick a **target number of givens** at random inside the difficulty's range and stop digging there (or when no more cells can be removed).
4. **Re-grade after every successful removal** once the givens count is inside the range, and accept the first puzzle whose tier matches and whose givens are ≤ the target. Grading only once, after digging all the way down, almost never hits Medium/Hard: measured yield was 0 % for both.
5. Repeat until the pool is full.

> Reference: the smallest number of givens that can give a unique 9×9 Sudoku is 17, so the Very Hard range (22–26) is well above the theoretical minimum and reachable.

### 10.2 Hole Digging

```dart
// lib/domain/generator.dart
import 'dart:math';
import 'models/difficulty.dart';
import 'models/puzzle_entry.dart';
import 'logic/grader.dart';
import 'solver.dart';

class PuzzleGenerator {
  /// Removes cells while the solution stays unique, until [targetGivens]
  /// remain or no more cells can be removed.
  static List<int> dig(
    List<int> solution,
    int targetGivens,
    Random rng, {
    bool symmetric = true,
  }) {
    final puzzle = List<int>.of(solution);
    final order = List<int>.generate(81, (i) => i)..shuffle(rng);
    var givens = 81;

    for (final i in order) {
      if (givens <= targetGivens) break;
      if (puzzle[i] == 0) continue;

      final j = symmetric ? 80 - i : i;     // 180° rotational partner
      final a = puzzle[i];
      final b = puzzle[j];
      puzzle[i] = 0;
      puzzle[j] = 0;
      final removed = i == j ? 1 : 2;

      if (SudokuSolver.countSolutions(puzzle, limit: 2) == 1) {
        givens -= removed;
      } else {
        puzzle[i] = a;                       // undo
        puzzle[j] = b;
      }
    }
    return puzzle;
  }

  /// Generates one puzzle for [cfg], or null if all attempts fail.
  static PuzzleEntry? generate(
    DifficultyConfig cfg,
    Random rng, {
    int id = 0,
    int maxAttempts = 500,
  }) {
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final solution = SudokuSolver.solve(List.filled(81, 0), rng: rng)!;
      final target =
          cfg.minGivens + rng.nextInt(cfg.maxGivens - cfg.minGivens + 1);
      final puzzle = dig(solution, target, rng);

      final givens = puzzle.where((v) => v != 0).length;
      if (givens < cfg.minGivens || givens > cfg.maxGivens) continue;

      final grade = Grader.standard().grade(puzzle);
      if (grade.tier != cfg.tier) continue;

      return PuzzleEntry(
        id: id,
        difficulty: cfg.id,
        puzzle: puzzle,
        solution: solution,
        givens: givens,
        score: grade.score,
      );
    }
    return null;
  }
}
```

**Efficiency improvement (implemented):** instead of digging to the target and grading once, `PuzzleGenerator._digWithGrade` re-grades after each successful removal and stops as soon as the puzzle reaches the desired tier (and givens are in range). Because removing clues generally makes puzzles harder, this raises the yield enormously: with the full grader a 200-puzzle Medium pool takes ~3 s and 200 Hard puzzles ~4 s; 120 Very Hard puzzles took ~5 s with seed 42. Measured per dig attempt (`dart run tool/measure_yield.dart`): 1 attempt in ~1 (Easy), ~90 (Medium), ~34 (Hard) and ~43 (Very Hard) produces a puzzle — a dig is cheap, so a pool still fills in seconds.

**Yield caveat:** many random puzzles will not match the requested tier (especially Very Hard). Measure the acceptance rate for each difficulty during Phase 2 and let the generation script run longer (or overnight) for Very Hard; do not lower the tier standard to hit a pool size.

### 10.3 Generation Script

```dart
// tool/generate_puzzles.dart
// Usage: dart run tool/generate_puzzles.dart <difficulty> <count> [seed]
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:up_sudoku/domain/generator.dart';
import 'package:up_sudoku/domain/models/difficulty.dart';

void main(List<String> args) {
  final d = Difficulty.values.byName(args[0]);
  final count = int.parse(args[1]);
  final seed = args.length > 2 ? int.parse(args[2]) : DateTime.now().millisecondsSinceEpoch;
  final cfg = kDifficulties[d]!;
  final rng = Random(seed);

  final file = File('assets/puzzles/${_fileName(d)}.json');
  final seen = <String>{};
  final puzzles = <Map<String, dynamic>>[];

  // Resume: keep puzzles that already exist.
  if (file.existsSync()) {
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    for (final p in json['puzzles'] as List) {
      puzzles.add(Map<String, dynamic>.from(p));
      seen.add(p['p'] as String);
    }
  }

  var attempts = 0;
  final watch = Stopwatch()..start();
  while (puzzles.length < count) {
    attempts++;
    final entry = PuzzleGenerator.generate(cfg, rng, id: puzzles.length + 1, maxAttempts: 50);
    if (entry == null) continue;
    final key = entry.puzzle.join();
    if (!seen.add(key)) continue;           // skip duplicates
    puzzles.add(entry.toJson());
    stdout.writeln('${d.name} ${puzzles.length}/$count  givens=${entry.givens}  score=${entry.score}');
  }

  file.writeAsStringSync(const JsonEncoder.withIndent(' ').convert({
    'version': 1,
    'difficulty': d.name,
    'puzzles': puzzles,
  }));
  stdout.writeln('Done in ${watch.elapsed}. generate() calls: $attempts');
}

String _fileName(Difficulty d) => d == Difficulty.veryHard ? 'very_hard' : d.name;
```

Run once per difficulty, e.g. `dart run tool/generate_puzzles.dart hard 200 42`. Commit the JSON files. Then run `tool/validate_puzzles.dart` (section 22).

### 10.4 Runtime Loading

```dart
// lib/data/puzzle_repository.dart
import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;
import '../domain/models/difficulty.dart';
import '../domain/models/puzzle_entry.dart';

class PuzzleRepository {
  final Map<Difficulty, List<PuzzleEntry>> _pools = {};

  Future<void> load() async {
    for (final d in Difficulty.values) {
      final name = d == Difficulty.veryHard ? 'very_hard' : d.name;
      final raw = await rootBundle.loadString('assets/puzzles/$name.json');
      final json = jsonDecode(raw) as Map<String, dynamic>;
      _pools[d] = [
        for (final p in json['puzzles'] as List)
          PuzzleEntry.fromJson(Map<String, dynamic>.from(p), d),
      ];
    }
  }

  int poolSize(Difficulty d) => _pools[d]!.length;

  PuzzleEntry byId(Difficulty d, int id) =>
      _pools[d]!.firstWhere((p) => p.id == id);

  /// Random puzzle not yet completed; falls back to any puzzle when all are done.
  PuzzleEntry pick(Difficulty d, Set<int> completed, Random rng) {
    final pool = _pools[d]!;
    final fresh = pool.where((p) => !completed.contains(p.id)).toList();
    final source = fresh.isNotEmpty ? fresh : pool;
    return source[rng.nextInt(source.length)];
  }

  /// Deterministic daily puzzle (see section 19.4).
  PuzzleEntry daily(DateTime date) {
    final d = dailyDifficulty(date);
    final pool = _pools[d]!;
    final day = DateTime.utc(date.year, date.month, date.day)
        .difference(DateTime.utc(2024, 1, 1))
        .inDays;
    return pool[day % pool.length];
  }
}

/// Mon–Tue easy, Wed medium, Thu–Fri hard, Sat–Sun very hard (example).
Difficulty dailyDifficulty(DateTime date) {
  switch (date.weekday) {
    case DateTime.monday:
    case DateTime.tuesday:
      return Difficulty.easy;
    case DateTime.wednesday:
      return Difficulty.medium;
    case DateTime.thursday:
    case DateTime.friday:
      return Difficulty.hard;
    default:
      return Difficulty.veryHard;
  }
}
```

### 10.5 Infinite Variety Offline: Puzzle Transformer (optional, v1.1)

Relabeling digits, permuting rows within bands (and bands themselves), permuting columns within stacks, and transposing all produce a puzzle that is **isomorphic** to the original: it keeps the same unique-solution property and the same technique tier. One bundled puzzle can therefore yield a huge number of different-looking puzzles at runtime.

```dart
// lib/domain/transformer.dart
import 'dart:math';

class PuzzleTransformer {
  static ({List<int> puzzle, List<int> solution}) randomize(
    List<int> puzzle,
    List<int> solution,
    Random rng,
  ) {
    final digits = (List<int>.generate(9, (i) => i + 1))..shuffle(rng);
    final digitMap = [0, ...digits];            // 0 stays 0 (empty)
    final rowOrder = _axisOrder(rng);
    final colOrder = _axisOrder(rng);
    final transpose = rng.nextBool();

    List<int> map(List<int> src) {
      final out = List<int>.filled(81, 0);
      for (var r = 0; r < 9; r++) {
        for (var c = 0; c < 9; c++) {
          final nr = rowOrder[r];
          final nc = colOrder[c];
          final to = transpose ? nc * 9 + nr : nr * 9 + nc;
          out[to] = digitMap[src[r * 9 + c]];
        }
      }
      return out;
    }

    return (puzzle: map(puzzle), solution: map(solution));
  }

  /// A permutation of 0..8 that keeps bands together:
  /// shuffles the three bands and the three lines inside each band.
  static List<int> _axisOrder(Random rng) {
    final bands = [0, 1, 2]..shuffle(rng);
    final result = List<int>.filled(9, 0);
    for (var b = 0; b < 3; b++) {
      final inner = [0, 1, 2]..shuffle(rng);
      for (var k = 0; k < 3; k++) {
        result[b * 3 + k] = bands[b] * 3 + inner[k];
      }
    }
    return result;
  }
}
```

Use it when the pool of un-played puzzles runs out, or always, to hide repetition. Track the **original id** as completed (not the transformed puzzle).

---

## 11. Logic Solver, Techniques & Grader

### 11.1 Why a Separate Logic Solver?

The backtracking solver proves *uniqueness* but says nothing about *difficulty*. The **logic solver** mimics a human: it keeps a candidate set per cell and applies named techniques. It is used for three things: grading (generation), hints (gameplay), and technique tests.

### 11.2 State and Steps

```dart
// lib/domain/logic/logic_state.dart
import '../sudoku_constants.dart';

class LogicState {
  final List<int> values;  // 0 = empty
  final List<int> cand;    // candidate bitmask per empty cell, 0 for filled cells

  LogicState(this.values, this.cand);

  /// Computes candidates from the placed digits only.
  factory LogicState.fromPuzzle(List<int> puzzle) {
    final values = List<int>.of(puzzle);
    final cand = List<int>.filled(81, 0);
    for (var i = 0; i < 81; i++) {
      if (values[i] != 0) continue;
      var used = 0;
      for (final p in kPeers[i]) {
        if (values[p] != 0) used |= bit(values[p]);
      }
      cand[i] = kAll & ~used;
    }
    return LogicState(values, cand);
  }

  void place(int cell, int digit) {
    values[cell] = digit;
    cand[cell] = 0;
    final b = bit(digit);
    for (final p in kPeers[cell]) {
      cand[p] &= ~b;
    }
  }

  void eliminate(int cell, int mask) => cand[cell] &= ~mask;

  bool get solved => !values.contains(0);

  bool get hasContradiction {
    for (var i = 0; i < 81; i++) {
      if (values[i] == 0 && cand[i] == 0) return true;
    }
    return false;
  }
}
```

```dart
// lib/domain/logic/technique.dart
import 'logic_state.dart';
import 'logic_step.dart';

enum Technique {
  nakedSingle, hiddenSingle,
  nakedPair, hiddenPair, nakedTriple, hiddenTriple, pointing, boxLine,
  nakedQuad, hiddenQuad, xWing, swordfish, xyWing, xyzWing,
}

abstract class SolveTechnique {
  Technique get id;
  int get tier;                      // 1..3 (4 = not implemented)
  /// First applicable step, or null if the technique does not apply now.
  LogicStep? find(LogicState s);
}
```

```dart
// lib/domain/logic/logic_step.dart
import 'logic_state.dart';
import 'technique.dart';

class LogicStep {
  final Technique technique;
  final int? cell;                    // placement
  final int? digit;                   // placement
  final Map<int, int> eliminations;   // cell → candidate mask to remove
  final List<int> pattern;            // cells forming the pattern (for hint highlighting)

  LogicStep.place(this.technique, int this.cell, int this.digit,
      {this.pattern = const []})
      : eliminations = const {};

  LogicStep.eliminate(this.technique, this.eliminations,
      {this.pattern = const []})
      : cell = null,
        digit = null;

  bool get isPlacement => cell != null;

  void applyTo(LogicState s) {
    if (cell != null) s.place(cell!, digit!);
    eliminations.forEach(s.eliminate);
  }
}
```

### 11.3 Technique Examples

Each technique is a small class returning the **first** step it can find. Implement tier 1 first, then tier 2, then tier 3 (the roadmap in section 24 reserves time for each).

```dart
// lib/domain/logic/singles.dart
import '../sudoku_constants.dart';
import 'logic_state.dart';
import 'logic_step.dart';
import 'technique.dart';

class NakedSingle implements SolveTechnique {
  @override Technique get id => Technique.nakedSingle;
  @override int get tier => 1;

  @override
  LogicStep? find(LogicState s) {
    for (var i = 0; i < 81; i++) {
      final m = s.cand[i];
      if (s.values[i] == 0 && m != 0 && (m & (m - 1)) == 0) {
        return LogicStep.place(id, i, m.bitLength, pattern: [i]);
      }
    }
    return null;
  }
}

class HiddenSingle implements SolveTechnique {
  @override Technique get id => Technique.hiddenSingle;
  @override int get tier => 1;

  @override
  LogicStep? find(LogicState s) {
    for (final unit in kUnits) {
      for (var d = 1; d <= 9; d++) {
        final b = bit(d);
        var count = 0;
        var only = -1;
        for (final i in unit) {
          if (s.values[i] == d) { count = 99; break; }   // already placed here
          if ((s.cand[i] & b) != 0) { count++; only = i; }
        }
        if (count == 1) return LogicStep.place(id, only, d, pattern: unit);
      }
    }
    return null;
  }
}
```

```dart
// lib/domain/logic/subsets.dart  (excerpt)
class NakedPair implements SolveTechnique {
  @override Technique get id => Technique.nakedPair;
  @override int get tier => 2;

  @override
  LogicStep? find(LogicState s) {
    for (final unit in kUnits) {
      for (var a = 0; a < 9; a++) {
        final ma = s.cand[unit[a]];
        if (popCount(ma) != 2) continue;
        for (var b = a + 1; b < 9; b++) {
          if (s.cand[unit[b]] != ma) continue;
          final elim = <int, int>{};
          for (final i in unit) {
            if (i == unit[a] || i == unit[b]) continue;
            final hit = s.cand[i] & ma;
            if (hit != 0) elim[i] = hit;
          }
          if (elim.isNotEmpty) {
            return LogicStep.eliminate(id, elim, pattern: [unit[a], unit[b]]);
          }
        }
      }
    }
    return null;
  }
}
```

The remaining techniques follow the same pattern:

| Class | Tier | Sketch |
|---|---|---|
| `HiddenPair`, `NakedTriple`, `HiddenTriple` | 2 | Generalize the subset logic with combinations of cells/digits inside a unit |
| `PointingPair` | 2 | For each box and digit: if all candidate cells lie in one row/column, eliminate from the rest of that line |
| `BoxLineReduction` | 2 | For each row/column and digit: if all candidate cells lie in one box, eliminate from the rest of the box |
| `NakedQuad`, `HiddenQuad` | 3 | Same as triples with N = 4 (rare; implement last) |
| `XWing`, `Swordfish` | 3 | For a digit: find 2 (3) rows whose candidate cells fall in the same 2 (3) columns; eliminate from other cells in those columns; repeat with rows/columns swapped |
| `XYWing`, `XYZWing` | 3 | Find pivot + pincers by candidate masks; eliminate the shared digit from cells seeing both pincers (XYZ: cells seeing all three) |

### 11.4 Grader

```dart
// lib/domain/logic/grader.dart
import 'logic_state.dart';
import 'logic_step.dart';
import 'technique.dart';
import 'singles.dart';
// ...import subsets.dart, intersections.dart, fish.dart, wings.dart

class GradeResult {
  final int tier;                       // 1..4
  final bool solvedLogically;
  final Map<Technique, int> usage;      // how many times each technique was used
  final int score;                      // weighted usage (see 11.5)
  const GradeResult(this.tier, this.solvedLogically, this.usage, this.score);
}

class Grader {
  /// Techniques in the order they are tried: simplest first.
  final List<SolveTechnique> techniques;
  Grader(this.techniques);

  factory Grader.standard() => Grader([
        NakedSingle(), HiddenSingle(),
        PointingPair(), BoxLineReduction(),
        NakedPair(), HiddenPair(), NakedTriple(), HiddenTriple(),
        XWing(), XYWing(), XYZWing(), Swordfish(), NakedQuad(), HiddenQuad(),
      ]);

  GradeResult grade(List<int> puzzle) {
    final s = LogicState.fromPuzzle(puzzle);
    final usage = <Technique, int>{};
    var maxTier = 1;
    var score = 0;

    while (!s.solved) {
      LogicStep? step;
      SolveTechnique? used;
      for (final t in techniques) {
        step = t.find(s);
        if (step != null) { used = t; break; }
      }
      if (step == null) {
        // Stuck: needs something beyond the implemented techniques.
        return GradeResult(4, false, usage, score);
      }
      step.applyTo(s);
      if (s.hasContradiction) {
        // Should never happen for a valid puzzle: indicates a technique bug.
        throw StateError('Contradiction while grading — check technique ${used!.id}');
      }
      usage[used!.id] = (usage[used.id] ?? 0) + 1;
      if (used.tier > maxTier) maxTier = used.tier;
      score += kTechniqueWeight[used.id]!;
    }
    return GradeResult(maxTier, true, usage, score);
  }

  /// The next step a human could take from the player's current board
  /// (used by hints). Returns null when stuck.
  LogicStep? nextStep(List<int> values) {
    final s = LogicState.fromPuzzle(values);
    for (final t in techniques) {
      final step = t.find(s);
      if (step != null) return step;
    }
    return null;
  }
}
```

**Ordering note:** within tier 2 the order (pointing, box-line, then subsets) follows the usual "cheapest to spot first" convention. The ordering affects which technique is *recorded* as the hardest needed, so **freeze it** once calibrated and treat any change as a re-grade of the entire pool.

### 11.5 Technique Weights (for the `score` field)

Illustrative starting weights; used only for ordering and diagnostics, never to decide the level:

```dart
const Map<Technique, int> kTechniqueWeight = {
  Technique.nakedSingle: 1,
  Technique.hiddenSingle: 2,
  Technique.pointing: 8,
  Technique.boxLine: 10,
  Technique.nakedPair: 12,
  Technique.hiddenPair: 14,
  Technique.nakedTriple: 20,
  Technique.hiddenTriple: 24,
  Technique.xWing: 40,
  Technique.xyWing: 45,
  Technique.xyzWing: 50,
  Technique.swordfish: 60,
  Technique.nakedQuad: 70,
  Technique.hiddenQuad: 80,
};
```

### 11.6 Grader Correctness Rules

- **Never mutate on failure:** each technique's `find` must only *propose* a step; applying happens in `Grader`.
- **Soundness first:** a technique must never remove a candidate that belongs to the solution. Verify with a **soundness test**: for many generated puzzles, apply each technique step and assert the eliminated candidates never include the digit from the known solution (section 21.3).
- **Completeness is not required:** missing a technique only makes the grader *more conservative* (puzzles may be graded harder than a human would). That is acceptable; wrongly *removing* candidates is not.

---

## 12. Difficulty Config in Code

```dart
// lib/domain/models/difficulty.dart
enum Difficulty { easy, medium, hard, veryHard }

enum FeedbackMode {
  instant,        // wrong digit (≠ solution) is flagged immediately and counts as a mistake
  conflictsOnly,  // only duplicates in a row/column/box are highlighted
  none,           // no live feedback; the player may use "Check board" a limited number of times
}

class DifficultyConfig {
  final Difficulty id;
  final String label;
  final int tier;                   // required grader tier
  final int minGivens;
  final int maxGivens;
  final FeedbackMode feedback;
  final int mistakeLimit;           // -1 = unlimited (instant mode only)
  final int checkLimit;             // "Check board" uses; 0 = button hidden
  final int hintLimit;
  final bool allowAutoFillNotes;
  final bool autoRemoveNotes;
  final int parSeconds;
  final int baseScore;

  const DifficultyConfig({
    required this.id,
    required this.label,
    required this.tier,
    required this.minGivens,
    required this.maxGivens,
    required this.feedback,
    required this.mistakeLimit,
    required this.checkLimit,
    required this.hintLimit,
    required this.allowAutoFillNotes,
    required this.autoRemoveNotes,
    required this.parSeconds,
    required this.baseScore,
  });
}

const Map<Difficulty, DifficultyConfig> kDifficulties = {
  Difficulty.easy: DifficultyConfig(
    id: Difficulty.easy, label: 'Easy', tier: 1,
    minGivens: 38, maxGivens: 45,
    feedback: FeedbackMode.instant, mistakeLimit: -1, checkLimit: 0,
    hintLimit: 5, allowAutoFillNotes: true, autoRemoveNotes: true,
    parSeconds: 600, baseScore: 500,
  ),
  Difficulty.medium: DifficultyConfig(
    id: Difficulty.medium, label: 'Medium', tier: 2,
    minGivens: 32, maxGivens: 37,
    feedback: FeedbackMode.instant, mistakeLimit: 5, checkLimit: 0,
    hintLimit: 3, allowAutoFillNotes: true, autoRemoveNotes: true,
    parSeconds: 1200, baseScore: 1000,
  ),
  Difficulty.hard: DifficultyConfig(
    id: Difficulty.hard, label: 'Hard', tier: 3,
    minGivens: 27, maxGivens: 31,
    feedback: FeedbackMode.conflictsOnly, mistakeLimit: -1, checkLimit: 3,
    hintLimit: 2, allowAutoFillNotes: false, autoRemoveNotes: true,
    parSeconds: 2100, baseScore: 2000,
  ),
  Difficulty.veryHard: DifficultyConfig(
    id: Difficulty.veryHard, label: 'Very Hard', tier: 4,
    minGivens: 22, maxGivens: 26,
    feedback: FeedbackMode.none, mistakeLimit: -1, checkLimit: 1,
    hintLimit: 1, allowAutoFillNotes: false, autoRemoveNotes: false,
    parSeconds: 3600, baseScore: 4000,
  ),
};
```

---

## 13. State Management & GameController

### 13.1 Controllers

| Controller | Responsibility |
|---|---|
| `GameController` | Current game: values, notes, selection, notes mode, timer, mistakes, hints/checks, undo/redo, status |
| `StatsController` | Per-difficulty stats, completed ids, streaks; reads/writes storage |
| `SettingsController` | Sound, haptics, theme, highlight options, language |

Bootstrapping in `main.dart` follows the same `MultiProvider` pattern as a typical Provider app: create `StorageService`, `PuzzleRepository` (call `load()`), `AudioService` (preload), then provide `SettingsController`, `StatsController` and `GameController`. Lock orientation to portrait on phones; allow landscape on tablets.

### 13.2 Undoable Changes

Every user action is a list of `CellChange`s, so auto-removed notes are undone together with the digit that caused them.

```dart
class CellChange {
  final int cell;
  final int oldValue, newValue;
  final int oldNotes, newNotes;
  const CellChange(this.cell, this.oldValue, this.newValue, this.oldNotes, this.newNotes);
}
```

### 13.3 `GameController` (skeleton)

```dart
enum GameStatus { playing, paused, won, lost }

class GameController extends ChangeNotifier {
  // ... dependencies: storage, repo, audio, settings, stats

  late DifficultyConfig cfg;
  late PuzzleEntry entry;
  late List<int> values;          // includes givens
  late List<int> notes;           // 81 bitmasks
  late List<bool> given;

  int? selected;
  bool notesMode = false;
  int mistakes = 0;
  int hintsLeft = 0;
  int checksLeft = 0;
  int hintsUsed = 0;
  int checksUsed = 0;
  int elapsedSeconds = 0;
  Set<int> flagged = {};          // cells marked wrong by "Check board"
  GameStatus status = GameStatus.playing;
  LogicStep? activeHint;

  final List<List<CellChange>> _undo = [];
  final List<List<CellChange>> _redo = [];
  Timer? _timer;

  void startGame(Difficulty d, {PuzzleEntry? specific}) {
    cfg = kDifficulties[d]!;
    entry = specific ?? repo.pick(d, stats.of(d).completedIds, Random());
    values = List<int>.of(entry.puzzle);
    notes = List<int>.filled(81, 0);
    given = [for (final v in entry.puzzle) v != 0];
    selected = null;
    notesMode = false;
    mistakes = 0;
    hintsLeft = cfg.hintLimit;
    checksLeft = cfg.checkLimit;
    hintsUsed = 0;
    checksUsed = 0;
    elapsedSeconds = 0;
    flagged = {};
    activeHint = null;
    status = GameStatus.playing;
    _undo.clear();
    _redo.clear();
    stats.onStarted(d);
    _startTimer();
    notifyListeners();
  }

  void select(int cell) {
    selected = cell;
    audio.play(Sfx.tap);
    notifyListeners();
  }

  /// Digit pad pressed.
  void inputDigit(int d) {
    final i = selected;
    if (i == null || given[i] || status != GameStatus.playing) return;
    notesMode ? _toggleNote(i, d) : _setValue(i, d);
  }

  void erase() {
    final i = selected;
    if (i == null || given[i] || status != GameStatus.playing) return;
    if (values[i] == 0 && notes[i] == 0) return;
    _commit([CellChange(i, values[i], 0, notes[i], 0)]);
  }

  void _toggleNote(int i, int d) {
    if (values[i] != 0) return;           // notes only in empty cells
    _commit([CellChange(i, 0, 0, notes[i], notes[i] ^ bit(d))]);
  }

  void _setValue(int i, int d) {
    if (values[i] == d) return;
    final changes = <CellChange>[CellChange(i, values[i], d, notes[i], 0)];
    if (cfg.autoRemoveNotes) {
      for (final p in kPeers[i]) {
        if ((notes[p] & bit(d)) != 0) {
          changes.add(CellChange(p, values[p], values[p], notes[p], notes[p] & ~bit(d)));
        }
      }
    }
    _commit(changes);
    flagged.remove(i);

    final wrong = d != entry.solution[i];
    if (wrong && cfg.feedback == FeedbackMode.instant) {
      mistakes++;
      audio.play(Sfx.error);
      settings.haptic(HapticKind.error);
      if (cfg.mistakeLimit > 0 && mistakes >= cfg.mistakeLimit) {
        _finish(GameStatus.lost);
        return;
      }
    } else {
      audio.play(Sfx.place);
    }
    _checkWin();
  }

  void _commit(List<CellChange> changes) {
    _apply(changes, undo: false);
    _undo.add(changes);
    _redo.clear();
    activeHint = null;
    _autosave();
    notifyListeners();
  }

  void _apply(List<CellChange> changes, {required bool undo}) {
    for (final c in changes) {
      values[c.cell] = undo ? c.oldValue : c.newValue;
      notes[c.cell] = undo ? c.oldNotes : c.newNotes;
    }
  }

  void undo() {
    if (_undo.isEmpty || status != GameStatus.playing) return;
    final a = _undo.removeLast();
    _apply(a, undo: true);
    _redo.add(a);
    notifyListeners();
  }

  void redo() {
    if (_redo.isEmpty || status != GameStatus.playing) return;
    final a = _redo.removeLast();
    _apply(a, undo: false);
    _undo.add(a);
    notifyListeners();
  }

  /// Fills every empty cell's notes with its current candidates (Easy/Medium only).
  void fillAllNotes() {
    if (!cfg.allowAutoFillNotes || status != GameStatus.playing) return;
    final s = LogicState.fromPuzzle(values);
    final changes = <CellChange>[
      for (var i = 0; i < 81; i++)
        if (values[i] == 0 && notes[i] != s.cand[i])
          CellChange(i, 0, 0, notes[i], s.cand[i]),
    ];
    if (changes.isNotEmpty) _commit(changes);
  }

  void _checkWin() {
    for (var i = 0; i < 81; i++) {
      if (values[i] != entry.solution[i]) {
        // Full board but wrong (only possible with deferred/duplicate-only feedback)
        if (!values.contains(0)) _onFullButWrong();
        return;
      }
    }
    _finish(GameStatus.won);
  }

  void _onFullButWrong() {
    // Show "Not solved yet — something is wrong" without revealing which cell.
    audio.play(Sfx.error);
    notifyListeners();
  }

  void _finish(GameStatus s) {
    status = s;
    _timer?.cancel();
    if (s == GameStatus.won) {
      stats.onWon(cfg.id, entry.id,
          seconds: elapsedSeconds,
          flawless: mistakes == 0 && hintsUsed == 0 && checksUsed == 0);
      audio.play(Sfx.win);
    } else {
      stats.onLost(cfg.id);
    }
    storage.clearGame(cfg.id);
    notifyListeners();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (status == GameStatus.playing) {
        elapsedSeconds++;
        notifyListeners();   // consider a dedicated ValueNotifier for the timer
      }
    });
  }

  void pause() { if (status == GameStatus.playing) { status = GameStatus.paused; _autosave(); notifyListeners(); } }
  void resume() { if (status == GameStatus.paused) { status = GameStatus.playing; notifyListeners(); } }
}
```

**Notes**

- **Wrong-digit rule:** a "mistake" is a digit that differs from the stored solution. Because puzzles have **unique** solutions, this is equivalent to "this digit makes the puzzle unsolvable".
- **Completion** is decided by comparing with the solution (cheap and exact). Do not rely on "no conflicts" alone.
- **Win with `FeedbackMode.none`:** the player never gets feedback until the board is full; if full but wrong, show a neutral message (and keep the game running).
- Use a separate `ValueNotifier<int>` for the timer so the whole board does not rebuild every second.

---

## 14. UI/UX & Screens

### 14.1 Navigation Flow

```
Splash ──► Home ──► Game ──► (Win / Lose dialog) ──► Game (new puzzle) or Home
             │         ▲
             ├──► Daily│
             ├──► Stats└── Continue (resume the saved game of that difficulty)
             ├──► Settings
             └──► How to play
```

### 14.2 Screens

**Splash:** logo + load settings, stats, puzzle pools (≤ 1–2 s).

**Home:**
- Four **difficulty cards**; each shows name, one-line description, rule badges (e.g. "Instant feedback", "5 mistakes", "3 hints", "No live feedback"), best time, and **Continue / New game** buttons.
- A **Daily puzzle** card (today's difficulty, completed check mark).
- Buttons for Stats, Settings, How to play.

**Game:**
- Top bar: back, difficulty label, timer, pause button.
- Status row: mistakes (`1 / 5`, hidden when unlimited), hints left, checks left (when the difficulty has them).
- **Board** (square, section 15).
- Toolbar: `Undo`, `Redo`, `Erase`, `Notes` (toggle, shows ON/OFF), `Hint (n)`, `Check (n)` (only if `checkLimit > 0`), `Auto notes` (only if allowed).
- **Number pad** (1–9) showing remaining counts; a digit is disabled once all nine are placed.
- Pause overlay: board is **hidden** (prevents peeking while the timer is stopped).
- Win dialog: time, mistakes, hints, score, stars, → **Next puzzle** / **Home**.
- Lose dialog (mistake limit): **Retry same puzzle** / **New puzzle** / **Home**.

**Stats:** per difficulty: started, completed, win-rate, best time, average time, flawless wins, current/best streak.

**Settings:** sound, haptics, dark mode, highlight peers, highlight same digit, large digits, language; "Reset data" with confirmation.

**How to play:** rules, controls, and a short description of each difficulty (including what techniques to expect).

### 14.3 Visual Design

- Per-difficulty accent colors: Easy = green, Medium = blue, Hard = orange, Very Hard = purple/red.
- **Distinguish three digit types clearly:** givens (bold, dark), player digits (accent color), notes (small, gray).
- Error styling must not rely on color alone: red background **plus** a small marker (e.g. diagonal hatch or "×" corner icon) for color-blind players.
- Thick 3×3 box borders, thin cell borders; selected cell strongly highlighted, peers lightly, same-digit cells in a third tint.

---

## 15. Board Rendering & Input

### 15.1 One Canvas, Hit-Tested Cells

Render the whole board in a single `CustomPainter` (fewer widgets, smooth, precise) and map taps to cells arithmetically.

```dart
class SudokuBoard extends StatelessWidget {
  const SudokuBoard({super.key});

  @override
  Widget build(BuildContext context) {
    final g = context.watch<GameController>();
    final s = context.watch<SettingsController>();
    return LayoutBuilder(builder: (context, c) {
      final side = min(c.maxWidth, c.maxHeight);
      return Center(
        child: SizedBox(
          width: side,
          height: side,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) {
              final cell = side / 9;
              final col = (d.localPosition.dx / cell).floor().clamp(0, 8);
              final row = (d.localPosition.dy / cell).floor().clamp(0, 8);
              g.select(row * 9 + col);
            },
            child: RepaintBoundary(
              child: CustomPaint(
                painter: SudokuPainter(
                  values: List.of(g.values),
                  notes: List.of(g.notes),
                  given: g.given,
                  selected: g.selected,
                  feedback: g.cfg.feedback,
                  solution: g.entry.solution,
                  flagged: g.flagged,
                  hint: g.activeHint,
                  highlightPeers: s.settings.highlightPeers,
                  highlightSameDigit: s.settings.highlightSameDigit,
                  dark: s.settings.darkMode,
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}
```

### 15.2 Painter Structure

Paint in this order so layers stack correctly:

1. **Cell backgrounds:** base color; peers tint; same-digit tint; selected cell; hint pattern cells; error cells.
2. **Grid lines:** 1 px thin lines between cells, 3 px thick lines on box borders.
3. **Digits:** givens (bold), player digits (accent), centered, font size ≈ `cell × 0.6` (`×0.7` with large digits).
4. **Notes:** nine tiny digits laid out in a 3×3 mini-grid inside the cell, font size ≈ `cell × 0.25`.
5. **Error markers** and hint arrows/outlines on top.

```dart
class SudokuPainter extends CustomPainter {
  // fields: values, notes, given, selected, feedback, solution, flagged, hint,
  //         highlightPeers, highlightSameDigit, dark

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 9;
    final sel = selected;
    final selDigit = sel == null ? 0 : values[sel];
    final peers = sel == null ? const <int>{} : kPeers[sel].toSet();
    final hintCells = hint?.pattern.toSet() ?? const <int>{};

    // 1. backgrounds
    for (var i = 0; i < 81; i++) {
      final rect = Rect.fromLTWH((i % 9) * cell, (i ~/ 9) * cell, cell, cell);
      var color = dark ? const Color(0xFF1E2430) : Colors.white;
      if (sel != null) {
        if (i == sel) {
          color = const Color(0xFFB3D4FF);
        } else if (highlightPeers && peers.contains(i)) {
          color = dark ? const Color(0xFF2A3345) : const Color(0xFFEAF2FF);
        } else if (highlightSameDigit && selDigit != 0 && values[i] == selDigit) {
          color = dark ? const Color(0xFF34506E) : const Color(0xFFD6E8FF);
        }
      }
      if (hintCells.contains(i)) color = const Color(0xFFFFF2B3);
      if (_isWrong(i)) color = const Color(0xFFFFC9C9);
      canvas.drawRect(rect, Paint()..color = color);
    }

    // 2. grid lines
    final thin = Paint()..color = Colors.grey.shade400..strokeWidth = 1;
    final thick = Paint()..color = Colors.black87..strokeWidth = 3;
    for (var k = 0; k <= 9; k++) {
      final p = k % 3 == 0 ? thick : thin;
      canvas.drawLine(Offset(k * cell, 0), Offset(k * cell, size.width), p);
      canvas.drawLine(Offset(0, k * cell), Offset(size.width, k * cell), p);
    }

    // 3 & 4. digits and notes
    for (var i = 0; i < 81; i++) {
      if (values[i] != 0) {
        _paintDigit(canvas, i, cell, bold: given[i]);
      } else if (notes[i] != 0) {
        _paintNotes(canvas, i, cell);
      }
    }
  }

  bool _isWrong(int i) {
    if (given[i] || values[i] == 0) return false;
    switch (feedback) {
      case FeedbackMode.instant:
        return values[i] != solution[i];
      case FeedbackMode.conflictsOnly:
        return _hasConflict(i) || flagged.contains(i);
      case FeedbackMode.none:
        return flagged.contains(i);
    }
  }

  bool _hasConflict(int i) {
    for (final p in kPeers[i]) {
      if (values[p] == values[i]) return true;
    }
    return false;
  }

  @override
  bool shouldRepaint(SudokuPainter old) => true; // inputs are copied per build; tune later
}
```

Performance tips: cache `TextPainter`s per (digit, size, style); repaint only when the controller notifies; do not rebuild the painter for timer ticks (use a separate widget for the timer).

### 15.3 Input

- **Tap** a cell to select it; **tap a digit** on the pad to enter it (or toggle a note when Notes is ON).
- **Drag-select** (optional, v1.1): multi-select cells to write the same note quickly.
- **Double-tap a digit on the pad** (optional): lock that digit and tap cells to place it repeatedly.
- **Long-press the Notes button** (optional): toggle auto-remove behaviour if permitted by the difficulty.
- **Hardware keyboard** (Web/Desktop): `1–9`, `Backspace/Delete`, arrow keys to move, `N` for Notes, `Ctrl+Z/Y` for undo/redo.

---

## 16. Hints, Checks & Assists

### 16.1 Logical Hints

Hints explain a **technique**, not just a value. They are computed by `Grader.nextStep(values)` from the player's **current board** and shown in three escalating stages, all for **one** hint charge:

| Stage | UI | Content |
|---|---|---|
| 1 | Tap "Hint" | Technique name and the region/pattern cells highlighted (e.g. "Hidden Single in this box") |
| 2 | Tap "Show more" | A short explanation ("Digit 7 can only go in this cell of the box") |
| 3 | Tap "Apply" | The digit is placed (or the candidates are removed in notes) |

If the player **already has wrong digits** on the board (detected by comparing with the solution), the hint instead highlights the first wrong cell ("Something here is incorrect") rather than computing a step from corrupted candidates.

### 16.2 Very Hard Fallback

Tier-4 puzzles cannot always produce a logical step (the grader gets stuck). In that case the hint:

1. Says "No simple technique applies — try looking for chains, or use a hint to reveal a cell".
2. On confirmation, **reveals one digit** from the solution (choose the empty cell with the fewest candidates).

### 16.3 Check Board (Hard / Very Hard)

- Compares every player digit with the solution and marks wrong cells (`flagged`), consuming one check.
- Marked cells stay highlighted until the player edits them.
- Using a check reduces the score (section 19) and disqualifies a "flawless" win.

### 16.4 Notes Helpers

- **Auto-fill notes** (Easy/Medium): fills each empty cell's notes with the currently valid candidates; undoable.
- **Auto-remove notes** (Easy/Medium/Hard): placing a digit removes it from the notes of its peers; undoable together with the digit.
- Very Hard: neither helper exists — the player maintains candidates manually.

---

## 17. Local Persistence

### 17.1 `StorageService`

Same pattern as the other games in this series, with versioned keys:

| Key | Content |
|---|---|
| `settings_v1` | `Settings` JSON |
| `stats_v1_<difficulty>` | `DifficultyStats` JSON (includes completed ids) |
| `game_v1_<difficulty>` | `SavedGame` JSON (one slot per difficulty) |
| `daily_v1` | Last completed daily date (`yyyy-MM-dd`) and streak |

Every read goes through `try/catch`; on failure return defaults (never crash on corrupted data).

### 17.2 Principles

- **One saved game per difficulty:** switching difficulty never destroys another game.
- **Autosave** after every change, on pause, and when the app goes to the background (`WidgetsBindingObserver`).
- On resume, restore `values`, `notes`, counters and `elapsedSeconds`; the **undo stack is not saved** (keeps saves small) — the undo button is empty until the next action.
- When a game ends (win/lose), clear that difficulty's saved game.
- Keys carry a version (`_v1`) so formats can be migrated later.

---

## 18. Audio & Haptics

| Event | Sound | Haptic |
|---|---|---|
| Select cell | `tap.mp3` (very short) | none |
| Place digit | `place.mp3` | light |
| Wrong digit (instant feedback) | `error.mp3` | heavy |
| Row/column/box completed | `unit_complete.mp3` | medium |
| Win | `win.mp3` | medium |

- Use **royalty-free (CC0)** audio and record sources in `ASSETS_LICENSE.md`.
- One preloaded `AudioPlayer` per effect, a global on/off flag, haptics gated by the setting.
- Do not vibrate on every selection (annoying for long sessions).

---

## 19. Scoring, Stats & Daily Puzzle

### 19.1 Score

```dart
// lib/domain/score_calculator.dart
class ScoreCalculator {
  static int score({
    required DifficultyConfig cfg,
    required int seconds,
    required int mistakes,
    required int hintsUsed,
    required int checksUsed,
  }) {
    final base = cfg.baseScore;
    final timeFactor = (1 - seconds / cfg.parSeconds).clamp(0.0, 1.0);
    final timeBonus = base * 0.5 * timeFactor;
    final penalty = base * (0.05 * mistakes + 0.10 * hintsUsed + 0.05 * checksUsed);
    return (base + timeBonus - penalty).round().clamp(0, 1 << 30);
  }
}
```

All coefficients (0.5, 0.05, 0.10) are starting values to tune after playtests.

### 19.2 Stars

| Stars | Condition |
|---|---|
| ★★★ | No hints, no checks, no mistakes, and time ≤ par |
| ★★ | ≤ 1 hint and ≤ 2 mistakes (checks count as hints for this rule) |
| ★ | Anything else (the puzzle is solved) |

### 19.3 Stats

Per difficulty: started, completed, win-rate, best time, average time, flawless wins, current and best streak (a lost game or an abandoned-then-replaced game resets the streak; decide and document the rule). Everything is local.

### 19.4 Daily Puzzle

- `PuzzleRepository.daily(date)` picks a puzzle **deterministically** from the pool using the number of days since a fixed epoch, so every device shows the same puzzle for the same date, with no server.
- The difficulty follows the weekday (example mapping in section 10.4).
- Store the last completed date and a daily streak locally.
- Use the **device date**; accept that a user can change the system clock (this is a single-player offline game).

---

## 20. Edge Cases

| # | Situation | Handling |
|---|---|---|
| 1 | Tap a given cell | Select it (for highlighting), but ignore digit input |
| 2 | Enter a digit in a cell that already has the same digit | No-op (do not count a mistake twice) |
| 3 | Enter a digit while Notes mode is ON in a filled cell | Ignore; notes exist only in empty cells |
| 4 | Placing a digit with notes in that cell | Notes of the cell are cleared in the same undoable action |
| 5 | Undo after a mistake | Digit removed, **mistake counter is not decreased** (prevents exploiting undo) |
| 6 | Mistake limit reached | Status `lost`, timer stops, dialog offers retry / new / home |
| 7 | Board full but wrong (conflicts-only / none modes) | Neutral message, game continues; no cell is revealed |
| 8 | Hint requested with wrong digits on the board | Hint points at the first wrong cell instead of a technique step |
| 9 | Hint on a Very Hard puzzle where the grader is stuck | Fallback of section 16.2 |
| 10 | Pause | Timer stops, board hidden behind an overlay |
| 11 | App backgrounded | Auto-pause + autosave; resume when the app returns |
| 12 | Corrupted saved game | `try/catch` → treat as no saved game |
| 13 | Pool exhausted | Reuse (optionally through the transformer, section 10.5) |
| 14 | Digit pad count shows 9 placed but some are wrong | Count digits **placed**, not digits correct (no leakage in non-instant modes) |
| 15 | Auto-fill notes on a board containing wrong digits | Candidates are computed from visible digits only; they may exclude the true solution digit — acceptable and consistent with human logic |
| 16 | Tablet/landscape | Board left, controls right; board is always square |
| 17 | System clock changed (daily) | Accepted; local-only feature |

---

## 21. Testing

### 21.1 Constants & Solver Tests

```dart
// test/constants_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:up_sudoku/domain/sudoku_constants.dart';

void main() {
  test('every cell has exactly 20 peers', () {
    for (var i = 0; i < 81; i++) {
      expect(kPeers[i].length, 20);
      expect(kPeers[i].contains(i), isFalse);
    }
  });

  test('units partition the board', () {
    for (final units in [kRows, kCols, kBoxes]) {
      final all = units.expand((u) => u).toList()..sort();
      expect(all, List.generate(81, (i) => i));
    }
  });

  test('boxOf agrees with kBoxes', () {
    for (var b = 0; b < 9; b++) {
      for (final i in kBoxes[b]) {
        expect(boxOf(i), b);
      }
    }
  });
}
```

```dart
// test/solver_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:up_sudoku/domain/models/puzzle_entry.dart';
import 'package:up_sudoku/domain/solver.dart';

// A widely used example puzzle (30 givens) and its solution.
const _p = '530070000600195000098000060800060003400803001700020006060000280000419005000080079';
const _s = '534678912672195348198342567859761423426853791713924856961537284287419635345286179';

void main() {
  final puzzle = PuzzleEntry.decode(_p);
  final solution = PuzzleEntry.decode(_s);

  test('solves the example puzzle', () {
    expect(SudokuSolver.solve(puzzle), solution);
  });

  test('example puzzle has exactly one solution', () {
    expect(SudokuSolver.countSolutions(puzzle, limit: 2), 1);
  });

  test('an empty grid has more than one solution', () {
    expect(SudokuSolver.countSolutions(List.filled(81, 0), limit: 2), 2);
  });

  test('contradictory givens → zero solutions', () {
    final bad = List<int>.filled(81, 0)..[0] = 5..[1] = 5;
    expect(SudokuSolver.countSolutions(bad), 0);
  });
}
```

### 21.2 Generator Tests

- With fixed seeds, for each difficulty generate ≥ 10 puzzles: assert `countSolutions == 1`, `givens` in range, `solution` matches all givens, and `Grader.standard().grade(puzzle).tier == cfg.tier`.
- `dig` never returns a puzzle whose solution count differs from 1.
- `PuzzleTransformer.randomize`: the transformed puzzle still has exactly one solution, equal to the transformed solution, and the grade tier is unchanged (test on a handful of bundled puzzles).

### 21.3 Technique & Grader Tests

- **Unit tests per technique** with hand-built `LogicState`s (construct `values`/`cand` directly): e.g. a naked pair that must eliminate exactly the expected candidates; a pointing pair; an X-Wing example. Assert both the **step found** and the **resulting eliminations**.
- **Soundness test (critical):** for ~200 generated puzzles of all tiers, run the grader and, at every step, assert that the placed digit equals the known solution digit and that **no eliminated candidate equals the solution digit** of its cell.
- **Tier-1 sanity:** the example puzzle in 21.1 is a classic "easy" puzzle; the grader is expected to return tier 1 for it (verify when implementing, and keep it as a regression test).
- **Stuck detection:** a puzzle that tiers 1–3 cannot finish must return tier 4 with `solvedLogically == false`, and the backtracking solver must still find its (unique) solution.
- **Determinism:** grading the same puzzle twice gives the same result.

### 21.4 Controller Tests

- Entering a correct digit → value set, notes of peers cleared (when `autoRemoveNotes`), no mistake.
- Entering a wrong digit in `instant` mode → mistake +1; reaching the limit → `lost`.
- Entering a wrong digit in `conflictsOnly` / `none` → no mistake, no flag (except via Check).
- Undo/redo restore digits **and** auto-removed notes exactly.
- `fillAllNotes` disabled on Hard/Very Hard.
- Hint consumes exactly one charge; hint limits respected per difficulty.
- Win flow: board equals solution → `won`, stats updated once, saved game cleared.
- Use fake storage or `SharedPreferences.setMockInitialValues({})`.

### 21.5 Manual Test Plan (before release)

- [ ] Play 2 puzzles per difficulty in **airplane mode**.
- [ ] Kill the app mid-game on each difficulty → relaunch → each game restored independently.
- [ ] Verify feedback modes: instant (Easy/Medium), duplicates-only (Hard), none (Very Hard).
- [ ] Verify notes: auto-fill / auto-remove availability per difficulty; undo of auto-removals.
- [ ] Pause hides the board; timer stops.
- [ ] Small phone, large phone, tablet, landscape.
- [ ] Dark mode, large digits, color-blind check (errors visible without relying on red).
- [ ] Daily puzzle shows the same puzzle after relaunch; changes at midnight.

Run: `flutter test` and `flutter analyze`.

---

## 22. Calibration & Validation Workflow

### 22.1 Validate the Pool (hard gate)

```dart
// tool/validate_puzzles.dart  (outline)
// For every puzzle in assets/puzzles/*.json:
//   1. decode puzzle and solution, check length == 81 and digits are valid
//   2. check the solution is a valid full grid and matches the givens
//   3. SudokuSolver.countSolutions(puzzle, limit: 2) == 1
//   4. Grader.standard().grade(puzzle).tier == difficulty tier
//   5. givens within the difficulty's range and equal to the stored "g"
//   6. no duplicate puzzle strings within the pool
// Print a per-difficulty report; exit with code 1 if anything fails.
```

Run it in every release build and whenever the grader changes (**changing a technique or the order requires re-grading the pool**).

### 22.2 Distribution Report

For each difficulty, print: pool size, givens distribution (min/median/max), technique usage histogram, average and maximum `score`. Check:

- Easy puzzles contain **only** singles.
- Medium puzzles include at least one tier-2 step; Hard at least one tier-3 step; Very Hard are stuck after tier 3.
- No difficulty has an extreme outlier (e.g. a "Medium" puzzle requiring 30 pair eliminations).

### 22.3 Human Playtests (the final judge)

Algorithms measure *logical* difficulty; players experience *effort*. Collect, per difficulty, from at least 5 players:

- Solve time (median), mistakes, hints used, abandon rate.
- Perceived difficulty (1–5) and fairness.

Starting hypotheses to compare against (not measured facts): median time roughly **5–10 min** (Easy), **10–20** (Medium), **20–40** (Hard), **40+ or frequent abandonment** (Very Hard). If medians overlap heavily between two levels, adjust the tier boundaries, the `score` cut-offs within a tier, or the assist rules (not the generator) first.

### 22.4 Tuning Levers (in order of safety)

1. **Assist rules** (mistake limit, hint count, par time) — cheapest to change, no re-generation needed.
2. **Pool filtering inside a tier** by `score` (e.g. Medium = tier 2 with score in a window) — no change to generation.
3. **Givens ranges** — requires re-generation.
4. **Technique ordering/tiers** — requires re-grading the whole pool; do this rarely.

---

## 23. Performance & Quality

- The bitmask backtracking solver handles a typical uniqueness check in well under a millisecond-to-a-few-milliseconds range on a laptop (measure on a real device); hint calculation is cheap. Run hints in `compute()` anyway if you add expensive techniques.
- **Runtime generation** (if you add it) must run in an **Isolate** and be time-boxed (e.g. 2 s) with a fallback to the bundled pool.
- Painter: cache `TextPainter`s, avoid allocating lists in `paint()`, separate the timer widget from the board.
- Target **60 fps** on mid-range devices; verify with Flutter DevTools.
- Keep the app small: compress audio, puzzles are text (~200 bytes each → well under 1 MB for thousands).
- Enable `flutter_lints` and fix all warnings.
- **Accessibility:** per-cell semantics ("Row 3, column 5, value 7, given"), large-digit mode, high-contrast theme, non-color error markers, VoiceOver/TalkBack-friendly number pad.

---

## 24. Phased Roadmap

> Estimates assume one developer working part-time (about 2–3 hours/day). Adjust to your experience.

### Phase 0 – Setup (0.5 day) ✅

- [x] `flutter create up_sudoku`, remove sample code, create the folder structure of section 7.2.
- [x] Add dependencies, assets, fonts; set app name to **UpSudoku**; Git init.

Repo layout: docs (`PLAN.md`, `AGENTS.md`, `ASSETS_LICENSE.md`) at the repo root,
the Flutter project in `up_sudoku/`. Package/bundle id
`com.up5tech.upsudoku`. Platforms: Android + iOS (Web/desktop can be added later
with `flutter create --platforms=web .`). Baloo 2 (OFL) is bundled in
`assets/fonts/`; audio and images stay empty until Phase 8.

**Done when:** the app runs with an empty screen and `flutter analyze` is clean.
✅ `flutter analyze` clean, `flutter test` green, debug + release APKs build,
release manifest has no `INTERNET` permission.

### Phase 1 – Core Domain & Tests (2 days)

- [x] `sudoku_constants.dart` with tests.
- [x] Backtracking solver (`countSolutions`, `solve`) with tests, including the example puzzle.
- [x] `Difficulty` / `DifficultyConfig`.

**Done when:** solver tests are green and uniqueness checks are fast.

> Status: implemented in `lib/domain/` (`sudoku_constants.dart`, `solver.dart`,
> `models/difficulty.dart`, `models/puzzle_entry.dart`) with
> `test/constants_test.dart`, `test/solver_test.dart`,
> `test/difficulty_test.dart`, `test/puzzle_entry_test.dart`.
> `flutter analyze` clean, `flutter test` green (28 tests).

### Phase 2 – Generator & Singles Grader (2–3 days)

- [x] `PuzzleGenerator.dig` and `generate` (symmetric digging).
- [x] `LogicState`, `LogicStep`, `NakedSingle`, `HiddenSingle`, `Grader`.
- [x] Measure the acceptance rate per difficulty with only tier-1 grading (Easy works; others fall into "stuck").
- [x] First pool: 50 Easy puzzles.

**Done when:** Easy puzzles are generated, graded tier 1, and validated.

> Status: implemented in `lib/domain/logic/` (`logic_state.dart`, `logic_step.dart`,
> `technique.dart`, `singles.dart`, `grader.dart`) and `lib/domain/generator.dart`,
> with the tools `tool/generate_puzzles.dart`, `tool/validate_puzzles.dart` and
> `tool/measure_yield.dart`. Pool: `assets/puzzles/easy.json` (50 puzzles, givens
> 38–45, score 36–43) — every gate of §22.1 passes.
> `flutter analyze` clean, `flutter test` green (49 tests).
>
> **Acceptance rate with tier-1 grading only** (`tool/measure_yield.dart`,
> 100 samples/difficulty): Easy 90% solved by singles / 0% stuck / 10% out of
> range; Medium 87% / 4% / 9%; Hard 76% / 22% / 2%; Very Hard 19% / 14% / 67%.
> Conclusions for phase 5:
> - Medium and Hard need the tier 2/3 techniques to be graded correctly —
>   almost nothing falls into "stuck" today.
> - Very Hard: symmetric digging only reaches ~24–31 givens, i.e. the
>   22–26 window is mostly unreachable (67% out of range). Phase 5 must dig
>   asymmetrically (or dig further) for the Very Hard pool.
> - Easy yield is high, so the pool can be regenerated cheaply.

### Phase 3 – Playable Prototype on Easy (3 days)

- [x] `PuzzleRepository` (Easy only), `GameController` (digits, erase, win).
- [x] `SudokuPainter` + `SudokuBoard` (selection, highlights, digits).
- [x] Number pad, timer, win dialog.

**Done when:** a full Easy game can be played from start to win.

> Status: implemented in `lib/data/puzzle_repository.dart`,
> `lib/controllers/game_controller.dart` and `lib/ui/` (`screens/home_screen.dart`,
> `screens/game_screen.dart`, `widgets/sudoku_painter.dart`,
> `widgets/sudoku_board.dart`, `widgets/number_pad.dart`,
> `widgets/game_toolbar.dart`, `widgets/game_timer.dart`,
> `widgets/result_dialog.dart`).
> `flutter analyze` clean, `flutter test` green (63 tests, including an
> end-to-end widget test: home → Easy game → tap cell → digit pad → win
> dialog). Verified on an iOS simulator (iPhone 16e): board, timer, mistakes
> counter, number pad with remaining counts and the pause overlay all render
> correctly.
> Still open for later phases: splash screen, notes/undo/hint/check toolbar
> entries, stars and score in the win dialog, persistence.

### Phase 4 – Notes, Undo/Redo, Assist Rules (2 days)

- [x] Notes mode, notes rendering, auto-fill and auto-remove notes.
- [x] `CellChange` undo/redo.
- [x] Feedback modes (`instant`, `conflictsOnly`, `none`), mistakes, lose dialog.

> Implemented in `controllers/game_controller.dart` plus
> `domain/models/cell_change.dart`; the toolbar now offers Undo / Redo /
> Erase / Notes / Auto notes (the last one only for Easy and Medium).
> `flutter analyze` clean, `flutter test` green (81 tests) — including undo
> restoring auto-removed notes, undo never decrementing the mistake counter,
> the Medium 5-mistake loss, and `fillAllNotes` being refused on Hard/
> Very Hard. The "board full but wrong" case shows a neutral snackbar and
> leaves the game running. Still open: audio/haptics on placement and the
> `flagged` cells only "Check board" fills (phase 6).

**Done when:** each difficulty's assist rules behave exactly as in section 3.3.

### Phase 5 – Tier 2 & 3 Techniques and Full Pools (4–5 days)

- [x] Implement tier-2 techniques (pointing, box/line, pairs, triples) with unit tests.
- [x] Implement tier-3 techniques (quads, X-Wing, Swordfish, XY-Wing, XYZ-Wing) with unit tests.
- [x] Soundness test (section 21.3).
- [x] Generate and validate pools: Medium, Hard, Very Hard (leave long runs overnight).
- [x] Distribution report (22.2).

> Techniques live in `subsets.dart` (naked/hidden 2–4), `intersections.dart`
> (pointing, box/line), `fish.dart` (X-Wing, Swordfish) and `wings.dart`
> (XY/XYZ-Wing); the frozen order in `technique.dart` is unchanged. Every
> technique returns a step only when it removes or places something, and the
> grader trips on a no-progress step instead of looping.
> Pools: Easy 200, Medium 200, Hard 200, Very Hard 120 — all pass
> `validate_puzzles.dart` (unique solution, valid grid, tier match, givens in
> range, no duplicates). The generator now re-grades while digging (10.1).
> `flutter test` green (100 tests); the soundness test replays 120 puzzles
> dug to 24–40 givens and checks every placement and elimination against the
> known solution.
> Distribution (per pool, technique uses): Easy singles only; Medium adds
> pointing/box-line/pairs; Hard adds X-Wing/XY-Wing/XYZ-Wing/Swordfish;
> Very Hard is any puzzle the tiers 1–3 grader cannot finish.

**Done when:** `validate_puzzles.dart` passes for all four pools.

### Phase 6 – Hints, Checks, Scoring (2 days)

- [ ] Logical hints with 3 stages and the Very Hard fallback.
- [ ] Check board (Hard/Very Hard), hint/check limits per difficulty.
- [ ] `ScoreCalculator`, stars, result dialog.

**Done when:** hints/checks respect limits and always give correct information.

### Phase 7 – Persistence, Stats, Settings, Daily (2–3 days)

- [ ] `StorageService`, `StatsController`, `SettingsController`.
- [ ] Autosave/restore per difficulty; Home with difficulty cards and Continue.
- [ ] Stats, Settings and How-to-play screens; daily puzzle.

**Done when:** quitting and relaunching restores every difficulty's game, stats and settings.

### Phase 8 – Polish, Playtests & Release (3 days)

- [ ] Audio, haptics, dark mode, large digits, accessibility semantics.
- [ ] Localization (en/vi).
- [ ] Human playtests and tuning (section 22.3–22.4).
- [ ] Icon, splash, store assets; full manual test (21.5); build and sign release (section 25).

**Done when:** you have an APK/AAB that runs reliably on at least 2 real devices.

**Estimated total:** ≈ 20–23 working days for the full version. A playable Easy game exists after Phase 3; all four difficulties after Phase 5.

---

## 25. Configuration, Build & Release

### 25.1 Android

- `AndroidManifest.xml`: set `android:label="UpSudoku"`; **do not add** the `INTERNET` permission.
- Application ID such as `com.yourname.upsudoku`.
- Create a keystore and `key.properties` for signing (never commit them).

```bash
flutter build apk --release            # .apk for direct install
flutter build appbundle --release      # .aab for Google Play
```

### 25.2 iOS (requires macOS + Xcode)

```bash
flutter build ios --release
```

Set Bundle ID, Team and icon; set `CFBundleDisplayName` to `UpSudoku`.

### 25.3 Web / Desktop (optional)

```bash
flutter build web --release
flutter build windows --release   # or macos / linux
```

The keyboard controls of section 15.3 make Web/Desktop fully usable.

### 25.4 Icon & Splash

```yaml
flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/images/icon.png"
```

Run `dart run flutter_launcher_icons`.

### 25.5 Final Pre-Release Checks

- [ ] `flutter analyze` has no errors; `flutter test` is green.
- [ ] `dart run tool/validate_puzzles.dart` passes (unique solutions, tiers match).
- [ ] Release build runs in airplane mode.
- [ ] No leftover debug `print` calls.
- [ ] `ASSETS_LICENSE.md` lists audio/font sources.
- [ ] `BALANCING.md` records final difficulty numbers, pool sizes and playtest results.

---

## 26. Risks & Mitigations

| Risk | Level | Mitigation |
|---|---|---|
| **A puzzle with more than one solution reaches players** | High | Uniqueness gate in generation **and** in `validate_puzzles.dart`; test over the whole pool in CI/pre-release |
| **Grader bug (unsound technique) mislabels difficulty or breaks hints** | High | Soundness test against known solutions, per-technique unit tests, throw on contradiction while grading |
| Very Hard generation yield is low | Medium | Re-grade while digging, run overnight, accept a smaller Very Hard pool; never lower the tier standard to fill the pool |
| "Very Hard = stuck after tier 3" includes puzzles that are only slightly harder than Hard | Medium | Use the `score`/givens as secondary filters; add tier-4 techniques later (v2.0) for a finer split |
| Difficulty feels wrong despite correct grading | Medium | Human playtests (22.3); tune assists and pool filtering before touching the grader |
| Hints on corrupted boards give wrong advice | Medium | Detect wrong digits first (section 16.1) |
| Hint/solver cost on low-end devices | Low | Isolates; time-boxed runtime generation; prefer the bundled pool |
| Corrupted/old saves after updates | Low | Versioned keys, `try/catch`, fall back to a new game |
| Timer exploits (pause to think, change clock) | Low | Hide the board when paused; daily puzzle is local-only by design |
| Audio latency on some Android devices | Low | `PlayerMode.lowLatency`, short compressed files, preload |
| A package silently needs network access | Low | Re-check `pubspec.yaml`; test in airplane mode |

---

## 27. Completion Checklist

### Gameplay

- [ ] Selection, digit entry, erase, notes, number pad with remaining counts
- [ ] Undo/redo (digits and auto-removed notes together)
- [ ] Row/column/box/same-digit highlighting
- [ ] Four difficulties with the assist rules of section 3.3
- [ ] Win/lose detection, pause, timer, stats, score and stars

### Puzzle Quality

- [ ] All pools generated and validated (unique solution, tier matches, givens in range, no duplicates)
- [ ] Soundness tests for all implemented techniques
- [ ] Distribution report reviewed; Easy = singles only
- [ ] Human playtests done and numbers recorded in `BALANCING.md`

### Features

- [ ] Logical hints (3 stages) + Very Hard fallback
- [ ] Check board (Hard/Very Hard)
- [ ] Autosave/resume per difficulty
- [ ] Daily puzzle, Stats, Settings, How-to-play
- [ ] Sound, haptics, dark mode, large digits, language

### Technical

- [ ] Domain layer does not import Flutter
- [ ] No network-dependent packages; fonts/audio/puzzles in assets; no INTERNET permission in release
- [ ] Smooth ~60 fps; timer isolated from board repaint
- [ ] Accessibility semantics and non-color error markers

### Release

- [ ] Icon, app name (**UpSudoku**), splash
- [ ] Signed APK/AAB built
- [ ] Tested on real devices in airplane mode
- [ ] Asset licenses and balancing notes in the repo

---

### Appendix: Ideas After Version 1.0

1. **Tier-4 techniques** (Jellyfish, W-Wing, XY-Chain, coloring, unique rectangles, ALS-XZ) so Very Hard hints can explain chains and the grader can split Very Hard into "Hard+" and "Extreme".
2. **Learn mode:** a short interactive tutorial for each technique, using stored example positions.
3. **Puzzle import:** let the player type or paste an 81-character puzzle, then validate (unique?), grade, and play it.
4. **Variants:** 6×6 for kids, Diagonal Sudoku, Killer Sudoku (needs a new solver/grader).
5. **Themes and digit styles:** classic, handwritten, minimal; unlocked by completed puzzles.
6. **Replay/export:** save the sequence of moves and replay finished games.
7. **Opening-move helper for beginners:** an overlay that explains scanning rows/columns/boxes step by step on an Easy puzzle.
