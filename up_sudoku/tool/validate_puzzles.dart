/// Validates the bundled puzzle pools against the quality gates.
///
/// Usage:
///   dart run tool/validate_puzzles.dart [difficulty ...]
///
/// Exits with code 1 when any gate fails (PLAN.md §22.1).
library;

import 'dart:convert';
import 'dart:io';

import 'package:up_sudoku/domain/logic/grader.dart';
import 'package:up_sudoku/domain/logic/technique.dart';
import 'package:up_sudoku/domain/models/difficulty.dart';
import 'package:up_sudoku/domain/models/puzzle_entry.dart';
import 'package:up_sudoku/domain/solver.dart';
import 'package:up_sudoku/domain/sudoku_constants.dart';

void main(List<String> args) {
  final difficulties = args.isEmpty
      ? Difficulty.values
      : args
            .map(
              (a) => Difficulty.values.firstWhere(
                (d) => d.name == a || d.key == a,
                orElse: () {
                  stderr.writeln('Unknown difficulty: $a');
                  exit(2);
                },
              ),
            )
            .toList();

  var failures = 0;
  for (final difficulty in difficulties) {
    failures += _validatePool(difficulty);
  }

  if (failures > 0) {
    stderr.writeln('\n$failures check(s) failed.');
    exit(1);
  }
  stdout.writeln('\nAll pools passed every gate.');
}

int _validatePool(Difficulty difficulty) {
  final cfg = kDifficulties[difficulty]!;
  final file = File('assets/puzzles/${difficulty.key}.json');
  if (!file.existsSync()) {
    stdout.writeln('${difficulty.key}: no pool file — skipped.');
    return 0;
  }

  final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final raw = (json['puzzles'] as List).cast<Map<String, dynamic>>();
  stdout.writeln('${difficulty.key}: ${raw.length} puzzles');

  final grader = Grader.standard();
  final seen = <String>{};
  final givensList = <int>[];
  final scores = <int>[];
  final usage = <Technique, int>{};
  var failures = 0;

  for (final p in raw) {
    final entry = PuzzleEntry.fromJson(p, difficulty);
    final problems = <String>[];

    // 1. format
    final puzzleString = p['p'] as String;
    final solutionString = p['s'] as String;
    if (puzzleString.length != 81 || !RegExp(r'^[0-9]{81}$').hasMatch(puzzleString)) {
      problems.add('puzzle string is not 81 digits');
    }
    if (solutionString.length != 81 ||
        !RegExp(r'^[1-9]{81}$').hasMatch(solutionString)) {
      problems.add('solution string is not 81 digits 1-9');
    }

    // 2. solution consistent with the givens and a valid full grid
    for (var i = 0; i < 81; i++) {
      if (entry.puzzle[i] != 0 && entry.puzzle[i] != entry.solution[i]) {
        problems.add('solution does not match the givens at cell $i');
        break;
      }
    }
    for (final unit in kUnits) {
      final digits = unit.map((i) => entry.solution[i]).toSet();
      if (digits.length != 9) {
        problems.add('solution is not a valid grid');
        break;
      }
    }

    // 3. unique solution
    if (SudokuSolver.countSolutions(entry.puzzle, limit: 2) != 1) {
      problems.add('puzzle does not have exactly one solution');
    }

    // 4. tier matches
    final grade = grader.grade(entry.puzzle);
    if (grade.tier != cfg.tier) {
      problems.add('tier is ${grade.tier}, expected ${cfg.tier}');
    }

    // 5. givens in range and equal to the stored "g"
    final givens = entry.puzzle.where((v) => v != 0).length;
    if (givens < cfg.minGivens || givens > cfg.maxGivens) {
      problems.add('givens $givens outside ${cfg.minGivens}..${cfg.maxGivens}');
    }
    if (entry.givens != givens) {
      problems.add('stored g ${entry.givens} != actual givens $givens');
    }

    // 6. no duplicates
    if (!seen.add(puzzleString)) {
      problems.add('duplicate puzzle in the pool');
    }

    if (problems.isEmpty) {
      givensList.add(givens);
      scores.add(entry.score);
      grade.usage.forEach((t, c) => usage[t] = (usage[t] ?? 0) + c);
    } else {
      failures++;
      stdout.writeln('  ✗ puzzle ${entry.id}: ${problems.join('; ')}');
    }
  }

  if (givensList.isNotEmpty) {
    givensList.sort();
    scores.sort();
    stdout.writeln(
      '  givens: ${givensList.first}..${givensList.last} '
      '(median ${givensList[givensList.length ~/ 2]})  '
      'score: ${scores.first}..${scores.last} '
      '(median ${scores[scores.length ~/ 2]})',
    );
    // Distribution report (PLAN.md §22.2): which techniques the pool needs.
    final ranked = usage.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    stdout.writeln(
      '  techniques: '
      '${ranked.map((e) => '${e.key.name}x${e.value}').join(', ')}',
    );
  }
  stdout.writeln(failures == 0 ? '  ✓ all gates passed' : '  $failures puzzle(s) failed');
  return failures;
}
