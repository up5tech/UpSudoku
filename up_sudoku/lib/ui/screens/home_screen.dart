/// The home screen with the difficulty cards.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../data/puzzle_repository.dart';
import '../../domain/models/difficulty.dart';
import 'game_screen.dart';

/// Entry screen of the app.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = context.read<PuzzleRepository>();

    return Scaffold(
      appBar: AppBar(title: const Text(kAppName)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final difficulty in Difficulty.values)
            _DifficultyCard(
              difficulty: difficulty,
              poolSize: repository.poolSize(difficulty),
              onPlay: repository.hasPool(difficulty)
                  ? () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => GameScreen(difficulty: difficulty),
                      ),
                    )
                  : null,
            ),
        ],
      ),
    );
  }
}

class _DifficultyCard extends StatelessWidget {
  const _DifficultyCard({
    required this.difficulty,
    required this.poolSize,
    required this.onPlay,
  });

  final Difficulty difficulty;
  final int poolSize;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cfg = kDifficulties[difficulty]!;
    final accent = accentColorFor(difficulty);
    final available = onPlay != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  cfg.label,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(_description(difficulty), style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _Badge(text: _feedbackBadge(cfg.feedback)),
                _Badge(text: '${cfg.hintLimit} hints'),
                if (cfg.mistakeLimit > 0)
                  _Badge(text: '${cfg.mistakeLimit} mistakes'),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  available ? '$poolSize puzzles' : 'Pool coming soon',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: onPlay,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Play'),
                  style: FilledButton.styleFrom(backgroundColor: accent),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _description(Difficulty difficulty) => switch (difficulty) {
    Difficulty.easy => 'Solved with singles — a gentle start.',
    Difficulty.medium => 'Pairs, triples and pointing — a warm-up.',
    Difficulty.hard => 'Fish and wings — real deductions needed.',
    Difficulty.veryHard => 'Chains and beyond — for the brave.',
  };

  String _feedbackBadge(FeedbackMode feedback) => switch (feedback) {
    FeedbackMode.instant => 'Instant feedback',
    FeedbackMode.conflictsOnly => 'Conflicts only',
    FeedbackMode.none => 'No live feedback',
  };
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: theme.textTheme.labelSmall),
    );
  }
}
