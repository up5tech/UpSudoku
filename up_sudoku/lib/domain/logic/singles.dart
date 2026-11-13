/// Tier 1 techniques: naked singles and hidden singles.
///
/// A technique only *proposes* a step — it never mutates the state
/// (PLAN.md §11.6).
library;

import '../sudoku_constants.dart';
import 'logic_state.dart';
import 'logic_step.dart';
import 'technique.dart';

/// A cell with exactly one candidate.
class NakedSingle implements SolveTechnique {
  @override
  Technique get id => Technique.nakedSingle;

  @override
  int get tier => 1;

  @override
  LogicStep? find(LogicState s) {
    for (var i = 0; i < kCellCount; i++) {
      final m = s.cand[i];
      if (s.values[i] == 0 && m != 0 && (m & (m - 1)) == 0) {
        return LogicStep.place(id, i, m.bitLength, pattern: [i]);
      }
    }
    return null;
  }
}

/// A digit that can only go into one cell of a unit.
class HiddenSingle implements SolveTechnique {
  @override
  Technique get id => Technique.hiddenSingle;

  @override
  int get tier => 1;

  @override
  LogicStep? find(LogicState s) {
    for (final unit in kUnits) {
      for (var d = 1; d <= kDigitCount; d++) {
        final b = bit(d);
        var count = 0;
        var only = -1;
        for (final i in unit) {
          if (s.values[i] == d) {
            count = 99; // already placed in this unit
            break;
          }
          if ((s.cand[i] & b) != 0) {
            count++;
            only = i;
          }
        }
        if (count == 1) return LogicStep.place(id, only, d, pattern: unit);
      }
    }
    return null;
  }
}
