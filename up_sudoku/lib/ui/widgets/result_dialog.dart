/// The win dialog shown when a puzzle is solved.
library;

import 'package:flutter/material.dart';

import 'game_timer.dart';

/// Shows the result of a solved puzzle.
///
/// Stars and the score arrive with phase 6.
class ResultDialog extends StatelessWidget {
  const ResultDialog({
    super.key,
    required this.difficultyLabel,
    required this.seconds,
    required this.mistakes,
    required this.onNext,
    required this.onHome,
  });

  /// Name of the difficulty that was played.
  final String difficultyLabel;

  /// Time it took to solve the puzzle.
  final int seconds;

  /// Number of wrong digits entered.
  final int mistakes;

  /// Called when the player wants another puzzle.
  final VoidCallback onNext;

  /// Called when the player wants to go back to the home screen.
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Puzzle solved!'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$difficultyLabel · ${GameTimer.format(seconds)}'),
          const SizedBox(height: 8),
          Text(
            mistakes == 0
                ? 'Flawless — no mistakes.'
                : 'Mistakes: $mistakes',
          ),
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
