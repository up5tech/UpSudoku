/// State of the running game.
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';

import '../core/sound_cue.dart';
import '../data/puzzle_repository.dart';
import '../data/storage_service.dart';
import '../domain/logic/grader.dart';
import '../domain/logic/logic_state.dart';
import '../domain/logic/logic_step.dart';
import '../domain/models/cell_change.dart';
import '../domain/models/daily_record.dart';
import '../domain/models/difficulty.dart';
import '../domain/models/puzzle_entry.dart';
import '../domain/models/saved_game.dart';
import '../domain/score_calculator.dart';
import '../domain/sudoku_constants.dart';
import '../l10n/app_localizations.dart';
import 'stats_controller.dart';

/// Lifecycle of a game.
enum GameStatus { playing, paused, won, lost }

/// Holds the current game: board, notes, selection, undo history, hints,
/// checks, timer, status and the save slot of its difficulty.
class GameController extends ChangeNotifier {
  GameController({
    PuzzleRepository? repository,
    StorageService? storage,
    StatsController? stats,
  })  : _repository = repository,
        _storage = storage,
        _stats = stats;

  final PuzzleRepository? _repository;
  final StorageService? _storage;
  final StatsController? _stats;
  final Grader _grader = Grader.standard();

  /// Strings used by the hint panel and the neutral notices.
  ///
  /// The game screen keeps this in step with the app locale; English is the
  /// default so headless tests and tools read stable text.
  AppLocalizations l10n = const AppLocalizations(Locale('en'));

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

  /// Cells marked as wrong by "Check board".
  final Set<int> flagged = <int>{};

  /// Number of wrong digits entered (instant feedback only).
  int mistakes = 0;

  /// Hints still available in this game.
  int hintsLeft = 0;

  /// "Check board" uses still available in this game.
  int checksLeft = 0;

  /// Hints already used (counts against the score and the stars).
  int hintsUsed = 0;

  /// Checks already used (counts against the score and the stars).
  int checksUsed = 0;

  /// Current hint stage: null = no hint, 1 = pattern, 2 = explained.
  int? hintStage;

  /// The logical step the active hint explains.
  LogicStep? activeHint;

  /// The cell highlighted by a wrong-digit hint or by the reveal fallback.
  int? hintCell;

  /// True when the hint offers to reveal a cell because the grader is stuck.
  bool hintRevealsCell = false;

  /// Points earned by the finished game.
  int score = 0;

  /// Stars earned by the finished game (0 while still playing).
  int stars = 0;

  /// Seconds elapsed since the game started.
  int elapsedSeconds = 0;

  /// Lifecycle state.
  GameStatus status = GameStatus.playing;

  /// True when the running game is the daily puzzle.
  bool isDaily = false;

  /// Date (`yyyy-MM-dd`) of the running daily game, if any.
  String? dailyDate;

  /// Neutral message shown when the board is full but not solved.
  final ValueNotifier<String?> notice = ValueNotifier<String?>(null);

  /// Fires every second so the timer widget can repaint without rebuilding
  /// the board.
  final ValueNotifier<int> elapsed = ValueNotifier<int>(0);

  /// One-shot sound cue of the last board event, consumed by the UI
  /// (PLAN.md §18). Null means "nothing to play".
  final ValueNotifier<SoundCue?> cue = ValueNotifier<SoundCue?>(null);

  /// Publishes exactly one cue per board event.
  ///
  /// The notifier is cleared first so a repeated cue still notifies, and the
  /// UI listener clears it again after playing, so no event is heard twice.
  void _emit(SoundCue value) {
    cue.value = null;
    cue.value = value;
  }

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

  /// True when the player may ask for a hint right now.
  bool get canAskHint => isPlaying && hintsLeft > 0 && hintStage == null;

  /// True when the player may use "Check board" right now.
  bool get canCheck => isPlaying && checksLeft > 0;

  /// True when the given of [cell] cannot be changed.
  bool isGiven(int cell) => given[cell];

  /// The digit placed in [cell] (0 when empty).
  int valueAt(int cell) => values[cell];

  /// Cells to highlight for the active hint (empty when there is none).
  List<int> get hintHighlight {
    final step = activeHint;
    if (step != null && step.pattern.isNotEmpty) return step.pattern;
    final cell = hintCell;
    return cell == null ? const [] : [cell];
  }

