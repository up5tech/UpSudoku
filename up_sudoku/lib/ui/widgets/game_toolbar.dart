/// The game toolbar below the board.
library;

import 'package:flutter/material.dart';

/// Actions on the board: undo/redo, erase, notes and the auto-fill helper.
///
/// Hint and check buttons arrive with phase 6.
class GameToolbar extends StatelessWidget {
  const GameToolbar({
    super.key,
    required this.onErase,
    required this.onUndo,
    required this.onRedo,
    required this.onToggleNotes,
    this.onFillNotes,
    this.canUndo = false,
    this.canRedo = false,
    this.notesMode = false,
    this.enabled = true,
  });

  /// Called when the player erases the selected cell.
  final VoidCallback onErase;

  /// Called when the player undoes the last action.
  final VoidCallback onUndo;

  /// Called when the player redoes the last undone action.
  final VoidCallback onRedo;

  /// Called when notes mode is toggled.
  final VoidCallback onToggleNotes;

  /// Called by the "Auto notes" helper; null hides the button.
  final VoidCallback? onFillNotes;

  /// Whether there is an action to undo.
  final bool canUndo;

  /// Whether there is an action to redo.
  final bool canRedo;

  /// Whether the number pad currently edits notes.
  final bool notesMode;

  /// Whether the actions are available.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ToolbarButton(
          icon: Icons.undo,
          label: 'Undo',
          onPressed: enabled && canUndo ? onUndo : null,
        ),
        _ToolbarButton(
          icon: Icons.redo,
          label: 'Redo',
          onPressed: enabled && canRedo ? onRedo : null,
        ),
        _ToolbarButton(
          icon: Icons.backspace_outlined,
          label: 'Erase',
          onPressed: enabled ? onErase : null,
        ),
        _ToolbarButton(
          icon: Icons.edit_note,
          label: 'Notes',
          active: notesMode,
          onPressed: enabled ? onToggleNotes : null,
        ),
        if (onFillNotes != null)
          _ToolbarButton(
            icon: Icons.auto_awesome,
            label: 'Auto notes',
            onPressed: enabled ? onFillNotes : null,
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
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onPressed != null;
    final color = !enabled
        ? theme.disabledColor
        : active
        ? theme.colorScheme.onSecondaryContainer
        : theme.colorScheme.onSurface;

    return Semantics(
      button: true,
      enabled: enabled,
      toggled: active,
      label: label,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: active
                ? theme.colorScheme.secondaryContainer
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(height: 2),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
