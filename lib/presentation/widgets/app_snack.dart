import 'dart:async';

import 'package:flutter/material.dart';

enum AppSnackKind { info, success, warning, error }

void showAppSnack(
  ScaffoldMessengerState messenger,
  String message, {
  AppSnackKind kind = AppSnackKind.info,
  Color? color,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 3),
}) {
  final (icon, tint) = switch (kind) {
    AppSnackKind.info => (Icons.info_outline, Colors.white24),
    AppSnackKind.success => (Icons.check_circle_outline, Colors.greenAccent),
    AppSnackKind.warning => (Icons.warning_amber_rounded, Colors.amberAccent),
    AppSnackKind.error => (Icons.error_outline, Colors.redAccent),
  };

  messenger.clearSnackBars();
  final controller = messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      duration: duration,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: kind == AppSnackKind.info ? tint : tint.withValues(alpha: 0.5),
        ),
      ),
      content: Row(
        children: [
          Builder(
            builder: (ctx) => Icon(
              icon,
              size: 20,
              color: kind == AppSnackKind.info
                  ? Theme.of(ctx).colorScheme.primary
                  : tint,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
      action: actionLabel == null
          ? null
          : SnackBarAction(label: actionLabel, onPressed: onAction ?? () {}),
    ),
  );

  var closed = false;
  controller.closed.then((_) => closed = true);
  Timer(duration, () {
    if (!closed) controller.close();
  });
}

extension AppSnack on BuildContext {
  void snack(
    String message, {
    AppSnackKind kind = AppSnackKind.info,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
  }) {
    showAppSnack(
      ScaffoldMessenger.of(this),
      message,
      kind: kind,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
  }
}
