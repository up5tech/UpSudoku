import 'package:flutter_test/flutter_test.dart';
import 'package:up_sudoku/domain/models/difficulty.dart';

void main() {
  test('every difficulty has a configuration', () {
    for (final d in Difficulty.values) {
      expect(kDifficulties.containsKey(d), isTrue);
      expect(kDifficulties[d]!.id, d);
    }
  });

  test('givens ranges are sane and ordered', () {
    for (final d in Difficulty.values) {
      final c = kDifficulties[d]!;
      expect(c.minGivens, greaterThan(0));
      expect(c.maxGivens, greaterThanOrEqualTo(c.minGivens));
      expect(c.maxGivens, lessThanOrEqualTo(81));
    }
  });

  test('tiers increase with difficulty', () {
    expect(kDifficulties[Difficulty.easy]!.tier, 1);
    expect(kDifficulties[Difficulty.medium]!.tier, 2);
    expect(kDifficulties[Difficulty.hard]!.tier, 3);
    expect(kDifficulties[Difficulty.veryHard]!.tier, 4);
  });

  test('pool keys are unique and stable', () {
    final keys = Difficulty.values.map((d) => d.key).toList();
    expect(keys.toSet().length, keys.length);
    expect(kDifficulties[Difficulty.veryHard]!.id.key, 'very_hard');
  });

  test('assist rules follow the plan', () {
    expect(kDifficulties[Difficulty.easy]!.allowAutoFillNotes, isTrue);
    expect(kDifficulties[Difficulty.hard]!.allowAutoFillNotes, isFalse);
    expect(kDifficulties[Difficulty.veryHard]!.autoRemoveNotes, isFalse);
  });

  test('feedback modes match the plan', () {
    expect(kDifficulties[Difficulty.easy]!.feedback, FeedbackMode.instant);
    expect(kDifficulties[Difficulty.hard]!.feedback, FeedbackMode.conflictsOnly);
    expect(kDifficulties[Difficulty.veryHard]!.feedback, FeedbackMode.none);
  });
}
