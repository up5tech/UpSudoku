import 'dart:math';

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
    final bad = List<int>.filled(81, 0)
      ..[0] = 5
      ..[1] = 5;
    expect(SudokuSolver.countSolutions(bad), 0);
  });

  test('a full valid grid has exactly one solution', () {
    expect(SudokuSolver.countSolutions(solution, limit: 2), 1);
  });

  test('solve returns null when there is no solution', () {
    final bad = List<int>.filled(81, 0)
      ..[0] = 5
      ..[1] = 5;
    expect(SudokuSolver.solve(bad), isNull);
  });

  test('solving an empty grid yields a valid complete grid', () {
    final result = SudokuSolver.solve(List.filled(81, 0), rng: Random(42));
    expect(result, isNotNull);
    expect(result!.length, 81);
    expect(result.every((v) => v >= 1 && v <= 9), isTrue);

    for (final unit in [
      for (var r = 0; r < 9; r++) [for (var c = 0; c < 9; c++) r * 9 + c],
      for (var c = 0; c < 9; c++) [for (var r = 0; r < 9; r++) r * 9 + c],
      for (var b = 0; b < 9; b++)
        [
          for (var k = 0; k < 9; k++)
            ((b ~/ 3) * 3 + k ~/ 3) * 9 + (b % 3) * 3 + k % 3,
        ],
    ]) {
      expect(unit.map((i) => result[i]).toSet().length, 9);
    }
  });

  test('randomised full grids are uniquely solvable', () {
    final rng = Random(7);
    for (var n = 0; n < 10; n++) {
      final grid = SudokuSolver.solve(List.filled(81, 0), rng: rng)!;
      expect(SudokuSolver.countSolutions(grid, limit: 2), 1);
    }
  });

  test('uniqueness checks are fast enough for pool generation', () {
    final rng = Random(11);
    final grid = SudokuSolver.solve(List.filled(81, 0), rng: rng)!;
    final partial = List<int>.of(grid);
    for (var i = 0; i < partial.length; i++) {
      if (i % 3 == 0) partial[i] = 0;
    }

    final sw = Stopwatch()..start();
    for (var n = 0; n < 200; n++) {
      SudokuSolver.countSolutions(partial, limit: 2);
    }
    sw.stop();
    expect(sw.elapsedMilliseconds, lessThan(5000));
  });
}
