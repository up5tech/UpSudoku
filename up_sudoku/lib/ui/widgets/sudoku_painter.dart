/// Draws the whole 9×9 board on one canvas.
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../domain/logic/logic_step.dart';
import '../../domain/models/difficulty.dart';
import '../../domain/sudoku_constants.dart';

/// Paints backgrounds, grid, digits, notes and error markers.
///
/// The layer order is: backgrounds → grid lines → digits → notes → error
/// markers / hint highlights (PLAN.md §15.2).
class SudokuPainter extends CustomPainter {
  SudokuPainter({
    required this.values,
    required this.notes,
    required this.given,
    required this.solution,
    required this.selected,
    required this.feedback,
    required this.accent,
    this.flagged = const <int>{},
    this.hint,
    this.hintCell,
    this.highlightPeers = true,
    this.highlightSameDigit = true,
    this.dark = false,
  });

  /// Board values (0 = empty).
  final List<int> values;

  /// Candidate notes per cell (bitmask).
  final List<int> notes;

  /// Whether a cell is a given.
  final List<bool> given;

  /// The solution, used to detect wrong digits.
  final List<int> solution;

  /// The selected cell.
  final int? selected;

  /// How wrong digits are shown.
  final FeedbackMode feedback;

  /// Accent colour of the current difficulty.
  final Color accent;

  /// Cells marked by "Check board".
  final Set<int> flagged;

  /// The step currently explained by a hint.
  final LogicStep? hint;

  /// A single cell highlighted by a wrong-digit hint or the reveal fallback.
  final int? hintCell;

  /// Whether the peers of the selected cell are highlighted.
  final bool highlightPeers;

  /// Whether cells with the same digit are highlighted.
  final bool highlightSameDigit;

  /// Whether the dark theme is used.
  final bool dark;

  /// Ratio between the digit size and the cell size.
  static const double _digitRatio = 0.6;

  /// Ratio between the note size and the cell size.
  static const double _noteRatio = 0.25;

  final Map<String, TextPainter> _textCache = {};

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 9;
    final sel = selected;
    final selDigit = sel == null ? 0 : values[sel];
    final peers = sel == null ? const <int>{} : kPeers[sel].toSet();
    final hintCells = <int>{
      ...?hint?.pattern,
      if (hintCell != null) hintCell!,
    };

    // 1. backgrounds
    for (var i = 0; i < kCellCount; i++) {
      final rect = Rect.fromLTWH((i % 9) * cell, (i ~/ 9) * cell, cell, cell);
      var color = dark ? const Color(0xFF1E2430) : Colors.white;

      if (sel != null) {
        if (i == sel) {
          color = dark ? accent.withValues(alpha: 0.45) : const Color(0xFFB3D4FF);
        } else if (highlightPeers && peers.contains(i)) {
          color = dark ? const Color(0xFF2A3345) : const Color(0xFFEAF2FF);
        } else if (highlightSameDigit &&
            selDigit != 0 &&
            values[i] == selDigit) {
          color = dark ? const Color(0xFF34506E) : const Color(0xFFD6E8FF);
        }
      }
      if (hintCells.contains(i)) {
        color = dark ? const Color(0xFF6B5B1E) : const Color(0xFFFFF2B3);
      }
      if (_isWrong(i)) {
        color = dark ? const Color(0xFF6E2A2A) : const Color(0xFFFFC9C9);
      }
      canvas.drawRect(rect, Paint()..color = color);
    }

    // 2. grid lines
    final thin = Paint()
      ..color = dark ? const Color(0xFF4A5568) : Colors.grey.shade400
      ..strokeWidth = 1;
    final thick = Paint()
      ..color = dark ? const Color(0xFFBFC7D5) : Colors.black87
      ..strokeWidth = 3;
    for (var k = 0; k <= 9; k++) {
      final paint = k % 3 == 0 ? thick : thin;
      canvas.drawLine(Offset(k * cell, 0), Offset(k * cell, size.width), paint);
      canvas.drawLine(Offset(0, k * cell), Offset(size.width, k * cell), paint);
    }

    // 3. digits
    for (var i = 0; i < kCellCount; i++) {
      if (values[i] != 0) {
        _paintDigit(canvas, i, cell);
      }
    }

