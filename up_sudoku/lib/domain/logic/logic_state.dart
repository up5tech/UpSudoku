/// Logic solver state: placed digits plus one candidate mask per empty cell.
///
/// Pure Dart — no Flutter imports allowed in the domain layer.
library;

import '../sudoku_constants.dart';

/// The board as a logic solver sees it.
class LogicState {
  /// Placed digits; 0 means empty.
  final List<int> values;

  /// Candidate bitmask per cell; 0 for filled cells.
  final List<int> cand;

  LogicState(this.values, this.cand);

  /// Builds a state from a puzzle, computing candidates from the givens.
  factory LogicState.fromPuzzle(List<int> puzzle) {
    final values = List<int>.of(puzzle);
    final cand = List<int>.filled(kCellCount, 0);
    for (var i = 0; i < kCellCount; i++) {
      if (values[i] != 0) continue;
      var used = 0;
      for (final p in kPeers[i]) {
        if (values[p] != 0) used |= bit(values[p]);
      }
      cand[i] = kAll & ~used;
    }
    return LogicState(values, cand);
  }

  /// Places [digit] in [cell] and removes it from the peers' candidates.
  void place(int cell, int digit) {
    values[cell] = digit;
    cand[cell] = 0;
    final b = bit(digit);
    for (final p in kPeers[cell]) {
      cand[p] &= ~b;
    }
  }

  /// Removes the candidates in [mask] from [cell].
  void eliminate(int cell, int mask) => cand[cell] &= ~mask;

  /// True when every cell is filled.
  bool get solved => !values.contains(0);

  /// True when some empty cell has no candidate left.
  bool get hasContradiction {
    for (var i = 0; i < kCellCount; i++) {
      if (values[i] == 0 && cand[i] == 0) return true;
    }
    return false;
  }

  /// An independent copy of this state.
  LogicState copy() => LogicState(List<int>.of(values), List<int>.of(cand));
}
