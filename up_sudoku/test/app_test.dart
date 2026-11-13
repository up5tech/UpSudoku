import 'package:flutter_test/flutter_test.dart';
import 'package:up_sudoku/app.dart';

void main() {
  testWidgets('app boots to the placeholder screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const UpSudokuApp());

    expect(find.text('UpSudoku'), findsOneWidget);
  });
}
