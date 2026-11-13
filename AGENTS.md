# AGENTS.md — UpSudoku

Guidance for coding agents working on **UpSudoku**: a fully offline Flutter/Dart 9×9 Sudoku game with four difficulty levels graded by a human-technique solver.

**Source of truth:** [`PLAN.md`](./PLAN.md). This file is a condensed operating manual. When they disagree, `PLAN.md` wins — but update both if you change a decision.

---

## 1. Project facts

| Item | Value |
|---|---|
| App name | UpSudoku |
| Dart package | `up_sudoku` |
| Framework | Flutter (stable), Dart >= 3.3 |
| State management | `provider` + `ChangeNotifier` |
| Storage | `shared_preferences` |
| Audio | `audioplayers` (local `AssetSource` files) |
| Icons / splash | `flutter_launcher_icons` + generated artwork |
| Localization | hand-written en/vi table in `lib/l10n/`, `flutter_localizations` |
| Board rendering | One `CustomPainter` canvas, arithmetic hit-testing |
| Background work | `compute()` (Isolates) for hints / runtime generation |
| Platforms | Android + iOS primary; Web/Desktop optional |
| Network | **None. Ever.** |
| Repo layout | Docs at repo root; Flutter project in `up_sudoku/` |
| App / bundle id | `com.up5tech.upsudoku` |

---

## 2. Non-negotiable rules

1. **Domain layer must not import `flutter/*`.** `lib/domain/**` is pure Dart so `dart run tool/*.dart` works and unit tests stay fast. Flutter imports only in `lib/data`, `lib/controllers`, `lib/ui`, `lib/core`.
2. **No network dependencies.** Forbidden packages: `http`, `dio`, `firebase_*`, `admob`, `google_fonts` (downloads at runtime). No `INTERNET` permission in the release `AndroidManifest.xml`. (`audioplayers` pulls `http` transitively; that is accepted because only `AssetSource` is ever used — never add `http` directly or use `UrlSource`.)
3. **All assets bundled**: fonts in `assets/fonts/`, audio in `assets/audio/`, puzzles in `assets/puzzles/`. Record sources in `ASSETS_LICENSE.md`.
4. **Uniqueness is a hard gate.** A puzzle enters a pool only if `SudokuSolver.countSolutions(puzzle, limit: 2) == 1`. No exceptions, ever.
5. **Tier is the authoritative difficulty classifier** — never the number of givens. Givens ranges are only a generator target + sanity filter.
6. **Techniques may only *propose* steps.** A technique's `find()` must not mutate state; `Grader` applies the step. Removing a candidate that belongs to the solution is a soundness bug (highest severity).
7. **Ordering of techniques is frozen.** Changing the order or a technique changes the recorded tier of every puzzle → requires re-grading the whole pool. Treat as a rare, deliberate act.
8. **Read `PLAN.md` before touching a subsystem.** The plan contains exact configs, code skeletons and rationale; match it unless the task says otherwise.

---

## 3. Architecture

```
UI (screens, widgets, SudokuPainter)      ← renders state, sends events
Controllers (ChangeNotifier)              ← GameController, StatsController, SettingsController
Domain (pure Dart)                        ← constants, solver, generator, logic solver, grader, config
Data/Services                             ← StorageService, AudioService, PuzzleRepository
```

### Folder layout (target)

```
up_sudoku/
├─ pubspec.yaml, analysis_options.yaml
├─ assets/
│  ├─ puzzles/{easy,medium,hard,very_hard}.json
│  ├─ audio/{tap,place,error,unit_complete,win}.mp3
│  ├─ images/, fonts/
├─ tool/
│  ├─ generate_puzzles.dart    # builds + grades pools
│  ├─ validate_puzzles.dart    # enforces the quality gates
│  ├─ measure_yield.dart       # real generate() yield + pool distribution
│  ├─ generate_sounds.py       # synthesises assets/audio/*.wav
│  └─ generate_icon.dart       # draws the icon, adaptive foreground and splash art
├─ lib/
│  ├─ main.dart, app.dart
│  ├─ core/{constants.dart,theme.dart,sound_cue.dart}
│  ├─ l10n/app_localizations.dart   # en/vi strings + delegate
│  ├─ domain/
│  │  ├─ sudoku_constants.dart
│  │  ├─ models/{difficulty.dart,puzzle_entry.dart,save_data.dart}
│  │  ├─ solver.dart, generator.dart, transformer.dart
│  │  ├─ logic/{logic_state.dart,logic_step.dart,technique.dart,singles.dart,
│  │  │         subsets.dart,intersections.dart,fish.dart,wings.dart,grader.dart}
│  │  └─ score_calculator.dart
│  ├─ data/{storage_service.dart,audio_service.dart,puzzle_repository.dart}
│  ├─ controllers/{game_controller.dart,stats_controller.dart,settings_controller.dart}
│  └─ ui/screens/… , ui/widgets/…
└─ test/{constants,solver,generator,techniques,grader,transformer,game_controller}_test.dart
```

