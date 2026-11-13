import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:up_sudoku/controllers/settings_controller.dart';
import 'package:up_sudoku/data/storage_service.dart';
import 'package:up_sudoku/domain/logic/technique.dart';
import 'package:up_sudoku/domain/models/difficulty.dart';
import 'package:up_sudoku/domain/models/settings.dart';
import 'package:up_sudoku/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const en = AppLocalizations(Locale('en'));
  const vi = AppLocalizations(Locale('vi'));

  group('AppLocalizations', () {
    test('English is the default table, Vietnamese the other', () {
      expect(en.isVietnamese, isFalse);
      expect(vi.isVietnamese, isTrue);
      expect(en.play, 'Play');
      expect(vi.play, 'Chơi');
      expect(en.settings, 'Settings');
      expect(vi.settings, 'Cài đặt');
    });

    test('difficulties are named in both languages', () {
      expect(en.difficulty(Difficulty.easy), 'Easy');
      expect(en.difficulty(Difficulty.veryHard), 'Very Hard');
      expect(vi.difficulty(Difficulty.easy), 'Dễ');
      expect(vi.difficulty(Difficulty.medium), 'Trung bình');
      expect(vi.difficulty(Difficulty.hard), 'Khó');
      expect(vi.difficulty(Difficulty.veryHard), 'Rất khó');
    });

    test('parameterised strings interpolate', () {
      expect(en.solvedCount(3, 200), '3/200 solved');
      expect(vi.solvedCount(3, 200), 'Đã giải 3/200');
      expect(en.dayStreak(4), '4 day streak');
      expect(vi.dayStreak(4), 'chuỗi 4 ngày');
      expect(en.digitLabel(7, 2, notesMode: false), 'Digit 7, 2 remaining');
      expect(vi.placementExplanation(5), 'Số 5 chỉ có thể nằm ở ô này.');
      expect(
        en.eliminationExplanation('1, 4', 2),
        'Remove 1, 4 from 2 cells.',
      );
      expect(vi.streakValue(2, 7), '2 (tốt nhất 7)');
      expect(en.boardCell(3, 5), 'Row 3, column 5');
      expect(vi.boardCell(3, 5), 'Hàng 3, cột 5');
    });

    test('feedback badges follow the mode', () {
      expect(en.feedbackBadge(FeedbackMode.instant), 'Instant feedback');
      expect(vi.feedbackBadge(FeedbackMode.conflictsOnly), 'Chỉ báo trùng');
      expect(vi.feedbackBadge(FeedbackMode.none), 'Không phản hồi trực tiếp');
    });

    test('every section of how-to-play has text', () {
      for (final strings in [en, vi]) {
        expect(strings.goalTitle, isNotEmpty);
        expect(strings.goalBody, isNotEmpty);
        expect(strings.controlsBody, isNotEmpty);
        expect(strings.notesBody, isNotEmpty);
        expect(strings.hintsBody, isNotEmpty);
        expect(strings.difficultiesBody, isNotEmpty);
        expect(strings.scoringBody, isNotEmpty);
        expect(strings.offlineBody, isNotEmpty);
      }
    });

    test('every technique has an English and a Vietnamese name', () {
      expect(en.techniqueName(Technique.nakedSingle), 'Naked Single');
      expect(vi.techniqueName(Technique.nakedSingle), 'Single trần');
      expect(vi.techniqueName(Technique.xWing), 'X-Wing');

      for (final technique in Technique.values) {
        final english = en.techniqueName(technique);
        final vietnamese = vi.techniqueName(technique);
        expect(english, isNotEmpty, reason: '${technique.name} in English');
        expect(vietnamese, isNotEmpty,
            reason: '${technique.name} in Vietnamese');
        // A missing translation would fall back to the generic hint label.
        expect(english, isNot(en.hint), reason: '${technique.name} in English');
        expect(vietnamese, isNot(vi.hint),
            reason: '${technique.name} in Vietnamese');
      }

      // No two techniques may share a name: the headline has to identify the
      // technique the hint is about.
      for (final strings in [en, vi]) {
        final names = {
          for (final technique in Technique.values)
            strings.techniqueName(technique),
        };
        expect(names.length, Technique.values.length);
      }
    });

    test('both locales are advertised', () {
      expect(
        AppLocalizations.supportedLocales.map((l) => l.languageCode),
        containsAll(<String>['en', 'vi']),
      );
    });
  });

  group('language setting', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('defaults to following the system', () {
      expect(const Settings().language, AppLanguage.system);
      expect(Settings.fromJson(const {}).language, AppLanguage.system);
    });

    test('round-trips through JSON', () {
      const settings = Settings(language: AppLanguage.vietnamese);
      final decoded = Settings.fromJson(
        jsonDecode(jsonEncode(settings.toJson())) as Map<String, dynamic>,
      );
      expect(decoded.language, AppLanguage.vietnamese);
    });

    test('an unknown language falls back to the system', () {
      final decoded = Settings.fromJson(const {'language': 'klingon'});
      expect(decoded.language, AppLanguage.system);
    });

    test('the controller exposes the locale and persists the choice', () async {
      final storage = await StorageService.create();
      final controller = SettingsController(storage: storage);

      expect(controller.locale, isNull);

      controller.setLanguage(AppLanguage.english);
      await pumpEventQueue();
      expect(controller.locale, const Locale('en'));
      expect(storage.readSettings().language, AppLanguage.english);

      controller.setLanguage(AppLanguage.vietnamese);
      await pumpEventQueue();
      expect(controller.locale, const Locale('vi'));
      expect(storage.readSettings().language, AppLanguage.vietnamese);

      controller.setLanguage(AppLanguage.system);
      await pumpEventQueue();
      expect(controller.locale, isNull);
    });
  });
}
