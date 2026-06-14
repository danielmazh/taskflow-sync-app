# Release signing — TaskFlow Sync

This project signs Play Store uploads with an **operator-owned upload keystore**. The keystore and its passwords MUST NEVER be committed. Gradle reads them at build time from `android/key.properties`, which is `.gitignore`d.

## One-time setup (per machine)

1. Generate the upload keystore (operator did this already — repeat only if you're setting up a new build machine):

   ```bash
   keytool -genkeypair -v \
     -keystore ~/taskflow-upload-keystore.jks \
     -keyalg RSA -keysize 2048 -validity 10000 \
     -alias upload
   ```

   Pick a strong store password and a strong key password. Record both in your password manager — losing them means you can never publish an update under the same Play Store listing (Play App Signing lets Google rotate the *app* signing key, but the *upload* key is yours forever unless you petition Google for a reset).

2. Create `android/key.properties` (NOT committed) using this template:

   ```properties
   storeFile=/absolute/path/to/taskflow-upload-keystore.jks
   storePassword=YOUR_STORE_PASSWORD
   keyAlias=upload
   keyPassword=YOUR_KEY_PASSWORD
   ```

   Notes:
   - `storeFile` may be absolute (recommended for an operator keystore that lives outside the repo) or relative to `android/app/`.
   - `keyAlias` must match the `-alias` you used with `keytool` (we use `upload`).
   - File mode: `chmod 600 android/key.properties` so other local accounts can't read it.

3. Verify the gitignore rules cover it:

   ```bash
   git check-ignore -v android/key.properties
   # → android/.gitignore:12:key.properties	android/key.properties
   ```

## Build a signed release App Bundle (for Play upload)

```bash
source .tools/env.sh
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab`. Upload that to Play Console (Internal testing or Closed testing track).

For a signed APK (sideload / pre-Play smoke test) use:

```bash
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`.

## How the Gradle config decides

`android/app/build.gradle.kts` reads `rootProject.file("key.properties")` (= `android/key.properties`):

- **Present** → the `release` signingConfig is populated from it; `buildTypes.release.signingConfig = signingConfigs["release"]`.
- **Absent** → `buildTypes.release.signingConfig = signingConfigs["debug"]` so `flutter run --release` still works on a fresh checkout without the keystore.

That fallback exists for development convenience only — a debug-signed APK CANNOT be uploaded to Play.

## Versioning rules (Play)

`pubspec.yaml → version: 1.0.0+1` maps to:
- `versionName = "1.0.0"` (what users see)
- `versionCode = 1` (monotonic integer; Play rejects re-uploads with a non-increasing code)

Bump the `+N` suffix on **every** Play upload, even if the user-facing name doesn't change. A typical pattern:

```
1.0.0+1   first internal upload
1.0.0+2   bug-fix internal build
1.0.1+3   first patch
1.1.0+4   minor feature
```

## After the first upload — release SHA-1

Play App Signing will give Google a **release** signing certificate (separate from your upload key). The release SHA-1 of *that* cert is what you must register against the Android OAuth client in GCP (alongside the debug SHA-1 already registered). Find it in:

**Play Console → Setup → App signing → App signing key certificate → SHA-1 certificate fingerprint**.

Until then the Android OAuth client only accepts the debug SHA-1, so signed-release APKs sideloaded outside Play won't be able to complete Google Sign-In.

## What never goes in git

- `*.jks`, `*.keystore`
- `android/key.properties`
- The store password, the key password, or any backup of either
- Screenshots showing any of the above
