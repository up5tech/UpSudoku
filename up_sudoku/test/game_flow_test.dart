import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:up_sudoku/app.dart';
import 'package:up_sudoku/controllers/game_controller.dart';
import 'package:up_sudoku/data/puzzle_repository.dart';
import 'package:up_sudoku/data/storage_service.dart';
import 'package:up_sudoku/domain/models/difficulty.dart';
import 'package:up_sudoku/ui/screens/game_screen.dart';
import 'package:up_sudoku/ui/widgets/number_pad.dart';
import 'package:up_sudoku/ui/widgets/sudoku_board.dart';

void main() {
  testWidgets('plays an Easy puzzle from the home screen to the win dialog', (
    tester,
  ) async {
    final repository = PuzzleRepository();
    await repository.load();
    expect(repository.poolSize(Difficulty.easy), greaterThan(0));

    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.create();

    await tester.pumpWidget(
      UpSudokuApp(repository: repository, storage: storage),
    );
    await tester.pumpAndSettle();

    // Start an Easy game.
    await tester.tap(find.widgetWithText(FilledButton, 'Play').first);
    await tester.pumpAndSettle();

    expect(find.byType(GameScreen), findsOneWidget);
    expect(find.byType(SudokuBoard), findsOneWidget);
    expect(find.byType(NumberPad), findsOneWidget);

    final game = Provider.of<GameController>(
      tester.element(find.byType(GameScreen)),
      listen: false,
    );
    expect(game.status, GameStatus.playing);

    // Tap an empty cell on the board and enter its solution digit.
    final empty = List<int>.generate(81, (i) => i)
        .firstWhere((i) => game.values[i] == 0);
    final row = empty ~/ 9;
    final col = empty % 9;

    final board = tester.getRect(
      find
          .descendant(
            of: find.byType(SudokuBoard),
            matching: find.byType(GestureDetector),
          )
          .first,
    );
    final cell = board.width / 9;
    await tester.tapAt(
      Offset(board.left + (col + 0.5) * cell, board.top + (row + 0.5) * cell),
    );
    await tester.pump();

    expect(game.selected, empty);

    final digit = game.entry.solution[empty];
    await tester.tap(find.byKey(ValueKey('digit-$digit')));
    await tester.pump();

    expect(game.values[empty], digit);
    expect(game.mistakes, 0);

    // Fill the rest of the board and expect the win dialog.
    for (var i = 0; i < 81; i++) {
      if (game.values[i] != 0) continue;
      game.select(i);
      game.inputDigit(game.entry.solution[i]);
    }
    await tester.pumpAndSettle();

    expect(game.status, GameStatus.won);
    expect(find.text('Puzzle solved!'), findsOneWidget);
  });
}
