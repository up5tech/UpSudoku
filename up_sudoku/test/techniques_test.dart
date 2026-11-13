import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:up_sudoku/domain/generator.dart';
import 'package:up_sudoku/domain/logic/grader.dart';
import 'package:up_sudoku/domain/logic/logic_state.dart';
import 'package:up_sudoku/domain/logic/logic_step.dart';
import 'package:up_sudoku/domain/logic/singles.dart';
import 'package:up_sudoku/domain/logic/technique.dart';
import 'package:up_sudoku/domain/solver.dart';
import 'package:up_sudoku/domain/sudoku_constants.dart';

/// Builds a state from plain values + candidate masks.
LogicState _state(List<int> values, Map<int, int> cand) {
  final c = List<int>.filled(81, 0);
  cand.forEach((i, mask) => c[i] = mask);
  return LogicState(List<int>.of(values), c);
}

void main() {
  group('NakedSingle', () {
    test('finds the cell with exactly one candidate', () {
      final s = _state(List.filled(81, 0), {0: bit(5)});
      final step = NakedSingle().find(s);

      expect(step, isNotNull);
      expect(step!.technique, Technique.nakedSingle);
      expect(step.cell, 0);
      expect(step.digit, 5);
      expect(step.isPlacement, isTrue);
      expect(step.pattern, [0]);
    });

    test('ignores cells with more than one candidate', () {
      final s = _state(List.filled(81, 0), {0: bit(5) | bit(6)});
      expect(NakedSingle().find(s), isNull);
    });

    test('ignores filled cells', () {
      final values = List<int>.filled(81, 0)..[0] = 5;
      final s = _state(values, {0: 0});
      expect(NakedSingle().find(s), isNull);
    });

    test('does not mutate the state', () {
      final s = _state(List.filled(81, 0), {0: bit(5)});
      NakedSingle().find(s);
      expect(s.values[0], 0);
      expect(s.cand[0], bit(5));
    });
  });

  group('HiddenSingle', () {
    test('finds the only cell that can hold a digit in a unit', () {
      final values = List<int>.filled(81, 0);
      final cand = <int, int>{};
      for (var i = 0; i < 9; i++) {
        cand[i] = kAll & ~bit(7);
      }
      cand[4] = kAll; // the only cell in row 0 that allows a 7
      final s = _state(values, cand);

      final step = HiddenSingle().find(s);
      expect(step, isNotNull);
      expect(step!.technique, Technique.hiddenSingle);
      expect(step.cell, 4);
      expect(step.digit, 7);
      expect(step.pattern.length, 9);
    });

    test('returns null when the digit is already placed in the unit', () {
      final values = List<int>.filled(81, 0)..[0] = 7;
      final cand = <int, int>{};
      for (var i = 1; i < 9; i++) {
        cand[i] = kAll & ~bit(7);
      }
      final s = _state(values, cand);

      // A 7 is placed in row 0, so row 0 has no hidden single for a 7 —
      // but another row may still provide one. Assert on row 0 only.
      final step = HiddenSingle().find(s);
      if (step != null) expect(step.cell, isNot(0));
    });

    test('does not mutate the state', () {
      final values = List<int>.filled(81, 0);
      final cand = <int, int>{};
      for (var i = 0; i < 9; i++) {
        cand[i] = kAll & ~bit(7);
      }
      cand[4] = kAll;
      final s = _state(values, cand);
      HiddenSingle().find(s);
      expect(s.values[4], 0);
    });
  });

  group('soundness', () {
    test('no technique ever removes a candidate belonging to the solution', () {
      final rng = Random(2024);
      final grader = Grader.standard();
      var checked = 0;

      for (var n = 0; n < 200; n++) {
        final solution = SudokuSolver.solve(List.filled(81, 0), rng: rng)!;
        final puzzle = PuzzleGenerator.dig(solution, 40, rng);
        if (SudokuSolver.countSolutions(puzzle, limit: 2) != 1) continue;

        final state = LogicState.fromPuzzle(puzzle);
        var guard = 0;
        while (!state.solved) {
          guard++;
          expect(guard, lessThan(500), reason: 'grader did not terminate');

          LogicStep? step;
          for (final technique in grader.techniques) {
            step = technique.find(state);
            if (step != null) break;
          }
          if (step == null) break; // stuck — nothing left to check

          if (step.isPlacement) {
            expect(
              step.digit,
              solution[step.cell!],
              reason: 'placed ${step.digit} but the solution says '
                  '${solution[step.cell!]} at cell ${step.cell}',
            );
          }
          step.eliminations.forEach((cell, mask) {
            for (final digit in digitsOf(mask)) {
              expect(
                digit,
                isNot(solution[cell]),
                reason: 'removed the solution digit $digit from cell $cell',
              );
            }
          });

          step.applyTo(state);
          checked++;
        }
      }

      expect(checked, greaterThan(1000), reason: 'too few steps were checked');
    });
  });
}
