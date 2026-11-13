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
    this.compact = false,
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

  /// Icons only, for landscape and large system fonts where a label row would
  /// take height away from the board. The label stays as semantics/tooltip.
  final bool compact;

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
          compact: compact,
          onPressed: enabled && canUndo ? onUndo : null,
        ),
        _ToolbarButton(
          icon: Icons.redo,
          label: l10n.redo,
          compact: compact,
          onPressed: enabled && canRedo ? onRedo : null,
        ),
        _ToolbarButton(
          icon: Icons.backspace_outlined,
          label: l10n.erase,
          compact: compact,
          onPressed: enabled ? onErase : null,
        ),
        _ToolbarButton(
          icon: Icons.edit_note,
          label: l10n.notes,
          compact: compact,
          active: notesMode,
          onPressed: enabled ? onToggleNotes : null,
        ),
        if (onHint != null)
          _ToolbarButton(
            icon: Icons.lightbulb_outline,
            label: l10n.hintWithCount(hintsLeft),
            compact: compact,
            onPressed: enabled ? onHint : null,
          ),
        if (onCheck != null)
          _ToolbarButton(
            icon: Icons.fact_check_outlined,
            label: l10n.checkWithCount(checksLeft),
            compact: compact,
            onPressed: enabled ? onCheck : null,
          ),
        if (onFillNotes != null)
          _ToolbarButton(
            icon: Icons.auto_awesome,
            label: l10n.autoNotes,
            compact: compact,
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
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool active;
  final bool compact;

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
      child: _maybeTooltip(
        InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 12 : 10,
              vertical: compact ? 8 : 6,
            ),
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
                if (!compact) ...[
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(color: color),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Without a visible label the meaning is only a long press away.
  Widget _maybeTooltip(Widget child) => compact
      ? Tooltip(
          message: label,
          excludeFromSemantics: true,
          child: child,
        )
      : child;
}
