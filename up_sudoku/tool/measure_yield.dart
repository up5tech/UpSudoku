/// Measures the generator yield and reports the tier distribution per
/// difficulty (PLAN.md §22.2).
///
/// Usage:
///   dart run tool/measure_yield.dart [samples] [seed]
///
/// For every sample a random full grid is dug down to a random target givens
/// count and graded; the report shows the tier distribution, how often the
/// puzzle is accepted for the target difficulty and which techniques were
/// needed.
library;

import 'dart:io';
import 'dart:math';

import 'package:up_sudoku/domain/generator.dart';
import 'package:up_sudoku/domain/logic/grader.dart';
import 'package:up_sudoku/domain/logic/technique.dart';
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

    final tierCount = <int, int>{1: 0, 2: 0, 3: 0, 4: 0};
    final usage = <Technique, int>{};
    final scores = <int>[];
    var accepted = 0;
    var outOfRange = 0;

    final watch = Stopwatch()..start();
    for (var n = 0; n < samples; n++) {
      final solution = SudokuSolver.solve(List.filled(kCellCount, 0), rng: rng)!;
      final target = cfg.minGivens + rng.nextInt(cfg.maxGivens - cfg.minGivens + 1);
      final puzzle = PuzzleGenerator.dig(solution, target, rng);
      final givens = puzzle.where((v) => v != 0).length;

      if (givens < cfg.minGivens || givens > cfg.maxGivens) {
        outOfRange++;
        continue;
      }

      final grade = grader.grade(puzzle);
      tierCount[grade.tier] = (tierCount[grade.tier] ?? 0) + 1;
      grade.usage.forEach((t, c) => usage[t] = (usage[t] ?? 0) + c);
      if (grade.tier == cfg.tier) {
        accepted++;
        scores.add(grade.score);
      }
    }
    watch.stop();

    final tiers = [
      for (var t = 1; t <= 4; t++)
        'T$t=${((tierCount[t] ?? 0) * 100 / samples).toStringAsFixed(1)}%',
    ].join(' ');
    final top = usage.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    stdout.writeln(
      '${difficulty.key.padRight(10)} '
      'accepted=${(accepted * 100 / samples).toStringAsFixed(1)}%  '
      'outOfRange=${(outOfRange * 100 / samples).toStringAsFixed(1)}%  '
      '$tiers  ${watch.elapsedMilliseconds}ms',
    );
    stdout.writeln(
      '           techniques: '
      '${top.take(6).map((e) => '${e.key.name}x${e.value}').join(', ')}',
    );
  }
}
