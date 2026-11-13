/// Pure-Dart Sudoku grid constants and bit helpers.
///
/// This library must never import `flutter/*` — the domain layer stays
/// dependency-free so `dart run tool/*.dart` and unit tests stay fast.
library;

/// Candidate mask with every digit 1..9 set (bits 0..8).
const int kAll = 0x1FF;

/// Number of cells on the board.
const int kCellCount = 81;

/// Number of digits in a Sudoku.
const int kDigitCount = 9;

/// Row of cell [i] (0..8).
int rowOf(int i) => i ~/ 9;

/// Column of cell [i] (0..8).
int colOf(int i) => i % 9;

/// Box (0..8) of cell [i].
int boxOf(int i) => (i ~/ 27) * 3 + (i % 9) ~/ 3;

/// Bit for digit [d] (1..9).
int bit(int d) => 1 << (d - 1);

/// Number of set bits in [x].
int popCount(int x) {
  var n = 0;
  while (x != 0) {
    x &= x - 1;
    n++;
  }
  return n;
}

/// Digits (1..9) contained in candidate [mask].
List<int> digitsOf(int mask) => [
  for (var d = 1; d <= kDigitCount; d++)
    if ((mask & bit(d)) != 0) d,
];

/// The 9 rows, each as 9 cell indices.
final List<List<int>> kRows = [
  for (var r = 0; r < 9; r++) [for (var c = 0; c < 9; c++) r * 9 + c],
];

/// The 9 columns, each as 9 cell indices.
final List<List<int>> kCols = [
  for (var c = 0; c < 9; c++) [for (var r = 0; r < 9; r++) r * 9 + c],
];

/// The 9 boxes, each as 9 cell indices.
final List<List<int>> kBoxes = [
  for (var b = 0; b < 9; b++)
    [
      for (var k = 0; k < 9; k++)
        ((b ~/ 3) * 3 + k ~/ 3) * 9 + (b % 3) * 3 + k % 3,
    ],
];

/// The 27 units: 9 rows, 9 columns, 9 boxes.
final List<List<int>> kUnits = [...kRows, ...kCols, ...kBoxes];

/// The 20 peers of each cell (cells sharing a unit with it).
final List<List<int>> kPeers = [
  for (var i = 0; i < kCellCount; i++)
    {...kRows[rowOf(i)], ...kCols[colOf(i)], ...kBoxes[boxOf(i)]}
        .where((j) => j != i)
        .toList(),
];
