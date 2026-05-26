import 'package:flutter/material.dart';

/// Keeps snackbar feedback quiet: one visible at a time, floating, no stacking.
abstract final class CalmSnackBar {
  static const Duration undoDuration = Duration(seconds: 4);
  static const Duration briefDuration = Duration(seconds: 3);

  static bool _undoSessionActive = false;

  /// True while an undo snackbar is visible and must not be replaced casually.
  static bool get isUndoSessionActive => _undoSessionActive;

  static void clear(BuildContext context) {
    _undoSessionActive = false;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..clearSnackBars();
  }

  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _showSnackBar(
    BuildContext context,
    SnackBar snackBar, {
    bool replaceActiveUndo = false,
  }) {
    if (!context.mounted) {
      return null;
    }
    if (!replaceActiveUndo) {
      clear(context);
    } else {
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger
        ?..hideCurrentSnackBar()
        ..clearSnackBars();
    }

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

  static void showMessage(
    BuildContext context, {
    required String message,
    Duration duration = briefDuration,
    SnackBarAction? action,
  }) {
    if (!context.mounted || _undoSessionActive) {
      return;
    }

    _showSnackBar(
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
    if (!context.mounted) {
      return Future.value(SnackBarClosedReason.remove);
    }

    final controller = _showSnackBar(
      context,
      SnackBar(
        duration: duration,
        content: Text(message),
        action: SnackBarAction(
          label: undoLabel,
          onPressed: onUndo,
        ),
      ),
      replaceActiveUndo: true,
    );
    if (controller == null) {
      return Future.value(SnackBarClosedReason.remove);
    }
    _undoSessionActive = true;
    return controller.closed.then((reason) {
      _undoSessionActive = false;
      return reason;
    });
  }
}
