/// Score and star rating of a finished puzzle (PLAN.md §19).
///
/// Pure Dart — no Flutter imports allowed in the domain layer.
library;

import 'models/difficulty.dart';

/// Score and stars of one completed puzzle.
class ScoreResult {
  /// Points awarded (never negative).
  final int score;

  /// 1..3 stars.
  final int stars;

  const ScoreResult(this.score, this.stars);
}

/// Turns time, mistakes and used assists into points and stars.
///
/// Every coefficient is a starting hypothesis to tune after playtests; the
/// weights live here only.
class ScoreCalculator {
  const ScoreCalculator._();

  /// Points for finishing [cfg] in [seconds].
  ///
  /// `base + timeBonus - penalty`, where the time bonus is up to half the base
  /// score and each mistake/hint/check costs a percentage of the base.
  static int score({
    required DifficultyConfig cfg,
    required int seconds,
    required int mistakes,
    required int hintsUsed,
    required int checksUsed,
  }) {
    final base = cfg.baseScore.toDouble();
    final timeFactor = (1 - seconds / cfg.parSeconds).clamp(0.0, 1.0);
    final timeBonus = base * 0.5 * timeFactor;
    final penalty =
        base * (0.05 * mistakes + 0.10 * hintsUsed + 0.05 * checksUsed);
    return (base + timeBonus - penalty).round().clamp(0, 1 << 30);
  }

  /// Stars for finishing [cfg].
  ///
  /// 3 stars: no mistakes, no hints, no checks and within par time.
  /// 2 stars: at most one assist in total and at most two mistakes.
  /// 1 star: anything else.
  static int stars({
    required DifficultyConfig cfg,
    required int seconds,
    required int mistakes,
    required int hintsUsed,
    required int checksUsed,
  }) {
    final assists = hintsUsed + checksUsed;
    if (assists == 0 && mistakes == 0 && seconds <= cfg.parSeconds) return 3;
    if (assists <= 1 && mistakes <= 2) return 2;
    return 1;
  }

  /// Score and stars together, as shown in the win dialog.
  static ScoreResult evaluate({
    required DifficultyConfig cfg,
    required int seconds,
    required int mistakes,
    required int hintsUsed,
    required int checksUsed,
  }) => ScoreResult(
    score(
      cfg: cfg,
      seconds: seconds,
      mistakes: mistakes,
      hintsUsed: hintsUsed,
      checksUsed: checksUsed,
    ),
    stars(
      cfg: cfg,
      seconds: seconds,
      mistakes: mistakes,
      hintsUsed: hintsUsed,
      checksUsed: checksUsed,
    ),
  );
}
