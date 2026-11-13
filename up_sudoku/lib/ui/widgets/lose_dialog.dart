/// The dialog shown when the player runs out of mistakes.
library;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(l10n.outOfMistakes),
      content: Text(l10n.outOfMistakesBody(mistakeLimit)),
      actions: [
        TextButton(onPressed: onHome, child: Text(l10n.home)),
        FilledButton(onPressed: onRetry, child: Text(l10n.newPuzzle)),
      ],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      backgroundColor: theme.colorScheme.surface,
    );
  }
}
