import 'package:flutter/material.dart';

import '../models/task.dart';
import '../state/task_store.dart';
import '../theme/app_theme.dart';
import '../util/task_outcome.dart';
import '../util/undo_snackbar.dart';
import '../util/week_start.dart';

class ArchiveScreen extends StatelessWidget {
  final TaskStore store;
  const ArchiveScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Archive'),
        actions: [
          ListenableBuilder(
            listenable: store,
            builder: (context, _) {
              final hasCompleted = store.tasks.any((t) => t.isDone);
              if (!hasCompleted) return const SizedBox.shrink();
              return IconButton(
                tooltip: 'Clear completed',
                onPressed: () => _confirmClearCompleted(context),
                icon: const Icon(Icons.delete_sweep_outlined),
              );
            },
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final now = DateTime.now();
          final completed = store.tasks.where((t) => t.isDone).toList();
          if (completed.isEmpty) {
            return const _ArchiveEmptyState();
          }
          final groups = _groupByRecency(completed, now);
          return ListView(
            children: [
              for (final g in groups) ...[
                _SectionHeader(title: g.title, count: g.tasks.length),
                ...g.tasks.map((t) => _ArchiveRow(
                      task: t,
                      now: now,
                      onRestore: () => store.toggle(t.id),
                      onDelete: () => _deleteWithUndo(context, t),
                    )),
              ],
              const SizedBox(height: AppSpacing.xl),
            ],
          );
        },
      ),
    );
  }

  void _deleteWithUndo(BuildContext context, Task task) {
    final snapshot = Task(
      id: task.id,
      title: task.title,
      note: task.note,
      dueAt: task.dueAt,
      isDone: task.isDone,
      snoozedUntil: task.snoozedUntil,
      completedAt: task.completedAt,
      label: task.label,
    );
    store.delete(task.id);
    final title =
        snapshot.title.length <= 36 ? snapshot.title : '${snapshot.title.substring(0, 35)}…';
    showUndoSnackBar(
      context,
      message: 'Deleted "$title"',
      onUndo: () => store.add(snapshot),
    );
  }

  Future<void> _confirmClearCompleted(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear completed?'),
        content: const Text(
          'This permanently removes every completed task from the archive.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final ids = store.tasks.where((t) => t.isDone).map((t) => t.id).toList();
      for (final id in ids) {
        store.delete(id);
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Grouping by completedAt recency
// ─────────────────────────────────────────────────────────────────────────────

class _ArchiveGroup {
  final String title;
  final List<Task> tasks;
  const _ArchiveGroup(this.title, this.tasks);
}

DateTime _ymd(DateTime d) => ymd(d);

List<_ArchiveGroup> _groupByRecency(List<Task> completed, DateTime now) {
  final today = _ymd(now);
  final yesterday = today.subtract(const Duration(days: 1));
  // Sunday-start (Israel). See lib/util/week_start.dart.
  final startOfWeek = startOfWeekSunday(now);

  final t = <Task>[];
  final y = <Task>[];
  final w = <Task>[];
  final older = <Task>[];

  for (final task in completed) {
    final stamp = task.completedAt;
    if (stamp == null) {
      older.add(task);
      continue;
    }
    final day = _ymd(stamp);
    if (day == today) {
      t.add(task);
    } else if (day == yesterday) {
      y.add(task);
    } else if (!day.isBefore(startOfWeek) && day.isBefore(today)) {
      w.add(task);
    } else {
      older.add(task);
    }
  }

  int byCompletedDesc(Task a, Task b) {
    final ax = a.completedAt ?? DateTime(1970);
    final bx = b.completedAt ?? DateTime(1970);
    return bx.compareTo(ax);
  }

  t.sort(byCompletedDesc);
  y.sort(byCompletedDesc);
  w.sort(byCompletedDesc);
  older.sort(byCompletedDesc);

  return [
    if (t.isNotEmpty) _ArchiveGroup('Today', t),
    if (y.isNotEmpty) _ArchiveGroup('Yesterday', y),
    if (w.isNotEmpty) _ArchiveGroup('Earlier this week', w),
    if (older.isNotEmpty) _ArchiveGroup('Older', older),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// Section header
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  const _SectionHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: scheme.onSurface,
              letterSpacing: 0.4,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '$count',
            style: theme.textTheme.labelLarge?.copyWith(
              color: scheme.muted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Archive row
// ─────────────────────────────────────────────────────────────────────────────

class _ArchiveRow extends StatelessWidget {
  final Task task;
  final DateTime now;
  final VoidCallback onRestore;
  final VoidCallback onDelete;
  const _ArchiveRow({
    required this.task,
    required this.now,
    required this.onRestore,
    required this.onDelete,
  });

  String _relative(DateTime when, DateTime now) {
    final diff = now.difference(when);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    final weeks = (diff.inDays / 7).floor();
    if (weeks < 5) return '${weeks}w ago';
    final months = (diff.inDays / 30).floor();
    return '${months}mo ago';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final outcome = outcomeFor(task, now);
    final completedAt = task.completedAt;
    final relative = completedAt == null
        ? 'Completed'
        : 'Completed ${_relative(completedAt, now)}';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: Icon(
                Icons.check_circle_rounded,
                color: scheme.primary,
                semanticLabel: 'Completed',
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    task.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: scheme.onSurface,
                      decoration: TextDecoration.lineThrough,
                      decorationColor: scheme.muted,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        relative,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.muted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (task.dueAt != null)
                        _OutcomeBadge(outcome: outcome),
                    ],
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Restore',
            onPressed: onRestore,
            icon: const Icon(Icons.undo_rounded),
          ),
          IconButton(
            tooltip: 'Delete',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}

class _OutcomeBadge extends StatelessWidget {
  final TaskOutcome outcome;
  const _OutcomeBadge({required this.outcome});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (label, icon, bg, fg) = switch (outcome) {
      TaskOutcome.onTime => (
          'On time',
          Icons.check_rounded,
          scheme.primaryContainer,
          scheme.onPrimaryContainer,
        ),
      TaskOutcome.late => (
          'Late',
          Icons.access_time_rounded,
          scheme.errorContainer,
          scheme.onErrorContainer,
        ),
      TaskOutcome.missed => (
          'Missed',
          Icons.warning_amber_rounded,
          scheme.errorContainer,
          scheme.onErrorContainer,
        ),
      TaskOutcome.pending => (
          'Pending',
          Icons.schedule_rounded,
          scheme.surfaceContainerHighest,
          scheme.onSurfaceVariant,
        ),
    };
    return Semantics(
      label: 'Outcome: $label',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 2,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: fg, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────

class _ArchiveEmptyState extends StatelessWidget {
  const _ArchiveEmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_rounded, size: 64, color: scheme.muted),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Nothing archived yet',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Completed tasks land here so Home stays focused on what\'s next.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.muted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
