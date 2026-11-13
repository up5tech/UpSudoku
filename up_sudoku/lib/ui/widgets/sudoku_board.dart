/// The interactive board: one canvas, arithmetic hit-testing.
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/game_controller.dart';
import '../../controllers/settings_controller.dart';
import '../../core/theme.dart';
import 'sudoku_painter.dart';

/// Renders the board and maps taps to cells.
class SudokuBoard extends StatelessWidget {
  const SudokuBoard({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameController>();
    final settings = context.watch<SettingsController>();
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final side = min(constraints.maxWidth, constraints.maxHeight);
        final cell = side / 9;

        return Center(
          child: SizedBox(
            width: side,
            height: side,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) {
                final col = (details.localPosition.dx / cell)
                    .floor()
                    .clamp(0, 8);
                final row = (details.localPosition.dy / cell)
                    .floor()
                    .clamp(0, 8);
                game.select(row * 9 + col);
              },
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: SudokuPainter(
                    values: List<int>.of(game.values),
                    notes: List<int>.of(game.notes),
                    given: List<bool>.of(game.given),
                    solution: game.entry.solution,
                    selected: game.selected,
                    feedback: game.cfg.feedback,
                    accent: accentColorFor(game.cfg.id),
                    flagged: Set<int>.of(game.flagged),
                    hint: game.activeHint,
                    hintCell: game.hintCell,
                    highlightPeers: settings.highlightPeers,
                    highlightSameDigit: settings.highlightSameDigit,
                    largeDigits: settings.largeDigits,
                    dark: dark,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