    // 4. notes
    for (var i = 0; i < kCellCount; i++) {
      if (values[i] == 0 && notes[i] != 0) {
        _paintNotes(canvas, i, cell);
      }
    }

    // 5. error markers — never rely on colour alone
    for (var i = 0; i < kCellCount; i++) {
      if (_isWrong(i)) _paintErrorMarker(canvas, i, cell);
    }
  }

  void _paintDigit(Canvas canvas, int i, double cell) {
    final isGiven = given[i];
    final color = isGiven
        ? (dark ? Colors.white : Colors.black87)
        : accent;
    final painter = _text(
      values[i].toString(),
      cell * _digitRatio,
      FontWeight.w700,
      color,
    );
    painter.paint(
      canvas,
      Offset(
        (i % 9) * cell + (cell - painter.width) / 2,
        (i ~/ 9) * cell + (cell - painter.height) / 2,
      ),
    );
  }

  void _paintNotes(Canvas canvas, int i, double cell) {
    final color = dark ? const Color(0xFF9AA6B8) : Colors.grey.shade600;
    final sub = cell / 3;
    for (final d in digitsOf(notes[i])) {
      final painter = _text(
        d.toString(),
        cell * _noteRatio,
        FontWeight.w400,
        color,
      );
      final index = d - 1;
      painter.paint(
        canvas,
        Offset(
          (i % 9) * cell + (index % 3) * sub + (sub - painter.width) / 2,
          (i ~/ 9) * cell + (index ~/ 3) * sub + (sub - painter.height) / 2,
        ),
      );
    }
  }

  void _paintErrorMarker(Canvas canvas, int i, double cell) {
    final paint = Paint()
      ..color = dark ? const Color(0xFFFF9A9A) : const Color(0xFFC62828)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final size = cell * 0.22;
    final left = (i % 9) * cell + cell - size - 2;
    final top = (i ~/ 9) * cell + 2;
    canvas.drawLine(Offset(left, top), Offset(left + size, top + size), paint);
    canvas.drawLine(Offset(left + size, top), Offset(left, top + size), paint);
  }

  TextPainter _text(String text, double size, FontWeight weight, Color color) {
    final key = '$text|${size.toStringAsFixed(1)}|$weight|${color.toARGB32()}';
    return _textCache.putIfAbsent(key, () {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontSize: size,
            fontWeight: weight,
            color: color,
            height: 1.0,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      return painter;
    });
  }

  /// True when the cell shows a wrong digit.
  bool _isWrong(int i) {
    if (given[i] || values[i] == 0) return false;
    switch (feedback) {
      case FeedbackMode.instant:
        return values[i] != solution[i];
      case FeedbackMode.conflictsOnly:
        return _hasConflict(i) || flagged.contains(i);
      case FeedbackMode.none:
        return flagged.contains(i);
    }
  }

  bool _hasConflict(int i) {
    for (final p in kPeers[i]) {
      if (values[p] == values[i]) return true;
    }
    return false;
  }

  @override
  SemanticsBuilderCallback get semanticsBuilder => (size) {
    final cell = size.width / 9;
    return [
      for (var i = 0; i < kCellCount; i++)
        CustomPainterSemantics(
          rect: Rect.fromLTWH(
            (i % 9) * cell,
            (i ~/ 9) * cell,
            cell,
            cell,
          ),
          properties: SemanticsProperties(
            label: _semanticsLabel(i),
            textDirection: TextDirection.ltr,
          ),
        ),
    ];
  };

  /// "Row 3, column 5, value 7, given" style description of a cell.
  String _semanticsLabel(int i) {
    final row = rowOf(i) + 1;
    final col = colOf(i) + 1;
    if (values[i] != 0) {
      return 'Row $row, column $col, value ${values[i]}'
          '${given[i] ? ', given' : ''}';
    }
    if (notes[i] != 0) {
      return 'Row $row, column $col, empty, notes ${digitsOf(notes[i]).join(' ')}';
    }
    return 'Row $row, column $col, empty';
  }

  @override
  bool shouldRepaint(SudokuPainter oldDelegate) => true;
}
