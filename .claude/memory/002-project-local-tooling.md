Date: 2026-06-11
All tooling must be project-local ("virtual env for everything"). User directive.
- JDK: <project>/.tools/jdk-17/  (NOT brew install --global, NOT /Library/Java)
- Android SDK: <project>/.tools/android-sdk/  (NOT ~/Library/Android/sdk)
- Env vars live in <project>/.tools/env.sh — source per session. Do NOT pollute ~/.zshrc with project-specific paths.
- Flutter SDK at ~/development/flutter is an existing exception (installed before this directive, shared across projects).
Rule: Default to project-local installs and a project-local env.sh; ~/.zshrc gets only project-agnostic tooling (Flutter SDK), nothing project-scoped.
