# Coding Agent — Operating Rules (index)

**Full rules:** `./rules.md` · **Plan (source of truth):** `../planning/000-init-plan.md` · **Target:** Android.

Non-negotiables:
- **Simplicity first; vertical slices** — every phase must be runnable/visible. No DB, no backend, no codegen.
- **Decide Tier-A items yourself and log them; HALT and ask on Tier-B** — any deviation from the plan's locked decisions, any new dependency, any scope/phase change, any complexity increase.
- **Halt on every error** — never work around an issue by changing the architecture.
- **Report at the end of every phase** (format in `rules.md`) and STOP for orchestrator approval.
