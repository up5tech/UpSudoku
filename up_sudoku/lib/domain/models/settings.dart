/// User settings (PLAN.md §13.1, §14.2).
///
/// Pure Dart — no Flutter imports allowed in the domain layer.
library;

/// Which theme the app uses.
enum ThemePreference { system, light, dark }

/// Which language the app uses.
///
/// [system] follows the device locale, falling back to English when the device
/// language is neither English nor Vietnamese.
enum AppLanguage { system, english, vietnamese }

/// Everything the player can change in the Settings screen.
class Settings {
  /// Whether sound effects play (used from phase 8).
  final bool sound;

  /// Whether the device vibrates on placement/errors (used from phase 8).
  final bool haptics;

  /// Light/dark/system theme.
  final ThemePreference theme;

  /// UI language (`en`/`vi`, or the device language).
  final AppLanguage language;

  /// Whether the peers of the selected cell are highlighted.
  final bool highlightPeers;

  /// Whether cells holding the same digit are highlighted.
  final bool highlightSameDigit;

  /// Whether digits and notes are drawn larger.
  final bool largeDigits;

  const Settings({
    this.sound = true,
    this.haptics = true,
    this.theme = ThemePreference.system,
    this.language = AppLanguage.system,
    this.highlightPeers = true,
    this.highlightSameDigit = true,
    this.largeDigits = false,
  });

  /// A copy with the given fields replaced.
  Settings copyWith({
    bool? sound,
    bool? haptics,
    ThemePreference? theme,
    AppLanguage? language,
    bool? highlightPeers,
    bool? highlightSameDigit,
    bool? largeDigits,
  }) => Settings(
    sound: sound ?? this.sound,
    haptics: haptics ?? this.haptics,
    theme: theme ?? this.theme,
    language: language ?? this.language,
    highlightPeers: highlightPeers ?? this.highlightPeers,
    highlightSameDigit: highlightSameDigit ?? this.highlightSameDigit,
    largeDigits: largeDigits ?? this.largeDigits,
  );

  /// JSON for `shared_preferences`.
  Map<String, dynamic> toJson() => {
    'sound': sound,
    'haptics': haptics,
    'theme': theme.name,
    'language': language.name,
    'highlightPeers': highlightPeers,
    'highlightSameDigit': highlightSameDigit,
    'largeDigits': largeDigits,
  };

  /// Reads settings, falling back to the defaults for missing/invalid values.
  factory Settings.fromJson(Map<String, dynamic> json) {
    final themeName = json['theme'];
    final languageName = json['language'];
    return Settings(
      sound: _bool(json, 'sound', true),
      haptics: _bool(json, 'haptics', true),
      theme: ThemePreference.values.firstWhere(
        (t) => t.name == themeName,
        orElse: () => ThemePreference.system,
      ),
      language: AppLanguage.values.firstWhere(
        (l) => l.name == languageName,
        orElse: () => AppLanguage.system,
      ),
      highlightPeers: _bool(json, 'highlightPeers', true),
      highlightSameDigit: _bool(json, 'highlightSameDigit', true),
      largeDigits: _bool(json, 'largeDigits', false),
    );
  }
}

bool _bool(Map<String, dynamic> json, String key, bool fallback) {
  final value = json[key];
  return value is bool ? value : fallback;
}
