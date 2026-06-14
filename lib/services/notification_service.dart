import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/task.dart';
import 'storage_service.dart';

const String actionIdDone = 'done';
const String actionIdSnooze15 = 'snooze_15';
const String actionIdSnooze30 = 'snooze_30';
const String actionIdSnooze60 = 'snooze_60';

const String _channelId = 'taskflow_due';
const String _channelName = 'Task reminders';
const String _channelDescription = 'Reminders for tasks with a due time';
// `AndroidInitializationSettings` expects a bare drawable name (no `@drawable/`
// prefix). The emulator was permissive about the prefix; real devices throw
// PlatformException(invalid_icon) at init time. Keep it bare.
const String _smallIconResource = 'ic_stat_taskflow';

const String _batteryPromptedKey = 'battery_opt_prompted';

const NotificationDetails _detailsWithActions = NotificationDetails(
  android: AndroidNotificationDetails(
    _channelId,
    _channelName,
    channelDescription: _channelDescription,
    importance: Importance.high,
    priority: Priority.high,
    actions: <AndroidNotificationAction>[
      AndroidNotificationAction(actionIdDone, 'Done',
          showsUserInterface: false, cancelNotification: true),
      AndroidNotificationAction(actionIdSnooze15, '+15',
          showsUserInterface: false, cancelNotification: true),
      AndroidNotificationAction(actionIdSnooze30, '+30',
          showsUserInterface: false, cancelNotification: true),
      AndroidNotificationAction(actionIdSnooze60, '+60',
          showsUserInterface: false, cancelNotification: true),
    ],
  ),
);

int notificationIdForTaskId(String taskId) {
  var h = 0;
  for (final c in taskId.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return h;
}

Future<void> _initTimezone() async {
  tzdata.initializeTimeZones();
  try {
    final localTz = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localTz.identifier));
  } catch (_) {
    tz.setLocalLocation(tz.UTC);
  }
}

/// Schedule with `exactAllowWhileIdle`, falling back to `inexactAllowWhileIdle`
/// if exact alarms aren't permitted on this device/install. Either way a
/// reminder fires rather than silently dropping.
Future<void> _scheduleWithFallback(
  FlutterLocalNotificationsPlugin plugin, {
  required int id,
  required String? title,
  required String? body,
  required tz.TZDateTime when,
  required String? payload,
}) async {
  try {
    await plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: when,
      notificationDetails: _detailsWithActions,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
    );
  } on PlatformException catch (_) {
    try {
      await plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: when,
        notificationDetails: _detailsWithActions,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: payload,
      );
    } catch (_) {/* truly broken — best-effort */}
  } catch (_) {/* best-effort */}
}

/// Background isolate entry-point. Spawned by the plugin's `ActionBroadcastReceiver`
/// when an action is tapped while the app process is dead or in the background.
@pragma('vm:entry-point')
Future<void> notificationActionBackground(NotificationResponse response) async {
  try {
    DartPluginRegistrant.ensureInitialized();
    await _initTimezone();

    final taskId = response.payload;
    final actionId = response.actionId;
    if (taskId == null || actionId == null) return;

    final plugin = FlutterLocalNotificationsPlugin();
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings(_smallIconResource),
    );
    await plugin.initialize(settings: initSettings);

    final storage = StorageService();
    final tasks = await storage.load();
    final i = tasks.indexWhere((t) => t.id == taskId);
    if (i < 0) return;
    final task = tasks[i];
    final notifId = notificationIdForTaskId(task.id);

    if (actionId == actionIdDone) {
      task.isDone = true;
      task.snoozedUntil = null;
      await storage.save(tasks);
      await plugin.cancel(id: notifId);
      return;
    }

    Duration? snooze;
    if (actionId == actionIdSnooze15) snooze = const Duration(minutes: 15);
    if (actionId == actionIdSnooze30) snooze = const Duration(minutes: 30);
    if (actionId == actionIdSnooze60) snooze = const Duration(minutes: 60);
    if (snooze == null) return;

    task.snoozedUntil = DateTime.now().add(snooze);
    await storage.save(tasks);

    final when = task.effectiveDueAt;
    if (when == null || task.isDone) return;
    final scheduledTz = tz.TZDateTime.from(when, tz.local);
    if (!scheduledTz.isAfter(tz.TZDateTime.now(tz.local))) return;

    await _scheduleWithFallback(
      plugin,
      id: notifId,
      title: task.title,
      body: task.note,
      when: scheduledTz,
      payload: task.id,
    );
  } catch (_) {/* best-effort */}
}

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> Function()? foregroundRehydrate;

  bool _initialized = false;

  static int notificationIdFor(String taskId) => notificationIdForTaskId(taskId);

  Future<void> init() async {
    if (_initialized) return;

    await _initTimezone();

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings(_smallIconResource),
    );
    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onForegroundResponse,
      onDidReceiveBackgroundNotificationResponse: notificationActionBackground,
    );

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(const AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
    ));

    _initialized = true;
  }

  Future<void> _onForegroundResponse(NotificationResponse response) async {
    await notificationActionBackground(response);
    final cb = foregroundRehydrate;
    if (cb != null) {
      try {
        await cb();
      } catch (_) {/* swallow */}
    }
  }

  Future<bool> _hasPermission() async {
    return (await Permission.notification.status).isGranted;
  }

  Future<bool> _ensurePermission() async {
    final status = await Permission.notification.status;
    if (status.isGranted) return true;
    final result = await Permission.notification.request();
    return result.isGranted;
  }

  /// Schedule a notification for [task].
  /// [requestPermission] = true (default): if POST_NOTIFICATIONS isn't granted,
  /// prompt the user (use for user-initiated mutations).
  /// [requestPermission] = false: only schedule if already granted; never prompt
  /// (use for non-user-initiated flows like reschedule-on-load).
  Future<void> schedule(Task task, {bool requestPermission = true}) async {
    final when = task.effectiveDueAt;
    if (when == null || task.isDone) return;
    final scheduledTz = tz.TZDateTime.from(when, tz.local);
    if (!scheduledTz.isAfter(tz.TZDateTime.now(tz.local))) return;

    final granted = requestPermission
        ? await _ensurePermission()
        : await _hasPermission();
    if (!granted) return;

    await _scheduleWithFallback(
      _plugin,
      id: notificationIdFor(task.id),
      title: task.title,
      body: task.note,
      when: scheduledTz,
      payload: task.id,
    );
  }

  Future<void> cancel(String taskId) async {
    try {
      await _plugin.cancel(id: notificationIdFor(taskId));
    } catch (_) {/* best-effort */}
  }

  /// One-time, contextual battery-optimization exemption prompt. Sets a
  /// shared_preferences flag so subsequent calls are no-ops — never re-nag.
  /// Safe to call after every dated-task mutation; dedupe is internal.
  Future<void> maybeRequestBatteryExemption(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    if (prefs.getBool(_batteryPromptedKey) == true) return;
    // Mark prompted BEFORE the await so a dismiss/abort never re-prompts.
    await prefs.setBool(_batteryPromptedKey, true);

    if ((await Permission.ignoreBatteryOptimizations.status).isGranted) return;
    if (!context.mounted) return;

    final allow = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reliable reminders?'),
        content: const Text(
          "Allow TaskFlow Sync to run in the background so reminders fire "
          "on time. You can change this later in your phone's Settings.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Allow'),
          ),
        ],
      ),
    );

    if (allow == true) {
      await Permission.ignoreBatteryOptimizations.request();
    }
  }
}
