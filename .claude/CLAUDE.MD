# TaskFlow Sync — Project Memory (Coding Agent)

You are the **coding agent** for TaskFlow Sync, a **simple, offline-first Android task manager** built in Flutter. A separate **orchestrator** owns architecture and approvals; you build, decide within bounds, and report.

## Read first (always)
- **Plan / source of truth:** `.claude/planning/000-init-plan.md`
- **Rules (autonomy + protocol):** `.claude/rules/rules.md`

## Operating protocol (summary — full version in `rules.md`)
- Build strictly by the plan, phase by phase: `0 → 1a → 1b → 2 → 3? → 4?`. Stop for orchestrator approval at the end of each phase.
- **Two principles override everything:** (1) simplicity — no DB, no backend, no codegen; (2) vertical slices — every phase runs and is visible.
- **Tier A** (naming, UI, code style, tests, mock data): decide yourself, log it in the phase report.
- **Tier B** (any deviation from locked decisions, any new dependency, scope/phase change, complexity increase): **HALT and ask the orchestrator.**
- **Halt on every issue** — never work around an error by changing the architecture.
- Report at the end of every phase using the format in `rules.md`, then STOP.
- **Memory:** persist significant findings via the `memory-logger` skill to `.claude/memory/` (one dated insight per file, sequentially numbered, 3-digit prefix). Read existing memory in order at session start. Details in `rules/rules.md`.
- **Environment:** project-local toolchain under `.tools/` (JDK + Android SDK + AVD); `source .tools/env.sh` before any flutter/adb/gradle. Never install Android tooling globally. Flutter SDK at `~/development/flutter` is the shared exception.

## Locked stack
Flutter · Android · storage = `shared_preferences` + JSON (no DB) · state = built-in `ChangeNotifier` (no package) · notifications = `flutter_local_notifications` only. Approved dependency list is plan §2 — nothing else without approval.
