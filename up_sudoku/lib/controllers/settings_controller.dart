/// Holds and persists the player's settings.
library;

import 'package:flutter/material.dart';

import '../data/storage_service.dart';
import '../domain/models/settings.dart';

/// ChangeNotifier wrapper around [Settings] (PLAN.md §13.1).
class SettingsController extends ChangeNotifier {
  SettingsController({required StorageService storage, Settings? initial})
    : _storage = storage,
      _settings = initial ?? storage.readSettings();

  final StorageService _storage;
  Settings _settings;

  /// The current settings.
  Settings get settings => _settings;

  /// Theme mode for `MaterialApp`.
  ThemeMode get themeMode => switch (_settings.theme) {
    ThemePreference.system => ThemeMode.system,
    ThemePreference.light => ThemeMode.light,
    ThemePreference.dark => ThemeMode.dark,
  };

  /// Whether sound effects are enabled.
  bool get sound => _settings.sound;

  /// Whether haptics are enabled.
  bool get haptics => _settings.haptics;

  /// Whether peers of the selected cell are highlighted.
  bool get highlightPeers => _settings.highlightPeers;

  /// Whether cells with the same digit are highlighted.
  bool get highlightSameDigit => _settings.highlightSameDigit;

  /// Whether digits and notes are drawn larger.
  bool get largeDigits => _settings.largeDigits;

  /// Replaces the settings and persists them.
  void update(Settings settings) {
    if (identical(settings, _settings)) return;
    _settings = settings;
    _storage.writeSettings(settings);
    notifyListeners();
  }

  /// Toggles sound effects.
  void setSound(bool value) => update(_settings.copyWith(sound: value));

  /// Toggles haptics.
  void setHaptics(bool value) => update(_settings.copyWith(haptics: value));

  /// Changes the theme.
  void setTheme(ThemePreference value) =>
      update(_settings.copyWith(theme: value));

  /// Toggles peer highlighting.
  void setHighlightPeers(bool value) =>
      update(_settings.copyWith(highlightPeers: value));

  /// Toggles same-digit highlighting.
  void setHighlightSameDigit(bool value) =>
      update(_settings.copyWith(highlightSameDigit: value));

  /// Toggles large digits and notes.
  void setLargeDigits(bool value) =>
      update(_settings.copyWith(largeDigits: value));

  /// Returns to the defaults (used by "Reset data").
  void reset() => update(const Settings());
}
