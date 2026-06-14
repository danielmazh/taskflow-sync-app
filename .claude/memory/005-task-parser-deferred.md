Date: 2026-06-11
Decision: TaskParser seam deferred from Phase 1a to Phase 1b.
The sheet collects title/note/dueAt as structured fields, so a synchronous PlainParser would only no-op on the title and bypass the structured fields — no real seam value.
Phase 1b is the right home: persistence + parser arrive together; the LLM parser swap (future) accepts freeform text → fully-populated Task, which is the real seam the plan §4 envisions.
Rule: Introduce lib/services/task_parser.dart (abstract TaskParser + PlainParser) only when the freeform text-entry path lands (Phase 1b or later) — do not add it speculatively.
