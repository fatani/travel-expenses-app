import 'package:flutter/material.dart';

/// Keeps snackbar feedback quiet: one visible at a time, floating, no stacking.
abstract final class CalmSnackBar {
  static const Duration undoDuration = Duration(seconds: 4);
  static const Duration briefDuration = Duration(seconds: 3);

  static void clear(BuildContext context) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..clearSnackBars();
  }

  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> show(
    BuildContext context,
    SnackBar snackBar,
  ) {
    clear(context);
    return ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: snackBar.duration,
        content: snackBar.content,
        action: snackBar.action,
        backgroundColor: snackBar.backgroundColor,
        dismissDirection: snackBar.dismissDirection,
        margin: snackBar.margin,
        padding: snackBar.padding,
        width: snackBar.width,
        elevation: snackBar.elevation,
        shape: snackBar.shape,
      ),
    );
  }

  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showMessage(
    BuildContext context, {
    required String message,
    Duration duration = briefDuration,
    SnackBarAction? action,
  }) {
    return show(
      context,
      SnackBar(
        duration: duration,
        content: Text(message),
        action: action,
      ),
    );
  }

  static Future<SnackBarClosedReason> showUndo(
    BuildContext context, {
    required String message,
    required String undoLabel,
    required VoidCallback onUndo,
    Duration duration = undoDuration,
  }) {
    final controller = show(
      context,
      SnackBar(
        duration: duration,
        content: Text(message),
        action: SnackBarAction(
          label: undoLabel,
          onPressed: onUndo,
        ),
      ),
    );
    return controller.closed;
  }
}
