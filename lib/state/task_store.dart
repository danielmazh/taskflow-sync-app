import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/task.dart';

typedef TaskPersist = Future<void> Function(List<Task> tasks);
typedef TaskScheduleCb = Future<void> Function(Task task);
typedef TaskCancelCb = Future<void> Function(String taskId);

/// Calendar upsert callback. Returns the resulting event id (new or existing),
/// or null on failure / not authorized. The store rounds the id back into the
/// task and re-persists when it changes.
typedef TaskSyncUpsertCb = Future<String?> Function(Task task);
typedef TaskSyncDeleteCb = Future<void> Function(String eventId);

class TaskStore extends ChangeNotifier {
  final List<Task> _tasks;
  final TaskPersist? onChanged;
  final TaskScheduleCb? onSchedule;
  final TaskCancelCb? onCancel;
  final TaskSyncUpsertCb? onSyncUpsert;
  final TaskSyncDeleteCb? onSyncDelete;

  TaskStore({
    List<Task>? seed,
    this.onChanged,
    this.onSchedule,
    this.onCancel,
    this.onSyncUpsert,
    this.onSyncDelete,
  }) : _tasks = [...?seed];

  List<Task> get tasks => List.unmodifiable(_tasks);

  static String newId() =>
      'task-${DateTime.now().microsecondsSinceEpoch}';

  void _persist() {
    final cb = onChanged;
    if (cb == null) return;
    cb(_tasks).catchError((_) {});
  }

  void _schedule(Task task) {
    final cb = onSchedule;
    if (cb == null) return;
    cb(task).catchError((_) {});
  }

  void _cancel(String id) {
    final cb = onCancel;
    if (cb == null) return;
    cb(id).catchError((_) {});
  }

  void _reconcile(Task task) {
    if (task.effectiveDueAt != null && !task.isDone) {
      _schedule(task);
    } else {
      _cancel(task.id);
    }
  }

  /// One-way Google Calendar mirror. Best-effort: any failure leaves the local
  /// task untouched. Round-trips the resulting event id back into the task and
  /// re-persists so the link survives restart.
  Future<void> _syncReconcile(Task task) async {
    final upsertCb = onSyncUpsert;
    final deleteCb = onSyncDelete;
    if (upsertCb == null && deleteCb == null) return;
    final shouldHaveEvent = task.effectiveDueAt != null && !task.isDone;
    try {
      if (shouldHaveEvent) {
        if (upsertCb == null) return;
        final newId = await upsertCb(task);
        if (newId == null) return;
        if (newId != task.calendarEventId) {
          task.calendarEventId = newId;
          _persist();
          notifyListeners();
        }
      } else {
        final existing = task.calendarEventId;
        if (existing == null || deleteCb == null) return;
        await deleteCb(existing);
        task.calendarEventId = null;
        _persist();
        notifyListeners();
      }
    } catch (_) {
      // best-effort, never throw out of the store
    }
  }

  void add(Task task) {
    _tasks.add(task);
    notifyListeners();
    _persist();
    _reconcile(task);
    unawaited(_syncReconcile(task));
  }

  void update({
    required String id,
    required String title,
    String? note,
    DateTime? dueAt,
  }) {
    final i = _tasks.indexWhere((t) => t.id == id);
    if (i < 0) return;
    final t = _tasks[i];
    t.title = title;
    t.note = note;
    t.dueAt = dueAt;
    // User reset the schedule — any prior snooze is stale.
    t.snoozedUntil = null;
    notifyListeners();
    _persist();
    _reconcile(t);
    unawaited(_syncReconcile(t));
  }

  void toggle(String id) {
    final i = _tasks.indexWhere((t) => t.id == id);
    if (i < 0) return;
    final t = _tasks[i];
    t.isDone = !t.isDone;
    t.completedAt = t.isDone ? DateTime.now() : null;
    notifyListeners();
    _persist();
    _reconcile(t);
    unawaited(_syncReconcile(t));
  }

  void delete(String id) {
    final i = _tasks.indexWhere((t) => t.id == id);
    if (i < 0) return;
    final removed = _tasks.removeAt(i);
    notifyListeners();
    _persist();
    _cancel(id);
    final eventId = removed.calendarEventId;
    final deleteCb = onSyncDelete;
    if (eventId != null && deleteCb != null) {
      unawaited(deleteCb(eventId));
    }
  }

  /// Re-run the calendar mirror for every task. Invoked once after the user
  /// newly connects to Google Calendar (back-fill).
  Future<void> resyncAll() async {
    if (onSyncUpsert == null && onSyncDelete == null) return;
    for (final t in List<Task>.of(_tasks)) {
      await _syncReconcile(t);
    }
  }

  /// Replace the in-memory task list from an authoritative source (disk after
  /// a background-isolate mutation). Does NOT trigger persist or reconcile —
  /// the source already wrote the disk + arranged any schedule changes.
  void replaceAll(List<Task> tasks) {
    _tasks
      ..clear()
      ..addAll(tasks);
    notifyListeners();
  }
}

List<Task> sampleSeed() {
  final today = DateTime(2026, 6, 11);
  return [
    Task(
      id: 'seed-1',
      title: 'Buy groceries',
      note: 'Milk, bread, eggs',
      dueAt: today.add(const Duration(hours: 18, minutes: 30)),
    ),
    Task(
      id: 'seed-2',
      title: 'Call the dentist',
      dueAt: today.add(const Duration(hours: 9)),
      isDone: true,
    ),
    Task(
      id: 'seed-3',
      title: 'Finish Flutter walking skeleton',
      note: 'Phase 0 of the plan',
    ),
    Task(
      id: 'seed-4',
      title: 'Water the plants',
      dueAt: today.add(const Duration(hours: 20)),
    ),
  ];
}
