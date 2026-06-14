Date: 2026-06-11
Phase 2a notification pipeline (verified):
- TaskStore: two optional callbacks (onSchedule, onCancel) wired the same way as onChanged — service-ignorant.
- NotificationService.init() does tzdata + flutter_timezone (returns TimezoneInfo, use .identifier) + creates one high-importance Android channel 'taskflow_due'.
- POST_NOTIFICATIONS requested contextually inside schedule() via permission_handler — NOT at cold launch.
- Notification ID = stable 31-bit hash of taskId (custom; String.hashCode is not stable across runs).
- Reconcile logic in store: dated && !done → schedule; else → cancel. Add/update/toggle/delete all go through it.
- main(): reschedule on cold load (Android keeps alarms across normal process death but loses them on force-stop + reboot).
- Build req: core library desugaring (com.android.tools:desugar_jdk_libs:2.1.4) — flutter_local_notifications 22.x mandates it.
Rule: never schedule notifications outside NotificationService; always go through the store's callbacks.
