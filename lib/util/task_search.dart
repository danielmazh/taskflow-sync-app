import '../models/task.dart';

/// Pure, widget-free search over a task list.
///
/// Returns the tasks whose title, note, or label contains [query] as a
/// case-insensitive substring, in the original input order (stable). An
/// empty/whitespace [query] returns an empty list — search is opt-in,
/// not a default "show everything".
///
/// No fuzzy matching, no scoring, no token boundaries — just simple
/// substring matching as called for by the plan's simplicity principle.
List<Task> searchTasks(List<Task> tasks, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return const [];
  return [
    for (final t in tasks)
      if (_matches(t, q)) t,
  ];
}

bool _matches(Task t, String lowerQuery) {
  if (t.title.toLowerCase().contains(lowerQuery)) return true;
  final note = t.note;
  if (note != null && note.toLowerCase().contains(lowerQuery)) return true;
  final label = t.label;
  if (label != null && label.toLowerCase().contains(lowerQuery)) return true;
  return false;
}
