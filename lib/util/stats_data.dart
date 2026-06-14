import '../models/task.dart';
import 'task_outcome.dart';
import 'week_start.dart';

/// Pure value-object computed from `store.tasks`. View layer derives all of
/// its numbers from here so it stays easy to test without widgets.
class StatsData {
  final int active;
  final int completed;
  final int onTime;
  final int late;
  final int missed;
  /// Counts completed on each weekday of the CURRENT week, Sunday → Saturday.
  final List<int> weeklyBars;
  /// 0..6, the column to highlight in [weeklyBars] for "today".
  final int todayIndex;

  const StatsData({
    required this.active,
    required this.completed,
    required this.onTime,
    required this.late,
    required this.missed,
    required this.weeklyBars,
    required this.todayIndex,
  });

  /// On-time % computed over every deadline-bearing task with a resolved
  /// outcome: on-time, late, OR missed. Missing a deadline counts against
  /// you, same as completing late. Returns 0 when there is no data.
  int get onTimePct {
    final scored = onTime + late + missed;
    if (scored == 0) return 0;
    return ((onTime / scored) * 100).round();
  }

  bool get hasOnTimeData => (onTime + late + missed) > 0;

  factory StatsData.from(List<Task> tasks, DateTime now) {
    var active = 0;
    var completed = 0;
    var onTime = 0;
    var late = 0;
    var missed = 0;
    final bars = List<int>.filled(7, 0);

    final start = startOfWeekSunday(now);
    final end = start.add(const Duration(days: 7));

    for (final t in tasks) {
      if (t.isDone) {
        completed++;
      } else {
        active++;
      }
      switch (outcomeFor(t, now)) {
        case TaskOutcome.onTime:
          if (t.dueAt != null) onTime++;
          break;
        case TaskOutcome.late:
          late++;
          break;
        case TaskOutcome.missed:
          missed++;
          break;
        case TaskOutcome.pending:
          break;
      }
      final completedAt = t.completedAt;
      if (completedAt != null &&
          !completedAt.isBefore(start) &&
          completedAt.isBefore(end)) {
        bars[weekdaySundayIndex(completedAt)]++;
      }
    }

    return StatsData(
      active: active,
      completed: completed,
      onTime: onTime,
      late: late,
      missed: missed,
      weeklyBars: bars,
      todayIndex: weekdaySundayIndex(now),
    );
  }
}