  /// Headline of the active hint (technique name or a special case).
  String get hintTitle {
    if (hintRevealsCell) return l10n.noSimpleTechnique;
    if (hintCell != null && activeHint == null) {
      return l10n.somethingIsWrong;
    }
    final step = activeHint;
    return step == null ? l10n.hint : l10n.techniqueName(step.technique);
  }

  /// Stage-2 explanation of the active hint; null at stage 1.
  String? get hintExplanation {
    final stage = hintStage;
    if (stage == null || stage < 2) return null;
    if (hintRevealsCell) return l10n.revealExplanation;
    if (hintCell != null && activeHint == null) {
      return l10n.wrongDigitExplanation;
    }
    final step = activeHint;
    if (step == null) return null;
    if (step.isPlacement) return l10n.placementExplanation(step.digit!);
    final cells = step.eliminations.length;
    final mask = step.eliminations.values.fold<int>(0, (a, m) => a | m);
    return l10n.eliminationExplanation(
      digitsOf(mask).join(', '),
      cells,
    );
  }

  /// True when [difficulty] has a game that can be continued.
  bool hasSaved(Difficulty difficulty) =>
      _storage?.readGame(difficulty) != null;

  /// Restores the saved game of [difficulty].
  ///
  /// Returns false when there is nothing (valid) to restore. The undo stack is
  /// not persisted, so undo/redo start empty (PLAN.md §17.2).
  bool restore(Difficulty difficulty) {
    final saved = _storage?.readGame(difficulty);
    if (saved == null) return false;

    final PuzzleEntry restored;
    try {
      restored = _repository!.byId(difficulty, saved.puzzleId);
    } catch (_) {
      // The puzzle vanished from the pool: treat the save as unusable.
      _storage!.clearGame(difficulty);
      return false;
    }

    cfg = kDifficulties[difficulty]!;
    entry = restored;
    values = List<int>.of(saved.values);
    given = [for (final v in entry.puzzle) v != 0];
    notes = List<int>.of(saved.notes);
    selected = null;
    notesMode = false;
    mistakes = saved.mistakes;
    hintsLeft = saved.hintsLeft;
    hintsUsed = saved.hintsUsed;
    checksLeft = saved.checksLeft;
    checksUsed = saved.checksUsed;
    isDaily = saved.daily;
    dailyDate = saved.dailyDate;
    score = 0;
    stars = 0;
    elapsedSeconds = saved.elapsedSeconds;
    elapsed.value = elapsedSeconds;
    status = GameStatus.playing;
    flagged.clear();
    notice.value = null;
    _clearHint();
    _undo.clear();
    _redo.clear();
    _started = true;
    _startTimer();
    notifyListeners();
    return true;
  }

