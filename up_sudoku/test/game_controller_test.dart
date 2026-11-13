import 'package:flutter_test/flutter_test.dart';
import 'package:up_sudoku/controllers/game_controller.dart';
import 'package:up_sudoku/domain/models/difficulty.dart';
import 'package:up_sudoku/domain/models/puzzle_entry.dart';

const _puzzle = '530070000600195000098000060800060003400803001700020006060000280000419005000080079';
const _solution = '534678912672195348198342567859761423426853791713924856961537284287419635345286179';

PuzzleEntry _entry() => PuzzleEntry(
  id: 1,
  difficulty: Difficulty.easy,
  puzzle: PuzzleEntry.decode(_puzzle),
  solution: PuzzleEntry.decode(_solution),
  givens: 30,
  score: 40,
);

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
}
