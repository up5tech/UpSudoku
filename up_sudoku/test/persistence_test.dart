import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:up_sudoku/controllers/settings_controller.dart';
import 'package:up_sudoku/controllers/stats_controller.dart';
import 'package:up_sudoku/core/constants.dart';
import 'package:up_sudoku/data/puzzle_repository.dart';
import 'package:up_sudoku/data/storage_service.dart';
import 'package:up_sudoku/domain/models/daily_record.dart';
import 'package:up_sudoku/domain/models/difficulty.dart';
import 'package:up_sudoku/domain/models/difficulty_stats.dart';
import 'package:up_sudoku/domain/models/saved_game.dart';
import 'package:up_sudoku/domain/models/settings.dart';

SavedGame _savedGame({bool daily = false}) => SavedGame(
  puzzleId: 3,
  values: List<int>.filled(81, 0)..[0] = 5,
  notes: List<int>.filled(81, 0)..[1] = 0x1FF,
  elapsedSeconds: 42,
  mistakes: 1,
  hintsLeft: 4,
  hintsUsed: 1,
  checksLeft: 0,
  checksUsed: 0,
  daily: daily,
  dailyDate: daily ? '2026-11-13' : null,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('StorageService', () {
    test('settings default to sane values and round-trip', () async {
      final storage = await StorageService.create();
      expect(storage.readSettings().sound, isTrue);
      expect(storage.readSettings().theme, ThemePreference.system);

      await storage.writeSettings(
        const Settings(
          sound: false,
          haptics: false,
          theme: ThemePreference.dark,
          highlightPeers: false,
          largeDigits: true,
        ),
      );

      final reloaded = (await StorageService.create()).readSettings();
      expect(reloaded.sound, isFalse);
      expect(reloaded.haptics, isFalse);
      expect(reloaded.theme, ThemePreference.dark);
      expect(reloaded.highlightPeers, isFalse);
      expect(reloaded.largeDigits, isTrue);
    });

    test('corrupted settings fall back to the defaults', () async {
      SharedPreferences.setMockInitialValues({kSettingsKey: '{not json'});
      final storage = await StorageService.create();
      expect(storage.readSettings().theme, ThemePreference.system);
      expect(storage.readSettings().sound, isTrue);
    });

    test('statistics round-trip per difficulty', () async {
      final storage = await StorageService.create();
      final stats = const DifficultyStats(started: 3).recordWon(
        id: 7,
        seconds: 120,
        flawless: true,
      );
      await storage.writeStats(Difficulty.hard, stats);

      final reloaded = await StorageService.create();
      final read = reloaded.readStats(Difficulty.hard);
      expect(read.started, 3);
      expect(read.completed, 1);
      expect(read.bestTime, 120);
      expect(read.completedIds, [7]);
      expect(reloaded.readStats(Difficulty.easy).completed, 0);
    });

    test('corrupted statistics fall back to an empty record', () async {
      SharedPreferences.setMockInitialValues({'stats_v1_hard': '[]'});
      final storage = await StorageService.create();
      expect(storage.readStats(Difficulty.hard).started, 0);
    });

    test('a saved game round-trips', () async {
      final storage = await StorageService.create();
      await storage.writeGame(Difficulty.easy, _savedGame(daily: true));

      final read = (await StorageService.create()).readGame(Difficulty.easy);
      expect(read, isNotNull);
      expect(read!.puzzleId, 3);
      expect(read.values[0], 5);
      expect(read.notes[1], 0x1FF);
      expect(read.elapsedSeconds, 42);
      expect(read.mistakes, 1);
      expect(read.hintsLeft, 4);
      expect(read.daily, isTrue);
      expect(read.dailyDate, '2026-11-13');
      expect(storage.readGame(Difficulty.hard), isNull);
    });

    test('an incomplete saved game is rejected', () async {
      SharedPreferences.setMockInitialValues({
        'game_v1_easy': '{"puzzleId": 1, "values": [1, 2], "notes": []}',
      });
      final storage = await StorageService.create();
      expect(storage.readGame(Difficulty.easy), isNull);
    });

    test('clearGame only forgets that difficulty', () async {
      final storage = await StorageService.create();
      await storage.writeGame(Difficulty.easy, _savedGame());
      await storage.writeGame(Difficulty.hard, _savedGame());

      await storage.clearGame(Difficulty.easy);
      expect(storage.readGame(Difficulty.easy), isNull);
      expect(storage.readGame(Difficulty.hard), isNotNull);
    });

    test('clearAll removes every key the app owns', () async {
      final storage = await StorageService.create();
      await storage.writeSettings(const Settings(sound: false));
      await storage.writeGame(Difficulty.easy, _savedGame());
      await storage.writeDaily(
        const DailyRecord(lastCompleted: '2026-11-13', streak: 2),
      );

      await storage.clearAll();

      final reloaded = await StorageService.create();
      expect(reloaded.readSettings().sound, isTrue);
      expect(reloaded.readGame(Difficulty.easy), isNull);
      expect(reloaded.readDaily().lastCompleted, isNull);
    });
  });

  group('SettingsController', () {
    test('persists a change and exposes the theme mode', () async {
      final storage = await StorageService.create();
      final controller = SettingsController(storage: storage);

      controller.setTheme(ThemePreference.dark);
      controller.setLargeDigits(true);

      expect(controller.themeMode, ThemeMode.dark);
      expect(controller.largeDigits, isTrue);

      final reloaded = SettingsController(storage: storage);
      expect(reloaded.settings.theme, ThemePreference.dark);
      expect(reloaded.largeDigits, isTrue);
    });

    test('reset returns to the defaults', () async {
      final storage = await StorageService.create();
      final controller = SettingsController(storage: storage)
        ..setSound(false)
        ..setHighlightPeers(false);

      controller.reset();

      expect(controller.sound, isTrue);
      expect(controller.highlightPeers, isTrue);
    });
  });

  group('StatsController', () {
    test('records starts, wins and losses and persists them', () async {
      final storage = await StorageService.create();
      final stats = StatsController(storage: storage);

      stats.recordStarted(Difficulty.easy);
      stats.recordWon(
        Difficulty.easy,
        puzzleId: 4,
        seconds: 90,
        flawless: true,
      );

      expect(stats.of(Difficulty.easy).completed, 1);
      expect(stats.of(Difficulty.easy).bestTime, 90);
      expect(stats.of(Difficulty.easy).flawlessWins, 1);
      expect(stats.of(Difficulty.easy).currentStreak, 1);

      await pumpEventQueue();
      final reloaded = StatsController(storage: await StorageService.create());
      expect(reloaded.of(Difficulty.easy).completed, 1);
      expect(reloaded.of(Difficulty.easy).completedIds, [4]);
    });

    test('a loss resets the streak but keeps the history', () async {
      final storage = await StorageService.create();
      final stats = StatsController(storage: storage)
        ..recordWon(Difficulty.hard, puzzleId: 1, seconds: 300, flawless: false)
        ..recordWon(Difficulty.hard, puzzleId: 2, seconds: 200, flawless: false);

      expect(stats.of(Difficulty.hard).currentStreak, 2);
      expect(stats.of(Difficulty.hard).bestStreak, 2);

      stats.recordLost(Difficulty.hard);

      expect(stats.of(Difficulty.hard).currentStreak, 0);
      expect(stats.of(Difficulty.hard).bestStreak, 2);
      expect(stats.of(Difficulty.hard).completed, 2);
    });

    test('starting over an unfinished game resets the streak', () async {
      final storage = await StorageService.create();
      final stats = StatsController(storage: storage)
        ..recordWon(Difficulty.easy, puzzleId: 1, seconds: 60, flawless: true);

      expect(stats.of(Difficulty.easy).currentStreak, 1);

      stats.recordStarted(Difficulty.easy, abandoned: true);
      expect(stats.of(Difficulty.easy).currentStreak, 0);
      expect(stats.of(Difficulty.easy).started, 1);
    });

    test('win rate and average time follow the counters', () async {
      final storage = await StorageService.create();
      final stats = StatsController(storage: storage)
        ..recordStarted(Difficulty.medium)
        ..recordStarted(Difficulty.medium)
        ..recordWon(
          Difficulty.medium,
          puzzleId: 1,
          seconds: 100,
          flawless: false,
        )
        ..recordWon(
          Difficulty.medium,
          puzzleId: 2,
          seconds: 300,
          flawless: false,
        );

      expect(stats.of(Difficulty.medium).winRate, 1.0);
      expect(stats.of(Difficulty.medium).averageTime, 200);
      expect(stats.of(Difficulty.medium).bestTime, 100);
    });
  });

  group('daily puzzle', () {
    test('the weekday mapping follows the plan', () {
      expect(dailyDifficulty(DateTime(2026, 11, 9)), Difficulty.easy); // Mon
      expect(dailyDifficulty(DateTime(2026, 11, 10)), Difficulty.easy); // Tue
      expect(
        dailyDifficulty(DateTime(2026, 11, 11)),
        Difficulty.medium,
      ); // Wed
      expect(dailyDifficulty(DateTime(2026, 11, 12)), Difficulty.hard); // Thu
      expect(dailyDifficulty(DateTime(2026, 11, 13)), Difficulty.hard); // Fri
      expect(
        dailyDifficulty(DateTime(2026, 11, 14)),
        Difficulty.veryHard,
      ); // Sat
      expect(
        dailyDifficulty(DateTime(2026, 11, 15)),
        Difficulty.veryHard,
      ); // Sun
    });

    test('the daily puzzle is deterministic for a date', () async {
      final repository = PuzzleRepository();
      await repository.load();

      final morning = repository.daily(DateTime(2026, 11, 13, 8));
      final evening = repository.daily(DateTime(2026, 11, 13, 22, 30));
      expect(morning.id, evening.id);
      expect(morning.difficulty, Difficulty.hard);

      final today = repository.daily(DateTime(2026, 11, 13));
      final tomorrow = repository.daily(DateTime(2026, 11, 14));
      expect(tomorrow.id, isNot(today.id));
      expect(tomorrow.difficulty, Difficulty.veryHard);
    });
  });

  group('DailyRecord', () {
    test('first completion starts a streak of one', () {
      final record = const DailyRecord().completedOn(DateTime(2026, 11, 13));
      expect(record.streak, 1);
      expect(record.isCompletedOn(DateTime(2026, 11, 13)), isTrue);
      expect(record.isCompletedOn(DateTime(2026, 11, 14)), isFalse);
    });

    test('consecutive days increase the streak', () {
      var record = const DailyRecord().completedOn(DateTime(2026, 11, 12));
      record = record.completedOn(DateTime(2026, 11, 13));
      record = record.completedOn(DateTime(2026, 11, 14));
      expect(record.streak, 3);
    });

    test('completing the same day twice changes nothing', () {
      final once = const DailyRecord().completedOn(DateTime(2026, 11, 13));
      final twice = once.completedOn(DateTime(2026, 11, 13));
      expect(twice.streak, 1);
      expect(twice.lastCompleted, '2026-11-13');
    });

    test('a gap restarts the streak', () {
      var record = const DailyRecord().completedOn(DateTime(2026, 11, 10));
      record = record.completedOn(DateTime(2026, 11, 13));
      expect(record.streak, 1);
    });
  });
}
