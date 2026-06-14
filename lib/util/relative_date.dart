/// Human-readable due-date formatting.
///
/// Pure function: pass `now` explicitly so the formatter is testable and
/// stable across daylight-savings boundaries.
library;

const _weekdays = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _two(int n) => n.toString().padLeft(2, '0');
String _hhmm(DateTime t) => '${_two(t.hour)}:${_two(t.minute)}';

DateTime _ymd(DateTime t) => DateTime(t.year, t.month, t.day);

/// Returns a short, human label for a due date relative to [now].
///
/// Examples:
///   - 'Overdue · 2h ago'  (when due < now)
///   - 'Today 18:30'
///   - 'Tomorrow 09:00'
///   - 'Wed 15:00'         (within next 6 days)
///   - 'Tue 15 Jul'        (later this year)
///   - 'Tue 15 Jul 2027'   (different year)
String formatRelativeDue(DateTime due, DateTime now) {
  final today = _ymd(now);
  final dueDay = _ymd(due);
  final dayDiff = dueDay.difference(today).inDays;

  if (due.isBefore(now)) {
    return 'Overdue · ${_overdueDelta(now.difference(due))} ago';
  }
  if (dayDiff == 0) return 'Today ${_hhmm(due)}';
  if (dayDiff == 1) return 'Tomorrow ${_hhmm(due)}';
  if (dayDiff > 1 && dayDiff < 7) {
    return '${_weekdays[due.weekday - 1]} ${_hhmm(due)}';
  }
  // 1+ weeks out: drop the time, lead with the weekday.
  final base = '${_weekdays[due.weekday - 1]} ${due.day} ${_months[due.month - 1]}';
  if (due.year != now.year) return '$base ${due.year}';
  return base;
}

String _overdueDelta(Duration d) {
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m';
  if (d.inHours < 24) return '${d.inHours}h';
  if (d.inDays < 7) return '${d.inDays}d';
  final weeks = (d.inDays / 7).floor();
  if (weeks < 5) return '${weeks}w';
  final months = (d.inDays / 30).floor();
  return '${months}mo';
}

/// Bucket a task's effective due date relative to [now], for section grouping.
enum DueBucket { overdue, today, upcoming, none }

DueBucket bucketFor({required DateTime? effectiveDueAt, required DateTime now}) {
  if (effectiveDueAt == null) return DueBucket.none;
  if (effectiveDueAt.isBefore(now)) return DueBucket.overdue;
  final today = _ymd(now);
  final dueDay = _ymd(effectiveDueAt);
  if (dueDay == today) return DueBucket.today;
  return DueBucket.upcoming;
}
