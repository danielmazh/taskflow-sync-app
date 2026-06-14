Date: 2026-06-11
Android toolchain installed project-locally at <project>/.tools/.
JDK: Temurin OpenJDK 17.0.19 LTS (aarch64) → .tools/jdk-17/Contents/Home (JAVA_HOME).
Android SDK: cmdline-tools 20.0, platform-tools 37.0.0, build-tools 36.0.0, platforms;android-36, emulator 36.6.11, system-images;android-36;google_apis;arm64-v8a, cmake 3.22.1 (auto-pulled by AGP).
AVD: phase0_pixel under .tools/avd/ (ANDROID_AVD_HOME).
Activate via: source .tools/env.sh  — exports JAVA_HOME, ANDROID_HOME/SDK_ROOT/AVD_HOME, prepends Flutter + Android paths.
Rule: Never install Android tooling globally; always source .tools/env.sh before any flutter/adb/gradle work.
