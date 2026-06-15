import 'package:flutter/material.dart';

import '../models/task.dart';
import '../services/calendar_sync_service.dart';
import '../services/notification_service.dart';
import '../services/task_parser.dart';
import '../state/task_store.dart';
import '../state/theme_controller.dart';
import '../theme/app_theme.dart';
import '../util/relative_date.dart';
import '../util/task_search.dart';
import '../util/undo_snackbar.dart';
import '../widgets/add_task_sheet.dart';
import '../widgets/task_card.dart';
import '../widgets/voice_capture_sheet.dart';

class HomeScreen extends StatefulWidget {
  final TaskStore store;
  final NotificationService? notifications;
  final TaskParser parser;
  final ThemeController? themeController;
  final CalendarSyncService? calendarSync;
  const HomeScreen({
    super.key,
    required this.store,
    this.notifications,
    this.parser = const PlainParser(),
    this.themeController,
    this.calendarSync,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool get _calendarAvailable =>
      widget.calendarSync?.connection.value.authorized ?? false;

  Future<void> _openAddSheet() async {
    final result = await showAddTaskSheet(
      context,
      calendarAvailable: _calendarAvailable,
      knownLabels: widget.store.labels,
    );
    if (result == null) return;
    final newId = TaskStore.newId();
    widget.store.add(Task(
      id: newId,
      title: result.title,
      note: result.note,
      dueAt: result.dueAt,
      label: result.label,
    ));
    if (result.dueAt != null &&
        widget.notifications != null &&
        mounted) {
      await widget.notifications!.maybeRequestBatteryExemption(context);
    }
    if (result.addToCalendar) {
      final ok = await widget.store.exportTaskToCalendar(newId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok
              ? 'Added to Google Calendar'
              : 'Could not add to Google Calendar'),
        ),
      );
    }
  }

