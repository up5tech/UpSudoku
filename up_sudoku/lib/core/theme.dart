import 'package:flutter/material.dart';

import '../domain/models/difficulty.dart';
import 'constants.dart';

/// Seed colour for the Material 3 colour scheme.
const Color _kSeedColor = Color(0xFF3F51B5);

/// Light theme used by the app.
ThemeData buildLightTheme() => _buildTheme(Brightness.light);

/// Dark theme used by the app.
ThemeData buildDarkTheme() => _buildTheme(Brightness.dark);

ThemeData _buildTheme(Brightness brightness) {
  final ColorScheme scheme = ColorScheme.fromSeed(
    seedColor: _kSeedColor,
    brightness: brightness,
  );
  return ThemeData(
    colorScheme: scheme,
    fontFamily: kFontFamily,
    useMaterial3: true,
  );
}

/// Accent colour per difficulty (PLAN.md §14.3).
const Map<Difficulty, Color> kDifficultyAccents = {
  Difficulty.easy: Color(0xFF2E7D32),
  Difficulty.medium: Color(0xFF1565C0),
  Difficulty.hard: Color(0xFFEF6C00),
  Difficulty.veryHard: Color(0xFF6A1B9A),
};

/// The accent colour of [difficulty].
Color accentColorFor(Difficulty difficulty) =>
    kDifficultyAccents[difficulty] ?? const Color(0xFF3F51B5);
