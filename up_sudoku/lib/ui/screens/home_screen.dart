/// The home screen: daily puzzle, difficulty cards and the menu buttons.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/game_controller.dart';
import '../../controllers/stats_controller.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../data/puzzle_repository.dart';
import '../../data/storage_service.dart';
import '../../domain/models/daily_record.dart';
import '../../domain/models/difficulty.dart';
import '../../l10n/app_localizations.dart';
import '../widgets/game_timer.dart';
import 'game_screen.dart';
import 'how_to_play_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';

/// Entry screen of the app.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = context.watch<PuzzleRepository>();
    final stats = context.watch<StatsController>();
    final storage = context.watch<StorageService>();
    final game = context.watch<GameController>();
    final l10n = AppLocalizations.of(context);

    final now = DateTime.now();
    final daily = dailyDifficulty(now);
    final dailyRecord = storage.readDaily();

    void open(
      Difficulty difficulty, {
      bool dailyGame = false,
      bool newGame = false,
    }) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => GameScreen(
            difficulty: difficulty,
            daily: dailyGame,
            forceNew: newGame,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(kAppName),
        actions: [
          IconButton(
            tooltip: l10n.statistics,
            icon: const Icon(Icons.bar_chart),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const StatsScreen()),
            ),
          ),
          IconButton(
            tooltip: l10n.howToPlay,
            icon: const Icon(Icons.help_outline),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const HowToPlayScreen()),
            ),
          ),
          IconButton(
            tooltip: l10n.settings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _DailyCard(
            difficulty: daily,
            record: dailyRecord,
            date: now,
            onPlay: repository.hasPool(daily)
                ? () => open(daily, dailyGame: true)
                : null,
          ),
          const SizedBox(height: 12),
          for (final difficulty in Difficulty.values)
            _DifficultyCard(
              difficulty: difficulty,
              poolSize: repository.poolSize(difficulty),
              bestTime: stats.of(difficulty).bestTimeOrNull,
              completed: stats.of(difficulty).completedIds.length,
              hasSaved: game.hasSaved(difficulty),
              onContinue: () => open(difficulty),
              onPlay: repository.hasPool(difficulty)
                  ? () => open(difficulty, newGame: true)
                  : null,
            ),
        ],
      ),
    );
  }
}

class _DailyCard extends StatelessWidget {
  const _DailyCard({
    required this.difficulty,
    required this.record,
    required this.date,
    required this.onPlay,
  });

  final Difficulty difficulty;
  final DailyRecord record;
  final DateTime date;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final accent = accentColorFor(difficulty);
    final done = record.isCompletedOn(date);
    final streak = record.streak > 0
        ? ' · ${l10n.dayStreak(record.streak)}'
        : '';

    return Card(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.today, color: accent),
                const SizedBox(width: 8),
                Text(
                  l10n.dailyPuzzle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (done) Icon(Icons.check_circle, color: accent, size: 20),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${l10n.difficulty(difficulty)} · '
              '${done ? l10n.dailyCompleted : l10n.dailySameEveryday}'
              '$streak',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: onPlay,
                icon: Icon(done ? Icons.replay : Icons.play_arrow),
                label: Text(done ? l10n.playDailyAgain : l10n.playDaily),
                style: FilledButton.styleFrom(backgroundColor: accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DifficultyCard extends StatelessWidget {
  const _DifficultyCard({
    required this.difficulty,
    required this.poolSize,
    required this.bestTime,
    required this.completed,
    required this.hasSaved,
    required this.onContinue,
    required this.onPlay,
  });

  final Difficulty difficulty;
  final int poolSize;
  final int? bestTime;
  final int completed;
  final bool hasSaved;
  final VoidCallback onContinue;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final cfg = kDifficulties[difficulty]!;
    final accent = accentColorFor(difficulty);

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
                  l10n.difficulty(difficulty),
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (bestTime != null)
                  Text(
                    l10n.bestTime(GameTimer.format(bestTime!)),
                    style: theme.textTheme.labelMedium,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.difficultyDescription(difficulty),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _Badge(text: l10n.feedbackBadge(cfg.feedback)),
                _Badge(text: l10n.hintsBadge(cfg.hintLimit)),
                if (cfg.mistakeLimit > 0)
                  _Badge(text: l10n.mistakesBadge(cfg.mistakeLimit)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  poolSize > 0
                      ? l10n.solvedCount(completed, poolSize)
                      : l10n.poolComingSoon,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                if (hasSaved) ...[
                  OutlinedButton(
                    onPressed: onContinue,
                    child: Text(l10n.continueGame),
                  ),
                  const SizedBox(width: 8),
                ],
                FilledButton.icon(
                  onPressed: onPlay,
                  icon: const Icon(Icons.play_arrow),
                  label: Text(l10n.play),
                  style: FilledButton.styleFrom(backgroundColor: accent),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
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
