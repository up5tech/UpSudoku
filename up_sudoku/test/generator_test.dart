import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:up_sudoku/domain/generator.dart';
import 'package:up_sudoku/domain/logic/grader.dart';
import 'package:up_sudoku/domain/models/difficulty.dart';
import 'package:up_sudoku/domain/solver.dart';

void main() {
  final easy = kDifficulties[Difficulty.easy]!;

  group('dig', () {
    test('keeps the solution unique and never removes a given', () {
      final rng = Random(1);
      final solution = SudokuSolver.solve(List.filled(81, 0), rng: rng)!;

      for (var n = 0; n < 10; n++) {
        final puzzle = PuzzleGenerator.dig(solution, 40, rng);

        expect(SudokuSolver.countSolutions(puzzle, limit: 2), 1);
        final givens = puzzle.where((v) => v != 0).length;
        expect(givens, lessThanOrEqualTo(40));
        expect(givens, greaterThanOrEqualTo(30));

        for (var i = 0; i < 81; i++) {
          if (puzzle[i] != 0) expect(puzzle[i], solution[i]);
        }
      }
    });

    test('is symmetric when requested', () {
      final rng = Random(2);
      final solution = SudokuSolver.solve(List.filled(81, 0), rng: rng)!;
      final puzzle = PuzzleGenerator.dig(solution, 40, rng, symmetric: true);

      for (var i = 0; i < 81; i++) {
        expect(puzzle[i] == 0, puzzle[80 - i] == 0);
      }
    });

    test('is deterministic for the same seed', () {
      final a = PuzzleGenerator.dig(
        SudokuSolver.solve(List.filled(81, 0), rng: Random(3))!,
        40,
        Random(9),
      );
      final b = PuzzleGenerator.dig(
        SudokuSolver.solve(List.filled(81, 0), rng: Random(3))!,
        40,
        Random(9),
      );
      expect(a, b);
    });
  });

  group('generate', () {
    test('produces Easy puzzles that are tier 1 and valid', () {
      final rng = Random(42);
      final grader = Grader.standard();

      for (var n = 0; n < 10; n++) {
        final entry = PuzzleGenerator.generate(easy, rng, id: n + 1);
        expect(entry, isNotNull, reason: 'no Easy puzzle generated');

        final puzzle = entry!;
        expect(puzzle.difficulty, Difficulty.easy);
        expect(puzzle.givens, greaterThanOrEqualTo(easy.minGivens));
        expect(puzzle.givens, lessThanOrEqualTo(easy.maxGivens));
        expect(puzzle.puzzle.where((v) => v != 0).length, puzzle.givens);
        expect(SudokuSolver.countSolutions(puzzle.puzzle, limit: 2), 1);

        for (var i = 0; i < 81; i++) {
          if (puzzle.puzzle[i] != 0) {
            expect(puzzle.puzzle[i], puzzle.solution[i]);
          }
        }

        final grade = grader.grade(puzzle.puzzle);
        expect(grade.tier, easy.tier);
        expect(grade.solvedLogically, isTrue);
      }
    });

    test('produces Medium and Hard puzzles at their tier', () {
      final grader = Grader.standard();
      final rng = Random(7);

      for (final difficulty in [Difficulty.medium, Difficulty.hard]) {
        final cfg = kDifficulties[difficulty]!;
        final entry = PuzzleGenerator.generate(cfg, rng, maxAttempts: 300);
        expect(entry, isNotNull, reason: 'no $difficulty puzzle generated');

        expect(entry!.givens, greaterThanOrEqualTo(cfg.minGivens));
        expect(entry.givens, lessThanOrEqualTo(cfg.maxGivens));
        expect(SudokuSolver.countSolutions(entry.puzzle, limit: 2), 1);
        expect(grader.grade(entry.puzzle).tier, cfg.tier);
      }
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('produces a Very Hard puzzle the grader cannot finish', () {
      final cfg = kDifficulties[Difficulty.veryHard]!;
      final grader = Grader.standard();
      final entry = PuzzleGenerator.generate(
        cfg,
        Random(11),
        maxAttempts: 600,
      );

      expect(entry, isNotNull, reason: 'no Very Hard puzzle generated');
      expect(entry!.givens, inInclusiveRange(cfg.minGivens, cfg.maxGivens));
      expect(SudokuSolver.countSolutions(entry.puzzle, limit: 2), 1);

      final grade = grader.grade(entry.puzzle);
      expect(grade.tier, 4);
      expect(grade.solvedLogically, isFalse);
    }, timeout: const Timeout(Duration(minutes: 4)));
  });
}
