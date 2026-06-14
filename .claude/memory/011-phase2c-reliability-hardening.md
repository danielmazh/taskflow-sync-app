Date: 2026-06-12
Phase 2c reliability hardening (verified):
- AndroidScheduleMode.exactAllowWhileIdle via USE_EXACT_ALARM (install-time, normal-protection; no runtime prompt). On PlatformException → automatic fallback to inexactAllowWhileIdle. Same try/fallback in NotificationService.schedule() AND the bg snooze handler (shared helper _scheduleWithFallback).
- ScheduledNotificationBootReceiver + RECEIVE_BOOT_COMPLETED for reboot survival. The reschedule-on-load in main() complements it; together they handle reboot + force-stop.
- schedule(task, {requestPermission = true}). The reschedule-on-load loop passes requestPermission: false so the cold-start path never prompts.
- Battery-opt prompt: NotificationService.maybeRequestBatteryExemption(BuildContext). Flag battery_opt_prompted in shared_preferences set BEFORE the dialog so a dismiss never re-nags. Called from HomeScreen after add/update of any dated task.
- Small icon: @drawable/ic_stat_taskflow (vector, white-on-transparent checkbox+check).
Rule: never pull exact-alarm into a path that runs without user context; never prompt for permissions at cold start; never call zonedSchedule outside _scheduleWithFallback (silent fire-drop on exact-denied if you forget).
