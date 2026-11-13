import 'package:flutter_test/flutter_test.dart';
import 'package:up_sudoku/app.dart';
import 'package:up_sudoku/data/puzzle_repository.dart';

void main() {
  testWidgets('app boots to the home screen', (tester) async {
    await tester.pumpWidget(UpSudokuApp(repository: PuzzleRepository()));

    expect(find.text('UpSudoku'), findsOneWidget);
    expect(find.text('Easy'), findsOneWidget);
    expect(find.text('Medium'), findsOneWidget);
  });
}
