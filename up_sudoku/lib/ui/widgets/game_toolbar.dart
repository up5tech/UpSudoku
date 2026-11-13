/// The game toolbar below the board.
library;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Actions on the board: undo/redo, erase, notes, hint, check and the
/// auto-fill helper. Items that do not apply to a difficulty are hidden.
class GameToolbar extends StatelessWidget {
  const GameToolbar({
    super.key,
    required this.onErase,
    required this.onUndo,
    required this.onRedo,
    required this.onToggleNotes,
    this.onHint,
    this.onCheck,
    this.onFillNotes,
    this.canUndo = false,
    this.canRedo = false,
    this.notesMode = false,
    this.hintsLeft = 0,
    this.checksLeft = 0,
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

  /// Called when the player asks for a hint; null hides the button.
  final VoidCallback? onHint;

  /// Called when the player checks the board; null hides the button.
  final VoidCallback? onCheck;

  /// Called by the "Auto notes" helper; null hides the button.
  final VoidCallback? onFillNotes;

  /// Whether there is an action to undo.
  final bool canUndo;

  /// Whether there is an action to redo.
  final bool canRedo;

  /// Whether the number pad currently edits notes.
  final bool notesMode;

  /// Hints left, shown on the hint button.
  final int hintsLeft;

  /// Checks left, shown on the check button.
  final int checksLeft;

  /// Whether the actions are available.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Wrap(
      alignment: WrapAlignment.spaceEvenly,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _ToolbarButton(
          icon: Icons.undo,
          label: l10n.undo,
          onPressed: enabled && canUndo ? onUndo : null,
        ),
        _ToolbarButton(
          icon: Icons.redo,
          label: l10n.redo,
          onPressed: enabled && canRedo ? onRedo : null,
        ),
        _ToolbarButton(
          icon: Icons.backspace_outlined,
          label: l10n.erase,
          onPressed: enabled ? onErase : null,
        ),
        _ToolbarButton(
          icon: Icons.edit_note,
          label: l10n.notes,
          active: notesMode,
          onPressed: enabled ? onToggleNotes : null,
        ),
        if (onHint != null)
          _ToolbarButton(
            icon: Icons.lightbulb_outline,
            label: l10n.hintWithCount(hintsLeft),
            onPressed: enabled ? onHint : null,
          ),
        if (onCheck != null)
          _ToolbarButton(
            icon: Icons.fact_check_outlined,
            label: l10n.checkWithCount(checksLeft),
            onPressed: enabled ? onCheck : null,
          ),
        if (onFillNotes != null)
          _ToolbarButton(
            icon: Icons.auto_awesome,
            label: l10n.autoNotes,
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
