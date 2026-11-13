/// Holds and persists the per-difficulty statistics.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/storage_service.dart';
import '../domain/models/difficulty.dart';
import '../domain/models/difficulty_stats.dart';

/// ChangeNotifier wrapper around [DifficultyStats] (PLAN.md §13.1, §19.3).
class StatsController extends ChangeNotifier {
  StatsController({required StorageService storage}) : _storage = storage {
    for (final difficulty in Difficulty.values) {
      _stats[difficulty] = storage.readStats(difficulty);
    }
  }

  final StorageService _storage;
  final Map<Difficulty, DifficultyStats> _stats = {};

  /// The statistics of [difficulty].
  DifficultyStats of(Difficulty difficulty) =>
      _stats[difficulty] ?? const DifficultyStats();

  /// Records that a game was started.
  ///
  /// [abandoned] is true when an unfinished game of the same difficulty was
  /// replaced, which resets the streak.
  void recordStarted(Difficulty difficulty, {bool abandoned = false}) {
    _save(difficulty, of(difficulty).recordStarted(abandoned: abandoned));
  }

  /// Records a win.
  void recordWon(
    Difficulty difficulty, {
    required int puzzleId,
    required int seconds,
    required bool flawless,
  }) {
    _save(
      difficulty,
      of(
        difficulty,
      ).recordWon(id: puzzleId, seconds: seconds, flawless: flawless),
    );
  }

  /// Records a loss.
  void recordLost(Difficulty difficulty) {
    _save(difficulty, of(difficulty).recordLost());
  }

  /// Clears every counter (used by "Reset data").
  void reset() {
    for (final difficulty in Difficulty.values) {
      _save(difficulty, const DifficultyStats());
    }
  }

  void _save(Difficulty difficulty, DifficultyStats stats) {
    _stats[difficulty] = stats;
    unawaited(_storage.writeStats(difficulty, stats));
    notifyListeners();
  }
}
