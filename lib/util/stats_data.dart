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

/// One row in the per-label breakdown on the Statistics page.
///
/// Each row is built by running [StatsData.from] over the tasks that share a
/// (case-insensitively-deduped, trimmed) label — so on-time math is the same
/// engine that powers the global donut. There is no parallel stats path.
class LabelStat {
  /// Display string. Real labels carry their first-seen casing; the
  /// untagged bucket uses 'Unlabeled' as its display.
  final String label;
  final bool isUnlabeled;
  final int active;
  final int completed;
  final int onTimePct;
  final bool hasOnTimeData;

  const LabelStat({
    required this.label,
    required this.isUnlabeled,
    required this.active,
    required this.completed,
    required this.onTimePct,
    required this.hasOnTimeData,
  });
}

/// Pure widget-free per-label breakdown. Groups [tasks] by trimmed,
/// case-insensitively-deduped label (first-seen casing preserved for
/// display), runs [StatsData.from] on each subset, and returns the rows
/// in alphabetical order followed by an 'Unlabeled' bucket when both
/// (a) at least one real label exists and (b) at least one task is
/// untagged. Returns `const []` when there are no tasks at all, or when
/// every task is unlabeled (the screen has nothing meaningful to break
/// down in that case).
List<LabelStat> labelStatsFrom(List<Task> tasks, DateTime now) {
  if (tasks.isEmpty) return const [];

  final groups = <String, _LabelGroup>{};
  final unlabeled = <Task>[];

  for (final t in tasks) {
    final raw = t.label?.trim();
    if (raw == null || raw.isEmpty) {
      unlabeled.add(t);
      continue;
    }
    final key = raw.toLowerCase();
    final g = groups.putIfAbsent(key, () => _LabelGroup(display: raw));
    g.tasks.add(t);
  }

  if (groups.isEmpty) return const [];

  final keys = groups.keys.toList()..sort();
  final out = <LabelStat>[];
  for (final k in keys) {
    final g = groups[k]!;
    final s = StatsData.from(g.tasks, now);
    out.add(LabelStat(
      label: g.display,
      isUnlabeled: false,
      active: s.active,
      completed: s.completed,
      onTimePct: s.onTimePct,
      hasOnTimeData: s.hasOnTimeData,
    ));
  }
  if (unlabeled.isNotEmpty) {
    final s = StatsData.from(unlabeled, now);
    out.add(LabelStat(
      label: 'Unlabeled',
      isUnlabeled: true,
      active: s.active,
      completed: s.completed,
      onTimePct: s.onTimePct,
      hasOnTimeData: s.hasOnTimeData,
    ));
  }
  return out;
}

class _LabelGroup {
  final String display;
  final List<Task> tasks = [];
  _LabelGroup({required this.display});
}
