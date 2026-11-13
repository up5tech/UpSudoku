import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:up_sudoku/app.dart';
import 'package:up_sudoku/data/puzzle_repository.dart';
import 'package:up_sudoku/data/storage_service.dart';
import 'package:up_sudoku/domain/models/settings.dart';
import 'package:up_sudoku/ui/screens/game_screen.dart';
import 'package:up_sudoku/ui/screens/how_to_play_screen.dart';
import 'package:up_sudoku/ui/screens/settings_screen.dart';
import 'package:up_sudoku/ui/screens/stats_screen.dart';

/// Test fonts are a fixed-width placeholder by default; loading the real ones
/// measures the same text the player sees.
Future<void> _loadAppFonts() async {
  final loader = FontLoader('Baloo2');
  for (final path in [
    'assets/fonts/Baloo2-Regular.ttf',
    'assets/fonts/Baloo2-Bold.ttf',
  ]) {
    final bytes = File(path).readAsBytesSync();
    loader.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

/// Vietnamese strings are the longest ones the app ships, so they are the
/// useful worst case for a small phone.
void main() {
  setUpAll(_loadAppFonts);

  testWidgets('every Vietnamese screen fits a 320x568 phone', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = PuzzleRepository();
    await repository.load();
    SharedPreferences.setMockInitialValues({
      'settings_v1': jsonEncode(
        const Settings(language: AppLanguage.vietnamese).toJson(),
      ),
    });
    final storage = await StorageService.create();

    await tester.pumpWidget(
      UpSudokuApp(repository: repository, storage: storage),
    );
    await tester.pumpAndSettle();
    // A render overflow would have been thrown while laying the screen out.
    expect(tester.takeException(), isNull, reason: 'home');

    await tester.tap(find.byTooltip('Thống kê'));
    await tester.pumpAndSettle();
    expect(find.byType(StatsScreen), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'stats');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Cách chơi'));
    await tester.pumpAndSettle();
    expect(find.byType(HowToPlayScreen), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'how to play');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Cài đặt'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'settings');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Chơi').first);
    await tester.pumpAndSettle();
    expect(find.byType(GameScreen), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'game');
  });
}
