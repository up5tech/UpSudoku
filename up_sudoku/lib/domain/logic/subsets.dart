/// Tier 2 techniques: naked and hidden pairs, triples and quads.
///
/// A technique only *proposes* a step — it never mutates the state
/// (PLAN.md §11.6). Every step is only returned when it actually removes at
/// least one candidate, so the grader always makes progress.
library;

import '../sudoku_constants.dart';
import 'combinations.dart';
import 'logic_state.dart';
import 'logic_step.dart';
import 'technique.dart';

/// `size` cells of one unit that between them hold exactly `size` candidates.
///
/// Those candidates can be removed from the rest of the unit.
class NakedSubset implements SolveTechnique {
  NakedSubset(this.id, this.size);

  @override
  final Technique id;

  /// Number of cells in the subset (2, 3 or 4).
  final int size;

  @override
  int get tier => kTechniqueTier[id]!;

  @override
  LogicStep? find(LogicState s) {
    for (final unit in kUnits) {
      final cells = <int>[
        for (final i in unit)
          if (s.values[i] == 0 &&
              popCount(s.cand[i]) >= 2 &&
              popCount(s.cand[i]) <= size)
            i,
      ];
      for (final combo in combinations(cells, size)) {
        var mask = 0;
        for (final i in combo) {
          mask |= s.cand[i];
        }
        if (popCount(mask) != size) continue;

        final eliminations = <int, int>{};
        for (final i in unit) {
          if (s.values[i] != 0 || combo.contains(i)) continue;
          final hit = s.cand[i] & mask;
          if (hit != 0) eliminations[i] = hit;
        }
        if (eliminations.isNotEmpty) {
          return LogicStep.eliminate(id, eliminations, pattern: combo);
        }
      }
    }
    return null;
  }
}

/// `size` digits of one unit that can only appear in the same `size` cells.
///
/// Every other candidate of those cells can be removed.
class HiddenSubset implements SolveTechnique {
  HiddenSubset(this.id, this.size);

  @override
  final Technique id;

  /// Number of digits in the subset (2, 3 or 4).
  final int size;

  @override
  int get tier => kTechniqueTier[id]!;

  @override
  LogicStep? find(LogicState s) {
    for (final unit in kUnits) {
      final digits = <int>[
        for (var d = 1; d <= kDigitCount; d++)
          if (!unit.any((i) => s.values[i] == d) &&
              unit.any((i) => s.values[i] == 0 && (s.cand[i] & bit(d)) != 0))
            d,
      ];
      for (final combo in combinations(digits, size)) {
        var mask = 0;
        for (final d in combo) {
          mask |= bit(d);
        }
        final cells = <int>[
          for (final i in unit)
            if (s.values[i] == 0 && (s.cand[i] & mask) != 0) i,
        ];
        if (cells.length != size) continue;

        final eliminations = <int, int>{};
        for (final i in cells) {
          final extra = s.cand[i] & ~mask;
          if (extra != 0) eliminations[i] = extra;
        }
        if (eliminations.isNotEmpty) {
          return LogicStep.eliminate(id, eliminations, pattern: cells);
        }
      }
    }
    return null;
  }
}

/// Naked pair.
class NakedPair extends NakedSubset {
  NakedPair() : super(Technique.nakedPair, 2);
}

/// Naked triple.
class NakedTriple extends NakedSubset {
  NakedTriple() : super(Technique.nakedTriple, 3);
}

/// Naked quad.
class NakedQuad extends NakedSubset {
  NakedQuad() : super(Technique.nakedQuad, 4);
}

/// Hidden pair.
class HiddenPair extends HiddenSubset {
  HiddenPair() : super(Technique.hiddenPair, 2);
}

/// Hidden triple.
class HiddenTriple extends HiddenSubset {
  HiddenTriple() : super(Technique.hiddenTriple, 3);
}

/// Hidden quad.
class HiddenQuad extends HiddenSubset {
  HiddenQuad() : super(Technique.hiddenQuad, 4);
}
