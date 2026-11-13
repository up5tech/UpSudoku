/// Tier 2 techniques: pointing pairs/triples and box/line reduction.
///
/// These connect a box with a line: candidates confined to the intersection
/// can be removed from the rest of the crossing unit.
library;

import '../sudoku_constants.dart';
import 'logic_state.dart';
import 'logic_step.dart';
import 'technique.dart';

/// A digit confined to one row or column inside a box.
///
/// It can be removed from the rest of that row/column outside the box.
class Pointing implements SolveTechnique {
  @override
  Technique get id => Technique.pointing;

  @override
  int get tier => 2;

  @override
  LogicStep? find(LogicState s) {
    for (final box in kBoxes) {
      for (var d = 1; d <= kDigitCount; d++) {
        final b = bit(d);
        final cells = <int>[
          for (final i in box)
            if (s.values[i] == 0 && (s.cand[i] & b) != 0) i,
        ];
        if (cells.length < 2 || cells.length > 3) continue;

        final rows = {for (final i in cells) rowOf(i)};
        final cols = {for (final i in cells) colOf(i)};

        if (rows.length == 1) {
          final line = kRows[rows.first];
          if (_eliminates(s, line, cells, b)) {
            return LogicStep.eliminate(
              id,
              _eliminations(s, line, cells, b),
              pattern: cells,
            );
          }
        }
        if (cols.length == 1) {
          final line = kCols[cols.first];
          if (_eliminates(s, line, cells, b)) {
            return LogicStep.eliminate(
              id,
              _eliminations(s, line, cells, b),
              pattern: cells,
            );
          }
        }
      }
    }
    return null;
  }
}

/// A digit confined to one box inside a row or column.
///
/// It can be removed from the rest of that box.
class BoxLine implements SolveTechnique {
  @override
  Technique get id => Technique.boxLine;

  @override
  int get tier => 2;

  @override
  LogicStep? find(LogicState s) {
    for (final line in [...kRows, ...kCols]) {
      for (var d = 1; d <= kDigitCount; d++) {
        final b = bit(d);
        final cells = <int>[
          for (final i in line)
            if (s.values[i] == 0 && (s.cand[i] & b) != 0) i,
        ];
        if (cells.length < 2 || cells.length > 3) continue;

        final boxes = {for (final i in cells) boxOf(i)};
        if (boxes.length != 1) continue;

        final box = kBoxes[boxes.first];
        if (_eliminates(s, box, cells, b)) {
          return LogicStep.eliminate(
            id,
            _eliminations(s, box, cells, b),
            pattern: cells,
          );
        }
      }
    }
    return null;
  }
}

/// True when [digitMask] can be removed from cells of [target] outside
/// [pattern].
bool _eliminates(
  LogicState s,
  List<int> target,
  List<int> pattern,
  int digitMask,
) {
  for (final i in target) {
    if (pattern.contains(i) || s.values[i] != 0) continue;
    if ((s.cand[i] & digitMask) != 0) return true;
  }
  return false;
}

/// The actual eliminations of [digitMask] in [target] outside [pattern].
Map<int, int> _eliminations(
  LogicState s,
  List<int> target,
  List<int> pattern,
  int digitMask,
) => {
  for (final i in target)
    if (!pattern.contains(i) &&
        s.values[i] == 0 &&
        (s.cand[i] & digitMask) != 0)
      i: digitMask,
};
