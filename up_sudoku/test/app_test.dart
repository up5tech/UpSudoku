import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:up_sudoku/app.dart';
import 'package:up_sudoku/data/puzzle_repository.dart';
import 'package:up_sudoku/data/storage_service.dart';
import 'package:up_sudoku/domain/models/settings.dart';

void main() {
  testWidgets('app boots to the home screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.create();

    await tester.pumpWidget(
      UpSudokuApp(repository: PuzzleRepository(), storage: storage),
    );

    expect(find.text('UpSudoku'), findsOneWidget);
    expect(find.text('Easy'), findsOneWidget);
    expect(find.text('Medium'), findsOneWidget);
    expect(find.text('Daily puzzle'), findsOneWidget);
  });

  testWidgets('the saved Vietnamese language localizes the home screen', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'settings_v1': jsonEncode(
        const Settings(language: AppLanguage.vietnamese).toJson(),
      ),
    });
    final storage = await StorageService.create();

    await tester.pumpWidget(
      UpSudokuApp(repository: PuzzleRepository(), storage: storage),
    );
    await tester.pumpAndSettle();

    expect(find.text('Câu đố hằng ngày'), findsOneWidget);
    expect(find.text('Dễ'), findsOneWidget);
    expect(find.text('Chơi'), findsWidgets);
    expect(find.text('Daily puzzle'), findsNothing);
  });
}
