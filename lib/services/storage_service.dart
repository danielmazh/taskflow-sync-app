import 'dart:convert';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/task.dart';

class StorageService {
  static const String _tasksKey = 'tasks';
  static const String _themeModeKey = 'theme_mode';
  static const String _calendarConnectedKey = 'calendar_connected';

  Future<List<Task>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Bust per-isolate cache so foreground sees background isolate's writes.
      await prefs.reload();
      final raw = prefs.getString(_tasksKey);
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((e) => Task.fromJson(e.cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<Task> tasks) async {
    final encoded = jsonEncode(tasks.map((t) => t.toJson()).toList());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tasksKey, encoded);
  }

  Future<ThemeMode> loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final raw = prefs.getString(_themeModeKey);
      return switch (raw) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
    } catch (_) {
      return ThemeMode.system;
    }
  }

  Future<void> saveThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    });
  }

  /// "User has previously opted in to Google Calendar sync." Used to gate the
  /// silent-recovery attempt on cold start: we only attempt to restore the
  /// session when the user has actually connected before, so the very first
  /// launch never auto-prompts.
  Future<bool> loadCalendarConnected() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      return prefs.getBool(_calendarConnectedKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> saveCalendarConnected(bool connected) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_calendarConnectedKey, connected);
  }
}
