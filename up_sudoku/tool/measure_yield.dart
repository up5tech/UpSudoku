/// Measures the acceptance rate of the generator per difficulty.
///
/// Usage:
///   dart run tool/measure_yield.dart [samples] [seed]
///
/// For every sample a random full grid is dug down to a random target givens
/// count and graded; the report shows how often the puzzle is accepted for
/// the target difficulty.
library;

import 'dart:io';
import 'dart:math';

import 'package:up_sudoku/domain/generator.dart';
import 'package:up_sudoku/domain/logic/grader.dart';
import 'package:up_sudoku/domain/models/difficulty.dart';
import 'package:up_sudoku/domain/solver.dart';
import 'package:up_sudoku/domain/sudoku_constants.dart';

void main(List<String> args) {
  final samples = args.isNotEmpty ? int.parse(args[0]) : 100;
  final seed = args.length > 1 ? int.parse(args[1]) : 42;

  for (final difficulty in Difficulty.values) {
    final cfg = kDifficulties[difficulty]!;
    final rng = Random(seed);
    final grader = Grader.standard();

    var accepted = 0;
    var stuck = 0;
    var outOfRange = 0;
    final givens = <int>[];

    final watch = Stopwatch()..start();
    for (var n = 0; n < samples; n++) {
      final solution = SudokuSolver.solve(List.filled(kCellCount, 0), rng: rng)!;
      final target =
          cfg.minGivens + rng.nextInt(cfg.maxGivens - cfg.minGivens + 1);
      final puzzle = PuzzleGenerator.dig(solution, target, rng);
      final g = puzzle.where((v) => v != 0).length;
      givens.add(g);

      if (g < cfg.minGivens || g > cfg.maxGivens) {
        outOfRange++;
        continue;
      }
      final grade = grader.grade(puzzle);
      if (grade.solvedLogically) {
        // Solved by the implemented techniques (tier 1 for now).
        accepted++;
      } else {
        // The grader got stuck: the puzzle needs techniques we do not have
        // yet (tiers 2/3), so it can only be tier 4 once those exist.
        stuck++;
      }
    }
    watch.stop();

    givens.sort();
    final median = givens.isEmpty ? 0 : givens[givens.length ~/ 2];
    stdout.writeln(
      '${difficulty.key.padRight(10)} '
      'solvedBySingles=${(accepted * 100 / samples).toStringAsFixed(1)}%  '
      'stuck=${(stuck * 100 / samples).toStringAsFixed(1)}%  '
      'outOfRange=${(outOfRange * 100 / samples).toStringAsFixed(1)}%  '
      'givens=${givens.isEmpty ? '-' : '${givens.first}..${givens.last} (median $median)'}  '
      'grader maxTier=${grader.maxTier}  '
      '${watch.elapsedMilliseconds}ms',
    );
  }
}
