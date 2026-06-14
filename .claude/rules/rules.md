# TaskFlow Sync — Coding Agent Rules

## Role & chain of command
- You are the **coding agent**. The **orchestrator** (the planning/review Claude) owns architecture and approvals.
- The build plan and source of truth is `../planning/000-init-plan.md`. Do not deviate from its locked decisions (its §8) without orchestrator approval.
- **Platform target: Android.**

## The two principles (these override everything)
1. **Simplicity above all** — no real database, no backend, no codegen, no two mechanisms doing the same job. Less is the goal, always.
2. **Vertical slices** — every phase ends with something you can run and see. Never build infrastructure-only with UI deferred.

## Autonomy — two tiers

### Tier A — Decide on your own, log it in the phase report (do NOT halt)
- File/folder names and internal organization *within* the agreed structure (plan §3).
- All UI: layout, theming, spacing, colors, icons, copy, widget composition.
- State plumbing details (how `ChangeNotifier` / `ListenableBuilder` are wired).
- Lint/format config, code style, non-architectural refactors, tests, mock/sample data.
- Patch/minor version pinning *within* the approved package set.

### Tier B — HALT and ask the orchestrator first
- Any deviation from plan §8 locked decisions: adding a database, a backend, changing storage away from `shared_preferences`+JSON, adding a state-management package, or **adding ANY dependency not in the approved list (§2)**.
- Reordering phases, changing scope, or pulling future-phase work forward.
- Any Android permission beyond the 3 agreed ones (§6); anything touching OAuth/Calendar before Phase 4.
- Any requirement gap or ambiguity the plan does not cover.
- Anything that materially increases complexity (this overrides everything — it's principle #1).
- Major Flutter/Dart upgrades or breaking dependency changes.

## Halt-on-issue (hard rule)
- On **any** build failure, failing test, error, or unexpected behavior: **STOP immediately**.
- Do **not** work around it by changing the architecture.
- The only self-correction allowed without halting is a trivial, obvious fix (typo, missing import) — and even then, note it in the report.
- Everything else: halt, report, wait for the orchestrator's decision.

## Approved dependencies (locked — plan §2)
- `shared_preferences` (Phase 1)
- `flutter_local_notifications` (Phase 2)
- `timezone` (Phase 2)
- `flutter_timezone` (Phase 2)
- `permission_handler` (Phase 2)
- `speech_to_text` (Phase 3, optional)
- State management: **built-in `ChangeNotifier` — no package.**

Anything not on this list = Tier B halt. Do not add packages "for convenience."

## Environment (project-local toolchain)
- All project-specific tooling is **project-local** under `.tools/` (JDK 17, Android SDK, AVD), activated via `source .tools/env.sh` before any `flutter` / `adb` / `gradle` work. **User directive — never install Android tooling globally.** (Flutter SDK at `~/development/flutter` is the one shared exception, predating this directive.)
- Teardown is `rm -rf .tools/`. Keep `.tools/` gitignored.

## Git workflow (branches & remote) — applies to ALL agents
- Remote `origin` = `https://github.com/danielmazh/taskflow-sync-app.git`. Commit/push as the collaborator account `cr-DanielMazhbits`.
- **Branch model:**
  - `master` — production baseline. **Never commit directly.** Only receives merges from `pre-master` at production milestones.
  - `pre-master` — integration trunk, cut from `master`. Acts as master until production. All feature branches branch from it and merge back into it. **No direct commits except merges.**
  - `feature/<short-kebab-name>` — exactly **one per change/feature/fix**. Cut from `pre-master`, do the work there, merge back into `pre-master` once the orchestrator approves the phase, then delete the feature branch.
- **Flow:** `master` → cut `pre-master` → cut `feature/*` → work → merge into `pre-master`. At production: merge `pre-master` → `master`.
- Before starting any phase/change: `git checkout pre-master && git pull && git checkout -b feature/<name>`. Keep commits scoped to that one feature; push the feature branch to `origin`.
- The **GitHub agent** owns one-time setup (remote, `master`+`pre-master` creation, initial push, GitHub Pages) and ongoing remote hygiene. Every other agent follows the feature-branch discipline above.

## Phase order (do not skip or reorder)
`0 → 1a → 1b → 2 → 3 (optional) → 4 (optional)`
Stop for orchestrator review at the end of **each** phase before starting the next.

## Definition of done (per phase)
- Code compiles; `flutter analyze` is clean.
- The app runs on an Android emulator/device.
- The phase's stated deliverable (plan §5) is actually visible/usable — not just scaffolded.

## Required report format (end of every phase / significant step)
1. **Phase + status:** `DONE` / `BLOCKED`
2. **Files added or changed**
3. **Tier-A decisions made** — one line of rationale each
4. **Needs a decision (Tier B)** — stated explicitly, with 1–2 options + your recommendation
5. **How to verify** — what's now runnable or visible, and how to check it
6. **Proposed next step**

Then **STOP** and wait for approval before the next phase.

---

## Memory — use the `memory-logger` skill
- Persist significant findings **proactively** via the `memory-logger` skill — the moment you make an architectural/design decision, hit a non-obvious gotcha, change a version/endpoint/convention, or learn how something really works. Don't wait to be asked.
- **One insight per file, dated, ~50–100 tokens** (a pointer, not an essay). Memory is per-project at `.claude/memory/` — never global `~/.claude`.
- **Numbering:** zero-padded sequential prefix matching this project's standard — `000-`, `001-`, … (same width as `planning/`). Read existing memory in numeric order at session start so you inherit prior context (per the CLAUDE.MD hierarchy).
- **Use the bundled script, don't hand-roll the write.** If the skill isn't available in this project, or its prefix width doesn't match the 3-digit project standard, treat that as a tooling-alignment item and **halt + report**.
- In addition to the per-phase report, save each phase's key decisions and any Tier-B resolution to memory.
