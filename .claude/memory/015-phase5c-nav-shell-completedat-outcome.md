Date: 2026-06-12
Phase 5c — authorized core changes + 3-page nav (orchestrator-approved).
Core changes (the only ones authorized): (1) Task.completedAt (DateTime?) w/ backward-compat fromJson (missing→null); (2) TaskStore.toggle sets completedAt=now on complete, clears to null on un-complete; (3) ThemeMode persisted in shared_preferences key 'theme_mode' (separate from 'tasks').
Outcome model: onTime = isDone && (dueAt==null || completedAt<=dueAt); late = isDone && dueAt!=null && completedAt>dueAt; missed = !isDone && dueAt!=null && dueAt<now; else pending. Legacy isDone w/ null completedAt → onTime.
Nav: M3 NavigationBar shell w/ Home / Archive / Statistics(stub). IndexedStack preserves state; each page own Scaffold.
Home: Completed section moved to Archive; new AppBar PopupMenu (Light/Dark/System) → ThemeController.setMode.
Archive: completed-only, grouped by completedAt recency (Today/Yesterday/Earlier this week/Older), per-row Restore + Delete, on-time/late badge when dueAt present.
Rule: do NOT extend the core-change exception list; future model/state additions stay Tier-B.
