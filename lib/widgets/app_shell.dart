import 'package:flutter/material.dart';

import '../screens/archive_screen.dart';
import '../screens/home_screen.dart';
import '../screens/statistics_screen.dart';
import '../services/calendar_sync_service.dart';
import '../services/notification_service.dart';
import '../state/task_store.dart';
import '../state/theme_controller.dart';

class AppShell extends StatefulWidget {
  final TaskStore store;
  final NotificationService? notifications;
  final ThemeController themeController;
  final CalendarSyncService? calendarSync;
  const AppShell({
    super.key,
    required this.store,
    required this.themeController,
    this.notifications,
    this.calendarSync,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  // Tab order: Archive (0), Home (1, center), Statistics (2).
  // Home defaults selected so the app opens on the primary surface.
  static const int _homeIndex = 1;
  int _index = _homeIndex;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          ArchiveScreen(store: widget.store),
          HomeScreen(
            store: widget.store,
            notifications: widget.notifications,
            themeController: widget.themeController,
            calendarSync: widget.calendarSync,
          ),
          StatisticsScreen(store: widget.store),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.inbox_outlined),
            selectedIcon: Icon(Icons.inbox_rounded),
            label: 'Archive',
          ),
          NavigationDestination(
            icon: _HomeAnchor(
              selected: false,
              accent: scheme.primary,
              accentBg: scheme.primaryContainer,
              onAccentBg: scheme.onPrimaryContainer,
            ),
            selectedIcon: _HomeAnchor(
              selected: true,
              accent: scheme.primary,
              accentBg: scheme.primaryContainer,
              onAccentBg: scheme.onPrimaryContainer,
            ),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights_rounded),
            label: 'Statistics',
          ),
        ],
      ),
    );
  }
}

/// Center "Home" destination — always emphasized: a soft accent-tinted disc
/// behind a slightly larger icon. The M3 selected-indicator still appears on
/// selection, reinforcing the center as the primary surface.
class _HomeAnchor extends StatelessWidget {
  final bool selected;
  final Color accent;
  final Color accentBg;
  final Color onAccentBg;
  const _HomeAnchor({
    required this.selected,
    required this.accent,
    required this.accentBg,
    required this.onAccentBg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: accentBg.withValues(alpha: selected ? 0 : 0.55),
        shape: BoxShape.circle,
      ),
      child: Icon(
        selected ? Icons.home_rounded : Icons.home_outlined,
        size: 26,
        color: selected ? accent : onAccentBg,
      ),
    );
  }
}
