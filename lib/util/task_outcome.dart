import '../models/task.dart';

enum TaskOutcome { onTime, late, missed, pending }

/// Classify a task's outcome relative to its deadline.
///
/// Spec:
///   - onTime  : isDone && (dueAt == null || completedAt <= dueAt)
///   - late    : isDone && dueAt != null && completedAt > dueAt
///   - missed  : !isDone && dueAt != null && dueAt < now
///   - pending : everything else
///
/// Legacy completed tasks (persisted before 5c) have `completedAt == null`.
/// In that case we cannot prove they were late, so we default to onTime —
/// the user-friendly read of "no information recorded."
TaskOutcome outcomeFor(Task t, DateTime now) {
  if (t.isDone) {
    final due = t.dueAt;
    if (due == null) return TaskOutcome.onTime;
    final completed = t.completedAt;
    if (completed == null) return TaskOutcome.onTime;
    return completed.isAfter(due) ? TaskOutcome.late : TaskOutcome.onTime;
  }
  final due = t.dueAt;
  if (due != null && due.isBefore(now)) return TaskOutcome.missed;
  return TaskOutcome.pending;
}
