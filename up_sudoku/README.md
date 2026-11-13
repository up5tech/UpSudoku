# UpSudoku

An offline 9×9 Sudoku game for Android and iOS, built with Flutter. Four
difficulty levels (Easy, Medium, Hard, Very Hard) are graded by a
human-technique solver, not by clue count.

**No network access, ever.** Puzzle pools are pre-generated and bundled; saves,
stats and settings live in `shared_preferences`.

The full design and roadmap live in [`../PLAN.md`](../PLAN.md); the condensed
operating manual for contributors is [`../AGENTS.md`](../AGENTS.md).

## Layout

```
lib/
  main.dart, app.dart
  core/          app-wide constants, theme
  domain/        pure Dart: constants, solver, generator, logic solver, grader
  data/          storage, audio, puzzle repository
  controllers/   ChangeNotifier controllers
  ui/            screens and widgets
assets/
  puzzles/       per-difficulty puzzle pools (JSON)
  audio/         bundled sound effects
  fonts/         Baloo 2 (SIL OFL 1.1)
tool/            dart scripts: generate_puzzles.dart, validate_puzzles.dart
test/            unit + widget tests
```

`lib/domain/**` must stay free of `flutter/*` imports so `dart run tool/*.dart`
works.

## Commands

```bash
flutter pub get
flutter analyze
flutter test
flutter run

# Puzzle pipeline (later phases)
dart run tool/generate_puzzles.dart easy 200 42
dart run tool/validate_puzzles.dart
```
