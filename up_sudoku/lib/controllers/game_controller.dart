/// State of the running game.
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/puzzle_repository.dart';
import '../domain/logic/logic_state.dart';
import '../domain/models/cell_change.dart';
import '../domain/models/difficulty.dart';
import '../domain/models/puzzle_entry.dart';
import '../domain/sudoku_constants.dart';

/// Lifecycle of a game.
enum GameStatus { playing, paused, won, lost }

/// Holds the current game: board, notes, selection, undo history, timer and
/// status.
///
/// Persistence (phase 7) and hints (phase 6) are added on top of this class.
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

  /// Candidate notes per cell (bitmask).
  late List<int> notes;

  /// Currently selected cell.
  int? selected;

  /// Whether the number pad edits notes instead of placing digits.
  bool notesMode = false;

  /// Cells marked as wrong by "Check board" (filled in phase 6).
  final Set<int> flagged = <int>{};

  /// Number of wrong digits entered (instant feedback only).
  int mistakes = 0;

  /// Seconds elapsed since the game started.
  int elapsedSeconds = 0;

  /// Lifecycle state.
  GameStatus status = GameStatus.playing;

  /// Neutral message shown when the board is full but not solved.
  final ValueNotifier<String?> notice = ValueNotifier<String?>(null);

  /// Fires every second so the timer widget can repaint without rebuilding
  /// the board.
  final ValueNotifier<int> elapsed = ValueNotifier<int>(0);

  final List<List<CellChange>> _undo = [];
  final List<List<CellChange>> _redo = [];

  Timer? _timer;

  bool _started = false;

  /// True once a game has been started.
  bool get hasGame => _started;

  /// True while the player may interact with the board.
  bool get isPlaying => status == GameStatus.playing;

  /// True when there is an action to undo.
  bool get canUndo => isPlaying && _undo.isNotEmpty;

  /// True when there is an undone action to redo.
  bool get canRedo => isPlaying && _redo.isNotEmpty;

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
        specific ?? _repository!.pick(difficulty, const <int>{}, Random());
    values = List<int>.of(entry.puzzle);
    given = [for (final v in entry.puzzle) v != 0];
    notes = List<int>.filled(kCellCount, 0);
    selected = null;
    notesMode = false;
    mistakes = 0;
    elapsedSeconds = 0;
    status = GameStatus.playing;
    flagged.clear();
    notice.value = null;
    _undo.clear();
    _redo.clear();
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

  /// Turns notes mode on or off.
  void toggleNotesMode() {
    if (!isPlaying) return;
    notesMode = !notesMode;
    notifyListeners();
  }

  /// Enters [digit] in the selected cell, or toggles it as a note in notes
  /// mode.
  void inputDigit(int digit) {
    final i = selected;
    if (i == null || given[i] || !isPlaying) return;
    if (notesMode) {
      _toggleNote(i, digit);
    } else {
      _setValue(i, digit);
    }
  }

  /// Removes the digit or the notes of the selected cell.
  void erase() {
    final i = selected;
    if (i == null || given[i] || !isPlaying) return;
    if (values[i] == 0 && notes[i] == 0) return;
    _commit([CellChange(i, values[i], 0, notes[i], 0)]);
  }

  /// Undoes the last action.
  ///
  /// The mistake counter is intentionally left untouched (undo abuse is not
  /// rewarded).
  void undo() {
    if (_undo.isEmpty || !isPlaying) return;
    final action = _undo.removeLast();
    _apply(action, undo: true);
    _redo.add(action);
    notice.value = null;
    notifyListeners();
  }

  /// Re-applies the last undone action.
  void redo() {
    if (_redo.isEmpty || !isPlaying) return;
    final action = _redo.removeLast();
    _apply(action, undo: false);
    _undo.add(action);
    notice.value = null;
    notifyListeners();
    _checkWin();
  }

  /// Fills every empty cell with its current candidates (Easy/Medium only).
  void fillAllNotes() {
    if (!cfg.allowAutoFillNotes || !isPlaying) return;
    final state = LogicState.fromPuzzle(values);
    final changes = <CellChange>[
      for (var i = 0; i < kCellCount; i++)
        if (values[i] == 0 && notes[i] != state.cand[i])
          CellChange(i, 0, 0, notes[i], state.cand[i]),
    ];
    _commit(changes);
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

  void _toggleNote(int i, int digit) {
    if (values[i] != 0) return; // notes only in empty cells
    _commit([CellChange(i, 0, 0, notes[i], notes[i] ^ bit(digit))]);
  }

  void _setValue(int i, int digit) {
    if (values[i] == digit) return; // no-op, never counts twice
    final changes = <CellChange>[CellChange(i, values[i], digit, notes[i], 0)];
    if (cfg.autoRemoveNotes) {
      for (final p in kPeers[i]) {
        if ((notes[p] & bit(digit)) != 0) {
          changes.add(
            CellChange(p, values[p], values[p], notes[p], notes[p] & ~bit(digit)),
          );
        }
      }
    }
    flagged.remove(i);
    _commit(changes);

    if (digit != entry.solution[i] && cfg.feedback == FeedbackMode.instant) {
      mistakes++;
      if (cfg.mistakeLimit > 0 && mistakes >= cfg.mistakeLimit) {
        _finish(GameStatus.lost);
        return;
      }
      notifyListeners();
    }
    _checkWin();
  }

  void _commit(List<CellChange> changes) {
    if (changes.isEmpty) return;
    _apply(changes, undo: false);
    _undo.add(changes);
    _redo.clear();
    notice.value = null;
    notifyListeners();
  }

  void _apply(List<CellChange> changes, {required bool undo}) {
    for (final c in changes) {
      values[c.cell] = undo ? c.oldValue : c.newValue;
      notes[c.cell] = undo ? c.oldNotes : c.newNotes;
    }
  }

  void _checkWin() {
    for (var i = 0; i < kCellCount; i++) {
      if (values[i] != entry.solution[i]) {
        // Full board but wrong is only possible with deferred feedback.
        if (!values.contains(0)) _onFullButWrong();
        return;
      }
    }
    _finish(GameStatus.won);
  }

  void _onFullButWrong() {
    notice.value = 'The board is full but something is still wrong.';
  }

  void _finish(GameStatus result) {
    status = result;
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
    notice.dispose();
    super.dispose();
  }
}
