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

---

## Release management & environments

This section codifies how production and Claude-internal releases relate to the `master` / `pre-master` branches, so neither agent confuses them.

### Branch roles (production vs. integration)

- **`master` = Google Play production mirror.** It reflects exactly what is (or is about to be) live in the Play Store. **NEVER a development target.** No agent may commit to `master` directly, cut a feature branch off `master`, build a Claude-internal artifact from `master`, or treat `master` as a working trunk.
  - `master` is updated **only** by a gated `pre-master → master` merge at the moment of an actual store release. The merge is operator-approved, executed by the git agent, and immediately followed by rebuilding and uploading the AAB to Play.
  - Every production release MUST be tagged `prod-vX.Y.Z+N` on the `master` commit it ships from.
- **`pre-master` = integration trunk.** All feature branches branch from it, and merge back into it `--no-ff` **only after the operator's on-device smoke test on the S25 Ultra (or current target device) passes**. Merges land chronologically — no reordering history to "tidy" a sequence; the order in which features pass the on-device gate is the order they enter `pre-master`.
- **Feature branches** are short-lived, scoped to one change, named `feature/<short-kebab-name>`, and deleted (local + remote) immediately after their `--no-ff` merge into `pre-master`.

### Approval gates

- Any build whose **purpose** is to feed a `master` push (Play AAB upload, production-tagged APK, production verification build) **requires explicit operator approval** before the build is started. The operator approves the *intent to release*, not just the push.
- Any `git push origin master` (and any push that would advance `master` — fast-forward, merge, or tag) **requires explicit operator approval** at the moment of push. A standing approval from earlier in the session does not count.
- No agent may force-push `master` or `pre-master`, ever. If a `master` push is rejected by the remote, halt and report — never `--force` / `--force-with-lease` on a trunk.
- An on-device pass on the S25 Ultra (or whatever device the operator names for the current cycle) is a hard prerequisite for any `feature/* → pre-master` merge. Tests + analyze green is necessary but not sufficient.

### Claude / local-test releases

Claude builds release artifacts for the operator to sideload — never for the Store directly.

- Workflow:
  1. On `pre-master` (or a release-specific feature branch off `pre-master`), bump the version in `pubspec.yaml` (see versionCode rule below).
  2. `source .tools/env.sh && flutter build apk --release` — universal/fat APK signed by the upload keystore (verify the SHA-1 begins `6E:77:C3:89:…` per memory 029/032, **not** `AndroidDebugKey`).
  3. Copy the APK to `.claude/releases/taskflow-sync-<version>.apk`. This directory is **gitignored**; the binary **never** enters the repo (memory 017).
  4. Tag the release commit `claude-vX.Y.Z+N` on `pre-master` once the bump merges in (or on the feature branch immediately before merge, then promote the tag).
- Claude releases do **not** touch `master`. They never enter the Play Store. They exist exclusively for operator-side device testing.

### versionCode discipline (Play rejects ties or decreases)

- `versionCode` (`+N` in `pubspec.yaml`) is a single monotonic integer that increases by ≥1 on **every** build that could ever be uploaded or sideloaded — production, Claude release, hotfix, anything. Skipping numbers is allowed; reusing or lowering a number is not.
- Production and Claude releases draw from the **same** integer sequence — there is no separate ladder. Treat any `+N` as globally consumed once any build with that code has left this workstation (or, conservatively, once it has been built).
- `versionName` (`X.Y.Z`) follows ordinary semver and may stay constant across `+N` bumps (e.g. two Claude builds at `1.0.1+3` → `1.0.1+4` for an iteration fix).
- The operator owns the canonical "last consumed `+N`" — when in doubt, ask, do not guess.

### Persisted-state compatibility (no DB on purpose)

- **The app's only persisted state is JSON in `shared_preferences`.** There is **no database** — no Drift, no SQLite, no Hive, no Isar — by design (the radical-simplicity principle, plan §8). Introducing one is an explicit, separate, Tier-B decision; never assume it.
- Any change to a persisted shape must stay **backward-compatible**:
  - Add new fields as **optional with a null/empty/falsey default in `fromJson`**. Pre-feature tasks must continue to load cleanly. The Phase-7 `Task.label` field is the model: `j['label'] as String?` with a comment explaining the back-compat default (and the mirroring `calendarEventId` / `completedAt` patterns from earlier phases).
  - **Do not rename keys.** If a rename is unavoidable, ship a one-shot migration shim that reads the old key and writes the new one on next load, and keep the shim in place for at least one production release. Renames without a shim silently lose user data on update.
  - **Do not remove keys** that an older build wrote, even if the new build no longer reads them — older app installs may still write them, and round-tripping must not drop them on disk. If a key is genuinely dead, remove the writer first, ship that release, and only then remove the reader in a later release.
  - Any change that would force a wipe-and-reinstall is **Tier-B** — halt and ask.
