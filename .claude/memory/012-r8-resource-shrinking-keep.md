Date: 2026-06-12
Flutter release builds (3.44.x + AGP 8.x) run R8's resource shrinker by default — even with no isShrinkResources/isMinifyEnabled in build.gradle.kts.
R8 only sees Android-side references (manifest, styles, R fields). Resources referenced only from Dart strings (e.g., flutter_local_notifications' small icon passed by bare name) are marked 'is not reachable' in build/app/outputs/mapping/release/resources.txt and stripped — debug builds work, release silently breaks.
Fingerprint: PlatformException(invalid_icon, The resource X could not be found) at NotificationService.init → blocks runApp() → black screen.
Fix: android/app/src/main/res/raw/keep.xml with <resources xmlns:tools="..." tools:keep="@drawable/..." tools:shrinkMode="safe" />.
Also: AndroidInitializationSettings wants the BARE drawable name ('ic_stat_taskflow'), never the '@drawable/...' prefix — emulators tolerate the prefix, real devices throw invalid_icon at init.
Rule: any Android resource referenced only from Dart strings MUST be listed in res/raw/keep.xml, and AndroidInitializationSettings always takes the bare name.
