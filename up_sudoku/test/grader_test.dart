import 'package:flutter_test/flutter_test.dart';
import 'package:up_sudoku/domain/logic/grader.dart';
import 'package:up_sudoku/domain/logic/logic_state.dart';
import 'package:up_sudoku/domain/logic/technique.dart';
import 'package:up_sudoku/domain/models/puzzle_entry.dart';
import 'package:up_sudoku/domain/solver.dart';
import 'package:up_sudoku/domain/sudoku_constants.dart';

// Solvable with singles only (tier 1).
const _singlesPuzzle =
    '004070000600090048108000000000001003020800090710904006900030000000400605000000170';

// Unique, but the tier 1 grader gets stuck on it (tier 4 for now).
const _stuckPuzzle =
    '450760300200593000006481000000006500020030060004100000000218400000359008009047051';
const _stuckSolution =
    '458762319271593846396481725713926584925834167684175932567218493142359678839647251';

void main() {
  final grader = Grader.standard();

  test('the standard grader only implements tier 1 for now', () {
    expect(grader.maxTier, 1);
    expect(grader.techniques.map((t) => t.id), [
      Technique.nakedSingle,
      Technique.hiddenSingle,
    ]);
  });

  test('grading is deterministic', () {
    final puzzle = PuzzleEntry.decode(_singlesPuzzle);
    final a = grader.grade(puzzle);
    final b = grader.grade(puzzle);

    expect(a.tier, b.tier);
    expect(a.solvedLogically, b.solvedLogically);
    expect(a.score, b.score);
    expect(a.usage, b.usage);
  });

  test('a singles-only puzzle is graded tier 1', () {
    final result = grader.grade(PuzzleEntry.decode(_singlesPuzzle));

    expect(result.solvedLogically, isTrue);
    expect(result.tier, 1);
    expect(result.score, greaterThan(0));
    expect(result.steps, greaterThan(0));
    expect(
      result.usage.keys.every((t) => kTechniqueTier[t] == 1),
      isTrue,
      reason: 'Easy puzzles must only use tier 1 techniques',
    );
  });

  test('a stuck puzzle is graded tier 4 and not solved logically', () {
    final puzzle = PuzzleEntry.decode(_stuckPuzzle);
    final result = grader.grade(puzzle);

    expect(result.solvedLogically, isFalse);
    expect(result.tier, 4);
  });

  test('a stuck puzzle still has exactly one solution', () {
    final puzzle = PuzzleEntry.decode(_stuckPuzzle);
    expect(SudokuSolver.countSolutions(puzzle, limit: 2), 1);
    expect(
      SudokuSolver.solve(puzzle),
      PuzzleEntry.decode(_stuckSolution),
    );
  });

  test('nextStep proposes a step and does not touch the board', () {
    final values = List<int>.of(PuzzleEntry.decode(_singlesPuzzle));
    final step = grader.nextStep(values);

    expect(step, isNotNull);
    expect(step!.isPlacement, isTrue);
    expect(values, PuzzleEntry.decode(_singlesPuzzle));
  });

  test('nextStep returns null on a solved board', () {
    final values = List<int>.generate(81, (i) => (i % 9) + 1);
    expect(grader.nextStep(values), isNull);
  });

  test('LogicState tracks placement and elimination', () {
    final s = LogicState.fromPuzzle(PuzzleEntry.decode(_singlesPuzzle));

    expect(s.solved, isFalse);
    expect(s.hasContradiction, isFalse);

    s.place(0, 4);
    expect(s.values[0], 4);
    expect(s.cand[0], 0);
    for (final p in kPeers[0]) {
      expect(s.cand[p] & bit(4), 0);
    }

    s.eliminate(1, bit(1));
    expect(s.cand[1] & bit(1), 0);
  });
}