---

## 4. Domain cheat sheet

### Grid & bits
- Cell index `0..80`, row-major. `rowOf(i)=i~/9`, `colOf(i)=i%9`, `boxOf(i)=(i~/27)*3+(i%9)~/3`.
- Candidates are 9-bit masks: bit `d-1` = digit `d`. `kAll = 0x1FF`.
- `kUnits` = 9 rows + 9 cols + 9 boxes. `kPeers[i]` = the 20 other cells sharing a unit.
- Helpers: `bit(d)`, `popCount(x)`, `digitsOf(mask)`.

### Solver
`SudokuSolver.countSolutions(puzzle, limit: 2)` for uniqueness; `SudokuSolver.solve(puzzle, rng: rng)` for one solution (random when `rng` given). Backtracking with row/col/box bitmasks + **MRV** (branch on the cell with the fewest candidates).

### Generator
1. Random full grid via `solve(empty, rng: rng)`.
2. Dig holes in random order (with 180° rotational symmetry), keeping the puzzle uniquely solvable.
3. Stop at a target givens count (random inside the difficulty's range).
4. Re-grade after each removal once givens are in range; accept the first puzzle with the target tier and givens ≤ target.
5. Retry with a new solution until the pool is full. This re-grading is what makes Medium/Hard/Very Hard feasible (grading only once, after digging, yields ~0 %).

### Logic solver
- `LogicState`: `values` (0 = empty) + `cand` (bitmask per cell).
- `Technique` enum, `SolveTechnique` interface (`id`, `tier` 1..3, `find(LogicState) -> LogicStep?`).
- `LogicStep`: placement (`cell`, `digit`) or eliminations (`Map<int,int>`), plus `pattern` (cells to highlight for hints).
- `Grader.standard()` applies techniques **simplest first**; the puzzle's tier is the hardest tier ever needed. If stuck → tier 4, `solvedLogically = false`.

### Tiers

| Tier | Level | Techniques |
|---|---|---|
| 1 | Easy | Naked Single, Hidden Single |
| 2 | Medium | Naked/Hidden Pair & Triple, Pointing Pair/Triple, Box/Line Reduction |
| 3 | Hard | Naked/Hidden Quad, X-Wing, Swordfish, XY-Wing, XYZ-Wing |
| 4 | Very Hard | Grader stuck after tiers 1–3 (tier-4 techniques are v2.0) |

### Difficulty configs (source of truth = `lib/domain/models/difficulty.dart`)

| | Easy | Medium | Hard | Very Hard |
|---|---|---|---|---|
| Required tier | 1 | 2 | 3 | 4 |
| Givens | 38–45 | 32–37 | 27–31 | 22–26 |
| Feedback | instant | instant | conflictsOnly | none |
| Mistake limit | unlimited | 5 | — | — |
| Check board uses | 0 | 0 | 3 | 1 |
| Hints | 5 | 3 | 2 | 1 |
| Auto-fill notes | yes | yes | no | no |
| Auto-remove notes | yes | yes | yes | no |
| Par / base score | 10 min / 500 | 20 min / 1000 | 35 min / 2000 | 60 min / 4000 |

These are **starting hypotheses**, not measured facts. Tune via assist rules first, then pool filtering by `score`, then givens ranges, then technique tiers (see PLAN §22.4).

---

## 5. Gameplay rules the code must honour

- **Mistake** = a digit differing from the stored solution. (Valid because solutions are unique.)
- **Win** = board matches the solution exactly. Never rely on "no conflicts" alone.
- **Undo does not decrement the mistake counter** (prevents undo abuse).
- **Digit-pad counters count *placed* digits**, not correct ones (no leakage in `conflictsOnly`/`none`).
- **Notes only in empty cells.** Placing a digit clears that cell's notes and (where allowed) the digit from peers' notes — all in one undoable action.
- **Board full but wrong** (deferred-feedback modes) → neutral message, game continues, no cell revealed.
- **Undo stack is not persisted** (keeps saves small) — the undo button is empty after a restore.
- **One saved game per difficulty**; switching difficulty never destroys another game.
- **Pause hides the board** behind an overlay (prevents peeking) and stops the timer.
- **Very Hard hint fallback**: if the grader is stuck, offer to reveal one cell (fewest candidates).
- **Hint with wrong digits on board**: point at the first wrong cell instead of computing a step from corrupted candidates.

### Feedback modes
- `instant` — wrong digit is flagged immediately (red background **plus** a non-color marker) and counts as a mistake.
- `conflictsOnly` — only duplicates in a row/col/box are highlighted; wrong-but-legal digits are not flagged.
- `none` — no live feedback; only "Check board" (limited uses) reveals wrong cells.

---

## 6. Data & persistence

### Puzzle pool JSON (`assets/puzzles/<difficulty>.json`)

```json
{ "version": 1, "difficulty": "hard",
  "puzzles": [ { "id": 1, "p": "<81 chars, 0=empty>", "s": "<81 chars>", "g": 28, "score": 143 } ] }
```

`g` = givens, `score` = weighted technique score (diagnostics/ordering only, never decides level).

### `shared_preferences` keys (versioned)

| Key | Content |
|---|---|
| `settings_v1` | `Settings` JSON |
| `stats_v1_<difficulty>` | `DifficultyStats` JSON (incl. completed ids) |
| `game_v1_<difficulty>` | `SavedGame` JSON |
| `daily_v1` | last completed daily date + streak |

Every read goes through `try/catch` → fall back to defaults. **Never crash on corrupted data.**

### Autosave
After every change, on pause, and when the app is backgrounded (`WidgetsBindingObserver`). Clear the saved game on win/lose.

### Daily puzzle
Deterministic: difficulty by weekday, puzzle index = `daysSince(2024-01-01) % pool.length`. Uses the device date; no server.

---

## 7. UI guidance

- Navigation: `Splash → Home → Game → (Win/Lose dialog)`.
- **Home**: four difficulty cards (name, description, rule badges, best time, Continue/New game) + Daily card + Stats/Settings/How-to-play buttons.
- **Game**: top bar (back, difficulty, timer, pause), status row (mistakes, hints left, checks left), board, toolbar (Undo, Redo, Erase, Notes, Hint(n), Check(n), Auto notes), number pad with remaining counts.
- **Painter layer order**: backgrounds → grid lines → digits → notes → error markers / hint highlights.
  - Givens bold dark, player digits accent color, notes small grey.
  - Grid: thin 1 px cell lines, thick 3 px box borders.
  - Digit font ≈ `cell * 0.6` (`0.7` in large-digit mode); notes ≈ `cell * 0.25` in a 3×3 mini-grid.
- **Accessibility**: error state must not rely on colour alone (add a marker/icon); per-cell semantics ("Row 3, column 5, value 7, given"); VoiceOver/TalkBack-friendly number pad; large-digit mode; high-contrast theme.
- Accent colours per difficulty: Easy green, Medium blue, Hard orange, Very Hard purple/red.
- Timer must be a **separate widget/`ValueNotifier`** so the board does not repaint every second.

---

## 8. Testing requirements

Run `flutter analyze` (must be clean, `flutter_lints` on) and `flutter test` before considering any task done.

Required coverage:
- `constants_test` — 20 peers per cell, units partition the board, `boxOf` agrees with `kBoxes`.
- `solver_test` — known example puzzle solves, has exactly 1 solution, empty grid has >1, contradictory givens → 0.
- `generator_test` — fixed seeds, ≥10 puzzles per difficulty: unique solution, givens in range, solution matches givens, tier matches.
- `techniques_test` — per technique, hand-built `LogicState`s; assert both the step found and the exact eliminations.
- **Soundness test (critical)** — over ~160 generated puzzles of all tiers: at every grader step, the placed digit equals the solution digit and **no eliminated candidate equals the solution digit** of that cell. The run must also fail unless it actually exercised a tier-2 and a tier-3 technique, so fish/wing eliminations cannot silently stop being covered.
- `grader_test` — determinism; stuck puzzle → tier 4 + `solvedLogically == false` while the backtracking solver still finds its unique solution.
- `transformer_test` — transformed puzzle still uniquely solvable, transformed solution matches, tier unchanged.
- `game_controller_test` — digit entry, mistakes per feedback mode, undo/redo restoring digits **and** auto-removed notes, `fillAllNotes` disabled on Hard/Very Hard, hint charges, win flow (stats once, save cleared), one cue per action. Use `SharedPreferences.setMockInitialValues({})`.
- `localizations_test` — both string tables, parameterized strings, a name for every `Technique` in both locales (unique within a locale), the `Settings.language` JSON round-trip and persistence.
- `audio_cue_test` — a home → game → tap → place run plays one `tap` and one `place` cue through an `AudioService` spy.
- `layout_test` — every screen in Vietnamese at 320×568 with the bundled font, then the game screen on a landscape phone (844×390), a tablet (1024×768), with `textScaler` 1.5–2.0 and with the hint panel open at 844×390 in both text sizes; a render overflow, a board below its minimum usable square, a squeezed pad or a control outside the screen fails the test. Add new screens and sizes to it.
- `theme_test` — WCAG contrast of the light and dark difficulty accents against the board, so a new accent cannot become unreadable in dark mode.

Manual test plan before release: airplane mode, kill-and-restore per difficulty, all three feedback modes, notes helpers per difficulty, pause hides board, small/large phone + tablet + landscape, dark mode + colour-blind check, daily puzzle stable across relaunch.

---

## 9. Tooling

```bash
# Generate pools (one per difficulty; long runs for very_hard)
dart run tool/generate_puzzles.dart easy 200 42
dart run tool/generate_puzzles.dart very_hard 150 42

# Quality gates — MUST pass before any release
dart run tool/validate_puzzles.dart

# Yield + pool distribution report
dart run tool/measure_yield.dart 30 42

flutter analyze && flutter test

# Release builds are signed with the local keystore (android/key.properties +
# android/app/upsudoku-release.keystore, both git-ignored). A fresh clone has
# neither, so release builds need the keystore copied in first.
flutter build apk --release
flutter build appbundle --release   # needs the cmdline-tools SDK package
```

`validate_puzzles.dart` checks per puzzle: format (81 chars, digits 0–9), solution is a valid full grid matching the givens, `countSolutions == 1`, tier matches the difficulty, givens in range and equal to `g`, no duplicates within the pool. Exits non-zero on failure.

Run `validate_puzzles.dart` whenever the grader or technique order changes — the whole pool must be re-graded.

**Measured generator yield** (`dart run tool/measure_yield.dart 30 42`, which calls `PuzzleGenerator.generate()` with its re-grading while digging):

| | Easy | Medium | Hard | Very Hard |
|---|---|---|---|---|
| attempts per accepted puzzle | 1.1 | 89.3 | 33.8 | 43.0 |
| ms per accepted puzzle | 0.6 | 17.1 | 21.5 | 36.5 |

> ⚠️ Do **not** quote 0 % acceptance for Medium/Hard or “90/87/76/19 %” from older notes. Those came from digging to the target and grading **once at the end**, which is not what `PuzzleGenerator.generate()` does; it re-grades after every removal and stops at the first puzzle of the required tier. `measure_yield.dart` measures the real `generate()` path — if a report disagrees with the table above, the generator changed and the table must be re-measured, not the other way round.

---

## 10. Working style for agents

- **Read PLAN.md first**, then the relevant `lib/` files. Do not invent new architecture; extend the plan's structure.
- **Match existing code**: naming (`snake_case` files, `_camelCase` privates), the `CellChange` undo model, `k`-prefixed constants, `SolveTechnique` interface shape.
- **No literal UI text in widgets**: every user-visible string goes through `AppLocalizations` (English + Vietnamese getters); add both translations in the same change.
- **One concern per change.** Keep diffs reviewable; avoid drive-by refactors.
- **Every new domain behaviour needs a test** in the same change.
- **Never lower the difficulty standard to hit a pool size.** If Very Hard yield is low, run generation longer or accept a smaller pool.
- **Keep the app offline-verifiable**: after touching dependencies or the manifest, re-check that nothing network-capable crept in.
- **Don't commit secrets** (`key.properties`, keystores). Don't commit generated caches.
- Update `PLAN.md` checkboxes and `BALANCING.md` when you ship a phase's behaviour or change balancing numbers.

---

## 11. Roadmap (PLAN §24) — track progress here

| Phase | Scope | Status |
|---|---|---|
| 0 | Setup: project, folders, assets, deps | ✅ |
| 1 | Core domain: constants, backtracking solver, difficulty config | ✅ |
| 2 | Generator + tier-1 grader; first Easy pool | ✅ |
| 3 | Playable prototype on Easy (repo, controller, painter, pad, timer) | ✅ |
| 4 | Notes, undo/redo, assist rules & feedback modes | ✅ |
| 5 | Tier 2 & 3 techniques, soundness test, full pools | ✅ |
| 6 | Hints (3 stages + fallback), check board, scoring & stars | ✅ |
| 7 | Persistence, stats, settings, daily puzzle | ✅ |
| 8 | Polish, audio/haptics/theme/i18n, playtests, release | 🟡 audio, haptics, i18n, icon/splash, release signing done; high-contrast, playtests, store material open |

Order matters: do not build UI polish before the puzzle pipeline and grader are correct — difficulty quality is the core value of this app.

---

## 12. Out of scope for v1.0

Tier-4 techniques (Jellyfish, W-Wing, XY-Chain, colouring, unique rectangles, ALS-XZ), Learn mode, puzzle import, 6×6 / diagonal / killer variants, achievements & charts, themes & digit styles, move replay/export.
