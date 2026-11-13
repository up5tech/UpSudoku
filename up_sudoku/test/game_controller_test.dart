import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:up_sudoku/controllers/game_controller.dart';
import 'package:up_sudoku/controllers/stats_controller.dart';
import 'package:up_sudoku/data/puzzle_repository.dart';
import 'package:up_sudoku/data/storage_service.dart';
import 'package:up_sudoku/domain/logic/logic_state.dart';
import 'package:up_sudoku/domain/logic/technique.dart';
import 'package:up_sudoku/domain/models/difficulty.dart';
import 'package:up_sudoku/domain/models/puzzle_entry.dart';
import 'package:up_sudoku/domain/solver.dart';
import 'package:up_sudoku/domain/sudoku_constants.dart';

const _puzzle = '530070000600195000098000060800060003400803001700020006060000280000419005000080079';
const _solution = '534678912672195348198342567859761423426853791713924856961537284287419635345286179';

PuzzleEntry _entry([Difficulty difficulty = Difficulty.easy]) => PuzzleEntry(
  id: 1,
  difficulty: difficulty,
  puzzle: PuzzleEntry.decode(_puzzle),
  solution: PuzzleEntry.decode(_solution),
  givens: 30,
  score: 40,
);

/// A Hard pool puzzle whose first logical step is a pointing elimination
/// (digit 9 from cell 14).
const _pointingPuzzle =
    '000000009700320010041060005078003001000040000900800630100080290020035007800000000';

/// A Very Hard pool puzzle: the tiers 1–3 grader cannot finish it.
const _veryHardPuzzle =
    '100043000080005000020019400260000000400000008000000034006490050000600020000350009';
const _veryHardSolution =
    '157243986984765312623819475268534791431927568795186234316492857549678123872351649';

/// A board with a single empty cell, so the first hint is a naked single.
PuzzleEntry _almostSolvedEntry() {
  final puzzle = PuzzleEntry.decode(_solution)..[0] = 0;
  return PuzzleEntry(
    id: 9,
    difficulty: Difficulty.easy,
    puzzle: puzzle,
    solution: PuzzleEntry.decode(_solution),
    givens: 80,
    score: 1,
  );
}

PuzzleEntry _pointingEntry() {
  final puzzle = PuzzleEntry.decode(_pointingPuzzle);
  return PuzzleEntry(
    id: 140,
    difficulty: Difficulty.hard,
    puzzle: puzzle,
    solution: SudokuSolver.solve(puzzle)!,
    givens: 30,
    score: 150,
  );
}

PuzzleEntry _veryHardEntry() => PuzzleEntry(
  id: 1,
  difficulty: Difficulty.veryHard,
  puzzle: PuzzleEntry.decode(_veryHardPuzzle),
  solution: PuzzleEntry.decode(_veryHardSolution),
  givens: 24,
  score: 158,
);

/// A synthetic board no technique applies to (every cell has nine
/// candidates), i.e. the state in which the reveal fallback is offered.
PuzzleEntry _stuckEntry() => PuzzleEntry(
  id: 1,
  difficulty: Difficulty.veryHard,
  puzzle: List<int>.filled(kCellCount, 0),
  solution: PuzzleEntry.decode(_veryHardSolution),
  givens: 0,
  score: 158,
);

/// An empty peer of [cell], used to place a digit next to a note.
int _emptyPeer(GameController game, int cell) =>
    kPeers[cell].firstWhere((p) => game.values[p] == 0);

