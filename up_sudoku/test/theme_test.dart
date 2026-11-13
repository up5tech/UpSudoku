import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:up_sudoku/core/theme.dart';
import 'package:up_sudoku/domain/models/difficulty.dart';

/// WCAG relative luminance.
double _luminance(Color color) {
  double channel(double value) =>
      value <= 0.03928 ? value / 12.92 : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final lighter = math.max(la, lb);
  final darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  // The board background the painter draws behind the player's digits.
  const darkBoard = Color(0xFF1E2430);

  test('dark accents are readable on the dark board', () {
    for (final difficulty in Difficulty.values) {
      final accent = accentColorFor(difficulty, brightness: Brightness.dark);
      expect(
        _contrast(accent, darkBoard),
        greaterThanOrEqualTo(4.5),
        reason: difficulty.name,
      );
    }
  });

  test('light accents are readable on the white board', () {
    for (final difficulty in Difficulty.values) {
      expect(
        _contrast(accentColorFor(difficulty), Colors.white),
        greaterThanOrEqualTo(3.0),
        reason: difficulty.name,
      );
    }
  });

  test('the dark theme uses its own, lighter palette', () {
    for (final difficulty in Difficulty.values) {
      final dark = accentColorFor(difficulty, brightness: Brightness.dark);
      expect(dark, isNot(accentColorFor(difficulty)), reason: difficulty.name);
      expect(
        _luminance(dark),
        greaterThan(_luminance(accentColorFor(difficulty))),
        reason: difficulty.name,
      );
    }
  });
}
