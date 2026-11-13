/// One undoable change of a single cell.
///
/// Pure Dart — no Flutter imports allowed in the domain layer.
library;

/// The state of one cell before and after an action.
///
/// A user action is stored as a list of these, so notes removed automatically
/// by placing a digit are undone together with the digit that caused them
/// (PLAN.md §13.2).
class CellChange {
  /// The cell index (0..80).
  final int cell;

  /// Value before the action.
  final int oldValue;

  /// Value after the action.
  final int newValue;

  /// Notes before the action.
  final int oldNotes;

  /// Notes after the action.
  final int newNotes;

  const CellChange(
    this.cell,
    this.oldValue,
    this.newValue,
    this.oldNotes,
    this.newNotes,
  );
}
