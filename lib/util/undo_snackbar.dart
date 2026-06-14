import 'package:flutter/material.dart';

/// Show a single-line snackbar with an UNDO action. Cancels any in-flight
/// snackbar first so quick repeated actions don't queue behind each other.
void showUndoSnackBar(
  BuildContext context, {
  required String message,
  required VoidCallback onUndo,
  Duration duration = const Duration(seconds: 4),
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: duration,
      behavior: SnackBarBehavior.floating,
      action: SnackBarAction(
        label: 'UNDO',
        onPressed: onUndo,
      ),
    ),
  );
}
