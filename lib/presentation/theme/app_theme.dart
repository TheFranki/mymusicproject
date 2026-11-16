import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum GradientDir { vertical, diagonal, horizontal, radial }

extension GradientDirLabel on GradientDir {
  String get label => switch (this) {
    GradientDir.vertical => 'Vertical',
    GradientDir.diagonal => 'Diagonal',
    GradientDir.horizontal => 'Horizontal',
    GradientDir.radial => 'Radial',
  };
}

const double kMaxBgBrightness = 0.40;

Color clampBg(Color c) {
  final h = HSVColor.fromColor(c);
  return h.value <= kMaxBgBrightness
      ? c
      : h.withValue(kMaxBgBrightness).toColor();
}

enum RowStyle { plain, lines, cards }

extension RowStyleLabel on RowStyle {
  String get label => switch (this) {
        RowStyle.plain => 'Normal',
        RowStyle.lines => 'Con líneas',
        RowStyle.cards => 'Tarjetas',
      };
}

class AppThemeConfig {
  const AppThemeConfig({
    required this.name,
    required this.accent,
    required this.bg,
    this.dir = GradientDir.vertical,
    this.rowStyle = RowStyle.lines,
    this.rowColor,
  });

  final String name;
  final Color accent;
  final List<Color> bg;
  final GradientDir dir;
  final RowStyle rowStyle;
  final Color? rowColor; // null = igual al acento

  bool get isGradient => bg.length > 1;

  Color get lineColor => rowColor ?? accent;

  /// Texto de la canción que suena: si el color es muy oscuro, se aclara.
  Color get lineTextColor => lineColor.computeLuminance() < 0.25
      ? Color.lerp(lineColor, Colors.white, 0.6)!
      : lineColor;

  AppThemeConfig copyWith({
    String? name,
    Color? accent,
    List<Color>? bg,
    GradientDir? dir,
    RowStyle? rowStyle,
    Color? rowColor,
    bool clearRowColor = false,
  }) =>
      AppThemeConfig(
        name: name ?? this.name,
        accent: accent ?? this.accent,
        bg: bg ?? this.bg,
        dir: dir ?? this.dir,
        rowStyle: rowStyle ?? this.rowStyle,
        rowColor: clearRowColor ? null : (rowColor ?? this.rowColor),
      );

  /// Solo colores y fondo (se usa para marcar la paleta elegida).
  bool sameColors(AppThemeConfig o) =>
      accent.toARGB32() == o.accent.toARGB32() &&
      bg.length == o.bg.length &&
      (!isGradient || dir == o.dir) &&
      Iterable<int>.generate(bg.length)
          .every((i) => bg[i].toARGB32() == o.bg[i].toARGB32());

  /// Todo (se usa para saber si hay cambios sin guardar).
  bool sameLook(AppThemeConfig o) =>
      sameColors(o) &&
      rowStyle == o.rowStyle &&
      rowColor?.toARGB32() == o.rowColor?.toARGB32();

  BoxDecoration get decoration {
    if (!isGradient) return BoxDecoration(color: bg.first);
    return BoxDecoration(
      gradient: switch (dir) {
        GradientDir.vertical => LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: bg,
          ),
        GradientDir.diagonal => LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: bg,
          ),
        GradientDir.horizontal => LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: bg,
          ),
        GradientDir.radial => RadialGradient(
            center: const Alignment(0, -0.5),
            radius: 1.3,
            colors: bg,
          ),
      },
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'accent': accent.toARGB32(),
        'bg': bg.map((c) => c.toARGB32()).toList(),
        'dir': dir.index,
        'rowStyle': rowStyle.index,
        'rowColor': rowColor?.toARGB32(),
      };

  factory AppThemeConfig.fromJson(Map<String, dynamic> j) {
    final bg = (j['bg'] as List).map((e) => clampBg(Color(e as int))).toList();
    final dirIdx =
        ((j['dir'] as int?) ?? 0).clamp(0, GradientDir.values.length - 1);
    final styleIdx = ((j['rowStyle'] as int?) ?? RowStyle.lines.index)
        .clamp(0, RowStyle.values.length - 1);
    final rc = j['rowColor'] as int?;
    return AppThemeConfig(
      name: (j['name'] as String?) ?? 'Personalizado',
      accent: Color(j['accent'] as int),
      bg: bg.isEmpty ? const [Color(0xFF0F0F0F)] : bg,
      dir: GradientDir.values[dirIdx],
      rowStyle: RowStyle.values[styleIdx],
      rowColor: rc == null ? null : Color(rc),
    );
  }
}

