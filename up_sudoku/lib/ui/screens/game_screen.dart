/// The screen where a puzzle is played.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../controllers/game_controller.dart';
import '../../controllers/settings_controller.dart';
import '../../core/sound_cue.dart';
import '../../core/theme.dart';
import '../../data/audio_service.dart';
import '../../domain/models/difficulty.dart';
import '../../l10n/app_localizations.dart';
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
    // The hint and notice texts come from the controller; keep them in the
    // locale the app is showing right now.
    game.l10n = AppLocalizations.of(context);
    if (identical(game, _game)) return;
    _game?.notice.removeListener(_onNotice);
    _game?.cue.removeListener(_onCue);
    _game = game;
    game.notice.addListener(_onNotice);
    game.cue.addListener(_onCue);
  }

  @override
  void dispose() {
    _game?.notice.removeListener(_onNotice);
    _game?.cue.removeListener(_onCue);
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

  /// Plays the sound and the haptic of the last board event (PLAN.md §18).
  ///
  /// The controller publishes one cue per event and this listener clears it, so
  /// a cue is played exactly once.
  void _onCue() {
    final game = _game;
    final cue = game?.cue.value;
    if (game == null || cue == null) return;
    game.cue.value = null;
    if (!mounted) return;
    context.read<AudioService>().play(cue);
    if (context.read<SettingsController>().haptics) _haptic(cue);
  }

  void _haptic(SoundCue cue) {
    switch (cue) {
      case SoundCue.tap:
        // Selection stays silent in the hand: no buzz on every tap.
        break;
      case SoundCue.place:
        unawaited(HapticFeedback.lightImpact());
        break;
      case SoundCue.error:
      case SoundCue.lose:
        unawaited(HapticFeedback.heavyImpact());
        break;
      case SoundCue.unitComplete:
      case SoundCue.win:
        unawaited(HapticFeedback.mediumImpact());
        break;
    }
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
    game.startGame(widget.difficulty, daily: widget.daily);
  }

  Future<void> _showResultDialog() async {
    final game = context.read<GameController>();
    final l10n = AppLocalizations.of(context);
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
        difficultyLabel: l10n.difficulty(game.cfg.id),
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
    final l10n = AppLocalizations.of(context);

    if (!game.hasGame) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final accent = accentColorFor(game.cfg.id, brightness: theme.brightness);
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
            Text(
              l10n.difficulty(game.cfg.id),
              style: TextStyle(color: accent),
            ),
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
            tooltip: game.status == GameStatus.paused
                ? l10n.resume
                : l10n.pause,
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
          // The pad takes about a quarter of the body height, capped at its
          // design size, so short screens give the extra room to the board
          // instead of shrinking it to a thumbnail.
          LayoutBuilder(
            builder: (context, constraints) {
              final padHeight = (constraints.maxHeight * 0.28).clamp(
                140.0,
                210.0,
              );
              return Column(
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
                      height: padHeight,
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
              );
            },
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
                      Text(
                        l10n.paused,
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: game.resume,
                        child: Text(l10n.resume),
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
    final l10n = AppLocalizations.of(context);
    final label = switch (cfg.feedback) {
      FeedbackMode.instant => cfg.mistakeLimit > 0
          ? l10n.mistakesOf(mistakes, cfg.mistakeLimit)
          : l10n.mistakesCount(mistakes),
      FeedbackMode.conflictsOnly => l10n.conflictsOnly,
      FeedbackMode.none => l10n.noLiveFeedback,
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
