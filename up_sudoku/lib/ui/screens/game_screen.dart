/// The screen where a puzzle is played.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../controllers/game_controller.dart';
import '../../domain/models/difficulty.dart';
import '../widgets/game_timer.dart';
import '../widgets/game_toolbar.dart';
import '../widgets/hint_panel.dart';
import '../widgets/lose_dialog.dart';
import '../widgets/number_pad.dart';
import '../widgets/result_dialog.dart';
import '../widgets/sudoku_board.dart';

/// Plays one puzzle of [difficulty].
class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.difficulty,
    this.daily = false,
    this.forceNew = false,
  });

  /// The difficulty to play.
  final Difficulty difficulty;

  /// True when this is today's daily puzzle.
  final bool daily;

  /// True when "Play" was pressed: ignore any saved game and start fresh.
  final bool forceNew;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  bool _dialogShown = false;
  GameController? _game;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureGame());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final game = context.read<GameController>();
    if (identical(game, _game)) return;
    _game?.notice.removeListener(_onNotice);
    _game = game;
    game.notice.addListener(_onNotice);
  }

  @override
  void dispose() {
    _game?.notice.removeListener(_onNotice);
    super.dispose();
  }

  /// Shows the neutral "full but not solved" message without revealing cells.
  void _onNotice() {
    final message = _game?.notice.value;
    if (message == null || !mounted) return;
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(message)));
    _game!.notice.value = null;
  }

  /// Starts a game when the screen is entered (or continues the running one).
  void _ensureGame() {
    if (!mounted) return;
    final game = context.read<GameController>();
    final finished =
        game.hasGame &&
        (game.status == GameStatus.won || game.status == GameStatus.lost);
    if (game.hasGame && game.cfg.id == widget.difficulty && !finished) return;

    if (!widget.forceNew &&
        game.hasSaved(widget.difficulty) &&
        game.restore(widget.difficulty)) {
      return;
    }
    game.startGame(widget.difficulty, daily: widget.daily);
  }

  void _startNewPuzzle() {
    final game = context.read<GameController>();
    setState(() => _dialogShown = false);
    game.startGame(widget.difficulty);
  }

  Future<void> _showResultDialog() async {
    final game = context.read<GameController>();
    if (game.status == GameStatus.lost) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => LoseDialog(
          mistakeLimit: game.cfg.mistakeLimit,
          onRetry: () {
            Navigator.of(dialogContext).pop();
            _startNewPuzzle();
          },
          onHome: () {
            Navigator.of(dialogContext).pop();
            Navigator.of(context).pop();
          },
        ),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => ResultDialog(
        difficultyLabel: game.cfg.label,
        seconds: game.elapsedSeconds,
        mistakes: game.mistakes,
        stars: game.stars,
        score: game.score,
        hintsUsed: game.hintsUsed,
        checksUsed: game.checksUsed,
        onNext: () {
          Navigator.of(dialogContext).pop();
          _startNewPuzzle();
        },
        onHome: () {
          Navigator.of(dialogContext).pop();
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameController>();
    final theme = Theme.of(context);

    if (!game.hasGame) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final accent = accentColorFor(game.cfg.id);
    final finished =
        game.status == GameStatus.won || game.status == GameStatus.lost;

    if (finished && !_dialogShown) {
      _dialogShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showResultDialog();
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(game.cfg.label, style: TextStyle(color: accent)),
            if (game.isDaily) ...[
              const SizedBox(width: 6),
              Icon(Icons.today, size: 18, color: accent),
            ],
            const SizedBox(width: 12),
            GameTimer(elapsed: game.elapsed),
          ],
        ),
        actions: [
          IconButton(
            tooltip: game.status == GameStatus.paused ? 'Resume' : 'Pause',
            icon: Icon(
              game.status == GameStatus.paused ? Icons.play_arrow : Icons.pause,
            ),
            onPressed: () {
              if (game.status == GameStatus.paused) {
                game.resume();
              } else {
                game.pause();
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              _StatusRow(cfg: game.cfg, mistakes: game.mistakes),
              if (game.hintStage != null)
                HintPanel(
                  title: game.hintTitle,
                  explanation: game.hintExplanation,
                  stage: game.hintStage!,
                  revealsCell: game.hintRevealsCell,
                  onMore: game.showHintDetails,
                  onApply: game.applyHint,
                  onClose: game.closeHint,
                ),
              Expanded(child: const SudokuBoard()),
              GameToolbar(
                enabled: game.isPlaying,
                canUndo: game.canUndo,
                canRedo: game.canRedo,
                notesMode: game.notesMode,
                hintsLeft: game.hintsLeft,
                checksLeft: game.checksLeft,
                onUndo: game.undo,
                onRedo: game.redo,
                onErase: game.erase,
                onToggleNotes: game.toggleNotesMode,
                onHint: game.cfg.hintLimit > 0
                    ? (game.canAskHint ? game.requestHint : null)
                    : null,
                onCheck: game.cfg.checkLimit > 0
                    ? (game.canCheck ? game.checkBoard : null)
                    : null,
                onFillNotes: game.cfg.allowAutoFillNotes
                    ? game.fillAllNotes
                    : null,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: SizedBox(
                  height: 210,
                  child: NumberPad(
                    remaining: [
                      for (var d = 1; d <= 9; d++) game.remaining(d),
                    ],
                    onDigit: game.inputDigit,
                    accent: accent,
                    notesMode: game.notesMode,
                  ),
                ),
              ),
            ],
          ),
          if (game.status == GameStatus.paused)
            Positioned.fill(
              child: ColoredBox(
                color: theme.colorScheme.surface.withValues(alpha: 0.97),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.pause_circle_outline, size: 56),
                      const SizedBox(height: 12),
                      Text('Paused', style: theme.textTheme.headlineSmall),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: game.resume,
                        child: const Text('Resume'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.cfg, required this.mistakes});

  final DifficultyConfig cfg;
  final int mistakes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = switch (cfg.feedback) {
      FeedbackMode.instant => cfg.mistakeLimit > 0
          ? 'Mistakes: $mistakes / ${cfg.mistakeLimit}'
          : 'Mistakes: $mistakes',
      FeedbackMode.conflictsOnly => 'Conflicts only',
      FeedbackMode.none => 'No feedback',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
