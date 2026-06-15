# TaskFlow Sync — Development Plan (Simple, UI-First)

> **Guiding principle #1 — Simplicity above all.** No real database, no backend, no codegen, no two of anything that does the same job. Anything that adds complexity is deferred or dropped from v1.
>
> **Guiding principle #2 — Vertical slices, not horizontal layers.** Every phase ends with something you can *run and see*. We don't build "all infrastructure first, UI last." Phase 0 already renders a screen; by the end of Phase 1 you have a fully usable app on the device.

---

## 1. Minimal Architecture

- A single **Flutter** app, **offline-first**, **no server** of any kind.
- **Storage:** one JSON string in `shared_preferences` — not a database. Load once on launch, save on every change.
- **State:** built-in `ChangeNotifier` + `ListenableBuilder` — **zero extra packages**. (Add `provider` only if the app ever grows beyond a few screens.)
- **Notifications:** one package only — `flutter_local_notifications`. No `android_alarm_manager_plus`.
- **Voice & Calendar:** not part of v1. Optional later phases (Section 7).
- **LLM readiness:** a single small seam (`TaskParser`), nothing more.

The three real sources of complexity in an app like this are **database choice**, **two-way calendar sync**, and **OAuth**. This design removes all three from the core.

---

## 2. Tech Stack — Minimal Dependency List

| Package | Role | Introduced in |
|---|---|---|
| *(none — built-in `ChangeNotifier`)* | State management | Phase 1 |
| `shared_preferences` | Persist the task list as JSON | Phase 1 |
| `flutter_local_notifications` | Exact-time reminders + notification action buttons | Phase 2 |
| `timezone` | Required by `zonedSchedule` (timezone-aware scheduling) | Phase 2 |
| `flutter_timezone` | Read the device's local timezone | Phase 2 |
| `permission_handler` | Notification / exact-alarm permission requests | Phase 2 |
| `speech_to_text` | Speech → text input | Optional (Phase 3) |

That's it: **2 packages** for a fully working task app (Phases 0–1), and **5** once reminders are added. No `build_runner`, no DB engine, no external API client in v1.

---

## 3. Project Structure

A flat, pragmatic layout — **not** a 5-layer Clean Architecture. The annotation shows which phase introduces each file, so you can see the structure grow with the slices.

```
taskflow_sync/
├── android/
│   └── app/src/main/AndroidManifest.xml   # permissions added in Phase 2
├── lib/
│   ├── main.dart                          # Phase 0 — app entry, theme, home route
│   │
│   ├── models/
│   │   └── task.dart                      # Phase 0 — Task model + toJson/fromJson
│   │
│   ├── state/
│   │   └── task_store.dart                # Phase 1 — ChangeNotifier holding the list + CRUD
│   │
│   ├── services/
│   │   ├── storage_service.dart           # Phase 1 — load/save JSON via shared_preferences
│   │   ├── task_parser.dart               # Phase 3 — TaskParser interface + PlainParser (lands with voice/freeform text)
│   │   └── notification_service.dart      # Phase 2 — schedule / cancel / snooze + action handling
│   │
│   ├── screens/
│   │   ├── home_screen.dart               # Phase 0 — the single-page dash (mock data first)
│   │   └── edit_task_screen.dart          # Phase 1 — add / edit a task (optional: bottom sheet instead)
│   │
│   └── widgets/
│       ├── task_card.dart                 # Phase 0 — one task row (title, time, done toggle)
│       └── add_task_sheet.dart            # Phase 1 — quick-add bottom sheet from the FAB
│
└── pubspec.yaml
```

Rule of thumb: `models` = plain data, `state` = the single source of truth in memory, `services` = anything that touches the outside world (disk, OS notifications, STT), `screens`/`widgets` = pure UI that reads from `state`. Nothing more layered than that.

---

## 4. Data Model

One model, one storage key.

