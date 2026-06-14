Date: 2026-06-12
Release APK convention. Latest signed release APK lives ONLY at:
  .claude/releases/taskflow-sync-<phase>-v<pubspec-version>.apk
One file at a time — replace, do not accumulate history. User shares it via email / WhatsApp from there.
Directory is gitignored (50MB binaries don't belong in git).
Source APK: build/app/outputs/flutter-apk/app-release.apk (produced by `flutter build apk --release`).
Rule: at the end of every release-worthy phase (DoD met + orchestrator-approved), copy the freshly built release APK into .claude/releases/ with the phase + pubspec version in the filename, deleting the previous file first so only the current build is present.
