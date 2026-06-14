import 'package:flutter/material.dart';

import '../models/task.dart';
import '../theme/app_theme.dart';
import '../util/relative_date.dart';

/// Clean list row. Leading circular checkbox (left, 48dp tap target),
/// strong title, quiet metadata line beneath. Overdue is flagged with
/// an icon + accent color — never color alone.
class TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback? onToggle;
  final DateTime? now;
  /// Optional trailing widget rendered after the overdue indicator. Used by
  /// the home screen to surface the per-row calendar status + actions menu.
  final Widget? trailing;
  const TaskCard({
    super.key,
    required this.task,
    this.onToggle,
    this.now,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final nowOrDefault = now ?? DateTime.now();
    final due = task.effectiveDueAt;
    final bucket = bucketFor(effectiveDueAt: due, now: nowOrDefault);
    final isOverdue = !task.isDone && bucket == DueBucket.overdue;

    final titleColor = task.isDone ? scheme.muted : scheme.onSurface;
    final titleStyle = theme.textTheme.titleMedium?.copyWith(
      color: titleColor,
      decoration: task.isDone ? TextDecoration.lineThrough : null,
      decorationColor: scheme.muted,
    ) ?? const TextStyle();

    final metaParts = <Widget>[];
    if (due != null) {
      metaParts.add(_DueChip(
        label: formatRelativeDue(due, nowOrDefault),
        overdue: isOverdue,
        done: task.isDone,
      ));
    }
    if (task.note != null && task.note!.trim().isNotEmpty) {
      metaParts.add(_NoteHint(text: task.note!));
    }

    return Semantics(
      label: _semanticsLabel(),
      button: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
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
                child: Checkbox(
                  value: task.isDone,
                  onChanged:
                      onToggle == null ? null : (_) => onToggle!(),
                  shape: const CircleBorder(),
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
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      style: titleStyle,
                      child: Text(
                        task.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (metaParts.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: metaParts,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (isOverdue)
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.sm),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: scheme.danger,
                  semanticLabel: 'Overdue',
                ),
              ),
            ?trailing,
          ],
        ),
      ),
    );
  }

  String _semanticsLabel() {
    final state = task.isDone ? 'completed' : 'not completed';
    return '${task.title}, $state';
  }
}

class _DueChip extends StatelessWidget {
  final String label;
  final bool overdue;
  final bool done;
  const _DueChip({
    required this.label,
    required this.overdue,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = done
        ? scheme.muted
        : overdue
            ? scheme.danger
            : scheme.muted;
    final icon = overdue
        ? Icons.warning_amber_rounded
        : Icons.event_outlined;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: color,
            fontWeight: overdue ? FontWeight.w600 : FontWeight.w500,
            decoration: done ? TextDecoration.lineThrough : null,
            decorationColor: scheme.muted,
          ),
        ),
      ],
    );
  }
}

class _NoteHint extends StatelessWidget {
  final String text;
  const _NoteHint({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          Icons.notes,
          size: 14,
          color: theme.colorScheme.muted,
        ),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 240),
          child: Text(
            text.replaceAll('\n', ' '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.muted,
            ),
          ),
        ),
      ],
    );
  }
}
