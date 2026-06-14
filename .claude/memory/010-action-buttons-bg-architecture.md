Date: 2026-06-12
Phase 2b notification-action architecture (verified):
Background isolate writer + shared_preferences bridge + foreground rehydrate-on-resume — no isolate ports.
- Top-level @pragma('vm:entry-point') notificationActionBackground re-inits DartPluginRegistrant + timezone + the plugin in its own isolate, builds a fresh StorageService, mutates the task, writes back, and either cancels (Done) or zonedSchedules at effectiveDueAt (Snooze).
- Foreground action taps route to NotificationService._onForegroundResponse which calls the same top-level handler then triggers a closure (set by main()) that reloads via storage and store.replaceAll.
- task.effectiveDueAt = snoozedUntil ?? dueAt is the single source of truth — used by schedule(), reschedule-on-load, the bg handler, AND the UI's TaskCard display.
- WidgetsBindingObserver in main hooks AppLifecycleState.resumed to rehydrate.
GOTCHA: SharedPreferences caches per-isolate. StorageService.load() MUST call prefs.reload() before reading, or the foreground keeps seeing pre-action state. Built in.
Rule: never let the foreground store skip prefs.reload() in load(); never bypass the foregroundRehydrate closure after a foreground action tap.
