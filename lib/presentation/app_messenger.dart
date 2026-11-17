import 'package:flutter/material.dart';

import 'widgets/app_snack.dart';

final appMessengerKey = GlobalKey<ScaffoldMessengerState>();

void showAppMessage(String text, {AppSnackKind kind = AppSnackKind.info}) {
  final messenger = appMessengerKey.currentState;
  if (messenger == null) {
    debugPrint(
      '[showAppMessage] appMessengerKey no está conectada a MaterialApp: "$text"',
    );
    return;
  }
  showAppSnack(messenger, text, kind: kind);
}
