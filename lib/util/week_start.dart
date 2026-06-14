/// Week boundary helpers — Sunday-start (Israel).
///
/// `DateTime.weekday` returns 1 for Monday through 7 for Sunday. With Sunday
/// as the first day of the week, the offset from `startOfWeek` to `d` is
/// `d.weekday % 7` (Sun→0, Mon→1, …, Sat→6).
library;

DateTime ymd(DateTime d) => DateTime(d.year, d.month, d.day);

/// Midnight of the Sunday that begins the week containing [d].
DateTime startOfWeekSunday(DateTime d) {
  final base = ymd(d);
  return base.subtract(Duration(days: base.weekday % 7));
}

/// 0 = Sunday, 6 = Saturday. Used to index Sun→Sat-ordered weekly buckets.
int weekdaySundayIndex(DateTime d) => d.weekday % 7;
