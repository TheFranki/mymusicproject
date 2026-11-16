import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'local_music_provider.dart';
import 'player_controller.dart';

const String _oldPathsKey = 'favorite_songs_paths';
const String _idsKey = 'favorite_song_ids';

final favoritesIdsProvider =
    StateNotifierProvider<FavoritesNotifier, List<String>>((ref) {
  return FavoritesNotifier(ref);
});

/// Guarda IDs de canciones. El `state` expone las RUTAS actuales de esas
/// canciones, así que el resto de la app funciona sin cambios.
class FavoritesNotifier extends StateNotifier<List<String>> {
  FavoritesNotifier(this._ref) : super([]) {
    _ref.listen(libraryByIdProvider, (_, _) => _publish());
    _load();
  }

  final Ref _ref;
  List<String> _ids = [];
  bool _loaded = false;

  Map<String, Map<String, dynamic>> get _lib => _ref.read(libraryByIdProvider);

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _ids = prefs.getStringList(_idsKey) ?? [];
      _loaded = true;
      _publish();

      // Migración única: rutas antiguas -> ids
      final oldPaths = prefs.getStringList(_oldPathsKey);
      if (oldPaths != null && oldPaths.isNotEmpty) {
        try {
          await _ref.read(localSongsProvider.future);
        } catch (_) {}
        final byPath = {
          for (final e in _lib.entries) (e.value['data']?.toString() ?? ''): e.key,
        };
        for (final p in oldPaths) {
          final id = byPath[p];
          if (id != null && !_ids.contains(id)) _ids.add(id);
        }
        await prefs.setStringList(_idsKey, _ids);
        await prefs.remove(_oldPathsKey);
        _publish();
      }
    } catch (e) {
      debugPrint('Error al cargar favoritos: $e');
    }
  }

  void _publish() {
    if (!_loaded) return;
    final lib = _lib;
    state = [
      for (final id in _ids)
        if ((lib[id]?['data']?.toString() ?? '').isNotEmpty)
          lib[id]!['data'].toString(),
    ];
  }

  String? _idForPath(String path) {
    for (final e in _lib.entries) {
      if (e.value['data']?.toString() == path) return e.key;
    }
    return null;
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_idsKey, _ids);
    } catch (e) {
      debugPrint('Error al guardar favoritos: $e');
    }
  }

  void toggleFavorite(String songPath) {
    if (songPath.isEmpty) return;
    final id = _idForPath(songPath);
    if (id == null) return;
    _ids = _ids.contains(id)
        ? _ids.where((e) => e != id).toList()
        : [..._ids, id];
    _save();
    _publish();
  }

  bool isFavorite(String songPath) => state.contains(songPath);
}