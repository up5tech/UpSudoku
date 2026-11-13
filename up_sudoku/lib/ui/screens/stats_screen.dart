/// Per-difficulty statistics.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/stats_controller.dart';
import '../../core/theme.dart';
import '../../domain/models/difficulty.dart';
import '../../domain/models/difficulty_stats.dart';
import '../../l10n/app_localizations.dart';
import '../widgets/game_timer.dart';

/// Shows the counters kept for every difficulty (PLAN.md §19.3).
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final stats = context.watch<StatsController>();
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.statistics)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final difficulty in Difficulty.values)
            _StatsCard(
              difficulty: difficulty,
              stats: stats.of(difficulty),
            ),
        ],
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.difficulty, required this.stats});

  final Difficulty difficulty;
  final DifficultyStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final accent = accentColorFor(difficulty, brightness: theme.brightness);

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
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.difficulty(difficulty),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  l10n.statsSolved(stats.completed),
                  style: theme.textTheme.labelMedium,
                ),
              ],
            ),
            const SizedBox(height: 10),
            _Row(label: l10n.started, value: '${stats.started}'),
            _Row(
              label: l10n.winRate,
              value: stats.started == 0
                  ? '—'
                  : '${(stats.winRate * 100).round()}%',
            ),
            _Row(
              label: l10n.bestTimeLabel,
              value: stats.bestTimeOrNull == null
                  ? '—'
                  : GameTimer.format(stats.bestTimeOrNull!),
            ),
            _Row(
              label: l10n.averageTime,
              value: stats.averageTime == null
                  ? '—'
                  : GameTimer.format(stats.averageTime!),
            ),
            _Row(label: l10n.flawlessWins, value: '${stats.flawlessWins}'),
            _Row(
              label: l10n.streak,
              value: l10n.streakValue(stats.currentStreak, stats.bestStreak),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
