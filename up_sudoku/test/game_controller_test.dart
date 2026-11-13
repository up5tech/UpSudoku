import 'package:flutter_test/flutter_test.dart';
import 'package:up_sudoku/controllers/game_controller.dart';
import 'package:up_sudoku/domain/logic/logic_state.dart';
import 'package:up_sudoku/domain/models/difficulty.dart';
import 'package:up_sudoku/domain/models/puzzle_entry.dart';
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

/// An empty peer of [cell], used to place a digit next to a note.
int _emptyPeer(GameController game, int cell) =>
    kPeers[cell].firstWhere((p) => game.values[p] == 0);

/// A digit that is not the solution digit of [cell].
int _wrongDigit(GameController game, int cell) {
  final solution = game.entry.solution[cell];
  return solution == 9 ? 1 : solution + 1;
}

void main() {
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
}
