/// The three-stage hint panel shown above the toolbar.
library;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Explains a hint and offers the next stage or the apply action.
class HintPanel extends StatelessWidget {
  const HintPanel({
    super.key,
    required this.title,
    required this.explanation,
    required this.stage,
    required this.revealsCell,
    required this.onMore,
    required this.onApply,
    required this.onClose,
  });

  /// Technique name, or the wrong-cell / fallback headline.
  final String title;

  /// Stage-2 explanation; null until the player asks for more.
  final String? explanation;

  /// Current stage (1 = pattern only, 2 = explained).
  final int stage;

  /// Whether the apply action reveals a cell instead of applying a step.
  final bool revealsCell;

  /// Called by "Show more".
  final VoidCallback onMore;

  /// Called by "Apply" / "Reveal cell".
  final VoidCallback onApply;

  /// Called when the player dismisses the hint.
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Row(
          children: [
            Icon(
              Icons.lightbulb_outline,
              color: theme.colorScheme.onSecondaryContainer,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (explanation != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        explanation!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (stage == 1)
              TextButton(onPressed: onMore, child: Text(l10n.showMore))
            else
              TextButton(
                onPressed: onApply,
                child: Text(revealsCell ? l10n.revealCell : l10n.apply),
              ),
            IconButton(
              tooltip: l10n.closeHint,
              icon: const Icon(Icons.close),
              onPressed: onClose,
            ),
          ],
        ),
      ),
    );
  }
}
