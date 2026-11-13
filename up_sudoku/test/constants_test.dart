import 'package:flutter_test/flutter_test.dart';
import 'package:up_sudoku/domain/sudoku_constants.dart';

void main() {
  test('every cell has exactly 20 peers', () {
    for (var i = 0; i < 81; i++) {
      expect(kPeers[i].length, 20);
      expect(kPeers[i].contains(i), isFalse);
    }
  });

  test('peers are exactly the cells sharing a unit', () {
    for (var i = 0; i < 81; i++) {
      final expected = <int>{
        ...kRows[rowOf(i)],
        ...kCols[colOf(i)],
        ...kBoxes[boxOf(i)],
      }..remove(i);
      expect(kPeers[i].toSet(), expected);
    }
  });

  test('units partition the board', () {
    for (final units in [kRows, kCols, kBoxes]) {
      final all = units.expand((u) => u).toList()..sort();
      expect(all, List.generate(81, (i) => i));
    }
  });

  test('kUnits contains 27 units of 9 distinct cells', () {
    expect(kUnits.length, 27);
    for (final unit in kUnits) {
      expect(unit.length, 9);
      expect(unit.toSet().length, 9);
    }
  });

  test('boxOf agrees with kBoxes', () {
    for (var b = 0; b < 9; b++) {
      for (final i in kBoxes[b]) {
        expect(boxOf(i), b);
      }
    }
  });

  test('rowOf and colOf agree with kRows and kCols', () {
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        final i = r * 9 + c;
        expect(rowOf(i), r);
        expect(colOf(i), c);
        expect(kRows[r], contains(i));
        expect(kCols[c], contains(i));
      }
    }
  });

  test('bit sets exactly one bit per digit', () {
    expect(bit(1), 1);
    expect(bit(9), 256);
    expect(kAll, 0x1FF);
  });

  test('popCount counts set bits', () {
    expect(popCount(0), 0);
    expect(popCount(kAll), 9);
    expect(popCount(bit(1) | bit(5)), 2);
  });

  test('digitsOf lists the digits inside a mask', () {
    expect(digitsOf(kAll), [1, 2, 3, 4, 5, 6, 7, 8, 9]);
    expect(digitsOf(bit(3) | bit(7)), [3, 7]);
    expect(digitsOf(0), isEmpty);
  });
}
