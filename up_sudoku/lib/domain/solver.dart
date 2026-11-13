/// Backtracking Sudoku solver used for uniqueness checks and for producing
/// full solutions.
///
/// Pure Dart — no Flutter imports allowed in the domain layer.
library;

import 'dart:math';

import 'sudoku_constants.dart';

/// Bitmask based backtracking solver with the minimum-remaining-values (MRV)
/// heuristic.
class SudokuSolver {
  const SudokuSolver._();

  /// Number of solutions of [puzzle], stopping once [limit] is reached.
  ///
  /// Use `limit: 2` to test uniqueness. Returns 0 for contradictory givens.
  static int countSolutions(List<int> puzzle, {int limit = 2}) {
    final search = _Search(puzzle, limit, null)..run();
    return search.found;
  }

  /// One solution of [puzzle] (random when [rng] is given), or null if none
  /// exists.
  static List<int>? solve(List<int> puzzle, {Random? rng}) {
    final search = _Search(puzzle, 1, rng)..run();
    return search.first;
  }
}

class _Search {
  final List<int> cells;
  final int limit;
  final Random? rng;
  final List<int> rows = List.filled(9, 0);
  final List<int> cols = List.filled(9, 0);
  final List<int> boxes = List.filled(9, 0);
  int found = 0;
  List<int>? first;

  _Search(List<int> puzzle, this.limit, this.rng) : cells = List<int>.of(puzzle);

  void run() {
    for (var i = 0; i < kCellCount; i++) {
      final v = cells[i];
      if (v == 0) continue;
      final b = bit(v);
      final r = rowOf(i), c = colOf(i), x = boxOf(i);
      if ((rows[r] & b) != 0 || (cols[c] & b) != 0 || (boxes[x] & b) != 0) {
        return; // contradictory givens → 0 solutions
      }
      rows[r] |= b;
      cols[c] |= b;
      boxes[x] |= b;
    }
    _dfs();
  }

  void _dfs() {
    // Pick the empty cell with the fewest candidates (MRV).
    var best = -1;
    var bestMask = 0;
    var bestCount = 10;
    for (var i = 0; i < kCellCount; i++) {
      if (cells[i] != 0) continue;
      final mask = kAll & ~(rows[rowOf(i)] | cols[colOf(i)] | boxes[boxOf(i)]);
      final n = popCount(mask);
      if (n < bestCount) {
        best = i;
        bestMask = mask;
        bestCount = n;
        if (n <= 1) break;
      }
    }

    if (best == -1) { // no empty cell: a full valid grid
      found++;
      first ??= List<int>.of(cells);
      return;
    }
    if (bestCount == 0) return; // dead end

    final r = rowOf(best), c = colOf(best), x = boxOf(best);
    final digits = digitsOf(bestMask);
    if (rng != null) digits.shuffle(rng);

    for (final d in digits) {
      if (found >= limit) return;
      final b = bit(d);
      cells[best] = d;
      rows[r] |= b;
      cols[c] |= b;
      boxes[x] |= b;
      _dfs();
      rows[r] &= ~b;
      cols[c] &= ~b;
      boxes[x] &= ~b;
      cells[best] = 0;
    }
  }
}
