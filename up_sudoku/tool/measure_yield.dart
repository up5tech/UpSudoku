/// Measures the real yield of `PuzzleGenerator.generate()` and reports the
/// pool distribution per difficulty (PLAN.md §22.2).
///
/// Usage:
///   dart run tool/measure_yield.dart [samples] [seed] [attemptsPerSample]
///
/// One sample is one puzzle request: `generate()` is called with
/// `maxAttempts: 1` until it returns a puzzle or the sample's attempt budget
/// is spent. That measures what the game's tooling actually gets, including
/// the re-grading the generator does while digging. Keep the budget generous
/// (the default) so `puzzles` reflects the generator, not the budget.
///
/// Reported per difficulty:
///   puzzles  — samples that produced a puzzle, and the percentage
///   attempts — generate() attempts per produced puzzle
///   ms/puzzle — wall-clock time per produced puzzle
///   givens / score — distribution of the accepted puzzles
///   T1..T4   — tier distribution of the accepted puzzles (must match)
///   techniques — technique usage accumulated over the accepted puzzles
library;

import 'dart:io';
import 'dart:math';

import 'package:up_sudoku/domain/generator.dart';
import 'package:up_sudoku/domain/logic/grader.dart';
import 'package:up_sudoku/domain/logic/technique.dart';
import 'package:up_sudoku/domain/models/difficulty.dart';

void main(List<String> args) {
  final samples = args.isNotEmpty ? int.parse(args[0]) : 30;
  final seed = args.length > 1 ? int.parse(args[1]) : 42;
  final attemptsPerSample = args.length > 2 ? int.parse(args[2]) : 200;

  final grader = Grader.standard();

  for (final difficulty in Difficulty.values) {
    final cfg = kDifficulties[difficulty]!;
    final rng = Random(seed + difficulty.index);

    final tierCount = <int, int>{1: 0, 2: 0, 3: 0, 4: 0};
    final usage = <Technique, int>{};
    final givens = <int>[];
    final scores = <int>[];
    var accepted = 0;
    var attempts = 0;

    final watch = Stopwatch()..start();
    for (var n = 0; n < samples; n++) {
      for (var attempt = 0; attempt < attemptsPerSample; attempt++) {
        attempts++;
        final entry = PuzzleGenerator.generate(
          cfg,
          rng,
          id: accepted + 1,
          maxAttempts: 1,
        );
        if (entry == null) continue;

        accepted++;
        givens.add(entry.givens);
        scores.add(entry.score);

        // The stored score comes from the generator's own grade; re-grading
        // here also checks that the accepted puzzle really has the tier of
        // its difficulty.
        final grade = grader.grade(entry.puzzle);
        tierCount[grade.tier] = (tierCount[grade.tier] ?? 0) + 1;
        grade.usage.forEach((t, c) => usage[t] = (usage[t] ?? 0) + c);
        break;
      }
    }
    watch.stop();

    final tiers = [
      for (var t = 1; t <= 4; t++)
        'T$t=${(tierCount[t]! * 100 / max(accepted, 1)).toStringAsFixed(1)}%',
    ].join(' ');
    final perPuzzle = accepted == 0
        ? '-'
        : (attempts / accepted).toStringAsFixed(1);
    final msPerPuzzle = accepted == 0
        ? '-'
        : (watch.elapsedMilliseconds / accepted).toStringAsFixed(1);

    stdout.writeln(
      '${difficulty.key.padRight(10)} '
      'puzzles=$accepted/$samples '
      '(${(accepted * 100 / samples).toStringAsFixed(1)}%)  '
      'attempts/puzzle=$perPuzzle  '
      'ms/puzzle=$msPerPuzzle  '
      'givens=${_summary(givens)}  score=${_summary(scores)}  '
      '$tiers',
    );

    if (usage.isNotEmpty) {
      final top = usage.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      stdout.writeln(
        '           techniques: '
        '${top.map((e) => '${e.key.name}x${e.value}').join(', ')}',
      );
    }
  }
}

/// "min..max (median n)" for a list, or "-" when empty.
String _summary(List<int> values) {
  if (values.isEmpty) return '-';
  final sorted = List<int>.of(values)..sort();
  return '${sorted.first}..${sorted.last} '
      '(median ${sorted[sorted.length ~/ 2]})';
}
