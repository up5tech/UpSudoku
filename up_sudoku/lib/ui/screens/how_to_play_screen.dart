/// Rules, controls and what each difficulty asks of the player.
library;

import 'package:flutter/material.dart';

/// How-to-play screen (PLAN.md §14.2).
class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('How to play')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _Section(
            title: 'The goal',
            body:
                'Fill the 9×9 grid so every row, column and 3×3 box contains '
                'each digit from 1 to 9 exactly once. Every bundled puzzle has '
                'exactly one solution.',
          ),
          _Section(
            title: 'Controls',
            body:
                'Tap a cell to select it, then tap a digit on the pad. '
                'Notes lets the pad write candidates instead of digits. '
                'Erase clears the selected cell. Undo and Redo step through '
                'your moves, including notes removed automatically.',
          ),
          _Section(
            title: 'Notes',
            body:
                'Notes are the candidates you keep by hand. Placing a digit '
                'removes it from the notes of the cells that share a row, '
                'column or box (except on Very Hard). Auto notes fills every '
                'candidate for you on Easy and Medium.',
          ),
          _Section(
            title: 'Hints and checks',
            body:
                'A hint names the technique that applies and highlights its '
                'cells; ask for more to read the explanation, then apply it. '
                'If the board holds a wrong digit the hint points at it. On '
                'Very Hard, a puzzle can be beyond the simple techniques — the '
                'hint then offers to reveal one cell. Check board marks every '
                'wrong digit and is limited per difficulty.',
          ),
          _Section(
            title: 'Difficulties',
            body:
                'Easy: singles only, instant feedback, unlimited mistakes.\n'
                'Medium: pairs, triples and pointing; instant feedback with a '
                '5-mistake limit.\n'
                'Hard: fish and wings; only duplicate conflicts are shown, '
                '3 checks.\n'
                'Very Hard: beyond the implemented techniques; no live '
                'feedback, 1 check, 1 hint.',
          ),
          _Section(
            title: 'Scoring and stars',
            body:
                'Finishing faster than par and avoiding mistakes, hints and '
                'checks earns more points. Three stars need a flawless win '
                'within par time.',
          ),
          _Section(
            title: 'Offline',
            body:
                'Everything is bundled with the app: puzzles, fonts and '
                'sounds. No network is ever used, and your games and '
                'statistics stay on this device.',
          ),
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
