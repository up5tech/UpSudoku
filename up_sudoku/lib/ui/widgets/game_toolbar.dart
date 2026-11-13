/// The game toolbar below the board.
library;

import 'package:flutter/material.dart';

/// Buttons acting on the board. Phase 4 adds undo/redo/notes, phase 6 adds
/// hint/check.
class GameToolbar extends StatelessWidget {
  const GameToolbar({
    super.key,
    required this.onErase,
    this.enabled = true,
  });

  /// Called when the player erases the selected cell.
  final VoidCallback onErase;

  /// Whether the actions are available.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ToolbarButton(
          icon: Icons.backspace_outlined,
          label: 'Erase',
          onPressed: enabled ? onErase : null,
        ),
      ],
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon),
          label: Text(label),
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
