import 'package:flutter_test/flutter_test.dart';
import 'package:up_sudoku/domain/models/difficulty.dart';
import 'package:up_sudoku/domain/score_calculator.dart';

void main() {
  final easy = kDifficulties[Difficulty.easy]!;
  final hard = kDifficulties[Difficulty.hard]!;

  group('score', () {
    test('a flawless fast win earns the base score plus the full time bonus',
        () {
      final score = ScoreCalculator.score(
        cfg: easy,
        seconds: 0,
        mistakes: 0,
        hintsUsed: 0,
        checksUsed: 0,
      );

      expect(score, (easy.baseScore * 1.5).round());
    });

    test('par time removes the time bonus', () {
      final score = ScoreCalculator.score(
        cfg: easy,
        seconds: easy.parSeconds,
        mistakes: 0,
        hintsUsed: 0,
        checksUsed: 0,
      );

      expect(score, easy.baseScore);
    });

    test('slower than par is not rewarded', () {
      final slow = ScoreCalculator.score(
        cfg: easy,
        seconds: easy.parSeconds * 3,
        mistakes: 0,
        hintsUsed: 0,
        checksUsed: 0,
      );

      expect(slow, easy.baseScore);
    });

    test('mistakes, hints and checks each cost part of the base score', () {
      final penalty = ScoreCalculator.score(
        cfg: hard,
        seconds: hard.parSeconds,
        mistakes: 2,
        hintsUsed: 2,
        checksUsed: 3,
      );

      // 0.05*2 + 0.10*2 + 0.05*3 = 0.45 of the base.
      expect(penalty, (hard.baseScore * 0.55).round());
    });

    test('never goes below zero', () {
      final score = ScoreCalculator.score(
        cfg: easy,
        seconds: easy.parSeconds,
        mistakes: 100,
        hintsUsed: 50,
        checksUsed: 50,
      );

      expect(score, 0);
    });
  });

  group('stars', () {
    test('three stars for a flawless win within par', () {
      expect(
        ScoreCalculator.stars(
          cfg: easy,
          seconds: easy.parSeconds,
          mistakes: 0,
          hintsUsed: 0,
          checksUsed: 0,
        ),
        3,
      );
    });

    test('three stars need the time to be within par', () {
      expect(
        ScoreCalculator.stars(
          cfg: easy,
          seconds: easy.parSeconds + 1,
          mistakes: 0,
          hintsUsed: 0,
          checksUsed: 0,
        ),
        2,
      );
    });

    test('one assist and at most two mistakes give two stars', () {
      expect(
        ScoreCalculator.stars(
          cfg: hard,
          seconds: hard.parSeconds,
          mistakes: 2,
          hintsUsed: 1,
          checksUsed: 0,
        ),
        2,
      );

      // A check counts as an assist too.
      expect(
        ScoreCalculator.stars(
          cfg: hard,
          seconds: hard.parSeconds,
          mistakes: 0,
          hintsUsed: 0,
          checksUsed: 1,
        ),
        2,
      );
    });

    test('more assistance drops to one star', () {
      expect(
        ScoreCalculator.stars(
          cfg: hard,
          seconds: hard.parSeconds,
          mistakes: 0,
          hintsUsed: 1,
          checksUsed: 1,
        ),
        1,
      );

      expect(
        ScoreCalculator.stars(
          cfg: easy,
          seconds: easy.parSeconds,
          mistakes: 3,
          hintsUsed: 0,
          checksUsed: 0,
        ),
        1,
      );
    });

    test('evaluate returns both values', () {
      final result = ScoreCalculator.evaluate(
        cfg: easy,
        seconds: easy.parSeconds,
        mistakes: 0,
        hintsUsed: 0,
        checksUsed: 0,
      );

      expect(result.score, easy.baseScore);
      expect(result.stars, 3);
    });
  });
}
