/// Tier 3 techniques: X-Wing and Swordfish.
///
/// Both are "fish": a digit is confined to the same small set of columns in a
/// set of rows (or the same rows in a set of columns), which removes it from
/// the rest of those columns (rows).
library;

import '../sudoku_constants.dart';
import 'combinations.dart';
import 'logic_state.dart';
import 'logic_step.dart';
import 'technique.dart';

/// A fish of [size] base sets (2 = X-Wing, 3 = Swordfish).
class Fish implements SolveTechnique {
  Fish(this.id, this.size);

  @override
  final Technique id;

  /// Number of rows/columns the fish spans.
  final int size;

  @override
  int get tier => 3;

  @override
  LogicStep? find(LogicState s) {
    for (var d = 1; d <= kDigitCount; d++) {
      final b = bit(d);
      final rowStep = _search(s, b, _positions(s, b, byRow: true), byRow: true);
      if (rowStep != null) return rowStep;

      final colStep = _search(
        s,
        b,
        _positions(s, b, byRow: false),
        byRow: false,
      );
      if (colStep != null) return colStep;
    }
    return null;
  }

  /// Map of base line → positions (columns for rows, rows for columns) that
  /// still allow [digitMask].
  Map<int, List<int>> _positions(
    LogicState s,
    int digitMask, {
    required bool byRow,
  }) {
    final result = <int, List<int>>{};
    for (var line = 0; line < 9; line++) {
      final positions = <int>[];
      for (var k = 0; k < 9; k++) {
        final i = byRow ? line * 9 + k : k * 9 + line;
        if (s.values[i] == 0 && (s.cand[i] & digitMask) != 0) positions.add(k);
      }
      // A fish line holds 2..size positions; more than size cannot be part
      // of the pattern.
      if (positions.length >= 2 && positions.length <= size) {
        result[line] = positions;
      }
    }
    return result;
  }

  LogicStep? _search(
    LogicState s,
    int digitMask,
    Map<int, List<int>> positions, {
    required bool byRow,
  }) {
    for (final base in combinations(positions.keys.toList(), size)) {
      final cover = <int>{};
      for (final line in base) {
        cover.addAll(positions[line]!);
      }
      if (cover.length != size) continue;

      final eliminations = <int, int>{};
      for (final cross in cover) {
        for (var line = 0; line < 9; line++) {
          if (base.contains(line)) continue;
          final i = byRow ? line * 9 + cross : cross * 9 + line;
          if (s.values[i] == 0 && (s.cand[i] & digitMask) != 0) {
            eliminations[i] = digitMask;
          }
        }
      }
      if (eliminations.isEmpty) continue;

      final pattern = <int>[
        for (final line in base)
          for (final cross in positions[line]!)
            byRow ? line * 9 + cross : cross * 9 + line,
      ];
      return LogicStep.eliminate(id, eliminations, pattern: pattern);
    }
    return null;
  }
}

/// X-Wing (fish of size 2).
class XWing extends Fish {
  XWing() : super(Technique.xWing, 2);
}

/// Swordfish (fish of size 3).
class Swordfish extends Fish {
  Swordfish() : super(Technique.swordfish, 3);
}
