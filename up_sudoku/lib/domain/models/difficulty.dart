/// Difficulty levels and their gameplay configuration.
///
/// Pure Dart — no Flutter imports allowed in the domain layer.
library;

/// The four difficulty levels offered by the game.
enum Difficulty {
  easy,
  medium,
  hard,
  veryHard;

  /// Lower-case wire name used in the puzzle pool JSON.
  String get key => switch (this) {
    Difficulty.easy => 'easy',
    Difficulty.medium => 'medium',
    Difficulty.hard => 'hard',
    Difficulty.veryHard => 'very_hard',
  };
}

/// How the game reacts to an incorrect digit.
enum FeedbackMode {
  /// A wrong digit (≠ solution) is flagged immediately and counts as a mistake.
  instant,

  /// Only duplicates within a row/column/box are highlighted.
  conflictsOnly,

  /// No live feedback; the player may use "Check board" a limited number of times.
  none,
}

/// Gameplay rules attached to a difficulty level.
class DifficultyConfig {
  /// The difficulty this configuration belongs to.
  final Difficulty id;

  /// Human readable name.
  final String label;

  /// Required grader tier (1..4).
  final int tier;

  /// Minimum number of givens.
  final int minGivens;

  /// Maximum number of givens.
  final int maxGivens;

  /// Feedback mode used on this difficulty.
  final FeedbackMode feedback;

  /// Number of allowed mistakes; -1 means unlimited.
  final int mistakeLimit;

  /// Number of "Check board" uses; 0 hides the button.
  final int checkLimit;

  /// Number of hints granted.
  final int hintLimit;

  /// Whether the "fill all notes" helper is offered.
  final bool allowAutoFillNotes;

  /// Whether placing a digit removes that digit from peers' notes.
  final bool autoRemoveNotes;

  /// Target completion time in seconds.
  final int parSeconds;

  /// Base score awarded for completing a puzzle.
  final int baseScore;

  const DifficultyConfig({
    required this.id,
    required this.label,
    required this.tier,
    required this.minGivens,
    required this.maxGivens,
    required this.feedback,
    required this.mistakeLimit,
    required this.checkLimit,
    required this.hintLimit,
    required this.allowAutoFillNotes,
    required this.autoRemoveNotes,
    required this.parSeconds,
    required this.baseScore,
  });
}

/// Configuration for every difficulty level.
const Map<Difficulty, DifficultyConfig> kDifficulties = {
  Difficulty.easy: DifficultyConfig(
    id: Difficulty.easy,
    label: 'Easy',
    tier: 1,
    minGivens: 38,
    maxGivens: 45,
    feedback: FeedbackMode.instant,
    mistakeLimit: -1,
    checkLimit: 0,
    hintLimit: 5,
    allowAutoFillNotes: true,
    autoRemoveNotes: true,
    parSeconds: 600,
    baseScore: 500,
  ),
  Difficulty.medium: DifficultyConfig(
    id: Difficulty.medium,
    label: 'Medium',
    tier: 2,
    minGivens: 32,
    maxGivens: 37,
    feedback: FeedbackMode.instant,
    mistakeLimit: 5,
    checkLimit: 0,
    hintLimit: 3,
    allowAutoFillNotes: true,
    autoRemoveNotes: true,
    parSeconds: 1200,
    baseScore: 1000,
  ),
  Difficulty.hard: DifficultyConfig(
    id: Difficulty.hard,
    label: 'Hard',
    tier: 3,
    minGivens: 27,
    maxGivens: 31,
    feedback: FeedbackMode.conflictsOnly,
    mistakeLimit: -1,
    checkLimit: 3,
    hintLimit: 2,
    allowAutoFillNotes: false,
    autoRemoveNotes: true,
    parSeconds: 2100,
    baseScore: 2000,
  ),
  Difficulty.veryHard: DifficultyConfig(
    id: Difficulty.veryHard,
    label: 'Very Hard',
    tier: 4,
    minGivens: 22,
    maxGivens: 26,
    feedback: FeedbackMode.none,
    mistakeLimit: -1,
    checkLimit: 1,
    hintLimit: 1,
    allowAutoFillNotes: false,
    autoRemoveNotes: false,
    parSeconds: 3600,
    baseScore: 4000,
  ),
};
