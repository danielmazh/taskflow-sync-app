Date: 2026-06-12
Phase 5 redesign direction (orchestrator-approved). View-layer only — lib/models, lib/services, lib/state functionally read-only this phase.
North star: calm, scannable, dense-but-breathable (Things/Todoist/Linear restraint). Full Material 3, light AND dark. Indigo accent.
Layout: AppBar(title L, voice-mic R) + FAB(+); summary line ('X overdue · Y due today', overdue in danger color); list ROWS (not cards) w/ circular checkbox leading-left, strong title, quiet metadata. Time-grouped sections w/ counts: Overdue → Today → Upcoming → No date → Completed (collapsible, muted). Relative dates ('Today 18:30', 'Tomorrow 09:00', 'Tue 15 Jul', 'Overdue · 2h ago'). Overdue flagged by icon + color (never color alone). Two empty states: nothing-yet vs all-done.
Slices: 5a (tokens + structure) → STOP → 5b (quick-date chips, undo snackbars, list animations, a11y).
Rule: derive grouping/sorting/formatting in the VIEW layer from existing store ops; never touch model/service/state behavior in Phase 5; any new dep = Tier-B halt.
