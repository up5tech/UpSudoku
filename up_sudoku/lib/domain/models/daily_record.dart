/// Daily-puzzle completion streak (PLAN.md §19.4).
///
/// Pure Dart — no Flutter imports allowed in the domain layer.
library;

/// The last daily puzzle solved and the current streak.
class DailyRecord {
  /// Date (`yyyy-MM-dd`) of the last completed daily, or null.
  final String? lastCompleted;

  /// Consecutive completed days.
  final int streak;

  const DailyRecord({this.lastCompleted, this.streak = 0});

  /// True when the daily puzzle of [date] has been completed.
  bool isCompletedOn(DateTime date) => lastCompleted == dayKey(date);

  /// The record after completing the daily puzzle of [date].
  ///
  /// Completing the same day twice changes nothing. A gap of more than one
  /// day restarts the streak at 1.
  DailyRecord completedOn(DateTime date) {
    final today = dayKey(date);
    if (lastCompleted == today) return this;
    final yesterday = dayKey(
      DateTime.utc(date.year, date.month, date.day)
          .subtract(const Duration(days: 1)),
    );
    return DailyRecord(
      lastCompleted: today,
      streak: lastCompleted == yesterday ? streak + 1 : 1,
    );
  }

  /// JSON for `shared_preferences`.
  Map<String, dynamic> toJson() => {
    if (lastCompleted != null) 'lastCompleted': lastCompleted,
    'streak': streak,
  };

  /// Reads the record, falling back to an empty one on corrupted data.
  factory DailyRecord.fromJson(Map<String, dynamic> json) {
    final last = json['lastCompleted'];
    final streak = json['streak'];
    return DailyRecord(
      lastCompleted: last is String ? last : null,
      streak: streak is int && streak > 0 ? streak : 0,
    );
  }
}

/// `yyyy-MM-dd` key of [date], in UTC so DST cannot shift the day.
String dayKey(DateTime date) {
  final utc = DateTime.utc(date.year, date.month, date.day);
  final month = utc.month.toString().padLeft(2, '0');
  final day = utc.day.toString().padLeft(2, '0');
  return '${utc.year}-$month-$day';
}
