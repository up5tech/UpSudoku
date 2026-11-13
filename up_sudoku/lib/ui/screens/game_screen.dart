/// The screen where a puzzle is played.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../controllers/game_controller.dart';
import '../../domain/models/difficulty.dart';
import '../widgets/game_timer.dart';
import '../widgets/game_toolbar.dart';
import '../widgets/number_pad.dart';
import '../widgets/result_dialog.dart';
import '../widgets/sudoku_board.dart';

/// Plays one puzzle of [difficulty].
class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.difficulty});

  /// The difficulty to play.
  final Difficulty difficulty;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  bool _dialogShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureGame());
  }

  /// Starts a game when the screen is entered (or continues the running one).
  void _ensureGame() {
    if (!mounted) return;
    final game = context.read<GameController>();
    final finished = game.hasGame && game.status == GameStatus.won;
    if (!game.hasGame || game.cfg.id != widget.difficulty || finished) {
      game.startGame(widget.difficulty);
    }
  }

  void _onNextPuzzle() {
    final game = context.read<GameController>();
    setState(() => _dialogShown = false);
    game.startGame(widget.difficulty);
  }

  Future<void> _showWinDialog() async {
    final game = context.read<GameController>();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => ResultDialog(
        difficultyLabel: game.cfg.label,
        seconds: game.elapsedSeconds,
        mistakes: game.mistakes,
        onNext: () {
          Navigator.of(dialogContext).pop();
          _onNextPuzzle();
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

    if (game.status == GameStatus.won && !_dialogShown) {
      _dialogShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showWinDialog();
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(game.cfg.label, style: TextStyle(color: accent)),
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
              _StatusRow(mistakes: game.mistakes),
              Expanded(child: const SudokuBoard()),
              GameToolbar(onErase: game.erase, enabled: game.isPlaying),
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
  const _StatusRow({required this.mistakes});

  final int mistakes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
            'Mistakes: $mistakes',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
