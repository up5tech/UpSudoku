/// Loads the bundled puzzle pools and hands out puzzles.
library;

import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;

import '../domain/models/difficulty.dart';
import '../domain/models/puzzle_entry.dart';

/// Read-only access to the bundled puzzle pools.
class PuzzleRepository {
  final Map<Difficulty, List<PuzzleEntry>> _pools = {};

  /// True once [load] has finished.
  bool get isLoaded => _loaded;
  bool _loaded = false;

  /// Loads every bundled pool. Pools that are not bundled yet are skipped.
  Future<void> load() async {
    for (final difficulty in Difficulty.values) {
      try {
        final raw = await rootBundle.loadString(
          'assets/puzzles/${difficulty.key}.json',
        );
        final json = jsonDecode(raw) as Map<String, dynamic>;
        final puzzles = (json['puzzles'] as List).cast<Map<String, dynamic>>();
        _pools[difficulty] = [
          for (final p in puzzles) PuzzleEntry.fromJson(p, difficulty),
        ];
      } catch (_) {
        // No pool bundled for this difficulty yet — skip it.
        continue;
      }
    }
    _loaded = true;
  }

  /// The puzzles of [difficulty] (empty when the pool is not bundled).
  List<PuzzleEntry> pool(Difficulty difficulty) =>
      _pools[difficulty] ?? const <PuzzleEntry>[];

  /// Number of bundled puzzles for [difficulty].
  int poolSize(Difficulty difficulty) => pool(difficulty).length;

  /// True when [difficulty] has at least one bundled puzzle.
  bool hasPool(Difficulty difficulty) => poolSize(difficulty) > 0;

  /// The puzzle with [id] in the pool of [difficulty].
  PuzzleEntry byId(Difficulty difficulty, int id) => pool(
    difficulty,
  ).firstWhere((p) => p.id == id);

  /// A random puzzle of [difficulty] that is not in [completed].
  ///
  /// Falls back to any puzzle when all of them have been completed.
  PuzzleEntry pick(Difficulty difficulty, Set<int> completed, Random rng) {
    final pool = this.pool(difficulty);
    if (pool.isEmpty) {
      throw StateError('No puzzle pool for ${difficulty.key}');
    }
    final fresh = pool.where((p) => !completed.contains(p.id)).toList();
    final source = fresh.isNotEmpty ? fresh : pool;
    return source[rng.nextInt(source.length)];
  }
}
