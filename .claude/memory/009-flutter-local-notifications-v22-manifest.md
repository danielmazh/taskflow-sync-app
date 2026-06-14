Date: 2026-06-12
flutter_local_notifications v16+ (we use v22) removed its bundled <receiver> declarations from the plugin manifest.
App MUST declare receivers in its OWN AndroidManifest.xml inside <application>:
- <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />  (required for any zonedSchedule to actually fire)
- ScheduledNotificationBootReceiver + RECEIVE_BOOT_COMPLETED → reboot-survival (Phase 2c).
- ActionBroadcastReceiver → notification actions (Phase 2b).
- ForegroundService → foreground services (out of scope).
Symptom when missing: alarm fires (visible in dumpsys alarm wake stats), BroadcastRecord appears in pm dump, but no NotificationRecord is ever posted — even in the foreground. No plugin logcat traces.
Rule: when upgrading flutter_local_notifications past v15, audit your app manifest against the plugin's README "AndroidManifest.xml setup" section before shipping.
