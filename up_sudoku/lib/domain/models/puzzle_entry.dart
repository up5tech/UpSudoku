/// A bundled puzzle together with its solution and metadata.
library;

import 'difficulty.dart';

/// One entry of the bundled puzzle pool.
class PuzzleEntry {
  /// Stable identifier inside the pool.
  final int id;

  /// Difficulty the puzzle belongs to.
  final Difficulty difficulty;

  /// The puzzle grid: 81 ints, 0 means empty.
  final List<int> puzzle;

  /// The solution grid: 81 ints in 1..9.
  final List<int> solution;

  /// Number of givens in [puzzle].
  final int givens;

  /// Weighted technique score (diagnostics only).
  final int score;

  const PuzzleEntry({
    required this.id,
    required this.difficulty,
    required this.puzzle,
    required this.solution,
    required this.givens,
    required this.score,
  });

  /// Decodes an 81 character string ('0' = empty) into cell values.
  static List<int> decode(String s) =>
      [for (var i = 0; i < s.length; i++) s.codeUnitAt(i) - 48];

  /// Encodes cell values into an 81 character string.
  static String encode(List<int> cells) => cells.join();

  /// Builds an entry from its JSON representation.
  factory PuzzleEntry.fromJson(Map<String, dynamic> j, Difficulty d) =>
      PuzzleEntry(
        id: j['id'] as int,
        difficulty: d,
        puzzle: decode(j['p'] as String),
        solution: decode(j['s'] as String),
        givens: j['g'] as int,
        score: j['score'] as int,
      );

  /// JSON representation used by the puzzle pool files.
  Map<String, dynamic> toJson() => {
    'id': id,
    'p': encode(puzzle),
    's': encode(solution),
    'g': givens,
    'score': score,
  };
}
