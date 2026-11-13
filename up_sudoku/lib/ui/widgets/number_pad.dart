/// The 1–9 digit pad with the remaining counts.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// A digit button showing how often the digit is still missing.
class NumberPad extends StatelessWidget {
  const NumberPad({
    super.key,
    required this.remaining,
    required this.onDigit,
    required this.accent,
    this.notesMode = false,
  });

  /// Remaining occurrences per digit (index 0 = digit 1).
  final List<int> remaining;

  /// Called with the pressed digit (1..9).
  final ValueChanged<int> onDigit;

  /// Accent colour of the current difficulty.
  final Color accent;

  /// Whether the pad currently writes notes instead of placing digits.
  final bool notesMode;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 6.0;
        final width = (constraints.maxWidth - spacing * 2) / 3;
        // A tall column (a tablet's control panel) would stretch the buttons
        // into letterboxes; keep them close to square and centre the pad.
        final padHeight = math.min(constraints.maxHeight, constraints.maxWidth);
        final height = (padHeight - spacing * 2) / 3;

        return Align(
          alignment: Alignment.topCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var row = 0; row < 3; row++) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var col = 0; col < 3; col++)
                      SizedBox(
                        width: width,
                        height: height,
                        child: Padding(
                          padding: const EdgeInsets.all(spacing / 2),
                          child: _DigitButton(
                            digit: row * 3 + col + 1,
                            remaining: remaining[row * 3 + col],
                            accent: accent,
                            notesMode: notesMode,
                            onPressed: onDigit,
                          ),
                        ),
                      ),
                  ],
                ),
                if (row < 2) const SizedBox(height: spacing),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _DigitButton extends StatelessWidget {
  const _DigitButton({
    required this.digit,
    required this.remaining,
    required this.accent,
    required this.notesMode,
    required this.onPressed,
  });

  final int digit;
  final int remaining;
  final Color accent;
  final bool notesMode;
  final ValueChanged<int> onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final used = remaining <= 0;
    final color = used ? theme.disabledColor : accent;

    return Semantics(
      key: ValueKey('digit-$digit'),
      button: true,
      enabled: !used,
      label: AppLocalizations.of(
        context,
      ).digitLabel(digit, remaining, notesMode: notesMode),
      child: Material(
        color: used
            ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4)
            : notesMode
                ? theme.colorScheme.secondaryContainer
                : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: used ? null : () => onPressed(digit),
          // Scale the digit down on very short screens instead of overflowing.
          // The natural size still fits on a normal phone, so nothing changes
          // there.
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$digit',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: notesMode ? 20 : null,
                    ),
                  ),
                  Text(
                    '$remaining',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
