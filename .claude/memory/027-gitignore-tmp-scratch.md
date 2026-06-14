Date: 2026-06-14
Added .claude/tmp/ to .gitignore on feature/gitignore-tmp-scratch, merged --no-ff into pre-master at 6af2468; existing scratch file (.claude/tmp/ic_launcher.png) preserved on disk. Standing down — no further git work until orchestrator approves a specific feature branch (next: Phase 4c, then release-signing).
Rule: Any directory used for operator scratch or handoff (e.g. .claude/tmp/) must be gitignored before a session can safely call 'git add -A'; preserve existing files (untrack-with-ignore, not delete).