class AppThemePresets {
  static const List<AppThemeConfig> all = [
    AppThemeConfig(
      name: 'Medianoche',
      accent: Color(0xFF448AFF),
      bg: [Color(0xFF0F0F0F)],
    ),
    AppThemeConfig(
      name: 'AMOLED',
      accent: Color(0xFF90CAF9),
      bg: [Color(0xFF000000)],
    ),
    AppThemeConfig(
      name: 'Océano',
      accent: Color(0xFF00E5FF),
      bg: [Color(0xFF0B132B), Color(0xFF1C3A5E)],
    ),
    AppThemeConfig(
      name: 'Aurora',
      accent: Color(0xFF64FFDA),
      bg: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
      dir: GradientDir.diagonal,
    ),
    AppThemeConfig(
      name: 'Atardecer',
      accent: Color(0xFFFF8A65),
      bg: [Color(0xFF1F1135), Color(0xFF5C2A3F), Color(0xFF63351D)],
      dir: GradientDir.diagonal,
    ),
    AppThemeConfig(
      name: 'Bosque',
      accent: Color(0xFF69F0AE),
      bg: [Color(0xFF0B1F17), Color(0xFF1B4D35)],
    ),
    AppThemeConfig(
      name: 'Neón rosa',
      accent: Color(0xFFFF4081),
      bg: [Color(0xFF1A0B1F), Color(0xFF4A1442)],
      dir: GradientDir.radial,
    ),
    AppThemeConfig(
      name: 'Púrpura',
      accent: Color(0xFFB388FF),
      bg: [Color(0xFF120A2A), Color(0xFF2A1B62)],
    ),
    AppThemeConfig(
      name: 'Carbón rojo',
      accent: Color(0xFFFF5252),
      bg: [Color(0xFF141414), Color(0xFF3A1212)],
      dir: GradientDir.horizontal,
    ),
    AppThemeConfig(
      name: 'Ámbar',
      accent: Color(0xFFFFC107),
      bg: [Color(0xFF16120A), Color(0xFF3D2F10)],
      dir: GradientDir.diagonal,
    ),
  ];
}

ThemeData buildAppTheme(AppThemeConfig c) {
  final base = c.bg.first;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: c.accent,
        brightness: Brightness.dark,
      ).copyWith(
        primary: c.accent,
        onPrimary: c.accent.computeLuminance() > 0.5
            ? Colors.black
            : Colors.white,
        surface: Color.lerp(base, Colors.black, 0.35),
        surfaceContainerLow: Color.lerp(base, Colors.black, 0.2),
        surfaceContainer: Color.lerp(base, Colors.white, 0.06),
        surfaceContainerHigh: Color.lerp(base, Colors.white, 0.10),
      );
    return ThemeData.dark(useMaterial3: true).copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: base,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
    ),
  );
}

const _themeKey = 'app_theme_config';

final appThemeProvider =
    StateNotifierProvider<AppThemeNotifier, AppThemeConfig>(
      (ref) => AppThemeNotifier(),
    );

class AppThemeNotifier extends StateNotifier<AppThemeConfig> {
  AppThemeNotifier([AppThemeConfig? initial])
    : super(initial ?? AppThemePresets.all.first);

  static Future<AppThemeConfig> loadSaved() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_themeKey);
      if (raw != null) {
        return AppThemeConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      }
    } catch (_) {}
    return AppThemePresets.all.first;
  }

  Future<void> set(AppThemeConfig c) async {
    state = c.copyWith(bg: c.bg.map(clampBg).toList());
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeKey, jsonEncode(state.toJson()));
    } catch (_) {}
  }
}

extension AppThemePanels on AppThemeConfig {
  Color get panelColor => Color.alphaBlend(
    accent.withValues(alpha: 0.14),
    Color.lerp(bg.last, Colors.black, 0.25)!,
  );
  Color get cardColor => Color.alphaBlend(
    Colors.white.withValues(alpha: 0.07),
    Color.lerp(bg.first, Colors.black, 0.2)!,
  );
}
