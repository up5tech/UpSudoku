/// Generates the bundled puzzle pool for one difficulty.
///
/// Usage:
///   dart run tool/generate_puzzles.dart `difficulty` `count` [seed]
///
/// Example:
///   dart run tool/generate_puzzles.dart easy 50 42
///
/// Existing puzzles are kept, so the script can be resumed.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:up_sudoku/domain/generator.dart';
import 'package:up_sudoku/domain/models/difficulty.dart';

void main(List<String> args) {
  if (args.length < 2) {
    stderr.writeln(
      'Usage: dart run tool/generate_puzzles.dart '
      '<easy|medium|hard|veryHard> <count> [seed]',
    );
    exit(2);
  }

  final difficulty = Difficulty.values.firstWhere(
    (d) => d.name == args[0] || d.key == args[0],
    orElse: () {
      stderr.writeln('Unknown difficulty: ${args[0]}');
      exit(2);
    },
  );
  final count = int.parse(args[1]);
  final seed = args.length > 2
      ? int.parse(args[2])
      : DateTime.now().millisecondsSinceEpoch;

  final cfg = kDifficulties[difficulty]!;
  final rng = Random(seed);
  final file = File('assets/puzzles/${difficulty.key}.json');

  final puzzles = <Map<String, dynamic>>[];
  final seen = <String>{};

  if (file.existsSync()) {
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    for (final p in (json['puzzles'] as List).cast<Map<String, dynamic>>()) {
      puzzles.add(p);
      seen.add(p['p'] as String);
    }
  }

  final watch = Stopwatch()..start();
  var attempts = 0;
  while (puzzles.length < count) {
    attempts++;
    final entry = PuzzleGenerator.generate(
      cfg,
      rng,
      id: puzzles.length + 1,
      maxAttempts: 50,
    );
    if (entry == null) continue;
    final key = entry.puzzle.join();
    if (!seen.add(key)) continue; // skip duplicates
    puzzles.add(entry.toJson());
    stdout.writeln(
      '${difficulty.key} ${puzzles.length}/$count  '
      'givens=${entry.givens}  score=${entry.score}',
    );
  }

  file.parent.createSync(recursive: true);
  file.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'version': 1,
      'difficulty': difficulty.key,
      'puzzles': puzzles,
    }),
  );
  stdout.writeln(
    'Done in ${watch.elapsed} — ${puzzles.length} puzzles, '
    '$attempts generate() calls.',
  );
}
