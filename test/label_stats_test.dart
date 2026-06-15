import 'package:flutter_test/flutter_test.dart';

import 'package:taskflow_sync/models/task.dart';
import 'package:taskflow_sync/util/stats_data.dart';

void main() {
  group('labelStatsFrom', () {
    final now = DateTime(2026, 7, 15, 14, 30);

    test('returns const [] when there are no tasks', () {
      expect(labelStatsFrom(const [], now), isEmpty);
    });

    test('returns const [] when every task is unlabeled', () {
      final tasks = [
        Task(id: 'a', title: 'one'),
        Task(id: 'b', title: 'two', label: ''),
        Task(id: 'c', title: 'three', label: '   '),
      ];
      expect(labelStatsFrom(tasks, now), isEmpty);
    });

    test(
        'buckets case-insensitively with first-seen casing; '
        'sorts alphabetically; Unlabeled last when present', () {
      final tasks = [
        Task(id: 'a', title: '1', label: 'Work'),
        Task(id: 'b', title: '2', label: 'work'),
        Task(id: 'c', title: '3', label: 'Errands'),
        Task(id: 'd', title: '4'), // unlabeled (null)
        Task(id: 'e', title: '5', label: '  '), // unlabeled (whitespace)
        Task(id: 'f', title: '6', label: 'Home'),
      ];
      final out = labelStatsFrom(tasks, now);
      // Real labels: Errands (1), Home (1), Work (2). Case-insensitive sort.
      // First-seen casing preserved ("Work" beats "work").
      expect(out.map((s) => s.label).toList(),
          ['Errands', 'Home', 'Work', 'Unlabeled']);
      expect(out.last.isUnlabeled, isTrue);
      expect(out.where((s) => !s.isUnlabeled).every((s) => !s.isUnlabeled),
          isTrue);
    });

    test('per-bucket numbers exactly match StatsData.from on the subset', () {
      // Construct tasks with a mix of completed + due dates so the on-time
      // math actually engages.
      final due = DateTime(2026, 7, 14, 9, 0); // yesterday relative to now
      final completedOnTime = DateTime(2026, 7, 14, 8, 30);
      final tasks = [
        // Work bucket: 1 active, 1 completed on-time → 100% on-time.
        Task(id: 'w1', title: 'wa', label: 'Work'),
        Task(
          id: 'w2',
          title: 'wb',
          label: 'Work',
          dueAt: due,
          isDone: true,
          completedAt: completedOnTime,
        ),
        // Home bucket: 1 active overdue (counts as missed in the outcome math
        // when due has passed), no completions.
        Task(id: 'h1', title: 'ha', label: 'Home', dueAt: due),
      ];
      final out = labelStatsFrom(tasks, now);
      // Map by label.
      final map = {for (final r in out) r.label: r};

      final workSubset = tasks.where((t) => t.label == 'Work').toList();
      final homeSubset = tasks.where((t) => t.label == 'Home').toList();
      final workStats = StatsData.from(workSubset, now);
      final homeStats = StatsData.from(homeSubset, now);

      expect(map['Work']!.active, workStats.active);
      expect(map['Work']!.completed, workStats.completed);
      expect(map['Work']!.onTimePct, workStats.onTimePct);
      expect(map['Work']!.hasOnTimeData, workStats.hasOnTimeData);

      expect(map['Home']!.active, homeStats.active);
      expect(map['Home']!.completed, homeStats.completed);
      expect(map['Home']!.onTimePct, homeStats.onTimePct);
      expect(map['Home']!.hasOnTimeData, homeStats.hasOnTimeData);
    });

    test('Unlabeled row carries its own on-time math', () {
      // One labeled (so the Unlabeled bucket survives) + two unlabeled, one
      // of them missed.
      final due = DateTime(2026, 7, 14, 9, 0);
      final tasks = [
        Task(id: 'a', title: 'labeled', label: 'Work'),
        Task(id: 'b', title: 'no-label active'),
        Task(id: 'c', title: 'no-label missed', dueAt: due),
      ];
      final out = labelStatsFrom(tasks, now);
      final unl = out.firstWhere((r) => r.isUnlabeled);
      final unlSubset = [tasks[1], tasks[2]];
      final unlStats = StatsData.from(unlSubset, now);
      expect(unl.active, unlStats.active);
      expect(unl.completed, unlStats.completed);
      expect(unl.onTimePct, unlStats.onTimePct);
      expect(unl.hasOnTimeData, unlStats.hasOnTimeData);
    });

    test('Unlabeled bucket is omitted when no task is untagged', () {
      final tasks = [
        Task(id: 'a', title: '1', label: 'Work'),
        Task(id: 'b', title: '2', label: 'Home'),
      ];
      final out = labelStatsFrom(tasks, now);
      expect(out.map((s) => s.label).toList(), ['Home', 'Work']);
      expect(out.any((s) => s.isUnlabeled), isFalse);
    });

    test('hasOnTimeData is false for a bucket with no deadline tasks', () {
      final tasks = [
        Task(id: 'a', title: 'no-due', label: 'Personal'),
        Task(id: 'b', title: 'also no-due', label: 'Personal'),
      ];
      final out = labelStatsFrom(tasks, now);
      expect(out.single.hasOnTimeData, isFalse);
      expect(out.single.onTimePct, 0);
    });
  });
}
