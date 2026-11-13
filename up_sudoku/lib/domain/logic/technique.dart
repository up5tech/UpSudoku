/// Technique identifiers, tiers, weights and the frozen application order.
///
/// Pure Dart — no Flutter imports allowed in the domain layer.
library;

import 'logic_state.dart';
import 'logic_step.dart';

/// Every logic technique the game knows about.
///
/// Techniques are added tier by tier; the enum itself is stable so puzzle
/// pools keep their meaning.
enum Technique {
  nakedSingle,
  hiddenSingle,
  nakedPair,
  hiddenPair,
  nakedTriple,
  hiddenTriple,
  pointing,
  boxLine,
  nakedQuad,
  hiddenQuad,
  xWing,
  swordfish,
  xyWing,
  xyzWing,
}

/// The tier a technique belongs to (1 = singles, 2 = subsets/intersections,
/// 3 = fish/wings). Tier 4 is reserved for "stuck" puzzles.
const Map<Technique, int> kTechniqueTier = {
  Technique.nakedSingle: 1,
  Technique.hiddenSingle: 1,
  Technique.nakedPair: 2,
  Technique.hiddenPair: 2,
  Technique.nakedTriple: 2,
  Technique.hiddenTriple: 2,
  Technique.pointing: 2,
  Technique.boxLine: 2,
  Technique.nakedQuad: 3,
  Technique.hiddenQuad: 3,
  Technique.xWing: 3,
  Technique.swordfish: 3,
  Technique.xyWing: 3,
  Technique.xyzWing: 3,
};

/// Human readable technique names, used by hints.
const Map<Technique, String> kTechniqueName = {
  Technique.nakedSingle: 'Naked Single',
  Technique.hiddenSingle: 'Hidden Single',
  Technique.nakedPair: 'Naked Pair',
  Technique.hiddenPair: 'Hidden Pair',
  Technique.nakedTriple: 'Naked Triple',
  Technique.hiddenTriple: 'Hidden Triple',
  Technique.pointing: 'Pointing Pair/Triple',
  Technique.boxLine: 'Box/Line Reduction',
  Technique.nakedQuad: 'Naked Quad',
  Technique.hiddenQuad: 'Hidden Quad',
  Technique.xWing: 'X-Wing',
  Technique.swordfish: 'Swordfish',
  Technique.xyWing: 'XY-Wing',
  Technique.xyzWing: 'XYZ-Wing',
};

/// Weighted usage of a technique — the raw material of the `score` field.
///
/// Diagnostic / ordering only: the score never decides the difficulty level.
const Map<Technique, int> kTechniqueWeight = {
  Technique.nakedSingle: 1,
  Technique.hiddenSingle: 2,
  Technique.pointing: 8,
  Technique.boxLine: 10,
  Technique.nakedPair: 12,
  Technique.hiddenPair: 14,
  Technique.nakedTriple: 20,
  Technique.hiddenTriple: 24,
  Technique.xWing: 40,
  Technique.xyWing: 45,
  Technique.xyzWing: 50,
  Technique.swordfish: 60,
  Technique.nakedQuad: 70,
  Technique.hiddenQuad: 80,
};

/// The frozen order techniques are tried in: simplest first.
///
/// Changing this order changes the recorded tier of every puzzle, so it
/// requires re-grading the whole pool (PLAN.md §11.4).
const List<Technique> kTechniqueOrder = [
  Technique.nakedSingle,
  Technique.hiddenSingle,
  Technique.pointing,
  Technique.boxLine,
  Technique.nakedPair,
  Technique.hiddenPair,
  Technique.nakedTriple,
  Technique.hiddenTriple,
  Technique.xWing,
  Technique.xyWing,
  Technique.xyzWing,
  Technique.swordfish,
  Technique.nakedQuad,
  Technique.hiddenQuad,
];

/// A technique proposes one step; it never mutates the state itself.
abstract class SolveTechnique {
  /// Which technique this is.
  Technique get id;

  /// Difficulty tier (1..3).
  int get tier;

  /// The first applicable step for [s], or null when the technique does not
  /// apply to the current state.
  LogicStep? find(LogicState s);
}
