/// The dialog shown when the player runs out of mistakes.
library;

import 'package:flutter/material.dart';

/// Explains the loss and offers a new puzzle.
class LoseDialog extends StatelessWidget {
  const LoseDialog({
    super.key,
    required this.mistakeLimit,
    required this.onRetry,
    required this.onHome,
  });

  /// Number of mistakes the difficulty allows.
  final int mistakeLimit;

  /// Called when the player wants to try another puzzle.
  final VoidCallback onRetry;

  /// Called when the player wants to go back to the home screen.
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Out of mistakes'),
      content: Text(
        'You reached the limit of $mistakeLimit mistakes. '
        'Start a new puzzle when you are ready.',
      ),
      actions: [
        TextButton(onPressed: onHome, child: const Text('Home')),
        FilledButton(onPressed: onRetry, child: const Text('New puzzle')),
      ],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      backgroundColor: theme.colorScheme.surface,
    );
  }
}
