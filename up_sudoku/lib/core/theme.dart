import 'package:flutter/material.dart';

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
