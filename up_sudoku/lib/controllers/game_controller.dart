/// State of the running game.
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/puzzle_repository.dart';
import '../domain/models/difficulty.dart';
import '../domain/models/puzzle_entry.dart';
import '../domain/sudoku_constants.dart';

/// Lifecycle of a game.
enum GameStatus { playing, paused, won, lost }

/// Holds the current game: board, selection, timer and status.
///
/// Persistence (phase 7), notes/undo (phase 4) and hints (phase 6) are added
/// on top of this class.
class GameController extends ChangeNotifier {
  GameController({PuzzleRepository? repository}) : _repository = repository;

  final PuzzleRepository? _repository;

  /// Configuration of the running difficulty.
  late DifficultyConfig cfg;

  /// The puzzle being played.
  late PuzzleEntry entry;

  /// Board values, givens included; 0 means empty.
  late List<int> values;

  /// Whether a cell is a given (not editable).
  late List<bool> given;

  /// Candidate notes per cell (bitmask); empty in phase 3.
  late List<int> notes;

  /// Currently selected cell.
  int? selected;

  /// Number of wrong digits entered (instant feedback only).
  int mistakes = 0;

  /// Seconds elapsed since the game started.
  int elapsedSeconds = 0;

  /// Lifecycle state.
  GameStatus status = GameStatus.playing;

  /// Fires every second so the timer widget can repaint without rebuilding
  /// the board.
  final ValueNotifier<int> elapsed = ValueNotifier<int>(0);

  Timer? _timer;

  bool _started = false;

  /// True once a game has been started.
  bool get hasGame => _started;

  /// True while the player may interact with the board.
  bool get isPlaying => status == GameStatus.playing;

  /// True when the given of [cell] cannot be changed.
  bool isGiven(int cell) => given[cell];

  /// The digit placed in [cell] (0 when empty).
  int valueAt(int cell) => values[cell];

  /// Starts a new game on [difficulty].
  ///
  /// When [specific] is null a puzzle is picked from the repository pool.
  void startGame(Difficulty difficulty, {PuzzleEntry? specific}) {
    cfg = kDifficulties[difficulty]!;
    entry =
        specific ??
        _repository!.pick(difficulty, const <int>{}, Random());
    values = List<int>.of(entry.puzzle);
    given = [for (final v in entry.puzzle) v != 0];
    notes = List<int>.filled(kCellCount, 0);
    selected = null;
    mistakes = 0;
    elapsedSeconds = 0;
    status = GameStatus.playing;
    elapsed.value = 0;
    _started = true;
    _startTimer();
    notifyListeners();
  }

  /// Selects [cell] (highlighting only — givens can be selected too).
  void select(int cell) {
    if (cell < 0 || cell >= kCellCount) return;
    selected = cell;
    notifyListeners();
  }

  /// Enters [digit] in the selected cell.
  void inputDigit(int digit) {
    final i = selected;
    if (i == null || given[i] || !isPlaying) return;
    if (values[i] == digit) return; // no-op, never counts twice
    values[i] = digit;
    notes[i] = 0;
    notifyListeners();

    if (digit != entry.solution[i]) {
      mistakes++;
      notifyListeners();
    }
    _checkWin();
  }

  /// Removes the digit of the selected cell.
  void erase() {
    final i = selected;
    if (i == null || given[i] || !isPlaying) return;
    if (values[i] == 0) return;
    values[i] = 0;
    notifyListeners();
  }

  /// Pauses the game: the timer stops and the board is hidden by the UI.
  void pause() {
    if (!isPlaying) return;
    status = GameStatus.paused;
    _timer?.cancel();
    _timer = null;
    notifyListeners();
  }

  /// Resumes a paused game.
  void resume() {
    if (status != GameStatus.paused) return;
    status = GameStatus.playing;
    _startTimer();
    notifyListeners();
  }

  /// Number of times [digit] is still missing from the board.
  int remaining(int digit) {
    var placed = 0;
    for (final v in values) {
      if (v == digit) placed++;
    }
    return 9 - placed;
  }

  /// True when the board matches the solution exactly.
  bool get isSolved {
    for (var i = 0; i < kCellCount; i++) {
      if (values[i] != entry.solution[i]) return false;
    }
    return true;
  }

  void _checkWin() {
    if (!isSolved) return;
    status = GameStatus.won;
    _timer?.cancel();
    _timer = null;
    notifyListeners();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!isPlaying) return;
      elapsedSeconds++;
      elapsed.value = elapsedSeconds;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    elapsed.dispose();
    super.dispose();
  }
}
