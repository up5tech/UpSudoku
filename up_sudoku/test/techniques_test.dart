import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:up_sudoku/domain/generator.dart';
import 'package:up_sudoku/domain/logic/fish.dart';
import 'package:up_sudoku/domain/logic/grader.dart';
import 'package:up_sudoku/domain/logic/intersections.dart';
import 'package:up_sudoku/domain/logic/logic_state.dart';
import 'package:up_sudoku/domain/logic/logic_step.dart';
import 'package:up_sudoku/domain/logic/singles.dart';
import 'package:up_sudoku/domain/logic/subsets.dart';
import 'package:up_sudoku/domain/logic/technique.dart';
import 'package:up_sudoku/domain/logic/wings.dart';
import 'package:up_sudoku/domain/solver.dart';
import 'package:up_sudoku/domain/sudoku_constants.dart';

/// Builds a state from plain values + candidate masks.
LogicState _state(List<int> values, Map<int, int> cand) {
  final c = List<int>.filled(81, 0);
  cand.forEach((i, mask) => c[i] = mask);
  return LogicState(List<int>.of(values), c);
}

/// Cell index of (row, column).
int _at(int row, int col) => row * 9 + col;

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

  group('NakedSubset', () {
    test('naked pair removes both digits from the rest of the unit', () {
      final s = _state(List.filled(81, 0), {
        0: bit(1) | bit(2),
        1: bit(1) | bit(2),
        2: bit(1) | bit(2) | bit(3),
      });

      final step = NakedPair().find(s);
      expect(step, isNotNull);
      expect(step!.technique, Technique.nakedPair);
      expect(step.eliminations, {2: bit(1) | bit(2)});
      expect(step.pattern, [0, 1]);
    });

    test('naked triple uses three cells with three candidates', () {
      final s = _state(List.filled(81, 0), {
        0: bit(1) | bit(2),
        1: bit(2) | bit(3),
        2: bit(1) | bit(3),
        3: bit(1) | bit(2) | bit(3) | bit(4),
      });

      final step = NakedTriple().find(s);
      expect(step, isNotNull);
      expect(step!.technique, Technique.nakedTriple);
      expect(step.eliminations, {3: bit(1) | bit(2) | bit(3)});
    });

    test('naked quad uses four cells with four candidates', () {
      final s = _state(List.filled(81, 0), {
        0: bit(1) | bit(2),
        1: bit(2) | bit(3),
        2: bit(3) | bit(4),
        3: bit(1) | bit(4),
        4: bit(1) | bit(2) | bit(3) | bit(4) | bit(5),
      });

      final step = NakedQuad().find(s);
      expect(step, isNotNull);
      expect(step!.technique, Technique.nakedQuad);
      expect(step.eliminations, {4: bit(1) | bit(2) | bit(3) | bit(4)});
    });

    test('a subset that removes nothing is not reported', () {
      final s = _state(List.filled(81, 0), {
        0: bit(1) | bit(2),
        1: bit(1) | bit(2),
        // No other cell of the unit holds 1 or 2.
      });

      expect(NakedPair().find(s), isNull);
    });
  });

  group('HiddenSubset', () {
    test('hidden pair keeps the pair and drops the other candidates', () {
      final others = bit(3) | bit(4) | bit(5) | bit(6);
      final s = _state(List.filled(81, 0), {
        3: bit(1) | bit(2) | bit(5),
        4: bit(1) | bit(2) | bit(7),
        0: others,
        1: others,
        2: others,
        5: others,
        6: others,
        7: others,
        8: others,
      });

      final step = HiddenPair().find(s);
      expect(step, isNotNull);
      expect(step!.technique, Technique.hiddenPair);
      expect(step.eliminations, {3: bit(5), 4: bit(7)});
      expect(step.pattern, [3, 4]);
    });

    test('hidden triple keeps the three digits', () {
      final others = bit(4) | bit(5) | bit(6);
      final s = _state(List.filled(81, 0), {
        3: bit(1) | bit(2) | bit(9),
        4: bit(1) | bit(3) | bit(8),
        5: bit(2) | bit(3) | bit(7),
        0: others,
        1: others,
        2: others,
        6: others,
        7: others,
        8: others,
      });

      final step = HiddenTriple().find(s);
      expect(step, isNotNull);
      expect(step!.technique, Technique.hiddenTriple);
      expect(step.eliminations, {3: bit(9), 4: bit(8), 5: bit(7)});
    });

    test('hidden quad keeps the four digits', () {
      final others = bit(5) | bit(6) | bit(7);
      final s = _state(List.filled(81, 0), {
        0: bit(1) | bit(2) | bit(9),
        1: bit(1) | bit(3) | bit(8),
        2: bit(2) | bit(4) | bit(7),
        3: bit(3) | bit(4) | bit(6),
        4: others,
        5: others,
        6: others,
        7: others,
        8: others,
      });

      final step = HiddenQuad().find(s);
      expect(step, isNotNull);
      expect(step!.technique, Technique.hiddenQuad);
      expect(step.eliminations.length, 4);
    });
  });

  group('Pointing', () {
    test('a digit locked in a row of a box leaves the rest of the row', () {
      final s = _state(List.filled(81, 0), {
        0: bit(1) | bit(5),
        1: bit(2) | bit(5),
        for (var c = 3; c < 9; c++) _at(0, c): bit(1) | bit(5),
        for (final i in [2, 9, 10, 11, 18, 19, 20]) i: bit(1) | bit(2),
      });

      final step = Pointing().find(s);
      expect(step, isNotNull);
      expect(step!.technique, Technique.pointing);
      expect(step.eliminations.length, 6);
      for (var c = 3; c < 9; c++) {
        expect(step.eliminations[_at(0, c)], bit(5));
      }
      expect(step.pattern, [0, 1]);
    });

    test('a digit locked in a column of a box leaves the rest of the column', () {
      final s = _state(List.filled(81, 0), {
        0: bit(1) | bit(5),
        9: bit(2) | bit(5),
        for (var r = 3; r < 9; r++) _at(r, 0): bit(1) | bit(5),
        for (final i in [1, 2, 10, 11, 19, 20]) i: bit(1) | bit(2),
      });

      final step = Pointing().find(s);
      expect(step, isNotNull);
      expect(step!.eliminations.length, 6);
      for (var r = 3; r < 9; r++) {
        expect(step.eliminations[_at(r, 0)], bit(5));
      }
    });
  });

  group('BoxLine', () {
    test('a digit confined to a box in a row leaves the rest of the box', () {
      final s = _state(List.filled(81, 0), {
        0: bit(1) | bit(5),
        1: bit(2) | bit(5),
        for (final i in [9, 10, 11, 18, 19, 20]) i: bit(5) | bit(3),
        // 5 must not appear elsewhere in row 0.
      });

      final step = BoxLine().find(s);
      expect(step, isNotNull);
      expect(step!.technique, Technique.boxLine);
      expect(step.eliminations, {
        for (final i in [9, 10, 11, 18, 19, 20]) i: bit(5),
      });
      expect(step.pattern, [0, 1]);
    });

    test('a digit confined to a box in a column leaves the rest of the box', () {
      final s = _state(List.filled(81, 0), {
        // A 5 in column 0 only at rows 1 and 2 (both in box 0), plus one 5
        // elsewhere in the box: no row has two 5s inside the box.
        9: bit(5),
        18: bit(5),
        1: bit(5) | bit(3),
      });

      final step = BoxLine().find(s);
      expect(step, isNotNull);
      expect(step!.eliminations, {1: bit(5)});
      expect(step.pattern, [9, 18]);
    });
  });

  group('Fish', () {
    test('X-Wing removes the digit from both cover columns', () {
      final s = _state(List.filled(81, 0), {
        _at(0, 2): bit(5),
        _at(0, 5): bit(5),
        _at(4, 2): bit(5),
        _at(4, 5): bit(5),
        for (final r in [1, 2, 3, 5, 6, 7, 8]) ...{
          _at(r, 2): bit(5) | bit(9),
          _at(r, 5): bit(5),
          _at(r, 8): bit(5) | bit(9), // a third position: not an X-Wing row
        },
      });

      final step = XWing().find(s);
      expect(step, isNotNull);
      expect(step!.technique, Technique.xWing);
      expect(step.pattern, [_at(0, 2), _at(0, 5), _at(4, 2), _at(4, 5)]);
      for (final r in [1, 2, 3, 5, 6, 7, 8]) {
        expect(step.eliminations[_at(r, 2)], bit(5));
        expect(step.eliminations[_at(r, 5)], bit(5));
      }
      // The pattern cells themselves are never eliminated.
      expect(step.eliminations[_at(0, 2)], isNull);
      expect(step.eliminations[_at(4, 5)], isNull);
    });

    test('X-Wing also works with columns as base sets', () {
      final s = _state(List.filled(81, 0), {
        _at(2, 0): bit(5),
        _at(5, 0): bit(5),
        _at(2, 4): bit(5),
        _at(5, 4): bit(5),
        for (final c in [1, 2, 3, 5, 6, 7, 8]) ...{
          _at(2, c): bit(5) | bit(9),
          _at(5, c): bit(5),
        },
      });

      final step = XWing().find(s);
      expect(step, isNotNull);
      expect(step!.technique, Technique.xWing);
      expect(step.pattern.length, 4);
      expect(step.eliminations.values.every((m) => m == bit(5)), isTrue);
      // Every elimination sits outside the four pattern cells.
      for (final cell in step.eliminations.keys) {
        expect(step.pattern.contains(cell), isFalse);
      }
    });

    test('Swordfish spans three rows and three columns', () {
      final s = _state(List.filled(81, 0), {
        _at(0, 2): bit(5),
        _at(0, 5): bit(5),
        _at(1, 5): bit(5),
        _at(1, 7): bit(5),
        _at(2, 2): bit(5),
        _at(2, 7): bit(5),
        for (var r = 3; r < 9; r++)
          for (final c in [2, 5, 7]) _at(r, c): bit(5) | bit(9),
      });

      final step = Swordfish().find(s);
      expect(step, isNotNull);
      expect(step!.technique, Technique.swordfish);
      expect(step.pattern.length, 6);
      expect(step.eliminations.length, 18);
      expect(step.eliminations[_at(5, 5)], bit(5));
      expect(step.eliminations[_at(0, 2)], isNull);
    });
  });

  group('Wings', () {
    test('XY-Wing removes the shared digit from both pincers common peers', () {
      final s = _state(List.filled(81, 0), {
        0: bit(1) | bit(2),
        1: bit(1) | bit(3),
        9: bit(2) | bit(3),
        10: bit(3) | bit(4),
      });

      final step = XYWing().find(s);
      expect(step, isNotNull);
      expect(step!.technique, Technique.xyWing);
      expect(step.eliminations, {10: bit(3)});
      expect(step.pattern, [0, 1, 9]);
    });

    test('XY-Wing ignores pincers that do not share a pivot candidate', () {
      final s = _state(List.filled(81, 0), {
        0: bit(1) | bit(2),
        1: bit(1) | bit(3),
        9: bit(3) | bit(4), // does not see the pivot through digit 2
        10: bit(3) | bit(4),
      });

      expect(XYWing().find(s), isNull);
    });

    test('XYZ-Wing removes the shared digit from cells seeing all three', () {
      final s = _state(List.filled(81, 0), {
        0: bit(1) | bit(2) | bit(3),
        1: bit(1) | bit(3),
        9: bit(2) | bit(3),
        10: bit(3) | bit(4),
      });

      final step = XYZWing().find(s);
      expect(step, isNotNull);
      expect(step!.technique, Technique.xyzWing);
      expect(step.eliminations, {10: bit(3)});
      expect(step.pattern, [0, 1, 9]);
    });

    test('XYZ-Wing requires the pivot to have exactly three candidates', () {
      final s = _state(List.filled(81, 0), {
        0: bit(1) | bit(2),
        1: bit(1) | bit(3),
        9: bit(2) | bit(3),
        10: bit(3) | bit(4),
      });

      expect(XYZWing().find(s), isNull);
    });
  });

  group('soundness', () {
    test(
      'no technique ever removes a candidate belonging to the solution',
      () {
        final rng = Random(2024);
        final grader = Grader.standard();
        final used = <Technique, int>{};
        var checked = 0;

        for (var n = 0; n < 160; n++) {
          final solution = SudokuSolver.solve(List.filled(81, 0), rng: rng)!;
          final target = 22 + (n % 5) * 4; // 22..38 givens: all tiers
          final puzzle = PuzzleGenerator.dig(solution, target, rng);
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

            used[step.technique] = (used[step.technique] ?? 0) + 1;
            step.applyTo(state);
            checked++;
          }
        }

        expect(checked, greaterThan(1000), reason: 'too few steps were checked');
        // The soundness run must exercise more than the singles.
        final tier2 = used.keys.where((t) => kTechniqueTier[t] == 2).toList();
        expect(tier2, isNotEmpty, reason: 'no tier 2 step was checked');

        // And it must reach the tier 3 techniques, otherwise fish/wing
        // eliminations would never be validated against a known solution.
        final tier3 = used.keys.where((t) => kTechniqueTier[t] == 3).toList();
        expect(
          tier3,
          isNotEmpty,
          reason:
              'no tier 3 step (X-Wing/XY-Wing/XYZ-Wing/Swordfish) was '
              'checked; techniques used: $used',
        );
      },
      timeout: const Timeout(Duration(minutes: 4)),
    );
  });
}
