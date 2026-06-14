import 'dart:async';

import 'package:flutter/material.dart';

import 'services/calendar_sync_service.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'state/task_store.dart';
import 'state/theme_controller.dart';
import 'theme/app_theme.dart';
import 'widgets/app_shell.dart';

/// Google **web** client ID for Phase 4 calendar export. Web client IDs are
/// public identifiers — safe to embed in source. The matching client *secret*
/// must never appear here; google_sign_in's Android flow doesn't need it.
/// Source: .claude/env/client_secret_…(web).json → web.client_id
const String _googleWebClientId =
    '552734224992-2hgq407fd6pp5elmov50kgqsi53a8jiu.apps.googleusercontent.com';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storage = StorageService();
  final notifications = NotificationService();
  await notifications.init();

  final calendarSync = CalendarSyncService(
    serverClientId: _googleWebClientId,
    loadConnectedFlag: storage.loadCalendarConnected,
    saveConnectedFlag: storage.saveCalendarConnected,
  );
  unawaited(calendarSync.init());

  final initial = await storage.load();
  final store = TaskStore(
    seed: initial,
    onChanged: storage.save,
    onSchedule: notifications.schedule,
    onCancel: notifications.cancel,
    onSyncUpsert: calendarSync.upsertEvent,
    onSyncDelete: calendarSync.deleteEvent,
    onSyncLinkStatus: (id) async {
      final s = await calendarSync.eventLinkStatus(id);
      return switch (s) {
        EventLinkStatus.exists => TaskCalendarLinkStatus.exists,
        EventLinkStatus.gone => TaskCalendarLinkStatus.gone,
        EventLinkStatus.unknown => TaskCalendarLinkStatus.unknown,
      };
    },
    isCalendarAuthorized: () => calendarSync.isAuthorized,
  );

  final initialThemeMode = await storage.loadThemeMode();
  final themeController = ThemeController(
    initial: initialThemeMode,
    onChanged: storage.saveThemeMode,
  );

  // Foreground action taps update disk via the same handler the background
  // isolate uses; this closure pulls the new state back into the store.
  Future<void> rehydrate() async {
    final fresh = await storage.load();
    store.replaceAll(fresh);
  }

  /// Resume hook: refresh persisted state and then ask Calendar whether each
  /// linked event still exists. The store's own throttle keeps rapid resumes
  /// from hammering the API; auth/offline cases short-circuit cheaply.
  Future<void> onResume() async {
    await rehydrate();
    unawaited(store.reconcileCalendarLinks());
  }

  notifications.foregroundRehydrate = rehydrate;

  // Re-arm notifications for already-due tasks on cold start. Non-user-initiated:
  // pass requestPermission: false so a denied user never gets re-prompted at boot.
  for (final t in initial) {
    if (t.effectiveDueAt != null && !t.isDone) {
      notifications.schedule(t, requestPermission: false);
    }
  }

  final lifecycle = _LifecycleHandler(onResumed: onResume);
  WidgetsBinding.instance.addObserver(lifecycle);

  runApp(TaskFlowApp(
    store: store,
    notifications: notifications,
    themeController: themeController,
    calendarSync: calendarSync,
  ));
}

class _LifecycleHandler extends WidgetsBindingObserver {
  final Future<void> Function() onResumed;
  _LifecycleHandler({required this.onResumed});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      onResumed();
    }
  }
}

class TaskFlowApp extends StatelessWidget {
  final TaskStore store;
  final NotificationService? notifications;
  final ThemeController? themeController;
  final CalendarSyncService? calendarSync;
  const TaskFlowApp({
    super.key,
    required this.store,
    this.notifications,
    this.themeController,
    this.calendarSync,
  });

  @override
  Widget build(BuildContext context) {
    final controller = themeController ??
        ThemeController(initial: ThemeMode.system);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => MaterialApp(
        title: 'TaskFlow Sync',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: controller.mode,
        home: AppShell(
          store: store,
          notifications: notifications,
          themeController: controller,
          calendarSync: calendarSync,
        ),
      ),
    );
  }
}