```dart
class Task {
  final String id;          // uuid or millisecondsSinceEpoch as String
  String title;
  String? note;             // optional free text
  DateTime? dueAt;          // when to remind (optional)
  bool isDone;
  DateTime? snoozedUntil;   // set when the user snoozes

  Task({
    required this.id,
    required this.title,
    this.note,
    this.dueAt,
    this.isDone = false,
    this.snoozedUntil,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'note': note,
    'dueAt': dueAt?.toIso8601String(),
    'isDone': isDone,
    'snoozedUntil': snoozedUntil?.toIso8601String(),
  };

  factory Task.fromJson(Map<String, dynamic> j) => Task(
    id: j['id'],
    title: j['title'],
    note: j['note'],
    dueAt: j['dueAt'] == null ? null : DateTime.parse(j['dueAt']),
    isDone: j['isDone'] ?? false,
    snoozedUntil: j['snoozedUntil'] == null ? null : DateTime.parse(j['snoozedUntil']),
  );
}
```

**Persistence:** `List<Task>` → `jsonEncode` → one string under the key `"tasks"` in `shared_preferences`. Load = one read on launch. Save = one write per change. No schema, no migrations, no queries.

> Conscious limit: great up to a few hundred tasks. If the list ever grows very large, the *only* migration is to `sqflite` (plain SQL, no codegen) — and not before.

---

## 5. Development Phases (each one runs and is visible)

### Phase 0 — Walking Skeleton *(you already see UI here)*
**Goal:** open the app and see the dash, immediately.

- Create the Flutter project.
- `task.dart` (model) and `home_screen.dart` rendering a **hardcoded** list of 3–4 sample tasks via `task_card.dart`.
- Theme, app bar, an empty FAB.

**Deliverable:** a runnable app showing the task dashboard with sample data. No state, no storage, no permissions needed yet.

---

### Phase 1 — Working Task App *(fully usable by the end)*
**Goal:** a real, persistent task manager you can touch. Built as two sub-slices so it's interactive *before* persistence exists.

- **1a — In-memory CRUD (visible immediately):**
  `task_store.dart` as a `ChangeNotifier` holding `List<Task>`. Wire the FAB → `add_task_sheet.dart` to add tasks, tap-to-toggle done on `task_card.dart`, swipe-to-delete, tap-to-edit. `home_screen.dart` rebuilds via `ListenableBuilder`. Everything works in RAM.
- **1b — Persistence (survives restart):**
  `storage_service.dart` loads JSON on launch and saves on every `task_store` change. (The `TaskParser` seam is **deferred to Phase 3** — over structured form fields a `PlainParser` is a no-op; it earns its keep only when a freeform-text path exists. See `.claude/memory/005`.)

**Deliverable:** add / edit / delete / mark-done tasks that persist across restarts. A genuinely usable app — still zero notifications, zero special Android setup.

---

### Phase 2 — Reminders + Snooze
**Goal:** tasks with a time fire an exact, reliable reminder; snooze works from the notification.

- `notification_service.dart` using `flutter_local_notifications` with `zonedSchedule` + `AndroidScheduleMode.exactAllowWhileIdle`.
- Notification action buttons: **Done / +15 / +30 / +60**. Snooze = cancel the existing notification and reschedule.
- Handle taps when the app is terminated via a top-level `@pragma('vm:entry-point')` background handler.
- Add the Android permissions from Section 6.

**Deliverable:** scheduling a task produces an on-time notification; snooze re-arms it without opening the app.

---

### Phase 3 — Voice (optional)
`speech_to_text`: a mic button records → STT → the text flows through `TaskParser` (the seam is introduced **here**, when freeform text first exists) as the new task title.

**Deliverable:** dictate a task instead of typing it.

---

### Phase 4 — Calendar, one-way only (optional, only if truly needed)
Export only: a task with a date creates a calendar **event**. **No** listening for changes, **no** two-way sync, **no** conflict resolution — those are exactly what bring all the complexity back.

**Deliverable:** dated tasks show up in Google Calendar.

---

## 6. Required Android Setup *(only matters from Phase 2 — does not block early UI)*

Even in the simple version these are non-negotiable, or reminders won't fire reliably:

1. **Notification permission (Android 13+):** request `POST_NOTIFICATIONS` at runtime.
2. **Exact alarms:** add `USE_EXACT_ALARM` in the Manifest (allowed for reminder apps under Play policy), or request `SCHEDULE_EXACT_ALARM` at runtime.
3. **Battery-optimization exemption:** a one-time prompt. This is the single thing that stops Doze and aggressive OEMs (Xiaomi / Samsung / Huawei) from killing the scheduler. Without it, reminders will be late on common devices.

