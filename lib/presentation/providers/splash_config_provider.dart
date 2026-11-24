import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';

class SplashConfig {
  const SplashConfig({this.bgColor, this.accent});

  final Color? bgColor;
  final Color? accent;

  SplashConfig copyWith({
    Color? bgColor,
    Color? accent,
    bool clearBg = false,
    bool clearAccent = false,
  }) =>
      SplashConfig(
        bgColor: clearBg ? null : (bgColor ?? this.bgColor),
        accent: clearAccent ? null : (accent ?? this.accent),
      );
}

const _kBg = 'splash_bg_color';
const _kAccent = 'splash_accent_color';

final splashConfigProvider =
    StateNotifierProvider<SplashConfigNotifier, SplashConfig>(
  (ref) => SplashConfigNotifier(),
);

class SplashConfigNotifier extends StateNotifier<SplashConfig> {
  SplashConfigNotifier([SplashConfig? initial])
      : super(initial ?? const SplashConfig());

  static Future<SplashConfig> loadSaved() async {
    try {
      final p = await SharedPreferences.getInstance();
      final bg = p.getInt(_kBg);
      final ac = p.getInt(_kAccent);
      return SplashConfig(
        bgColor: bg == null ? null : clampBg(Color(bg)),
        accent: ac == null ? null : Color(ac),
      );
    } catch (_) {
      return const SplashConfig();
    }
  }

  Future<void> set(SplashConfig c) async {
    state = c;
    try {
      final p = await SharedPreferences.getInstance();
      if (c.bgColor == null) {
        await p.remove(_kBg);
      } else {
        await p.setInt(_kBg, c.bgColor!.toARGB32());
      }
      if (c.accent == null) {
        await p.remove(_kAccent);
      } else {
        await p.setInt(_kAccent, c.accent!.toARGB32());
      }
    } catch (_) {}
  }
}