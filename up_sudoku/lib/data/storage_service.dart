/// Versioned `shared_preferences` access (PLAN.md §17).
///
/// Every read is wrapped in `try/catch` and returns a default, so corrupted
/// data can never crash the app.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../domain/models/daily_record.dart';
import '../domain/models/difficulty.dart';
import '../domain/models/difficulty_stats.dart';
import '../domain/models/saved_game.dart';
import '../domain/models/settings.dart';

/// Reads and writes the game's local state.
class StorageService {
  StorageService(this._prefs);

  /// Opens the platform preferences.
  static Future<StorageService> create() async =>
      StorageService(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;

  /// The stored settings, or the defaults.
  Settings readSettings() {
    try {
      final raw = _prefs.getString(kSettingsKey);
      if (raw == null) return const Settings();
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return const Settings();
      return Settings.fromJson(json);
    } catch (_) {
      return const Settings();
    }
  }

  /// Stores [settings].
  Future<void> writeSettings(Settings settings) =>
      _prefs.setString(kSettingsKey, jsonEncode(settings.toJson()));

  /// The stored statistics of [difficulty], or an empty record.
  DifficultyStats readStats(Difficulty difficulty) {
    try {
      final raw = _prefs.getString('$kStatsKeyPrefix${difficulty.key}');
      if (raw == null) return const DifficultyStats();
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return const DifficultyStats();
      return DifficultyStats.fromJson(json);
    } catch (_) {
      return const DifficultyStats();
    }
  }

  /// Stores the statistics of [difficulty].
  Future<void> writeStats(Difficulty difficulty, DifficultyStats stats) =>
      _prefs.setString(
        '$kStatsKeyPrefix${difficulty.key}',
        jsonEncode(stats.toJson()),
      );

  /// The saved game of [difficulty], or null when there is none.
  SavedGame? readGame(Difficulty difficulty) {
    try {
      final raw = _prefs.getString('$kGameKeyPrefix${difficulty.key}');
      if (raw == null) return null;
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      return SavedGame.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// Stores (or replaces) the saved game of [difficulty].
  Future<void> writeGame(Difficulty difficulty, SavedGame game) =>
      _prefs.setString(
        '$kGameKeyPrefix${difficulty.key}',
        jsonEncode(game.toJson()),
      );

  /// Forgets the saved game of [difficulty].
  Future<void> clearGame(Difficulty difficulty) =>
      _prefs.remove('$kGameKeyPrefix${difficulty.key}');

  /// The daily-puzzle record, or an empty one.
  DailyRecord readDaily() {
    try {
      final raw = _prefs.getString(kDailyKey);
      if (raw == null) return const DailyRecord();
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return const DailyRecord();
      return DailyRecord.fromJson(json);
    } catch (_) {
      return const DailyRecord();
    }
  }

  /// Stores the daily-puzzle record.
  Future<void> writeDaily(DailyRecord record) =>
      _prefs.setString(kDailyKey, jsonEncode(record.toJson()));

  /// Removes every key this app owns (used by "Reset data").
  Future<void> clearAll() async {
    await _prefs.remove(kSettingsKey);
    await _prefs.remove(kDailyKey);
    for (final difficulty in Difficulty.values) {
      await _prefs.remove('$kStatsKeyPrefix${difficulty.key}');
      await _prefs.remove('$kGameKeyPrefix${difficulty.key}');
    }
  }
}