  Future<void> _openVoiceCapture() async {
    final spoken = await showVoiceCaptureSheet(context);
    if (spoken == null || spoken.isEmpty) return;
    final task = widget.parser.parse(spoken);
    if (task.title.isEmpty) return;
    widget.store.add(task);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added: ${task.title}')),
    );
  }

  void _onToggle(Task task) {
    final wasIncomplete = !task.isDone;
    widget.store.toggle(task.id);
    if (wasIncomplete) {
      showUndoSnackBar(
        context,
        message: 'Completed "${_ellipsize(task.title)}"',
        onUndo: () => widget.store.toggle(task.id),
      );
    }
  }

  Future<void> _onExport(Task task) async {
    final ok = await widget.store.exportTaskToCalendar(task.id);
    if (!mounted) return;
    final exported = task.calendarEventId != null;
    final msg = ok
        ? (exported ? 'Calendar event updated' : 'Added to Google Calendar')
        : 'Could not update Google Calendar';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _onRemoveFromCalendar(Task task) async {
    final ok = await widget.store.removeTaskFromCalendar(task.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? 'Removed from Google Calendar'
          : 'Not linked to Google Calendar'),
    ));
  }

  void _onDelete(Task task) {
    final snapshot = Task(
      id: task.id,
      title: task.title,
      note: task.note,
      dueAt: task.dueAt,
      isDone: task.isDone,
      snoozedUntil: task.snoozedUntil,
      completedAt: task.completedAt,
      // calendarEventId intentionally omitted — store.delete tears down the
      // remote event, so on undo the task is a fresh (unlinked) instance.
      label: task.label,
    );
    widget.store.delete(task.id);
    showUndoSnackBar(
      context,
      message: 'Deleted "${_ellipsize(snapshot.title)}"',
      onUndo: () => widget.store.add(snapshot),
    );
  }

  static String _ellipsize(String s, [int max = 36]) =>
      s.length <= max ? s : '${s.substring(0, max - 1)}…';

  Future<void> _openSearch() async {
    final picked = await showSearch<Task?>(
      context: context,
      delegate: _TaskSearchDelegate(store: widget.store),
    );
    if (picked == null || !mounted) return;
    // showSearch popped its own route; reopen the edit sheet on this screen so
    // the user can act on the result they picked.
    await _openEditSheet(picked);
  }

  Future<void> _openEditSheet(Task task) async {
    final result = await showAddTaskSheet(
      context,
      initial: task,
      calendarAvailable: _calendarAvailable,
      knownLabels: widget.store.labels,
    );
    if (result == null) return;
    widget.store.update(
      id: task.id,
      title: result.title,
      note: result.note,
      dueAt: result.dueAt,
      label: result.label,
    );
    if (result.dueAt != null &&
        widget.notifications != null &&
        mounted) {
      await widget.notifications!.maybeRequestBatteryExemption(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TaskFlow Sync'),
        actions: [
          if (widget.calendarSync != null)
            _AccountButton(service: widget.calendarSync!),
          if (widget.themeController != null)
            _ThemeMenuButton(controller: widget.themeController!),
          IconButton(
            tooltip: 'Search tasks',
            onPressed: _openSearch,
            icon: const Icon(Icons.search),
          ),
          IconButton(
            tooltip: 'Add by voice',
            onPressed: _openVoiceCapture,
            icon: const Icon(Icons.mic_none_outlined),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) {
          final now = DateTime.now();
          final activeTasks =
              widget.store.tasks.where((t) => !t.isDone).toList();
          if (activeTasks.isEmpty) {
            final hasAnyTask = widget.store.tasks.isNotEmpty;
            return hasAnyTask
                ? const _EmptyState.allDone()
                : const _EmptyState.nothingYet();
          }
          final grouped = _group(activeTasks, now);
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _SummaryLine(
                  overdue: grouped.overdue.length,
                  dueToday: grouped.today.length,
                ),
              ),
              ..._sectionSliver(
                title: 'Overdue',
                tasks: grouped.overdue,
                now: now,
                tone: _SectionTone.danger,
              ),
              ..._sectionSliver(
                title: 'Today',
                tasks: grouped.today,
                now: now,
              ),
              ..._sectionSliver(
                title: 'Upcoming',
                tasks: grouped.upcoming,
                now: now,
              ),
              ..._sectionSliver(
                title: 'No date',
                tasks: grouped.noDate,
                now: now,
              ),
              const SliverPadding(
                padding: EdgeInsets.only(bottom: 96),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddSheet,
        tooltip: 'Add task',
        child: const Icon(Icons.add),
      ),
    );
  }

  List<Widget> _sectionSliver({
    required String title,
    required List<Task> tasks,
    required DateTime now,
    _SectionTone tone = _SectionTone.normal,
  }) {
    if (tasks.isEmpty) return const [];
    return [
      SliverToBoxAdapter(
        child: _SectionHeader(title: title, count: tasks.length, tone: tone),
      ),
      SliverList.builder(
        itemCount: tasks.length,
        itemBuilder: (context, i) {
          final task = tasks[i];
          return _TaskRowDismissible(
            task: task,
            now: now,
            onTap: () => _openEditSheet(task),
            onToggle: () => _onToggle(task),
            onDelete: () => _onDelete(task),
            calendarSync: widget.calendarSync,
            onExport: () => _onExport(task),
            onRemoveFromCalendar: () => _onRemoveFromCalendar(task),
          );
        },
      ),
    ];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Theme menu
// ─────────────────────────────────────────────────────────────────────────────

class _ThemeMenuButton extends StatelessWidget {
  final ThemeController controller;
  const _ThemeMenuButton({required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final mode = controller.mode;
        final icon = switch (mode) {
          ThemeMode.light => Icons.light_mode_outlined,
          ThemeMode.dark => Icons.dark_mode_outlined,
          ThemeMode.system => Icons.brightness_auto_outlined,
        };
        return PopupMenuButton<ThemeMode>(
          tooltip: 'Theme',
          icon: Icon(icon),
          onSelected: controller.setMode,
          itemBuilder: (ctx) => [
            _menuItem(ctx, ThemeMode.system, 'System', Icons.brightness_auto_outlined, mode),
            _menuItem(ctx, ThemeMode.light, 'Light', Icons.light_mode_outlined, mode),
            _menuItem(ctx, ThemeMode.dark, 'Dark', Icons.dark_mode_outlined, mode),
          ],
        );
      },
    );
  }

  PopupMenuItem<ThemeMode> _menuItem(
    BuildContext context,
    ThemeMode value,
    String label,
    IconData icon,
    ThemeMode current,
  ) {
    final selected = value == current;
    final scheme = Theme.of(context).colorScheme;
    return PopupMenuItem<ThemeMode>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20, color: selected ? scheme.primary : scheme.muted),
          const SizedBox(width: AppSpacing.md),
          Text(
            label,
            style: TextStyle(
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? scheme.primary : null,
            ),
          ),
          const Spacer(),
          if (selected)
            Icon(Icons.check_rounded, size: 18, color: scheme.primary),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Grouping (active tasks only — completed lives in Archive)
// ─────────────────────────────────────────────────────────────────────────────

class _Grouped {
  final List<Task> overdue;
  final List<Task> today;
  final List<Task> upcoming;
  final List<Task> noDate;
  const _Grouped({
    required this.overdue,
    required this.today,
    required this.upcoming,
    required this.noDate,
  });
}

_Grouped _group(List<Task> tasks, DateTime now) {
  final overdue = <Task>[];
  final today = <Task>[];
  final upcoming = <Task>[];
  final noDate = <Task>[];

  for (final t in tasks) {
    switch (bucketFor(effectiveDueAt: t.effectiveDueAt, now: now)) {
      case DueBucket.overdue:
        overdue.add(t);
      case DueBucket.today:
        today.add(t);
      case DueBucket.upcoming:
        upcoming.add(t);
      case DueBucket.none:
        noDate.add(t);
    }
  }

  int byDue(Task a, Task b) =>
      (a.effectiveDueAt ?? DateTime(9999)).compareTo(
        b.effectiveDueAt ?? DateTime(9999),
      );
  overdue.sort(byDue);
  today.sort(byDue);
  upcoming.sort(byDue);
  return _Grouped(
    overdue: overdue,
    today: today,
    upcoming: upcoming,
    noDate: noDate,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Summary line
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryLine extends StatelessWidget {
  final int overdue;
  final int dueToday;
  const _SummaryLine({required this.overdue, required this.dueToday});

  @override
  Widget build(BuildContext context) {
    if (overdue == 0 && dueToday == 0) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final spans = <InlineSpan>[];
    if (overdue > 0) {
      spans.add(TextSpan(
        text: '$overdue overdue',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: scheme.danger,
          fontWeight: FontWeight.w600,
        ),
      ));
    }
    if (dueToday > 0) {
      if (spans.isNotEmpty) {
        spans.add(TextSpan(
          text: ' · ',
          style: theme.textTheme.bodyMedium?.copyWith(color: scheme.muted),
        ));
      }
      spans.add(TextSpan(
        text: '$dueToday due today',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: scheme.muted,
          fontWeight: FontWeight.w500,
        ),
      ));
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Text.rich(TextSpan(children: spans)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section header
// ─────────────────────────────────────────────────────────────────────────────

enum _SectionTone { normal, danger, muted }

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final _SectionTone tone;
  const _SectionHeader({
    required this.title,
    required this.count,
    this.tone = _SectionTone.normal,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = switch (tone) {
      _SectionTone.danger => scheme.danger,
      _SectionTone.muted => scheme.muted,
      _SectionTone.normal => scheme.onSurface,
    };
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
              color: color,
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
// Dismissible row wrapper
// ─────────────────────────────────────────────────────────────────────────────

class _TaskRowDismissible extends StatelessWidget {
  final Task task;
  final DateTime now;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final CalendarSyncService? calendarSync;
  final VoidCallback onExport;
  final VoidCallback onRemoveFromCalendar;
  const _TaskRowDismissible({
    required this.task,
    required this.now,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
    required this.onExport,
    required this.onRemoveFromCalendar,
    this.calendarSync,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.endToStart,
      background: const _DismissBackground(),
      onDismissed: (_) => onDelete(),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        builder: (context, t, child) => Opacity(opacity: t, child: child),
        child: InkWell(
          onTap: onTap,
          child: _TaskRowContent(
            task: task,
            now: now,
            onToggle: onToggle,
            calendarSync: calendarSync,
            onExport: onExport,
            onRemoveFromCalendar: onRemoveFromCalendar,
          ),
        ),
      ),
    );
  }
}

/// TaskCard + the per-row calendar trailing (indicator + menu), rebuilt when
/// the CalendarSyncService's connection state changes so menu visibility is
/// always in sync with authorization.
class _TaskRowContent extends StatelessWidget {
  final Task task;
  final DateTime now;
  final VoidCallback onToggle;
  final CalendarSyncService? calendarSync;
  final VoidCallback onExport;
  final VoidCallback onRemoveFromCalendar;
  const _TaskRowContent({
    required this.task,
    required this.now,
    required this.onToggle,
    required this.calendarSync,
    required this.onExport,
    required this.onRemoveFromCalendar,
  });

  @override
  Widget build(BuildContext context) {
    final sync = calendarSync;
    if (sync == null) {
      return TaskCard(task: task, onToggle: onToggle, now: now);
    }
    return ValueListenableBuilder<CalendarConnection>(
      valueListenable: sync.connection,
      builder: (context, conn, _) {
        final isExported = task.calendarEventId != null;
        final hasDue = task.effectiveDueAt != null;
        // Export needs a due time + authorization. Update/Remove only need
        // authorization — the event already exists on the server.
        final canExport = conn.authorized && hasDue && !isExported;
        final canManageExisting = conn.authorized && isExported;
        if (!isExported && !canExport && !canManageExisting) {
          return TaskCard(task: task, onToggle: onToggle, now: now);
        }
        return TaskCard(
          task: task,
          onToggle: onToggle,
          now: now,
          trailing: _CalendarRowTrailing(
            isExported: isExported,
            canExport: canExport,
            canManageExisting: canManageExisting,
            onExport: onExport,
            onRemoveFromCalendar: onRemoveFromCalendar,
          ),
        );
      },
    );
  }
}

class _CalendarRowTrailing extends StatelessWidget {
  final bool isExported;
  final bool canExport;
  final bool canManageExisting;
  final VoidCallback onExport;
  final VoidCallback onRemoveFromCalendar;
  const _CalendarRowTrailing({
    required this.isExported,
    required this.canExport,
    required this.canManageExisting,
    required this.onExport,
    required this.onRemoveFromCalendar,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final children = <Widget>[];
    if (isExported) {
      children.add(Padding(
        padding: const EdgeInsets.only(left: AppSpacing.sm),
        child: Tooltip(
          message: 'Exported to Google Calendar',
          child: Icon(
            Icons.event_available_rounded,
            size: 18,
            color: scheme.primary,
          ),
        ),
      ));
    }
    final showMenu = canExport || canManageExisting;
    if (showMenu) {
      children.add(PopupMenuButton<String>(
        tooltip: 'Calendar actions',
        icon: const Icon(Icons.more_vert),
        onSelected: (v) {
          switch (v) {
            case 'export':
            case 'update':
              onExport();
              break;
            case 'remove':
              onRemoveFromCalendar();
              break;
          }
        },
        itemBuilder: (ctx) {
          if (canManageExisting) {
            return const [
              PopupMenuItem<String>(
                value: 'update',
                child: ListTile(
                  leading: Icon(Icons.sync),
                  title: Text('Update in calendar'),
                  dense: true,
                ),
              ),
              PopupMenuItem<String>(
                value: 'remove',
                child: ListTile(
                  leading: Icon(Icons.event_busy_outlined),
                  title: Text('Remove from calendar'),
                  dense: true,
                ),
              ),
            ];
          }
          return const [
            PopupMenuItem<String>(
              value: 'export',
              child: ListTile(
                leading: Icon(Icons.event_available_outlined),
                title: Text('Export to calendar'),
                dense: true,
              ),
            ),
          ];
        },
      ));
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}

class _DismissBackground extends StatelessWidget {
  const _DismissBackground();
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      alignment: Alignment.centerRight,
      color: scheme.errorContainer,
      child: Icon(
        Icons.delete_outline,
        color: scheme.onErrorContainer,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty states
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String headline;
  final String hint;
  const _EmptyState({
    required this.icon,
    required this.headline,
    required this.hint,
  });
  const _EmptyState.nothingYet()
      : icon = Icons.checklist_rounded,
        headline = 'No tasks yet',
        hint = 'Tap + to add one, or the mic to dictate.';
  const _EmptyState.allDone()
      : icon = Icons.task_alt_rounded,
        headline = 'All done',
        hint = 'Nothing left for now — completed tasks live in Archive.';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isAllDone = headline == 'All done';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 64,
              color: isAllDone ? scheme.primary : scheme.muted,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              headline,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              hint,
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

// ─────────────────────────────────────────────────────────────────────────────
// Google account button (Phase 4c)
// ─────────────────────────────────────────────────────────────────────────────

/// AppBar account button. Signed-out: generic icon → tap = `connect()`.
/// Signed-in: avatar (photoUrl, fallback to initials) → tap opens a menu
/// showing the user, the Google Calendar status, and a Disconnect action.
class _AccountButton extends StatelessWidget {
  final CalendarSyncService service;
  const _AccountButton({required this.service});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<CalendarConnection>(
      valueListenable: service.connection,
      builder: (context, conn, _) {
        if (!conn.isConnected) {
          return IconButton(
            tooltip: 'Sign in with Google',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => service.connect(),
          );
        }
        return PopupMenuButton<String>(
          tooltip: 'Account — ${conn.email ?? ''}',
          position: PopupMenuPosition.under,
          offset: const Offset(0, 8),
          icon: _AccountAvatar(conn: conn, size: 28),
          onSelected: (v) async {
            switch (v) {
              case 'reauth':
                await service.connect();
                break;
              case 'disconnect':
                await service.disconnect();
                break;
            }
          },
          itemBuilder: (ctx) => _accountMenuItems(ctx, conn),
        );
      },
    );
  }

  List<PopupMenuEntry<String>> _accountMenuItems(
    BuildContext context,
    CalendarConnection conn,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return [
      PopupMenuItem<String>(
        enabled: false,
        padding: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              _AccountAvatar(conn: conn, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      conn.displayName?.trim().isNotEmpty == true
                          ? conn.displayName!
                          : (conn.email ?? 'Signed in'),
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (conn.email != null &&
                        conn.email != conn.displayName) ...[
                      const SizedBox(height: 2),
                      Text(
                        conn.email!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.muted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      const PopupMenuDivider(),
      PopupMenuItem<String>(
        enabled: false,
        padding: EdgeInsets.zero,
        child: ListTile(
          dense: true,
          leading: Icon(
            conn.authorized
                ? Icons.event_available_outlined
                : Icons.event_busy_outlined,
            color: conn.authorized ? scheme.primary : scheme.muted,
          ),
          title: const Text('Google Calendar'),
          subtitle: Text(
            conn.authorized ? 'Connected' : 'Sign-in only — scope not granted',
            style: theme.textTheme.bodySmall?.copyWith(
              color: conn.authorized ? scheme.primary : scheme.muted,
            ),
          ),
        ),
      ),
      if (!conn.authorized)
        const PopupMenuItem<String>(
          value: 'reauth',
          child: ListTile(
            leading: Icon(Icons.lock_open_outlined),
            title: Text('Grant calendar access'),
            dense: true,
          ),
        ),
      const PopupMenuDivider(),
      const PopupMenuItem<String>(
        value: 'disconnect',
        child: ListTile(
          leading: Icon(Icons.logout),
          title: Text('Disconnect'),
          dense: true,
        ),
      ),
    ];
  }
}

class _AccountAvatar extends StatelessWidget {
  final CalendarConnection conn;
  final double size;
  const _AccountAvatar({required this.conn, this.size = 28});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final url = conn.photoUrl;
    final initials = _initialsFor(conn);
    final radius = size / 2;
    return CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primaryContainer,
      foregroundColor: scheme.onPrimaryContainer,
      backgroundImage: url != null ? NetworkImage(url) : null,
      child: url == null
          ? (initials.isNotEmpty
              ? Text(
                  initials,
                  style: TextStyle(
                    fontSize: size * 0.42,
                    fontWeight: FontWeight.w600,
                  ),
                )
              : Icon(Icons.person, size: size * 0.6))
          : null,
    );
  }

  static String _initialsFor(CalendarConnection conn) {
    final source =
        (conn.displayName?.trim().isNotEmpty == true ? conn.displayName : conn.email) ??
            '';
    if (source.isEmpty) return '';
    final parts = source.split(RegExp(r'[\s@._-]+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return source.substring(0, 1).toUpperCase();
    final first = parts.first[0];
    final second = parts.length > 1 ? parts.elementAt(1)[0] : '';
    return (first + second).toUpperCase();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Search (Phase 7c) — Flutter's built-in showSearch + a SearchDelegate
// ─────────────────────────────────────────────────────────────────────────────

/// Searches every task in the store (active AND completed) via [searchTasks].
/// Returns the tapped [Task] back to the caller — the caller is responsible
/// for opening an edit sheet on it. Read-only rows: no toggle, no dismiss,
/// no calendar trailing — that machinery belongs to the live list.
class _TaskSearchDelegate extends SearchDelegate<Task?> {
  final TaskStore store;
  _TaskSearchDelegate({required this.store})
      : super(searchFieldLabel: 'Search tasks');

  @override
  List<Widget>? buildActions(BuildContext context) {
    if (query.isEmpty) return null;
    return [
      IconButton(
        tooltip: 'Clear',
        icon: const Icon(Icons.clear),
        onPressed: () => query = '',
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      tooltip: 'Back',
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) => _resultsBody(context);

  @override
  Widget buildResults(BuildContext context) => _resultsBody(context);

  Widget _resultsBody(BuildContext context) {
    if (query.trim().isEmpty) {
      return const _SearchHint(
        icon: Icons.search,
        text: 'Type to search by title, note, or label.',
      );
    }
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final hits = searchTasks(store.tasks, query);
        if (hits.isEmpty) {
          return const _SearchHint(
            icon: Icons.search_off,
            text: 'No matches.',
          );
        }
        return ListView.builder(
          itemCount: hits.length,
          itemBuilder: (context, i) {
            final task = hits[i];
            return InkWell(
              onTap: () => close(context, task),
              child: TaskCard(task: task),
            );
          },
        );
      },
    );
  }
}

class _SearchHint extends StatelessWidget {
  final IconData icon;
  final String text;
  const _SearchHint({required this.icon, required this.text});

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
            Icon(icon, size: 56, color: scheme.muted),
            const SizedBox(height: AppSpacing.lg),
            Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.muted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
