import 'dart:async';
import 'package:flutter/material.dart';

void showAppSnack(
  ScaffoldMessengerState messenger,
  String message, {
  Color? color,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 3),
}) {
  messenger.clearSnackBars();

  final controller = messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: color,
      duration: duration,
      behavior: SnackBarBehavior.floating,
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
    Color? color,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
  }) {
    showAppSnack(
      ScaffoldMessenger.of(this),
      message,
      color: color,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
  }
}