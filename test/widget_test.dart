import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:taskflow_sync/main.dart';
import 'package:taskflow_sync/models/task.dart';
import 'package:taskflow_sync/services/notification_service.dart';
import 'package:taskflow_sync/services/storage_service.dart';
import 'package:taskflow_sync/services/task_parser.dart';
import 'package:taskflow_sync/state/task_store.dart';
import 'package:taskflow_sync/widgets/add_task_sheet.dart';
import 'package:taskflow_sync/util/motivational_messages.dart';
import 'package:taskflow_sync/util/relative_date.dart';
import 'package:taskflow_sync/util/stats_data.dart';
import 'package:taskflow_sync/util/task_outcome.dart';
import 'package:taskflow_sync/util/week_start.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Home screen renders app bar and seeded tasks',
      (WidgetTester tester) async {
    final store = TaskStore(seed: sampleSeed());
    await tester.pumpWidget(TaskFlowApp(store: store));

    expect(find.text('TaskFlow Sync'), findsOneWidget);
    expect(find.text('Buy groceries'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('Toggle marks a task done and back', (WidgetTester tester) async {
    final store = TaskStore(seed: sampleSeed());
    await tester.pumpWidget(TaskFlowApp(store: store));

    final notDone = store.tasks.firstWhere((t) => !t.isDone);
    store.toggle(notDone.id);
    await tester.pump();
    expect(store.tasks.firstWhere((t) => t.id == notDone.id).isDone, isTrue);

    store.toggle(notDone.id);
    await tester.pump();
    expect(store.tasks.firstWhere((t) => t.id == notDone.id).isDone, isFalse);
  });

  testWidgets('Add and delete update the list', (WidgetTester tester) async {
    final store = TaskStore();
    await tester.pumpWidget(TaskFlowApp(store: store));

    expect(find.text('No tasks yet'), findsOneWidget);

    store.add(Task(id: 'x', title: 'Read a book'));
    await tester.pump();
    expect(find.text('Read a book'), findsOneWidget);

    store.delete('x');
    await tester.pump();
    expect(find.text('Read a book'), findsNothing);
  });

  testWidgets(
      'Home shows All done when every task is completed (no Completed section on Home)',
      (WidgetTester tester) async {
    final store = TaskStore(seed: [
      Task(id: 'a', title: 'Done thing', isDone: true),
    ]);
    await tester.pumpWidget(TaskFlowApp(store: store));

    expect(find.text('All done'), findsOneWidget);
    // Completed lives in Archive now, not on Home.
    expect(find.text('Completed'), findsNothing);
  });

  test('notificationIdFor is deterministic for the same task id', () {
    expect(
      NotificationService.notificationIdFor('task-1781205580622682'),
      NotificationService.notificationIdFor('task-1781205580622682'),
    );
  });

  test('effectiveDueAt prefers snoozedUntil over dueAt', () {
    final due = DateTime(2026, 6, 12, 9, 0);
    final snooze = DateTime(2026, 6, 12, 9, 15);
    expect(Task(id: 'a', title: 't').effectiveDueAt, isNull);
    expect(Task(id: 'b', title: 't', dueAt: due).effectiveDueAt, due);
    expect(
      Task(id: 'c', title: 't', dueAt: due, snoozedUntil: snooze).effectiveDueAt,
      snooze,
    );
  });

  testWidgets('replaceAll swaps the in-memory list and notifies listeners',
      (WidgetTester tester) async {
    final store = TaskStore(seed: [Task(id: 'a', title: 'one')]);
    var notified = 0;
    store.addListener(() => notified++);

    store.replaceAll([Task(id: 'b', title: 'two')]);
    expect(store.tasks.length, 1);
    expect(store.tasks.single.id, 'b');
    expect(notified, 1);
  });

  test('PlainParser copies raw text into title and leaves rest null', () {
    const parser = PlainParser();
    final task = parser.parse('  Buy milk  ');
    expect(task.title, 'Buy milk');
    expect(task.note, isNull);
    expect(task.dueAt, isNull);
    expect(task.isDone, isFalse);
    expect(task.id, isNotEmpty);
  });

  test('StorageService round-trips tasks across save → load', () async {
    final storage = StorageService();

    expect(await storage.load(), isEmpty);

    final tasks = [
      Task(
        id: 'a',
        title: 'Hello',
        note: 'with note',
        dueAt: DateTime(2026, 1, 1, 9, 30),
      ),
      Task(id: 'b', title: 'Done thing', isDone: true),
    ];
    await storage.save(tasks);

    final loaded = await storage.load();
    expect(loaded.length, 2);
    expect(loaded[0].id, 'a');
    expect(loaded[0].title, 'Hello');
    expect(loaded[0].note, 'with note');
    expect(loaded[0].dueAt, DateTime(2026, 1, 1, 9, 30));
    expect(loaded[0].isDone, isFalse);
    expect(loaded[1].id, 'b');
    expect(loaded[1].isDone, isTrue);
    expect(loaded[1].dueAt, isNull);
  });

  group('formatRelativeDue', () {
    final now = DateTime(2026, 7, 15, 14, 30); // Wed 15 Jul 14:30
    test('overdue minutes', () {
      expect(
        formatRelativeDue(now.subtract(const Duration(minutes: 5)), now),
        'Overdue · 5m ago',
      );
    });
    test('overdue hours', () {
      expect(
        formatRelativeDue(now.subtract(const Duration(hours: 2)), now),
        'Overdue · 2h ago',
      );
    });
    test('overdue days', () {
      expect(
        formatRelativeDue(now.subtract(const Duration(days: 3)), now),
        'Overdue · 3d ago',
      );
    });
    test('today', () {
      expect(
        formatRelativeDue(DateTime(2026, 7, 15, 18, 30), now),
        'Today 18:30',
      );
    });
    test('tomorrow', () {
      expect(
        formatRelativeDue(DateTime(2026, 7, 16, 9, 0), now),
        'Tomorrow 09:00',
      );
    });
    test('within a week — weekday + time', () {
      expect(
        formatRelativeDue(DateTime(2026, 7, 19, 15, 0), now),
        'Sun 15:00',
      );
    });
    test('later this year — weekday + day + month', () {
      expect(
        formatRelativeDue(DateTime(2026, 9, 1, 10, 0), now),
        'Tue 1 Sep',
      );
    });
    test('different year — includes year', () {
      expect(
        formatRelativeDue(DateTime(2027, 1, 5, 10, 0), now),
        'Tue 5 Jan 2027',
      );
    });
  });

  group('bucketFor', () {
    final now = DateTime(2026, 7, 15, 14, 30);
    test('null due → none', () {
      expect(
        bucketFor(effectiveDueAt: null, now: now),
        DueBucket.none,
      );
    });
    test('past → overdue', () {
      expect(
        bucketFor(
          effectiveDueAt: now.subtract(const Duration(minutes: 1)),
          now: now,
        ),
        DueBucket.overdue,
      );
    });
    test('future-same-day → today', () {
      expect(
        bucketFor(
          effectiveDueAt: DateTime(2026, 7, 15, 23, 0),
          now: now,
        ),
        DueBucket.today,
      );
    });
    test('next-day → upcoming', () {
      expect(
        bucketFor(
          effectiveDueAt: DateTime(2026, 7, 16, 9, 0),
          now: now,
        ),
        DueBucket.upcoming,
      );
    });
  });

  group('Task.completedAt + toggle stamping', () {
    test('toggle stamps completedAt on complete and clears on un-complete', () {
      final store = TaskStore(seed: [Task(id: 'a', title: 't')]);
      expect(store.tasks.single.completedAt, isNull);

      store.toggle('a');
      expect(store.tasks.single.isDone, isTrue);
      expect(store.tasks.single.completedAt, isNotNull);

      store.toggle('a');
      expect(store.tasks.single.isDone, isFalse);
      expect(store.tasks.single.completedAt, isNull);
    });

    test('Task.fromJson with missing completedAt defaults to null (legacy)', () {
      final t = Task.fromJson({
        'id': 'legacy',
        'title': 'Old completed task',
        'isDone': true,
      });
      expect(t.isDone, isTrue);
      expect(t.completedAt, isNull);
    });

    test('StorageService round-trips completedAt', () async {
      final storage = StorageService();
      final completed = DateTime(2026, 6, 12, 14, 0);
      await storage.save([
        Task(
          id: 'c',
          title: 'done',
          isDone: true,
          dueAt: DateTime(2026, 6, 12, 9, 0),
          completedAt: completed,
        ),
      ]);
      final loaded = await storage.load();
      expect(loaded.single.completedAt, completed);
    });
  });

  group('outcomeFor', () {
    final now = DateTime(2026, 6, 12, 12, 0);
    final due = DateTime(2026, 6, 12, 9, 0);

    test('onTime — done with no due', () {
      expect(
        outcomeFor(Task(id: 'a', title: 't', isDone: true), now),
        TaskOutcome.onTime,
      );
    });
    test('onTime — done at exactly due time', () {
      expect(
        outcomeFor(
          Task(
            id: 'a',
            title: 't',
            isDone: true,
            dueAt: due,
            completedAt: due,
          ),
          now,
        ),
        TaskOutcome.onTime,
      );
    });
    test('onTime — done before due', () {
      expect(
        outcomeFor(
          Task(
            id: 'a',
            title: 't',
            isDone: true,
            dueAt: due,
            completedAt: due.subtract(const Duration(minutes: 30)),
          ),
          now,
        ),
        TaskOutcome.onTime,
      );
    });
    test('late — done after due', () {
      expect(
        outcomeFor(
          Task(
            id: 'a',
            title: 't',
            isDone: true,
            dueAt: due,
            completedAt: due.add(const Duration(hours: 2)),
          ),
          now,
        ),
        TaskOutcome.late,
      );
    });
    test('onTime — legacy isDone with null completedAt', () {
      expect(
        outcomeFor(
          Task(id: 'a', title: 't', isDone: true, dueAt: due),
          now,
        ),
        TaskOutcome.onTime,
      );
    });
    test('missed — undone past due', () {
      expect(
        outcomeFor(Task(id: 'a', title: 't', dueAt: due), now),
        TaskOutcome.missed,
      );
    });
    test('pending — undone future due', () {
      expect(
        outcomeFor(
          Task(
            id: 'a',
            title: 't',
            dueAt: now.add(const Duration(hours: 1)),
          ),
          now,
        ),
        TaskOutcome.pending,
      );
    });
    test('pending — undone no due', () {
      expect(
        outcomeFor(Task(id: 'a', title: 't'), now),
        TaskOutcome.pending,
      );
    });
  });

  group('startOfWeekSunday', () {
    test('Sunday → same day at midnight', () {
      // 2026-06-07 was a Sunday.
      final sun = DateTime(2026, 6, 7, 14, 30);
      expect(startOfWeekSunday(sun), DateTime(2026, 6, 7));
    });
    test('Monday → previous day (Sunday)', () {
      // 2026-06-08 Monday.
      final mon = DateTime(2026, 6, 8, 9, 0);
      expect(startOfWeekSunday(mon), DateTime(2026, 6, 7));
    });
    test('Saturday → previous Sunday', () {
      // 2026-06-13 Saturday.
      final sat = DateTime(2026, 6, 13, 23, 59);
      expect(startOfWeekSunday(sat), DateTime(2026, 6, 7));
    });
    test('weekdaySundayIndex Sun..Sat → 0..6', () {
      expect(weekdaySundayIndex(DateTime(2026, 6, 7)), 0);  // Sun
      expect(weekdaySundayIndex(DateTime(2026, 6, 8)), 1);  // Mon
      expect(weekdaySundayIndex(DateTime(2026, 6, 9)), 2);  // Tue
      expect(weekdaySundayIndex(DateTime(2026, 6, 10)), 3); // Wed
      expect(weekdaySundayIndex(DateTime(2026, 6, 11)), 4); // Thu
      expect(weekdaySundayIndex(DateTime(2026, 6, 12)), 5); // Fri
      expect(weekdaySundayIndex(DateTime(2026, 6, 13)), 6); // Sat
    });
  });

  group('StatsData.from', () {
    // Friday 2026-06-12, week starts Sunday 2026-06-07.
    final now = DateTime(2026, 6, 12, 12, 0);

    test('counts active/completed/onTime/late/missed correctly', () {
      final tasks = [
        // Active (pending future due) — counts as active, no outcome bucket.
        Task(
          id: 'p',
          title: 'pending',
          dueAt: now.add(const Duration(days: 1)),
        ),
        // Active (no due) — active, pending.
        Task(id: 'n', title: 'no-due'),
        // Missed — active, past due.
        Task(
          id: 'm',
          title: 'missed',
          dueAt: now.subtract(const Duration(hours: 1)),
        ),
        // On-time with deadline.
        Task(
          id: 'o',
          title: 'on-time',
          isDone: true,
          dueAt: DateTime(2026, 6, 10, 9, 0),
          completedAt: DateTime(2026, 6, 10, 8, 0),
        ),
        // Late.
        Task(
          id: 'l',
          title: 'late',
          isDone: true,
          dueAt: DateTime(2026, 6, 10, 9, 0),
          completedAt: DateTime(2026, 6, 10, 11, 0),
        ),
        // Done without deadline — completed counts, ring excludes it.
        Task(
          id: 'd',
          title: 'done-no-due',
          isDone: true,
          completedAt: DateTime(2026, 6, 11, 10, 0),
        ),
      ];
      final s = StatsData.from(tasks, now);
      expect(s.active, 3);
      expect(s.completed, 3);
      expect(s.onTime, 1);
      expect(s.late, 1);
      expect(s.missed, 1);
      expect(s.hasOnTimeData, isTrue);
      // 1 on-time / (1 on-time + 1 late + 1 missed) → 33%
      expect(s.onTimePct, 33);
    });

    test('missed-only → hasOnTimeData true, pct = 0', () {
      final tasks = [
        Task(
          id: 'm',
          title: 'missed',
          dueAt: now.subtract(const Duration(hours: 1)),
        ),
      ];
      final s = StatsData.from(tasks, now);
      expect(s.missed, 1);
      expect(s.hasOnTimeData, isTrue);
      expect(s.onTimePct, 0);
    });

    test('on-time-only → 100%', () {
      final tasks = [
        Task(
          id: 'o',
          title: 'o',
          isDone: true,
          dueAt: DateTime(2026, 6, 11, 9),
          completedAt: DateTime(2026, 6, 11, 8),
        ),
      ];
      final s = StatsData.from(tasks, now);
      expect(s.onTime, 1);
      expect(s.onTimePct, 100);
    });

    test('weeklyBars bucket by completedAt weekday Sun..Sat', () {
      final tasks = [
        // Sun 2026-06-07.
        Task(
          id: '1',
          title: 't',
          isDone: true,
          completedAt: DateTime(2026, 6, 7, 10),
        ),
        Task(
          id: '2',
          title: 't',
          isDone: true,
          completedAt: DateTime(2026, 6, 7, 12),
        ),
        // Mon 2026-06-08.
        Task(
          id: '3',
          title: 't',
          isDone: true,
          completedAt: DateTime(2026, 6, 8, 9),
        ),
        // Fri 2026-06-12 (today).
        Task(
          id: '4',
          title: 't',
          isDone: true,
          completedAt: DateTime(2026, 6, 12, 8),
        ),
        // Previous week — excluded.
        Task(
          id: '5',
          title: 't',
          isDone: true,
          completedAt: DateTime(2026, 6, 6, 10),
        ),
      ];
      final s = StatsData.from(tasks, now);
      // [Sun, Mon, Tue, Wed, Thu, Fri, Sat]
      expect(s.weeklyBars, [2, 1, 0, 0, 0, 1, 0]);
      expect(s.todayIndex, 5); // Fri
    });

    test('hasOnTimeData false → onTimePct 0', () {
      final s = StatsData.from([Task(id: 'a', title: 't')], now);
      expect(s.hasOnTimeData, isFalse);
      expect(s.onTimePct, 0);
    });

    test('empty list → all zeros', () {
      final s = StatsData.from(const [], now);
      expect(s.active, 0);
      expect(s.completed, 0);
      expect(s.onTime, 0);
      expect(s.late, 0);
      expect(s.missed, 0);
      expect(s.weeklyBars, [0, 0, 0, 0, 0, 0, 0]);
    });
  });

  group('bucketForOnTime', () {
    test('no data → noData regardless of pct', () {
      expect(
        bucketForOnTime(hasData: false, pct: 0),
        MotivationalBucket.noData,
      );
      expect(
        bucketForOnTime(hasData: false, pct: 100),
        MotivationalBucket.noData,
      );
    });
    test('<40 → low', () {
      expect(bucketForOnTime(hasData: true, pct: 0), MotivationalBucket.low);
      expect(bucketForOnTime(hasData: true, pct: 39), MotivationalBucket.low);
    });
    test('40–69 → mid', () {
      expect(bucketForOnTime(hasData: true, pct: 40), MotivationalBucket.mid);
      expect(bucketForOnTime(hasData: true, pct: 69), MotivationalBucket.mid);
    });
    test('70–89 → high', () {
      expect(bucketForOnTime(hasData: true, pct: 70), MotivationalBucket.high);
      expect(bucketForOnTime(hasData: true, pct: 89), MotivationalBucket.high);
    });
    test('>=90 → top', () {
      expect(bucketForOnTime(hasData: true, pct: 90), MotivationalBucket.top);
      expect(bucketForOnTime(hasData: true, pct: 100), MotivationalBucket.top);
    });
  });

  group('MotivationalSession', () {
    test('every pool bucket has ≥1 message', () {
      for (final b in MotivationalBucket.values) {
        expect(motivationalPool[b], isNotNull);
        expect(motivationalPool[b]!.length, greaterThanOrEqualTo(1));
      }
    });
    test('lineFor returns a message from the matching bucket', () {
      final session = MotivationalSession(random: Random(42));
      for (final b in MotivationalBucket.values) {
        final line = session.lineFor(b);
        expect(motivationalPool[b]!.contains(line), isTrue);
      }
    });
    test('lineFor is stable across calls within a session', () {
      final session = MotivationalSession(random: Random(7));
      final first = session.lineFor(MotivationalBucket.high);
      final second = session.lineFor(MotivationalBucket.high);
      final third = session.lineFor(MotivationalBucket.high);
      expect(second, first);
      expect(third, first);
    });
    test('different seeds can pick different lines (re-roll semantics)', () {
      // Use two distinct seeds, ensure at least one bucket differs across
      // many trials — proves the session is randomized at construction, not
      // hard-coded. (This is a probabilistic but very robust check.)
      final pool = motivationalPool[MotivationalBucket.mid]!;
      if (pool.length < 2) return; // skip if pool is trivially 1
      var sawDifference = false;
      for (var seed = 0; seed < 20 && !sawDifference; seed++) {
        final a = MotivationalSession(random: Random(seed))
            .lineFor(MotivationalBucket.mid);
        final b = MotivationalSession(random: Random(seed + 100))
            .lineFor(MotivationalBucket.mid);
        if (a != b) sawDifference = true;
      }
      expect(sawDifference, isTrue);
    });
  });

  group('quickDateOptions', () {
    test('Today before 17:00 → today at 17:00', () {
      final now = DateTime(2026, 6, 14, 10, 0); // morning
      final opts = quickDateOptions(now);
      expect(opts[0].label, 'Today');
      expect(opts[0].when, DateTime(2026, 6, 14, 17, 0));
    });
    test('Today after 17:00 → "in 1h" rounded to next :30', () {
      final now = DateTime(2026, 6, 14, 19, 12);
      final opts = quickDateOptions(now);
      // 19:12 + 1h = 20:12, round up to 20:30.
      expect(opts[0].label, 'Today');
      expect(opts[0].when, DateTime(2026, 6, 14, 20, 30));
    });
    test('This evening rolls to tomorrow once past 18:00', () {
      final past = DateTime(2026, 6, 14, 19, 0);
      final opts = quickDateOptions(past);
      expect(opts[1].label, 'This evening');
      expect(opts[1].when, DateTime(2026, 6, 15, 18, 0));
    });
    test('Tomorrow is +1 day 09:00, Next week is +7 days 09:00', () {
      final now = DateTime(2026, 6, 14, 10, 0);
      final opts = quickDateOptions(now);
      expect(opts[2].when, DateTime(2026, 6, 15, 9, 0));
      expect(opts[3].when, DateTime(2026, 6, 21, 9, 0));
    });
    test('Today clamps to 23:30 when very late', () {
      final lateNight = DateTime(2026, 6, 14, 23, 45);
      final opts = quickDateOptions(lateNight);
      expect(opts[0].when, DateTime(2026, 6, 14, 23, 30));
    });
  });

  group('Theme mode persistence', () {
    test('default theme mode is system when nothing saved', () async {
      final storage = StorageService();
      expect(await storage.loadThemeMode(), ThemeMode.system);
    });
    test('round-trips light/dark/system', () async {
      final storage = StorageService();
      await storage.saveThemeMode(ThemeMode.dark);
      expect(await storage.loadThemeMode(), ThemeMode.dark);
      await storage.saveThemeMode(ThemeMode.light);
      expect(await storage.loadThemeMode(), ThemeMode.light);
      await storage.saveThemeMode(ThemeMode.system);
      expect(await storage.loadThemeMode(), ThemeMode.system);
    });
  });

  group('Task.calendarEventId backward-compat', () {
    test('fromJson with missing key → null (legacy persisted task loads)', () {
      // Simulate a pre-Phase-4 saved task — no calendarEventId field at all.
      final legacy = {
        'id': 't1',
        'title': 'legacy',
        'isDone': false,
      };
      final t = Task.fromJson(legacy);
      expect(t.calendarEventId, isNull);
    });
    test('toJson includes calendarEventId field', () {
      final t = Task(id: 'x', title: 't', calendarEventId: 'evt-1');
      expect(t.toJson()['calendarEventId'], 'evt-1');
    });
    test('round-trip with null calendarEventId stays null', () {
      final t = Task(id: 'x', title: 't');
      final json = t.toJson();
      final back = Task.fromJson(json);
      expect(back.calendarEventId, isNull);
    });
    test('round-trip with set calendarEventId preserves it', () {
      final t = Task(id: 'x', title: 't', calendarEventId: 'evt-42');
      final json = t.toJson();
      final back = Task.fromJson(json);
      expect(back.calendarEventId, 'evt-42');
    });
  });

  group('TaskStore — explicit calendar export (Phase 4b)', () {
    test('add(dated) does NOT call upsert (no auto-sync)', () async {
      final mock = _MockSync();
      mock.upsertResult = 'evt-auto';
      final store = TaskStore(
        onSyncUpsert: mock.upsert,
        onSyncDelete: mock.delete,
      );
      store.add(Task(
        id: 't1',
        title: 'has due',
        dueAt: DateTime(2030, 1, 1, 9),
      ));
      await Future<void>.delayed(Duration.zero);
      expect(mock.upsertCalls, 0);
      expect(mock.deleteCalls, 0);
      expect(store.tasks.single.calendarEventId, isNull);
    });

    test('update / toggle do NOT call upsert (no auto-sync)', () async {
      final mock = _MockSync();
      mock.upsertResult = 'evt-auto';
      final store = TaskStore(
        seed: [Task(id: 't1', title: 'orig', dueAt: DateTime(2030, 1, 1, 9))],
        onSyncUpsert: mock.upsert,
        onSyncDelete: mock.delete,
      );
      store.update(id: 't1', title: 'new', note: null, dueAt: DateTime(2030, 1, 2));
      store.toggle('t1');
      await Future<void>.delayed(Duration.zero);
      expect(mock.upsertCalls, 0);
      expect(mock.deleteCalls, 0);
    });

    test('completing a task does NOT delete a calendar event (4b: explicit-only)',
        () async {
      final mock = _MockSync();
      final store = TaskStore(
        seed: [
          Task(
            id: 't1',
            title: 'do',
            dueAt: DateTime(2030, 1, 1, 9),
            calendarEventId: 'evt-1',
          ),
        ],
        onSyncUpsert: mock.upsert,
        onSyncDelete: mock.delete,
      );
      store.toggle('t1');
      await Future<void>.delayed(Duration.zero);
      expect(mock.deleteCalls, 0);
      expect(store.tasks.single.calendarEventId, 'evt-1');
    });

    test('deleting a synced task DOES delete its event (no orphans)',
        () async {
      final mock = _MockSync();
      final store = TaskStore(
        seed: [
          Task(
            id: 't1',
            title: 'do',
            dueAt: DateTime(2030, 1, 1, 9),
            calendarEventId: 'evt-2',
          ),
        ],
        onSyncUpsert: mock.upsert,
        onSyncDelete: mock.delete,
      );
      store.delete('t1');
      await Future<void>.delayed(Duration.zero);
      expect(mock.deleteCalls, 1);
      expect(mock.lastDeletedId, 'evt-2');
      expect(store.tasks, isEmpty);
    });

    test('exportTaskToCalendar(dated) upserts and stores returned id',
        () async {
      final mock = _MockSync();
      mock.upsertResult = 'evt-new';
      final store = TaskStore(
        seed: [Task(id: 't1', title: 'has due', dueAt: DateTime(2030, 1, 1, 9))],
        onSyncUpsert: mock.upsert,
        onSyncDelete: mock.delete,
      );
      final ok = await store.exportTaskToCalendar('t1');
      expect(ok, isTrue);
      expect(mock.upsertCalls, 1);
      expect(store.tasks.single.calendarEventId, 'evt-new');
    });

    test('exportTaskToCalendar with upsert returning null leaves id untouched',
        () async {
      final mock = _MockSync();
      mock.upsertResult = null;
      final store = TaskStore(
        seed: [Task(id: 't1', title: 'do', dueAt: DateTime(2030, 1, 1, 9))],
        onSyncUpsert: mock.upsert,
        onSyncDelete: mock.delete,
      );
      final ok = await store.exportTaskToCalendar('t1');
      expect(ok, isFalse);
      expect(mock.upsertCalls, 1);
      expect(store.tasks.single.calendarEventId, isNull);
    });

    test('exportTaskToCalendar returns false when no upsert callback wired',
        () async {
      final store = TaskStore(
        seed: [Task(id: 't1', title: 't', dueAt: DateTime(2030, 1, 1, 9))],
      );
      expect(await store.exportTaskToCalendar('t1'), isFalse);
      expect(await store.exportTaskToCalendar('nope'), isFalse);
    });

    test('removeTaskFromCalendar clears the link and calls onSyncDelete',
        () async {
      final mock = _MockSync();
      final store = TaskStore(
        seed: [
          Task(
            id: 't1',
            title: 'do',
            dueAt: DateTime(2030, 1, 1, 9),
            calendarEventId: 'evt-7',
          ),
        ],
        onSyncUpsert: mock.upsert,
        onSyncDelete: mock.delete,
      );
      final ok = await store.removeTaskFromCalendar('t1');
      expect(ok, isTrue);
      expect(mock.deleteCalls, 1);
      expect(mock.lastDeletedId, 'evt-7');
      expect(store.tasks.single.calendarEventId, isNull);
    });

    test('removeTaskFromCalendar is a no-op when not exported', () async {
      final mock = _MockSync();
      final store = TaskStore(
        seed: [Task(id: 't1', title: 'do', dueAt: DateTime(2030, 1, 1, 9))],
        onSyncUpsert: mock.upsert,
        onSyncDelete: mock.delete,
      );
      final ok = await store.removeTaskFromCalendar('t1');
      expect(ok, isFalse);
      expect(mock.deleteCalls, 0);
    });
  });

  group('AddTaskSheetResult.addToCalendar plumbing', () {
    test('default value is false', () {
      const r = AddTaskSheetResult(title: 'x');
      expect(r.addToCalendar, isFalse);
    });
    test('explicit true is preserved', () {
      const r = AddTaskSheetResult(title: 'x', addToCalendar: true);
      expect(r.addToCalendar, isTrue);
    });
  });
}

class _MockSync {
  int upsertCalls = 0;
  int deleteCalls = 0;
  String? upsertResult;
  Future<String?> Function(Task)? upsertFn;
  String? lastDeletedId;

  Future<String?> upsert(Task t) async {
    upsertCalls++;
    if (upsertFn != null) return upsertFn!(t);
    return upsertResult;
  }

  Future<void> delete(String id) async {
    deleteCalls++;
    lastDeletedId = id;
  }
}
