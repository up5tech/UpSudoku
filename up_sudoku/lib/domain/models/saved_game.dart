/// One resumable game (PLAN.md §17).
///
/// Pure Dart — no Flutter imports allowed in the domain layer.
library;

import '../sudoku_constants.dart';

/// Everything needed to restore a game.
///
/// The undo/redo stacks are intentionally not stored: that keeps the save
/// small, and the undo button is simply empty after a restore.
class SavedGame {
  /// Id of the puzzle inside its difficulty's pool.
  final int puzzleId;

  /// Board values, givens included; 0 means empty.
  final List<int> values;

  /// Candidate notes per cell.
  final List<int> notes;

  /// Seconds already played.
  final int elapsedSeconds;

  /// Wrong digits entered so far.
  final int mistakes;

  /// Hints still available.
  final int hintsLeft;

  /// Hints used so far.
  final int hintsUsed;

  /// "Check board" uses still available.
  final int checksLeft;

  /// "Check board" uses so far.
  final int checksUsed;

  /// True when the game is today's daily puzzle.
  final bool daily;

  /// Date (`yyyy-MM-dd`) of a daily game; null otherwise.
  final String? dailyDate;

  const SavedGame({
    required this.puzzleId,
    required this.values,
    required this.notes,
    required this.elapsedSeconds,
    required this.mistakes,
    required this.hintsLeft,
    required this.hintsUsed,
    required this.checksLeft,
    required this.checksUsed,
    this.daily = false,
    this.dailyDate,
  });

  /// JSON for `shared_preferences`.
  Map<String, dynamic> toJson() => {
    'puzzleId': puzzleId,
    'values': values,
    'notes': notes,
    'elapsedSeconds': elapsedSeconds,
    'mistakes': mistakes,
    'hintsLeft': hintsLeft,
    'hintsUsed': hintsUsed,
    'checksLeft': checksLeft,
    'checksUsed': checksUsed,
    'daily': daily,
    if (dailyDate != null) 'dailyDate': dailyDate,
  };

  /// Reads a saved game, or null when the data is incomplete/corrupted.
  static SavedGame? fromJson(Map<String, dynamic> json) {
    final values = _cells(json['values'], kDigitCount);
    final notes = _cells(json['notes'], kAll);
    final puzzleId = json['puzzleId'];
    if (values == null ||
        notes == null ||
        puzzleId is! int ||
        puzzleId <= 0) {
      return null;
    }

    int read(String key) {
      final value = json[key];
      return value is int && value >= 0 ? value : 0;
    }

    final dailyDate = json['dailyDate'];
    return SavedGame(
      puzzleId: puzzleId,
      values: values,
      notes: notes,
      elapsedSeconds: read('elapsedSeconds'),
      mistakes: read('mistakes'),
      hintsLeft: read('hintsLeft'),
      hintsUsed: read('hintsUsed'),
      checksLeft: read('checksLeft'),
      checksUsed: read('checksUsed'),
      daily: json['daily'] == true,
      dailyDate: dailyDate is String ? dailyDate : null,
    );
  }
}

/// A list of exactly [kCellCount] values in `0..max`, or null.
///
/// Board values are digits (`max` 9); notes are 9-bit candidate masks
/// (`max` [kAll]).
List<int>? _cells(Object? raw, int max) {
  if (raw is! List || raw.length != kCellCount) return null;
  final result = <int>[];
  for (final value in raw) {
    if (value is! int || value < 0 || value > max) return null;
    result.add(value);
  }
  return result;
}
