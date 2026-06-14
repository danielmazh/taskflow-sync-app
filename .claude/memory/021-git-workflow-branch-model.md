# 021 — Git workflow: master / pre-master / feature branches

2026-06-14. Remote `origin` = github.com/danielmazh/taskflow-sync-app (push as collaborator `cr-DanielMazhbits`; repo started empty).

Branch model (see rules.md "Git workflow"):
- `master` = production baseline; merge-only, receives `pre-master` at production milestones.
- `pre-master` = integration trunk, cut from master, acts as master until production.
- `feature/<name>` = one per change, cut from pre-master, merged back to pre-master then deleted.

Flow: master → pre-master → feature/* → merge into pre-master; pre-master → master at production. No direct commits to master/pre-master except merges.

GitHub agent owns one-time setup (remote, master+pre-master, initial push, GitHub Pages serving docs/index.html + docs/privacy-policy.html). All other agents follow feature-branch discipline.
