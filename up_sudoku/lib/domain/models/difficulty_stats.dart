/// Per-difficulty statistics (PLAN.md §19.3).
///
/// Pure Dart — no Flutter imports allowed in the domain layer.
library;

/// Counters kept for one difficulty.
///
/// A "started" game is one the player began; a game abandoned by starting
/// another one resets the streak (a lost game does too). Undo does not affect
/// any counter.
class DifficultyStats {
  /// Games started.
  final int started;

  /// Games won.
  final int completed;

  /// Sum of the winning times, in seconds.
  final int totalTime;

  /// Best winning time in seconds; 0 means "no win yet".
  final int bestTime;

  /// Wins with no mistakes, hints or checks.
  final int flawlessWins;

  /// Consecutive wins.
  final int currentStreak;

  /// Longest run of consecutive wins.
  final int bestStreak;

  /// Ids of the puzzles already solved.
  final List<int> completedIds;

  const DifficultyStats({
    this.started = 0,
    this.completed = 0,
    this.totalTime = 0,
    this.bestTime = 0,
    this.flawlessWins = 0,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.completedIds = const <int>[],
  });

  /// True when no game has been played yet.
  bool get isEmpty => started == 0 && completed == 0;

  /// Wins / started, 0..1.
  double get winRate => started == 0 ? 0 : completed / started;

  /// Best winning time, or null when nothing was won yet.
  int? get bestTimeOrNull => bestTime == 0 ? null : bestTime;

  /// Average winning time, or null when nothing was won yet.
  int? get averageTime =>
      completed == 0 ? null : (totalTime / completed).round();

  /// This difficulty's record after a new game was started.
  DifficultyStats recordStarted({bool abandoned = false}) => DifficultyStats(
    started: started + 1,
    completed: completed,
    totalTime: totalTime,
    bestTime: bestTime,
    flawlessWins: flawlessWins,
    currentStreak: abandoned ? 0 : currentStreak,
    bestStreak: bestStreak,
    completedIds: completedIds,
  );

  /// This difficulty's record after [id] was solved.
  DifficultyStats recordWon({
    required int id,
    required int seconds,
    required bool flawless,
  }) {
    final streak = currentStreak + 1;
    return DifficultyStats(
      started: started,
      completed: completed + 1,
      totalTime: totalTime + seconds,
      bestTime: bestTime == 0 || seconds < bestTime ? seconds : bestTime,
      flawlessWins: flawlessWins + (flawless ? 1 : 0),
      currentStreak: streak,
      bestStreak: streak > bestStreak ? streak : bestStreak,
      completedIds: completedIds.contains(id)
          ? completedIds
          : [...completedIds, id],
    );
  }

  /// This difficulty's record after a loss.
  DifficultyStats recordLost() => DifficultyStats(
    started: started,
    completed: completed,
    totalTime: totalTime,
    bestTime: bestTime,
    flawlessWins: flawlessWins,
    currentStreak: 0,
    bestStreak: bestStreak,
    completedIds: completedIds,
  );

  /// JSON for `shared_preferences`.
  Map<String, dynamic> toJson() => {
    'started': started,
    'completed': completed,
    'totalTime': totalTime,
    'bestTime': bestTime,
    'flawlessWins': flawlessWins,
    'currentStreak': currentStreak,
    'bestStreak': bestStreak,
    'completedIds': completedIds,
  };

  /// Reads a record, falling back to an empty record on corrupted data.
  factory DifficultyStats.fromJson(Map<String, dynamic> json) {
    final ids = json['completedIds'];
    return DifficultyStats(
      started: _int(json, 'started'),
      completed: _int(json, 'completed'),
      totalTime: _int(json, 'totalTime'),
      bestTime: _int(json, 'bestTime'),
      flawlessWins: _int(json, 'flawlessWins'),
      currentStreak: _int(json, 'currentStreak'),
      bestStreak: _int(json, 'bestStreak'),
      completedIds: ids is List
          ? [for (final id in ids) if (id is int) id]
          : const <int>[],
    );
  }
}

int _int(Map<String, dynamic> json, String key) {
  final value = json[key];
  return value is int && value >= 0 ? value : 0;
}
