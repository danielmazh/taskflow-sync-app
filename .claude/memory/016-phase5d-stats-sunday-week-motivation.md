Date: 2026-06-12
Phase 5d — Statistics page (real), Sunday-week, motivational pool. View-layer only.
Charts: built-in only — donut via CustomPainter; weekly bars via Column/Row + height-shaped Containers. NO chart package (dep = Tier-B halt).
Sunday-week rule: first day of week = Sunday (Israel) everywhere. startOfWeek(d) = d - ((weekday % 7)) days  // DateTime.weekday is Mon=1..Sun=7; Sun→0, Mon→1, ... Sat→6. Use this in Archive grouping AND Statistics weekly bars. Bars ordered Su Mo Tu We Th Fr Sa, today highlighted.
Motivational pool: const lists keyed by buckets {noData, low(<40), mid(40–69), high(70–89), top(≥90)} of on-time %. ~4 lines each. noData triggers when zero deadline-bearing completed tasks exist. Selected ONCE per app launch (top-level Random in motivational_messages.dart seeded at lib load; pick is a final field on a session-scope singleton). Stable across tab switches — re-roll only on next cold start.
Nav: order Archive(0) / Home(1) / Statistics(2). Home gets persistent emphasis (slightly larger icon + accent-tinted circular background behind icon when selected; tasteful, not gimmicky).
Rule: any new dependency, persistence, or model change is Tier-B halt. Motivation + stats derive purely from store.tasks + outcomeFor() + completedAt.