These are 3 one-time permission requests, not architectural complexity — but they're the difference between an app that works and one that breaks after a day.

---

## 7. LLM Readiness — a Single Seam, Nothing More

```dart
abstract class TaskParser {
  Task parse(String rawText);
}

// v1 implementation — the simplest possible:
class PlainParser implements TaskParser {
  Task parse(String rawText) =>
      Task(id: DateTime.now().millisecondsSinceEpoch.toString(), title: rawText);
}
```

Later, swap `PlainParser` for an implementation that calls an LLM and returns a fully-populated `Task` (title / note / dueAt / urgency) — **without touching any other code**. This is the one abstraction we allow ourselves, because it costs nothing today.

---

## 8. Decision Summary

| Concern | Decision |
|---|---|
| Database | None — one JSON string in `shared_preferences` |
| Backend | None |
| State management | Built-in `ChangeNotifier` (no package) |
| Notifications | One package (`flutter_local_notifications`) |
| Calendar / Voice | Optional, after the core works |
| Core dependencies | 2 (Phases 0–1), 5 (with reminders) |
| Non-negotiable | 3 Android permissions (Section 6) |
| First visible UI | Phase 0 |
| First fully usable app | End of Phase 1 |

Buildable, maintainable, and understandable by a single developer — while still delivering the core: tasks + exact reminders + snooze.

---

## Phase 7 — Task Labels (post-v1, additive)

Goal: free-form, single-label tagging on tasks, plus search and label-filtering, with labels reflected in statistics. Strictly additive — no new dependency, no new storage mechanism. Each slice runs and is visible on device.

### Locked decisions (carry through every slice)
- **One label per task.** `String? label` on `Task`. Multi-tag is an explicit non-goal.
- **Unlabeled = null or empty/whitespace.** No chip is rendered for unlabeled tasks; "Unlabeled" only appears as an explicit choice in the filter UI and stats breakdown.
- **Stored as typed but trimmed.** Dedup and match **case-insensitively**, preserving the first-seen casing for display.
- **Filter + search are view state** in `HomeScreen` — never in `TaskStore`, never persisted. `TaskStore` stays a pure data holder; it gains only a `labels` getter for the distinct in-use labels.
- **Search spans all tasks** (active + completed), case-insensitive substring over title + note + label.
- **Stats per-label** reuses the existing pure `StatsData` over per-label subsets (plus an "Unlabeled" bucket).
- **Out of scope:** calendar sync, notifications, voice `TaskParser` — none change behavior. Pure, widget-free helpers for search and per-label stats so they are unit-testable.
- **Backward compatibility:** pre-feature tasks lack the field; `fromJson` defaults `label` to null safely (mirrors the existing `calendarEventId` / `completedAt` pattern).

### Slices
- **7a — Label capture + display.** `Task.label` (model + JSON back-compat); add-task sheet gains a free-form label field with reuse suggestions (Flutter's built-in Autocomplete sourced from `TaskStore.labels`, no new dep); `TaskStore.update(label)` and `TaskStore.labels` getter; `TaskCard` shows a small label chip when present; `HomeScreen` wires label through add/edit/undo and feeds `knownLabels` to the sheet.
- **7b — Filter home by label.** HomeScreen-only `String? _activeLabel` view state. A horizontal `ChoiceChip` strip (mirroring the quick-date chip pattern) above the list when ≥1 label exists, with **All / <labels…> / Unlabeled**. Filter `activeTasks` before `_group`. Empty-state copy for "no tasks with this label."
- **7c — Search.** Top-bar search `IconButton` → Flutter `showSearch` + a `SearchDelegate` (no new dep). Pure helper `searchTasks(tasks, query)` in `lib/util/` (case-insensitive substring over title + note + label), unit-tested. Results span all tasks and reuse `TaskCard` (tap → open edit sheet; done state visible).
- **7d — Labels in statistics.** Extend the pure `StatsData` (`lib/util/stats_data.dart`) with a per-label summary (label, active, completed, on-time %), computed by reusing `StatsData.from` over per-label subsets including an "Unlabeled" bucket. Add a "By label" section to `statistics_screen.dart`. Unit-test the per-label aggregation.