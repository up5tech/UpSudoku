/// Grades a puzzle by replaying human-style solving steps.
///
/// Pure Dart — no Flutter imports allowed in the domain layer.
library;

import 'logic_state.dart';
import 'logic_step.dart';
import 'singles.dart';
import 'technique.dart';

/// The outcome of grading a puzzle.
class GradeResult {
  /// Hardest tier that was needed (1..3). Tier 4 means "stuck".
  final int tier;

  /// False when the grader could not finish the puzzle.
  final bool solvedLogically;

  /// How often each technique was used.
  final Map<Technique, int> usage;

  /// Weighted sum of the technique usage.
  final int score;

  const GradeResult(this.tier, this.solvedLogically, this.usage, this.score);

  /// The number of steps that were applied.
  int get steps => usage.values.fold(0, (a, b) => a + b);
}

/// Applies techniques, simplest first, until the puzzle is solved or the
/// grader gets stuck.
class Grader {
  /// The techniques to try, in order.
  final List<SolveTechnique> techniques;

  Grader(this.techniques);

  /// The standard grader: tier 1 techniques only for now.
  ///
  /// Tiers 2 and 3 are added in PLAN.md phase 5, in the frozen order of
  /// [kTechniqueOrder]. Adding them requires re-grading the whole pool.
  factory Grader.standard() => Grader(buildStandardTechniques());

  /// The highest tier any technique of this grader implements.
  int get maxTier => techniques.isEmpty
      ? 0
      : techniques.map((t) => t.tier).reduce((a, b) => a > b ? a : b);

  /// Grades [puzzle].
  GradeResult grade(List<int> puzzle) {
    final s = LogicState.fromPuzzle(puzzle);
    final usage = <Technique, int>{};
    var maxTier = 1;
    var score = 0;

    while (!s.solved) {
      LogicStep? step;
      SolveTechnique? used;
      for (final t in techniques) {
        step = t.find(s);
        if (step != null) {
          used = t;
          break;
        }
      }
      if (step == null || used == null) {
        // Stuck: needs something beyond the implemented techniques.
        return GradeResult(4, false, usage, score);
      }
      step.applyTo(s);
      if (s.hasContradiction) {
        // Should never happen for a valid puzzle: indicates a technique bug.
        throw StateError(
          'Contradiction while grading — check technique ${used.id}',
        );
      }
      usage[used.id] = (usage[used.id] ?? 0) + 1;
      if (used.tier > maxTier) maxTier = used.tier;
      score += kTechniqueWeight[used.id]!;
    }
    return GradeResult(maxTier, true, usage, score);
  }

  /// True when the puzzle can be finished with the implemented techniques.
  bool solvesLogically(List<int> puzzle) => grade(puzzle).solvedLogically;

  /// The next step a human could take from the player's current board
  /// (used by hints). Returns null when stuck.
  LogicStep? nextStep(List<int> values) {
    final s = LogicState.fromPuzzle(values);
    for (final t in techniques) {
      final step = t.find(s);
      if (step != null) return step;
    }
    return null;
  }
}

/// Builds the standard technique list, respecting the frozen order of
/// [kTechniqueOrder].
///
/// Only implemented techniques are included; the tiers 2 and 3 techniques are
/// added in PLAN.md phase 5 and require re-grading the whole pool.
List<SolveTechnique> buildStandardTechniques() {
  final registry = <Technique, SolveTechnique Function()>{
    Technique.nakedSingle: NakedSingle.new,
    Technique.hiddenSingle: HiddenSingle.new,
  };

  return [
    for (final technique in kTechniqueOrder)
      if (registry.containsKey(technique)) registry[technique]!(),
  ];
}
