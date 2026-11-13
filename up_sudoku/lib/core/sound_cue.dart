/// Sound cues of the game (PLAN.md §18).
///
/// Pure Dart so the controller can name a cue without depending on the audio
/// package.
library;

/// A one-shot sound effect.
enum SoundCue {
  /// A cell was selected (very short).
  tap,

  /// A digit or a note was placed.
  place,

  /// A wrong digit on a difficulty with instant feedback.
  error,

  /// A row, column or box was completed.
  unitComplete,

  /// The puzzle was solved.
  win,

  /// The mistake limit was reached.
  lose,
}
