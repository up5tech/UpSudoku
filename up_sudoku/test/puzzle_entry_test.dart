import 'package:flutter_test/flutter_test.dart';
import 'package:up_sudoku/domain/models/difficulty.dart';
import 'package:up_sudoku/domain/models/puzzle_entry.dart';

void main() {
  test('decode maps characters to cell values', () {
    expect(PuzzleEntry.decode('0123456789'.padRight(81, '0')).take(10).toList(), [
      0,
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
      9,
    ]);
  });

  test('encode and decode round-trip', () {
    final cells = List<int>.generate(81, (i) => (i % 9) + 1);
    expect(PuzzleEntry.decode(PuzzleEntry.encode(cells)), cells);
  });

  test('json round-trip keeps every field', () {
    final entry = PuzzleEntry(
      id: 3,
      difficulty: Difficulty.hard,
      puzzle: List.filled(81, 0),
      solution: List.filled(81, 1),
      givens: 28,
      score: 143,
    );

    final json = entry.toJson();
    expect(json['id'], 3);
    expect(json['g'], 28);
    expect(json['score'], 143);

    final back = PuzzleEntry.fromJson(json, Difficulty.hard);
    expect(back.id, entry.id);
    expect(back.difficulty, Difficulty.hard);
    expect(back.puzzle, entry.puzzle);
    expect(back.solution, entry.solution);
    expect(back.givens, entry.givens);
    expect(back.score, entry.score);
  });
}