/// A digit that is not the solution digit of [cell].
int _wrongDigit(GameController game, int cell) {
  final solution = game.entry.solution[cell];
  return solution == 9 ? 1 : solution + 1;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GameController game;

  setUp(() {
    game = GameController();
    game.startGame(Difficulty.easy, specific: _entry());
  });

  tearDown(() => game.dispose());

  test('starts with the givens of the puzzle', () {
    expect(game.values, PuzzleEntry.decode(_puzzle));
    expect(game.given.where((g) => g).length, 30);
    expect(game.status, GameStatus.playing);
    expect(game.mistakes, 0);
    expect(game.elapsedSeconds, 0);
  });

  test('selects a cell', () {
    game.select(4);
    expect(game.selected, 4);
  });

  test('enters a digit in the selected cell', () {
    game.select(2); // empty in the example puzzle
    game.inputDigit(4); // the solution digit of cell 2

    expect(game.values[2], 4);
    expect(game.mistakes, 0);
  });

  test('ignores input in a given cell', () {
    game.select(0); // a given (5)
    game.inputDigit(9);

    expect(game.values[0], 5);
    expect(game.mistakes, 0);
  });

  test('ignores input without a selection', () {
    final before = List<int>.of(game.values);
    game.inputDigit(4);
    expect(game.values, before);
  });

  test('counts a mistake for a wrong digit', () {
    game.select(2); // solution digit is 4
    game.inputDigit(9);

    expect(game.values[2], 9);
    expect(game.mistakes, 1);
  });

  test('does not count the same wrong digit twice', () {
    game.select(2);
    game.inputDigit(9);
    expect(game.mistakes, 1);

    game.inputDigit(9);
    expect(game.mistakes, 1);
  });

  test('erases the digit of the selected cell', () {
    game.select(2);
    game.inputDigit(3);
    expect(game.values[2], 3);

    game.erase();
    expect(game.values[2], 0);
  });

  test('does not erase a given', () {
    game.select(0);
    game.erase();
    expect(game.values[0], 5);
  });

  test('remaining counts the digits still missing', () {
    final puzzle = PuzzleEntry.decode(_puzzle);
    for (var d = 1; d <= 9; d++) {
      final placed = puzzle.where((v) => v == d).length;
      expect(game.remaining(d), 9 - placed);
    }
  });

  test('wins when the board matches the solution', () {
    final solution = PuzzleEntry.decode(_solution);
    for (var i = 0; i < 81; i++) {
      if (game.values[i] != 0) continue;
      game.select(i);
      game.inputDigit(solution[i]);
    }

    expect(game.isSolved, isTrue);
    expect(game.status, GameStatus.won);
  });

  test('does not win while the board is wrong', () {
    game.select(2);
    game.inputDigit(9);

    expect(game.isSolved, isFalse);
    expect(game.status, GameStatus.playing);
  });

  test('pausing stops the timer and blocks input', () {
    game.pause();
    expect(game.status, GameStatus.paused);

    game.select(2);
    game.inputDigit(3);
    expect(game.values[2], 0);

    game.resume();
    expect(game.status, GameStatus.playing);
  });

  test('notes mode toggles a note without touching the value', () {
    game.select(2);
    game.toggleNotesMode();
    expect(game.notesMode, isTrue);

    game.inputDigit(4);
    expect(game.notes[2] & bit(4), isNot(0));
    expect(game.values[2], 0);

    game.inputDigit(4);
    expect(game.notes[2] & bit(4), 0);
  });

  test('generous notes can be toggled in one cell', () {
    game.select(2);
    game.toggleNotesMode();
    game.inputDigit(1);
    game.inputDigit(7);

    expect(game.notes[2], bit(1) | bit(7));
  });

  test('notes are only written in empty cells', () {
    game.select(0); // a given
    game.toggleNotesMode();
    game.inputDigit(4);
    expect(game.notes[0], 0);

    game.select(2);
    game.toggleNotesMode();
    game.inputDigit(4);
    game.toggleNotesMode();
    game.inputDigit(4);
    expect(game.values[2], 4);
    expect(game.notes[2], 0);
  });

  test('placing a digit clears its own notes', () {
    game.select(2);
    game.toggleNotesMode();
    game.inputDigit(4);
    game.toggleNotesMode();

    game.inputDigit(4);
    expect(game.values[2], 4);
    expect(game.notes[2], 0);
  });

  test('placing a digit removes it from the peers notes (Easy)', () {
    game.select(2);
    game.toggleNotesMode();
    game.inputDigit(9);
    game.toggleNotesMode();

    final peer = _emptyPeer(game, 2);
    game.select(peer);
    game.inputDigit(9);

    expect(game.notes[2] & bit(9), 0);
  });

  test('Very Hard keeps the peers notes untouched', () {
    game.startGame(Difficulty.veryHard, specific: _entry(Difficulty.veryHard));

    game.select(2);
    game.toggleNotesMode();
    game.inputDigit(9);
    game.toggleNotesMode();

    final peer = _emptyPeer(game, 2);
    game.select(peer);
    game.inputDigit(9);

    expect(game.notes[2] & bit(9), isNot(0));
  });

  test('undo and redo restore the digit and the removed notes', () {
    game.select(2);
    game.toggleNotesMode();
    game.inputDigit(9);
    game.toggleNotesMode();

    final peer = _emptyPeer(game, 2);
    game.select(peer);
    game.inputDigit(9);
    expect(game.notes[2] & bit(9), 0);

    game.undo();
    expect(game.values[peer], 0);
    expect(game.notes[2] & bit(9), isNot(0));

    game.redo();
    expect(game.values[peer], 9);
    expect(game.notes[2] & bit(9), 0);
  });

  test('undo does not decrement the mistake counter', () {
    game.select(2);
    game.inputDigit(_wrongDigit(game, 2));
    expect(game.mistakes, 1);

    game.undo();
    expect(game.values[2], 0);
    expect(game.mistakes, 1);
  });

  test('a new action clears the redo stack', () {
    game.select(2);
    game.inputDigit(4);
    game.undo();
    expect(game.canRedo, isTrue);

    game.select(3);
    game.inputDigit(6);
    expect(game.canRedo, isFalse);
  });

  test('undo and redo are unavailable on a fresh game', () {
    expect(game.canUndo, isFalse);
    expect(game.canRedo, isFalse);
  });

  test('erase clears the notes of the selected cell', () {
    game.select(2);
    game.toggleNotesMode();
    game.inputDigit(3);
    game.toggleNotesMode();

    game.erase();
    expect(game.notes[2], 0);
  });

  test('fillAllNotes writes the candidates on Easy', () {
    game.fillAllNotes();

    final state = LogicState.fromPuzzle(game.entry.puzzle);
    for (var i = 0; i < kCellCount; i++) {
      expect(game.notes[i], state.cand[i]);
    }
    expect(game.canUndo, isTrue);

    game.undo();
    expect(game.notes.every((n) => n == 0), isTrue);
  });

  test('fillAllNotes is refused on Hard', () {
    game.startGame(Difficulty.hard, specific: _entry(Difficulty.hard));
    game.fillAllNotes();

    expect(game.notes.every((n) => n == 0), isTrue);
    expect(game.canUndo, isFalse);
  });

  test('Medium loses after the mistake limit', () {
    game.startGame(Difficulty.medium, specific: _entry(Difficulty.medium));

    final empties = [
      for (var i = 0; i < kCellCount; i++)
        if (game.values[i] == 0) i,
    ].take(5).toList();

    for (final cell in empties) {
      game.select(cell);
      game.inputDigit(_wrongDigit(game, cell));
    }

    expect(game.mistakes, 5);
    expect(game.status, GameStatus.lost);
  });

  test('Medium keeps playing below the mistake limit', () {
    game.startGame(Difficulty.medium, specific: _entry(Difficulty.medium));

    game.select(2);
    game.inputDigit(_wrongDigit(game, 2));

    expect(game.mistakes, 1);
    expect(game.status, GameStatus.playing);
  });

  test('Hard does not count wrong digits as mistakes', () {
    game.startGame(Difficulty.hard, specific: _entry(Difficulty.hard));

    game.select(2);
    game.inputDigit(_wrongDigit(game, 2));

    expect(game.mistakes, 0);
    expect(game.status, GameStatus.playing);
  });

  test('Very Hard never counts mistakes', () {
    game.startGame(Difficulty.veryHard, specific: _entry(Difficulty.veryHard));

    game.select(2);
    game.inputDigit(_wrongDigit(game, 2));

    expect(game.mistakes, 0);
  });

  test('a full but wrong board is reported without a win', () {
    game.startGame(Difficulty.hard, specific: _entry(Difficulty.hard));

    final solution = PuzzleEntry.decode(_solution);
    final empties = [
      for (var i = 0; i < kCellCount; i++)
        if (game.values[i] == 0) i,
    ];

    // Fill everything but the last empty cell with the right digits.
    for (final cell in empties.take(empties.length - 1)) {
      game.select(cell);
      game.inputDigit(solution[cell]);
    }

    final last = empties.last;
    game.select(last);
    game.inputDigit(solution[last] == 9 ? 1 : solution[last] + 1);

    expect(game.values.contains(0), isFalse);
    expect(game.status, GameStatus.playing);
    expect(game.notice.value, isNotNull);
  });

  test('starts with the hint and check limits of the difficulty', () {
    expect(game.hintsLeft, 5);
    expect(game.checksLeft, 0);
    expect(game.hintsUsed, 0);
    expect(game.stars, 0);

    game.startGame(Difficulty.hard, specific: _entry(Difficulty.hard));
    expect(game.hintsLeft, 2);
    expect(game.checksLeft, 3);

    game.startGame(
      Difficulty.veryHard,
      specific: _entry(Difficulty.veryHard),
    );
    expect(game.hintsLeft, 1);
    expect(game.checksLeft, 1);
  });

  test('a hint costs one charge and starts at stage 1', () {
    game.requestHint();

    expect(game.hintsLeft, 4);
    expect(game.hintsUsed, 1);
    expect(game.hintStage, 1);
    expect(game.activeHint, isNotNull);
    expect(game.hintTitle, isNotEmpty);
    expect(game.hintHighlight, isNotEmpty);
    expect(game.hintExplanation, isNull);

    // Asking again while a hint is open costs nothing.
    game.requestHint();
    expect(game.hintsLeft, 4);

    game.showHintDetails();
    expect(game.hintStage, 2);
    expect(game.hintExplanation, isNotNull);

    game.closeHint();
    expect(game.hintStage, isNull);
    expect(game.hintsLeft, 4);
  });

  test('applying a placement hint fills the cell without a mistake', () {
    game.startGame(Difficulty.easy, specific: _almostSolvedEntry());
    game.requestHint();

    expect(game.activeHint!.isPlacement, isTrue);
    expect(game.activeHint!.cell, 0);
    expect(game.activeHint!.digit, PuzzleEntry.decode(_solution)[0]);

    game.showHintDetails();
    expect(game.hintExplanation, contains('Digit'));
    game.applyHint();

    expect(game.values[0], PuzzleEntry.decode(_solution)[0]);
    expect(game.hintStage, isNull);
    expect(game.mistakes, 0);
    expect(game.status, GameStatus.won);
  });

  test('a hint costs a star on an otherwise perfect win', () {
    game.startGame(Difficulty.easy, specific: _almostSolvedEntry());
    game.requestHint();
    game.showHintDetails();
    game.applyHint();

    expect(game.status, GameStatus.won);
    expect(game.hintsUsed, 1);
    expect(game.stars, 2);
    expect(game.score, greaterThan(0));
  });

  test('a perfect win earns three stars and the full time bonus', () {
    final solution = PuzzleEntry.decode(_solution);
    for (var i = 0; i < kCellCount; i++) {
      if (game.values[i] != 0) continue;
      game.select(i);
      game.inputDigit(solution[i]);
    }

    expect(game.status, GameStatus.won);
    expect(game.stars, 3);
    expect(game.score, (game.cfg.baseScore * 1.5).round());
  });

  test('a hint on a wrong digit points at that cell and can erase it', () {
    game.select(2);
    game.inputDigit(_wrongDigit(game, 2));

    game.requestHint();
    expect(game.hintCell, 2);
    expect(game.activeHint, isNull);
    expect(game.hintTitle, 'Something here is incorrect');

    game.showHintDetails();
    expect(game.hintExplanation, contains('does not match'));
    game.applyHint();

    expect(game.values[2], 0);
    expect(game.hintStage, isNull);
  });

  test('an elimination hint removes the candidates from the notes', () {
    game.startGame(Difficulty.hard, specific: _pointingEntry());

    // Write the candidate the hint will remove as a note first.
    game.select(14);
    game.toggleNotesMode();
    game.inputDigit(9);
    game.toggleNotesMode();
    expect(game.notes[14] & bit(9), isNot(0));

    game.requestHint();
    expect(game.activeHint!.technique, Technique.pointing);
    expect(game.activeHint!.isElimination, isTrue);

    game.showHintDetails();
    expect(game.hintExplanation, contains('9'));
    game.applyHint();

    expect(game.notes[14] & bit(9), 0);
    expect(game.hintStage, isNull);
    expect(game.hintsUsed, 1);
  });

  test('a stuck Very Hard puzzle offers to reveal a cell', () {
    game.startGame(Difficulty.veryHard, specific: _stuckEntry());
    game.requestHint();

    expect(game.hintRevealsCell, isTrue);
    expect(game.hintCell, 0);
    expect(game.hintTitle, contains('No simple technique'));

    game.showHintDetails();
    expect(game.hintExplanation, contains('Reveal'));

    final cell = game.hintCell!;
    game.applyHint();

    expect(game.values[cell], game.entry.solution[cell]);
    expect(game.hintStage, isNull);
    expect(game.mistakes, 0);
    expect(game.hintsLeft, 0);
  });

  test('hints run out after the configured number', () {
    for (var i = 0; i < 5; i++) {
      expect(game.canAskHint, isTrue);
      game.requestHint();
      game.closeHint();
    }

    expect(game.hintsLeft, 0);
    expect(game.canAskHint, isFalse);
    game.requestHint();
    expect(game.hintsUsed, 5);
  });

  test('check board flags wrong digits and spends a use', () {
    game.startGame(Difficulty.hard, specific: _entry(Difficulty.hard));
    game.select(2);
    game.inputDigit(_wrongDigit(game, 2));

    game.checkBoard();
    expect(game.flagged, {2});
    expect(game.checksLeft, 2);
    expect(game.checksUsed, 1);

    // Editing the cell clears its flag.
    game.select(2);
    game.inputDigit(game.entry.solution[2]);
    expect(game.flagged, isEmpty);
  });

  test('Easy has no check board use', () {
    game.checkBoard();

    expect(game.checksLeft, 0);
    expect(game.checksUsed, 0);
    expect(game.flagged, isEmpty);
  });

  test('check board stops working when the uses are gone', () {
    game.startGame(Difficulty.veryHard, specific: _veryHardEntry());
    expect(game.canCheck, isTrue);

    game.checkBoard();
    expect(game.checksLeft, 0);
    expect(game.checksUsed, 1);
    expect(game.canCheck, isFalse);

    game.checkBoard();
    expect(game.checksUsed, 1);
  });

  group('persistence', () {
    late StorageService storage;
    late StatsController stats;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = await StorageService.create();
      stats = StatsController(storage: storage);
    });

    test('autosaves a move and restores it in a new controller', () async {
      final repository = PuzzleRepository();
      await repository.load();
      final entry = repository.pool(Difficulty.easy).first;

      final first = GameController(
        repository: repository,
        storage: storage,
        stats: stats,
      );
      first.startGame(Difficulty.easy, specific: entry);
      final empty = List<int>.generate(
        81,
        (i) => i,
      ).firstWhere((i) => first.values[i] == 0);
      first.select(empty);
      first.inputDigit(entry.solution[empty]);
      await pumpEventQueue();

      final saved = storage.readGame(Difficulty.easy);
      expect(saved, isNotNull);
      expect(saved!.puzzleId, entry.id);
      expect(saved.values[empty], entry.solution[empty]);

      final second = GameController(
        repository: repository,
        storage: storage,
        stats: stats,
      );
      expect(second.hasSaved(Difficulty.easy), isTrue);
      expect(second.restore(Difficulty.easy), isTrue);
      expect(second.entry.id, entry.id);
      expect(second.values, first.values);
      expect(second.notes, first.notes);
      expect(second.canUndo, isFalse, reason: 'undo is not persisted');

      first.dispose();
      second.dispose();
    });

    test('a win clears the save and records the statistics', () async {
      game = GameController(storage: storage, stats: stats);
      game.startGame(Difficulty.easy, specific: _entry());

      final solution = PuzzleEntry.decode(_solution);
      for (var i = 0; i < kCellCount; i++) {
        if (game.values[i] != 0) continue;
        game.select(i);
        game.inputDigit(solution[i]);
      }
      await pumpEventQueue();

      expect(game.status, GameStatus.won);
      expect(storage.readGame(Difficulty.easy), isNull);
      expect(stats.of(Difficulty.easy).started, 1);
      expect(stats.of(Difficulty.easy).completed, 1);
      expect(stats.of(Difficulty.easy).bestTime, game.elapsedSeconds);
      expect(stats.of(Difficulty.easy).completedIds, contains(_entry().id));
    });

    test('a loss clears the save and records the loss', () async {
      game = GameController(storage: storage, stats: stats);
      game.startGame(Difficulty.medium, specific: _entry(Difficulty.medium));

      final empties = [
        for (var i = 0; i < kCellCount; i++)
          if (game.values[i] == 0) i,
      ].take(5).toList();
      for (final cell in empties) {
        game.select(cell);
        game.inputDigit(_wrongDigit(game, cell));
      }
      await pumpEventQueue();

      expect(game.status, GameStatus.lost);
      expect(storage.readGame(Difficulty.medium), isNull);
      expect(stats.of(Difficulty.medium).started, 1);
      expect(stats.of(Difficulty.medium).completed, 0);
      expect(stats.of(Difficulty.medium).currentStreak, 0);
    });

    test('a pause stores the game', () async {
      game = GameController(storage: storage, stats: stats);
      game.startGame(Difficulty.easy, specific: _entry());
      game.pause();
      await pumpEventQueue();

      expect(storage.readGame(Difficulty.easy), isNotNull);
    });

    test('completing the daily puzzle advances the daily streak', () async {
      final today = DateTime.now();
      game = GameController(storage: storage, stats: stats);
      game.startGame(
        Difficulty.easy,
        specific: _entry(),
        daily: true,
        date: today,
      );
      expect(game.isDaily, isTrue);

      final solution = PuzzleEntry.decode(_solution);
      for (var i = 0; i < kCellCount; i++) {
        if (game.values[i] != 0) continue;
        game.select(i);
        game.inputDigit(solution[i]);
      }
      await pumpEventQueue();

      final daily = storage.readDaily();
      expect(daily.isCompletedOn(today), isTrue);
      expect(daily.streak, 1);
    });

    test('starting over a saved game resets the streak', () async {
      final repository = PuzzleRepository();
      await repository.load();
      final entry = repository.pool(Difficulty.easy).first;
      final controller = GameController(
        repository: repository,
        storage: storage,
        stats: stats,
      );

      controller.startGame(Difficulty.easy, specific: entry);
      stats.recordWon(
        Difficulty.easy,
        puzzleId: entry.id,
        seconds: 60,
        flawless: true,
      );
      expect(stats.of(Difficulty.easy).currentStreak, 1);

      controller.startGame(Difficulty.easy, specific: entry);
      expect(stats.of(Difficulty.easy).currentStreak, 0);
      controller.dispose();
    });
  });
}
