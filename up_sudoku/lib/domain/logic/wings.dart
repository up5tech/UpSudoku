/// Tier 3 techniques: XY-Wing and XYZ-Wing.
///
/// A pivot cell with two (XY) or three (XYZ) candidates and two pincer cells
/// that each share one pivot candidate plus a common "z" digit. The z digit
/// can be removed from every cell that sees the pincers.
library;

import '../sudoku_constants.dart';
import 'logic_state.dart';
import 'logic_step.dart';
import 'technique.dart';

/// Pivot {x,y}, pincers {x,z} and {y,z}: remove z from cells seeing both
/// pincers.
class XYWing implements SolveTechnique {
  @override
  Technique get id => Technique.xyWing;

  @override
  int get tier => 3;

  @override
  LogicStep? find(LogicState s) {
    for (var pivot = 0; pivot < kCellCount; pivot++) {
      if (s.values[pivot] != 0) continue;
      final pivotCand = s.cand[pivot];
      if (popCount(pivotCand) != 2) continue;

      for (final pincerA in kPeers[pivot]) {
        if (s.values[pincerA] != 0) continue;
        final candA = s.cand[pincerA];
        if (popCount(candA) != 2) continue;
        // Share exactly one candidate with the pivot.
        if ((candA & pivotCand) == 0 || (candA & pivotCand) == pivotCand) {
          continue;
        }
        final z = candA & ~pivotCand;
        final other = pivotCand & ~candA;

        for (final pincerB in kPeers[pivot]) {
          if (pincerB == pincerA || s.values[pincerB] != 0) continue;
          if (s.cand[pincerB] != (other | z)) continue;

          final targets = kPeers[pincerA].toSet().intersection(
            kPeers[pincerB].toSet(),
          );
          final eliminations = <int, int>{};
          for (final i in targets) {
            if (s.values[i] == 0 && (s.cand[i] & z) != 0) {
              eliminations[i] = z;
            }
          }
          if (eliminations.isEmpty) continue;
          return LogicStep.eliminate(
            id,
            eliminations,
            pattern: [pivot, pincerA, pincerB],
          );
        }
      }
    }
    return null;
  }
}

/// Pivot {x,y,z}, pincers {x,z} and {y,z}: remove z from cells seeing all
/// three cells.
class XYZWing implements SolveTechnique {
  @override
  Technique get id => Technique.xyzWing;

  @override
  int get tier => 3;

  @override
  LogicStep? find(LogicState s) {
    for (var pivot = 0; pivot < kCellCount; pivot++) {
      if (s.values[pivot] != 0) continue;
      final pivotCand = s.cand[pivot];
      if (popCount(pivotCand) != 3) continue;

      final pincers = <int>[];
      for (final p in kPeers[pivot]) {
        if (s.values[p] != 0) continue;
        final cand = s.cand[p];
        if (popCount(cand) != 2) continue;
        if ((cand & pivotCand) == cand) pincers.add(p);
      }

      for (var a = 0; a < pincers.length; a++) {
        for (var b = a + 1; b < pincers.length; b++) {
          final candA = s.cand[pincers[a]];
          final candB = s.cand[pincers[b]];
          final z = candA & candB;
          if (popCount(z) != 1) continue;
          if ((candA | candB) != pivotCand) continue;

          final targets = kPeers[pivot]
              .toSet()
              .intersection(kPeers[pincers[a]].toSet())
              .intersection(kPeers[pincers[b]].toSet());
          final eliminations = <int, int>{};
          for (final i in targets) {
            if (s.values[i] == 0 && (s.cand[i] & z) != 0) {
              eliminations[i] = z;
            }
          }
          if (eliminations.isEmpty) continue;
          return LogicStep.eliminate(
            id,
            eliminations,
            pattern: [pivot, pincers[a], pincers[b]],
          );
        }
      }
    }
    return null;
  }
}
