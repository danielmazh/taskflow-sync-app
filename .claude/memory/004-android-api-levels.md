Date: 2026-06-11
Android API levels locked for TaskFlow Sync (Flutter 3.44.1 template).
minSdk = 26 (Android 8.0 Oreo, hard-pinned in android/app/build.gradle.kts line 22).
compileSdk = 36 (resolves from flutter.compileSdkVersion in FlutterExtension.kt).
targetSdk = 36 (resolves from flutter.targetSdkVersion in FlutterExtension.kt).
NDK version default = 28.2.13676358 (not installed; no native code in Phase 0).
AGP/Kotlin: JVM target 17 throughout (sourceCompatibility/targetCompatibility/jvmTarget).
Rule: minSdk stays at 26; compile/target follow the Flutter template (currently 36). Raising minSdk past 26 or unpinning compile/target = Tier-B halt.
