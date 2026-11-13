/// Rules, controls and what each difficulty asks of the player.
library;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// How-to-play screen (PLAN.md §14.2).
class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.howToPlay)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Section(title: l10n.goalTitle, body: l10n.goalBody),
          _Section(title: l10n.controlsTitle, body: l10n.controlsBody),
          _Section(title: l10n.notesTitle, body: l10n.notesBody),
          _Section(title: l10n.hintsTitle, body: l10n.hintsBody),
          _Section(
            title: l10n.difficultiesTitle,
            body: l10n.difficultiesBody,
          ),
          _Section(title: l10n.scoringTitle, body: l10n.scoringBody),
          _Section(title: l10n.offlineTitle, body: l10n.offlineBody),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(body, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
