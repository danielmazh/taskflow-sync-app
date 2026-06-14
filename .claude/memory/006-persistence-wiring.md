Date: 2026-06-11
Persistence: shared_preferences ^2.5.5, single key 'tasks' (Android stores it as 'flutter.tasks' due to plugin prefix — transparent to Dart code).
Pattern: TaskStore holds an optional onChanged callback; main() wires storage.save into it. Every mutation calls notifyListeners() THEN _persist() (fire-and-forget, errors swallowed). No queue, no debouncer — single user, human-paced.
Load: StorageService.load() catches every failure (missing key, non-list JSON, parse errors) and returns []. Never crashes the app.
Boot: main() is async, WidgetsFlutterBinding.ensureInitialized() before SharedPreferences.getInstance(); await load() BEFORE first frame so the home screen never flickers from empty to populated.
Rule: All persistence flows through StorageService; never reach into SharedPreferences directly. Don't add a debouncer unless write volume actually warrants it.
