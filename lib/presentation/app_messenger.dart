import 'package:flutter/material.dart';

final appMessengerKey = GlobalKey<ScaffoldMessengerState>();

void showAppMessage(String text) {
  appMessengerKey.currentState
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 3)),
    );
}