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
  ///
  /// Holes are dug one at a time and the puzzle is re-graded as soon as its
  /// givens count enters the configured range; digging stops at the first
  /// puzzle that already has the required tier (PLAN.md §10.1 step 5). This
  /// is what makes Medium/Hard/Very Hard feasible: grading only after digging
  /// all the way to the minimum givens would almost always miss the tier.
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
      final dug = _digWithGrade(solution, cfg, rng, grader);
      if (dug == null) continue;

      return PuzzleEntry(
        id: id,
        difficulty: cfg.id,
        puzzle: dug.puzzle,
        solution: solution,
        givens: dug.puzzle.where((v) => v != 0).length,
        score: dug.grade.score,
      );
    }
    return null;
  }

  /// Digs holes from [solution], grading whenever the givens count is inside
  /// the range of [cfg], and returns the first puzzle of the required tier.
  static _Dug? _digWithGrade(
    List<int> solution,
    DifficultyConfig cfg,
    Random rng,
    Grader grader,
  ) {
    final puzzle = List<int>.of(solution);
    final order = List<int>.generate(kCellCount, (i) => i)..shuffle(rng);
    // Dig towards a random target inside the range so the pooled puzzles are
    // spread over the whole givens band instead of all sitting at its top.
    final target =
        cfg.minGivens + rng.nextInt(cfg.maxGivens - cfg.minGivens + 1);
    var givens = kCellCount;

    for (final i in order) {
      if (givens <= cfg.minGivens) break;
      if (puzzle[i] == 0) continue;

      final j = kCellCount - 1 - i;
      final cells = <int>{i, j};
      final saved = {for (final c in cells) c: puzzle[c]};
      for (final c in cells) {
        puzzle[c] = 0;
      }

      if (SudokuSolver.countSolutions(puzzle, limit: 2) != 1) {
        saved.forEach((c, v) => puzzle[c] = v); // undo
        continue;
      }

      givens -= saved.values.where((v) => v != 0).length;
      if (givens < cfg.minGivens) return null; // symmetric removal overshot
      if (givens > cfg.maxGivens) continue;

      final grade = grader.grade(puzzle);
      if (grade.tier == cfg.tier && givens <= target) {
        return _Dug(List<int>.of(puzzle), grade);
      }
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

/// A dug puzzle together with the grade that accepted it.
class _Dug {
  final List<int> puzzle;
  final GradeResult grade;

  const _Dug(this.puzzle, this.grade);
}
