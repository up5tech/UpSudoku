/// The win dialog shown when a puzzle is solved.
library;

import 'package:flutter/material.dart';

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
    final assists = [
      if (hintsUsed > 0) 'Hints: $hintsUsed',
      if (checksUsed > 0) 'Checks: $checksUsed',
    ];

    return AlertDialog(
      title: const Text('Puzzle solved!'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '★' * stars + '☆' * (3 - stars),
            semanticsLabel: '$stars of 3 stars',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text('Score: $score'),
          Text('$difficultyLabel · ${GameTimer.format(seconds)}'),
          const SizedBox(height: 8),
          Text(
            mistakes == 0
                ? 'Flawless — no mistakes.'
                : 'Mistakes: $mistakes',
          ),
          if (assists.isNotEmpty) Text(assists.join(' · ')),
        ],
      ),
      actions: [
        TextButton(onPressed: onHome, child: const Text('Home')),
        FilledButton(onPressed: onNext, child: const Text('Next puzzle')),
      ],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      backgroundColor: theme.colorScheme.surface,
    );
  }
}
