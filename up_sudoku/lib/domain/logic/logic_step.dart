/// One logical step proposed by a technique.
///
/// Pure Dart — no Flutter imports allowed in the domain layer.
library;

import 'logic_state.dart';
import 'technique.dart';

/// A single placement or elimination, plus the cells forming the pattern
/// (used to highlight the reasoning in hints).
class LogicStep {
  /// The technique that produced this step.
  final Technique technique;

  /// The cell to place into (placements only).
  final int? cell;

  /// The digit to place (placements only).
  final int? digit;

  /// Cell → candidate mask to remove (eliminations only).
  final Map<int, int> eliminations;

  /// Cells forming the pattern, for highlighting.
  final List<int> pattern;

  /// Creates a placement step.
  LogicStep.place(this.technique, int this.cell, int this.digit, {this.pattern = const []})
    : eliminations = const {};

  /// Creates an elimination step.
  LogicStep.eliminate(this.technique, this.eliminations, {this.pattern = const []})
    : cell = null,
      digit = null;

  /// True when this step places a digit.
  bool get isPlacement => cell != null;

  /// True when this step removes candidates.
  bool get isElimination => eliminations.isNotEmpty;

  /// Applies this step to [s].
  void applyTo(LogicState s) {
    if (cell != null) s.place(cell!, digit!);
    eliminations.forEach(s.eliminate);
  }
}
