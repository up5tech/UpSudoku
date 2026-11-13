/// Puzzle generation: random full grid → dig holes → grade → accept.
///
/// Pure Dart — no Flutter imports allowed in the domain layer.
library;

import 'dart:math';

import 'logic/grader.dart';
import 'models/difficulty.dart';
import 'models/puzzle_entry.dart';
import 'solver.dart';
import 'sudoku_constants.dart';

/// Creates puzzles for a difficulty configuration.
class PuzzleGenerator {
  const PuzzleGenerator._();

  /// Removes cells from [solution] while the puzzle keeps exactly one
  /// solution, until [targetGivens] remain or no more cells can be removed.
  ///
  /// With [symmetric] the 180° rotational partner of a cell is removed at the
  /// same time, which keeps the puzzle visually balanced.
  static List<int> dig(
    List<int> solution,
    int targetGivens,
    Random rng, {
    bool symmetric = true,
  }) {
    final puzzle = List<int>.of(solution);
    final order = List<int>.generate(kCellCount, (i) => i)..shuffle(rng);
    var givens = kCellCount;

    for (final i in order) {
      if (givens <= targetGivens) break;
      if (puzzle[i] == 0) continue;

      final j = symmetric ? kCellCount - 1 - i : i;
      final cells = <int>{i, if (symmetric) j}.toList();
      final saved = {for (final c in cells) c: puzzle[c]};

      for (final c in cells) {
        puzzle[c] = 0;
      }

      if (SudokuSolver.countSolutions(puzzle, limit: 2) == 1) {
        givens -= saved.values.where((v) => v != 0).length;
      } else {
        saved.forEach((c, v) => puzzle[c] = v); // undo
      }
    }
    return puzzle;
  }

  /// Generates one puzzle for [cfg], or null if all attempts fail.
  ///
  /// A puzzle is only accepted when it is uniquely solvable, has its givens
  /// inside the configured range and is graded exactly at the tier of [cfg].
  static PuzzleEntry? generate(
    DifficultyConfig cfg,
    Random rng, {
    int id = 0,
    int maxAttempts = 500,
  }) {
    final grader = Grader.standard();
    if (!_tierIsReachable(cfg.tier, grader)) return null;

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final solution = SudokuSolver.solve(List.filled(kCellCount, 0), rng: rng)!;
      final target =
          cfg.minGivens + rng.nextInt(cfg.maxGivens - cfg.minGivens + 1);
      final puzzle = dig(solution, target, rng);

      final givens = puzzle.where((v) => v != 0).length;
      if (givens < cfg.minGivens || givens > cfg.maxGivens) continue;

      final grade = grader.grade(puzzle);
      if (grade.tier != cfg.tier) continue;

      return PuzzleEntry(
        id: id,
        difficulty: cfg.id,
        puzzle: puzzle,
        solution: solution,
        givens: givens,
        score: grade.score,
      );
    }
    return null;
  }

  /// True when [grader] is able to produce the requested tier.
  ///
  /// Tier 4 means "stuck after tiers 1–3", so it needs the tier 3 techniques.
  static bool _tierIsReachable(int tier, Grader grader) {
    if (tier <= 3) return tier <= grader.maxTier;
    return grader.maxTier >= 3;
  }
}
