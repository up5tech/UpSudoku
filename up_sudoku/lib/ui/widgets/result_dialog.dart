/// The win dialog shown when a puzzle is solved.
library;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'game_timer.dart';

/// Shows the result of a solved puzzle: time, stars, score and assists.
class ResultDialog extends StatelessWidget {
  const ResultDialog({
    super.key,
    required this.difficultyLabel,
    required this.seconds,
    required this.mistakes,
    required this.stars,
    required this.score,
    required this.hintsUsed,
    required this.checksUsed,
    required this.onNext,
    required this.onHome,
  });

  /// Name of the difficulty that was played.
  final String difficultyLabel;

  /// Time it took to solve the puzzle.
  final int seconds;

  /// Number of wrong digits entered.
  final int mistakes;

  /// Stars earned (1..3).
  final int stars;

  /// Points earned.
  final int score;

  /// Hints used in the game.
  final int hintsUsed;

  /// "Check board" uses in the game.
  final int checksUsed;

  /// Called when the player wants another puzzle.
  final VoidCallback onNext;

  /// Called when the player wants to go back to the home screen.
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final assists = [
      if (hintsUsed > 0) l10n.hintsUsedLine(hintsUsed),
      if (checksUsed > 0) l10n.checksUsedLine(checksUsed),
    ];

    return AlertDialog(
      title: Text(l10n.puzzleSolved),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '★' * stars + '☆' * (3 - stars),
            semanticsLabel: l10n.starsLabel(stars),
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(l10n.scoreValue(score)),
          Text('$difficultyLabel · ${GameTimer.format(seconds)}'),
          const SizedBox(height: 8),
          Text(
            mistakes == 0 ? l10n.flawlessWin : l10n.mistakesLine(mistakes),
          ),
          if (assists.isNotEmpty) Text(assists.join(' · ')),
        ],
      ),
      actions: [
        TextButton(onPressed: onHome, child: Text(l10n.home)),
        FilledButton(onPressed: onNext, child: Text(l10n.nextPuzzle)),
      ],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      backgroundColor: theme.colorScheme.surface,
    );
  }
}
