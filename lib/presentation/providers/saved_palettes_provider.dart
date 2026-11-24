import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';

const int kMaxSavedPalettes = 24;
const int kMaxSavedColors = 30;
const _kPalettes = 'saved_palettes';
const _kColors = 'saved_colors';

final savedPalettesProvider =
    StateNotifierProvider<SavedPalettesNotifier, List<AppThemeConfig>>(
  (ref) => SavedPalettesNotifier(),
);

class SavedPalettesNotifier extends StateNotifier<List<AppThemeConfig>> {
  SavedPalettesNotifier() : super(const []) {
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final list = <AppThemeConfig>[];
      for (final s in p.getStringList(_kPalettes) ?? const <String>[]) {
        try {
          list.add(
            AppThemeConfig.fromJson(jsonDecode(s) as Map<String, dynamic>),
          );
        } catch (_) {}
      }
      state = list;
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList(
        _kPalettes,
        [for (final c in state) jsonEncode(c.toJson())],
      );
    } catch (_) {}
  }

  void add(AppThemeConfig c) {
    final next = [...state, c];
    if (next.length > kMaxSavedPalettes) next.removeAt(0);
    state = next;
    _save();
  }

  void removeAt(int index) {
    if (index < 0 || index >= state.length) return;
    state = [...state]..removeAt(index);
    _save();
  }
}

final savedColorsProvider =
    StateNotifierProvider<SavedColorsNotifier, List<Color>>(
  (ref) => SavedColorsNotifier(),
);

class SavedColorsNotifier extends StateNotifier<List<Color>> {
  SavedColorsNotifier() : super(const []) {
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      state = [
        for (final s in p.getStringList(_kColors) ?? const <String>[])
          if (int.tryParse(s) != null) Color(int.parse(s)),
      ];
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList(
        _kColors,
        [for (final c in state) c.toARGB32().toString()],
      );
    } catch (_) {}
  }

  void add(Color c) {
    if (state.any((e) => e.toARGB32() == c.toARGB32())) return;
    final next = [...state, c];
    if (next.length > kMaxSavedColors) next.removeAt(0);
    state = next;
    _save();
  }

  void remove(Color c) {
    state = state.where((e) => e.toARGB32() != c.toARGB32()).toList();
    _save();
  }
}