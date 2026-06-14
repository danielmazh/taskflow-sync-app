import 'package:flutter/material.dart';

typedef ThemeModePersist = Future<void> Function(ThemeMode mode);

class ThemeController extends ChangeNotifier {
  ThemeMode _mode;
  final ThemeModePersist? onChanged;

  ThemeController({
    ThemeMode initial = ThemeMode.system,
    this.onChanged,
  }) : _mode = initial;

  ThemeMode get mode => _mode;

  void setMode(ThemeMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    final cb = onChanged;
    if (cb != null) {
      cb(mode).catchError((_) {});
    }
  }
}
