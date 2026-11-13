/// The game toolbar below the board.
library;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Exact height of the icons-only toolbar.
///
/// The compact toolbar is laid out in a fixed-height row that scrolls sideways
/// instead of wrapping or shrinking, so this is a real measurement the game
/// layout can subtract when it sizes the board pane instead of guessing at a
/// toolbar height. 48 dp also keeps every icon button a full touch target.
const double kCompactToolbarHeight = 48.0;

/// Smallest touch target of a compact toolbar button.
const double kCompactToolbarMinButton = 48.0;

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

    final buttons = <Widget>[
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
    ];

    if (compact) {
      // One row of exactly [kCompactToolbarHeight]: the game layout subtracts
      // this height when it sizes the board pane, so the bar must not wrap to a
      // second row and leave the board short of width. When the row is wider
      // than a narrow board pane it scrolls, because shrinking the buttons would
      // take them below a comfortable touch target.
      return SizedBox(
        height: kCompactToolbarHeight,
        child: _CompactBar(children: buttons),
      );
    }

    return Wrap(
      alignment: WrapAlignment.spaceEvenly,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: buttons,
    );
  }
}

/// The scrolling icons-only row, with a fade on any edge that hides actions.
///
/// A half-visible icon row reads as a layout bug; the fade says "there is more
/// this way" without adding a second row of controls.
class _CompactBar extends StatefulWidget {
  const _CompactBar({required this.children});

  final List<Widget> children;

  @override
  State<_CompactBar> createState() => _CompactBarState();
}

class _CompactBarState extends State<_CompactBar> {
  final ScrollController _controller = ScrollController();
  bool _atStart = true;
  bool _atEnd = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_syncEdges);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _syncEdges() {
    if (!mounted || !_controller.hasClients) return;
    final position = _controller.position;
    final atStart = position.pixels <= 0.5;
    final atEnd = position.pixels >= position.maxScrollExtent - 0.5;
    if (atStart == _atStart && atEnd == _atEnd) return;
    setState(() {
      _atStart = atStart;
      _atEnd = atEnd;
    });
  }

  @override
  Widget build(BuildContext context) {
    // The scroll extent is only known after layout, and it changes when the
    // pane is resized, so re-check it on every frame this bar builds.
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncEdges());
    return LayoutBuilder(
      builder: (context, constraints) {
        final overflows = widget.children.length * kCompactToolbarMinButton >
            constraints.maxWidth;
        final bar = SingleChildScrollView(
          controller: _controller,
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: widget.children,
            ),
          ),
        );
        if (!overflows) return bar;

        // The chevron gets its own slot so it never covers a button; it points
        // the way the bar still has to travel, which makes the hidden actions
        // discoverable instead of leaving a silently clipped row.
        final forward = !_atEnd;
        return Row(
          children: [
            Expanded(child: bar),
            _ScrollChevron(
              forward: forward,
              tooltip: AppLocalizations.of(context).moreActions,
              onPressed: () {
                final position = _controller.position;
                _controller.animateTo(
                  forward ? position.maxScrollExtent : 0,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                );
              },
            ),
          ],
        );
      },
    );
  }
}

/// The small button that pages the toolbar to its hidden end.
class _ScrollChevron extends StatelessWidget {
  const _ScrollChevron({
    required this.forward,
    required this.tooltip,
    required this.onPressed,
  });

  final bool forward;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          width: kCompactToolbarMinButton,
          height: kCompactToolbarHeight,
          child: Icon(
            forward ? Icons.chevron_right : Icons.chevron_left,
            size: 20,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
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
            constraints: compact
                ? const BoxConstraints(
                    minWidth: kCompactToolbarMinButton,
                    minHeight: kCompactToolbarMinButton,
                  )
                : null,
            alignment: compact ? Alignment.center : null,
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
