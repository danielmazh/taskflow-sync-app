Date: 2026-06-11
Phase 1 persistence architecture (signed off).
TaskStore is decoupled from StorageService via an optional onChanged callback (typedef TaskPersist). main() wires storage.save into the store. Every mutation calls notifyListeners() THEN _persist() — fire-and-forget, errors swallowed. Storage layer = single shared_preferences key 'tasks' (Android stores as 'flutter.tasks'); value = jsonEncode of toJson list. load() is fail-safe: missing key, non-list payload, or any parse error → empty list, never crashes. main() awaits load BEFORE first frame so the home never flickers empty-then-populated.
Rule: Phase 2+ wires new behaviors (notifications, sync, etc.) via additional optional callbacks on TaskStore — keep the store ignorant of services.
