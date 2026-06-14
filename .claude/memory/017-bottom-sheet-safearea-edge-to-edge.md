Date: 2026-06-12

Under Android edge-to-edge (default in modern Flutter on Android 15+), `showModalBottomSheet(useSafeArea: true)` ensures top inset for status bar but does NOT pad the **bottom system gesture bar**. The classic `Padding(EdgeInsets.only(bottom: viewInsets.bottom))` only covers the soft keyboard — when no keyboard is shown, the sheet's action row sits flush against the viewport bottom and gets clipped by the gesture indicator.

Fix: wrap the sheet body in `SafeArea(top: false, child: ...)` INSIDE the existing keyboard `Padding`. Applied to `add_task_sheet.dart` and `voice_capture_sheet.dart`.

Rule: Every modal bottom sheet must wrap its content in `SafeArea(top: false)` in addition to `viewInsets.bottom` padding. `useSafeArea: true` alone is not enough on Android edge-to-edge.
