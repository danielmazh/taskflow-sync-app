import 'package:flutter_test/flutter_test.dart';

import 'package:taskflow_sync/models/task.dart';
import 'package:taskflow_sync/util/task_search.dart';

void main() {
  group('searchTasks', () {
    final tasks = [
      Task(id: 'a', title: 'Buy milk', note: 'whole milk', label: 'Errands'),
      Task(id: 'b', title: 'Push branch', note: null, label: 'Work'),
      Task(id: 'c', title: 'Read book', note: 'About the Battle of Hastings'),
      Task(id: 'd', title: 'Floss'),
      Task(id: 'e', title: 'Call mum', note: 'about MILK delivery'),
      Task(id: 'f', title: 'Done thing', isDone: true, label: 'Personal'),
    ];

    test('empty query returns no results (not all tasks)', () {
      expect(searchTasks(tasks, ''), isEmpty);
      expect(searchTasks(tasks, '   '), isEmpty);
      expect(searchTasks(tasks, '\t\n  '), isEmpty);
    });

    test('matches by title (case-insensitive)', () {
      final got = searchTasks(tasks, 'PUSH').map((t) => t.id).toList();
      expect(got, ['b']);
    });

    test('matches by note (case-insensitive)', () {
      final got = searchTasks(tasks, 'hastings').map((t) => t.id).toList();
      expect(got, ['c']);
    });

    test('matches by label (case-insensitive)', () {
      final got = searchTasks(tasks, 'work').map((t) => t.id).toList();
      expect(got, ['b']);
    });

    test('a task matching on multiple fields appears exactly once', () {
      // "milk" matches task a on title AND note; should not be duplicated.
      final got = searchTasks(tasks, 'milk').map((t) => t.id).toList();
      expect(got, ['a', 'e']); // a: title+note; e: note. Each once.
    });

    test('order is the same as the input order (stable)', () {
      final shuffled = [tasks[3], tasks[0], tasks[5], tasks[1]];
      final got = searchTasks(shuffled, 'o').map((t) => t.id).toList();
      // Substring 'o' appears in 'Floss', 'Done', 'Work' (label), and 'whole milk' (note).
      // Match order tracks input order.
      expect(got, ['d', 'a', 'f', 'b']);
    });

    test('no match returns empty list', () {
      expect(searchTasks(tasks, 'zzzz_no_such_thing'), isEmpty);
    });

    test('completed tasks are searchable too (caller controls scope)', () {
      final got = searchTasks(tasks, 'personal').map((t) => t.id).toList();
      expect(got, ['f']);
    });

    test('query is trimmed before matching', () {
      final got = searchTasks(tasks, '  Floss  ').map((t) => t.id).toList();
      expect(got, ['d']);
    });

    test('substring is matched anywhere, not just word-start', () {
      // 'ranch' is inside 'branch'.
      final got = searchTasks(tasks, 'ranch').map((t) => t.id).toList();
      expect(got, ['b']);
    });
  });
}