  /// Starts a new game on [difficulty].
  ///
  /// When [specific] is null a puzzle is picked from the repository pool,
  /// preferring one that has not been completed yet.
  void startGame(
    Difficulty difficulty, {
    PuzzleEntry? specific,
    bool daily = false,
    DateTime? date,
  }) {
    final replacedUnfinished = _storage?.readGame(difficulty) != null;
    cfg = kDifficulties[difficulty]!;
    entry = specific ??
        _repository!.pick(
          difficulty,
          _stats?.of(difficulty).completedIds.toSet() ?? const <int>{},
          Random(),
        );
    isDaily = daily;
    dailyDate = daily ? dayKey(date ?? DateTime.now()) : null;
    values = List<int>.of(entry.puzzle);
    given = [for (final v in entry.puzzle) v != 0];
    notes = List<int>.filled(kCellCount, 0);
    selected = null;
    notesMode = false;
    mistakes = 0;
    hintsLeft = cfg.hintLimit;
    checksLeft = cfg.checkLimit;
    hintsUsed = 0;
    checksUsed = 0;
    _clearHint();
    score = 0;
    stars = 0;
    elapsedSeconds = 0;
    status = GameStatus.playing;
    flagged.clear();
    notice.value = null;
    _undo.clear();
    _redo.clear();
    elapsed.value = 0;
    _started = true;
    _stats?.recordStarted(difficulty, abandoned: replacedUnfinished);
    _startTimer();
    // A new game is written at once, so a kill right after starting restores it.
    _autosave(immediate: true);
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

  /// Asks for a hint; the first call of a game consumes one hint charge.
  ///
  /// Stage 1 only highlights the pattern (or the first wrong cell, or the
  /// "no technique applies" fallback). [showHintDetails] explains it and
  /// [applyHint] carries it out.
  void requestHint() {
    if (!canAskHint) return;
    hintsLeft--;
    hintsUsed++;
    _autosave();
    hintStage = 1;
    activeHint = null;
    hintCell = null;
    hintRevealsCell = false;

    final wrong = _firstWrongCell();
    if (wrong != null) {
      hintCell = wrong;
      notifyListeners();
      return;
    }

    final step = _grader.nextStep(values);
    if (step != null) {
      activeHint = step;
    } else {
      hintRevealsCell = true;
      hintCell = _fewestCandidatesCell();
    }
    notifyListeners();
  }

  /// Moves the active hint to stage 2 (the explanation).
  void showHintDetails() {
    if (hintStage == null) return;
    if (hintStage == 1) hintStage = 2;
    notifyListeners();
  }

  /// Applies the active hint: places the digit, removes the candidates from
  /// the notes, erases the wrong digit or reveals a cell.
  void applyHint() {
    if (!isPlaying || hintStage == null) return;

    if (hintRevealsCell) {
      final cell = hintCell;
      if (cell != null) _setValue(cell, entry.solution[cell]);
      return;
    }

    if (hintCell != null && activeHint == null) {
      final cell = hintCell!;
      _commit([CellChange(cell, values[cell], 0, notes[cell], notes[cell])]);
      return;
    }

    final step = activeHint;
    if (step == null) {
      _clearHint();
      notifyListeners();
      return;
    }

    if (step.isPlacement) {
      _setValue(step.cell!, step.digit!);
      return;
    }

    final changes = <CellChange>[
      for (final entry in step.eliminations.entries)
        if ((notes[entry.key] & entry.value) != 0)
          CellChange(
            entry.key,
            0,
            0,
            notes[entry.key],
            notes[entry.key] & ~entry.value,
          ),
    ];
    if (changes.isEmpty) {
      notice.value = l10n.candidatesAlreadyRemoved;
      _clearHint();
      notifyListeners();
      return;
    }
    _commit(changes);
  }

  /// Dismisses the active hint without applying it.
  void closeHint() {
    if (hintStage == null) return;
    _clearHint();
    notifyListeners();
  }

  /// Marks every wrong player digit (Hard/Very Hard).
  void checkBoard() {
    if (!canCheck) return;
    checksLeft--;
    checksUsed++;
    _autosave();
    flagged.clear();
    for (var i = 0; i < kCellCount; i++) {
      if (given[i] || values[i] == 0) continue;
      if (values[i] != entry.solution[i]) flagged.add(i);
    }
    notifyListeners();
  }

  /// Pauses the game: the timer stops and the board is hidden by the UI.
  void pause() {
    if (!isPlaying) return;
    status = GameStatus.paused;
    _timer?.cancel();
    _timer = null;
    // Pausing is also how backgrounding saves, so it must not wait.
    _autosave(immediate: true);
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
    if (values[i] == digit) {
      _clearHint();
      notifyListeners();
      return; // no-op, never counts twice
    }
    final changes = <CellChange>[CellChange(i, values[i], digit, notes[i], 0)];
    if (cfg.autoRemoveNotes) {
      for (final p in kPeers[i]) {
        if ((notes[p] & bit(digit)) != 0) {
          changes.add(
            CellChange(
                p, values[p], values[p], notes[p], notes[p] & ~bit(digit)),
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
      _emit(SoundCue.error);
      notifyListeners();
    } else if (!isSolved) {
      // Deferred-feedback modes must stay silent about correctness, so a
      // wrong-but-accepted digit sounds exactly like a correct one. The
      // winning move announces only the win.
      _emit(
        _completesUnit(i) ? SoundCue.unitComplete : SoundCue.place,
      );
    }
    _checkWin();
  }

  void _commit(List<CellChange> changes) {
    if (changes.isEmpty) return;
    _apply(changes, undo: false);
    _undo.add(changes);
    _redo.clear();
    notice.value = null;
    _clearHint();
    _autosave();
    notifyListeners();
  }

  /// How long a board change waits before it is written to the save slot.
  ///
  /// Every move used to serialize and write the whole game. Typing quickly then
  /// meant dozens of JSON encodes and platform writes a minute, so changes are
  /// coalesced and a burst of moves costs one write. Anything that must not be
  /// lost — a new game, a pause, backgrounding, disposal — flushes instead.
  static const Duration autosaveDelay = Duration(milliseconds: 400);

  Timer? _autosaveTimer;
  bool _savePending = false;

  /// Writes the current game into its difficulty's save slot.
  ///
  /// [immediate] writes now and cancels a pending debounced write.
  void _autosave({bool immediate = false}) {
    final storage = _storage;
    if (storage == null || !_started) return;
    // A finished game has no save slot: `_finish` cleared it.
    if (status == GameStatus.won || status == GameStatus.lost) return;
    _savePending = true;
    if (immediate) {
      _writeSave();
      return;
    }
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(autosaveDelay, _writeSave);
  }

  /// Writes any pending change right now (backgrounding, disposal).
  void flush() => _writeSave();

  void _writeSave() {
    _autosaveTimer?.cancel();
    _autosaveTimer = null;
    if (!_savePending) return;
    _savePending = false;
    final storage = _storage;
    if (storage == null || !_started) return;
    if (status == GameStatus.won || status == GameStatus.lost) return;
    storage.writeGame(
      cfg.id,
      SavedGame(
        puzzleId: entry.id,
        values: List<int>.of(values),
        notes: List<int>.of(notes),
        elapsedSeconds: elapsedSeconds,
        mistakes: mistakes,
        hintsLeft: hintsLeft,
        hintsUsed: hintsUsed,
        checksLeft: checksLeft,
        checksUsed: checksUsed,
        daily: isDaily,
        dailyDate: dailyDate,
      ),
    );
  }

  void _apply(List<CellChange> changes, {required bool undo}) {
    for (final c in changes) {
      values[c.cell] = undo ? c.oldValue : c.newValue;
      notes[c.cell] = undo ? c.oldNotes : c.newNotes;
    }
  }

  void _clearHint() {
    hintStage = null;
    activeHint = null;
    hintCell = null;
    hintRevealsCell = false;
  }

  /// The first player digit that differs from the solution, if any.
  int? _firstWrongCell() {
    for (var i = 0; i < kCellCount; i++) {
      if (given[i] || values[i] == 0) continue;
      if (values[i] != entry.solution[i]) return i;
    }
    return null;
  }

  /// The empty cell with the fewest candidates (reveal fallback).
  int? _fewestCandidatesCell() {
    final state = LogicState.fromPuzzle(values);
    int? best;
    var bestCount = 10;
    for (var i = 0; i < kCellCount; i++) {
      if (values[i] != 0) continue;
      final count = popCount(state.cand[i]);
      if (count < bestCount) {
        bestCount = count;
        best = i;
      }
    }
    return best;
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
    notice.value = l10n.boardFullButWrong;
  }

  /// True when [cell] completes a row, column or box correctly.
  bool _completesUnit(int cell) {
    for (final unit in kUnits) {
      if (!unit.contains(cell)) continue;
      var complete = true;
      for (final c in unit) {
        if (values[c] != entry.solution[c]) {
          complete = false;
          break;
        }
      }
      if (complete) return true;
    }
    return false;
  }

  void _finish(GameStatus result) {
    status = result;
    // The save slot is about to be cleared: a pending write must not put the
    // finished game back into it.
    _autosaveTimer?.cancel();
    _autosaveTimer = null;
    _savePending = false;
    _emit(result == GameStatus.won ? SoundCue.win : SoundCue.lose);
    _timer?.cancel();
    _timer = null;
    if (result == GameStatus.won) {
      final scored = ScoreCalculator.evaluate(
        cfg: cfg,
        seconds: elapsedSeconds,
        mistakes: mistakes,
        hintsUsed: hintsUsed,
        checksUsed: checksUsed,
      );
      score = scored.score;
      stars = scored.stars;
      _stats?.recordWon(
        cfg.id,
        puzzleId: entry.id,
        seconds: elapsedSeconds,
        flawless: mistakes == 0 && hintsUsed == 0 && checksUsed == 0,
      );
      if (isDaily) _recordDaily();
    } else if (result == GameStatus.lost) {
      _stats?.recordLost(cfg.id);
    }
    _storage?.clearGame(cfg.id);
    notifyListeners();
  }

  /// Marks today's daily puzzle as completed and advances the streak.
  void _recordDaily() {
    final storage = _storage;
    if (storage == null) return;
    final date = dailyDate != null
        ? DateTime.tryParse(dailyDate!) ?? DateTime.now()
        : DateTime.now();
    storage.writeDaily(storage.readDaily().completedOn(date));
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
    // Last chance to persist a move that is still inside the debounce window.
    _writeSave();
    _autosaveTimer?.cancel();
    _autosaveTimer = null;
    _timer?.cancel();
    _timer = null;
    elapsed.dispose();
    notice.dispose();
    cue.dispose();
    super.dispose();
  }
}
