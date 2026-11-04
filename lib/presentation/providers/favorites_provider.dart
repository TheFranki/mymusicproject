import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _favoritesStorageKey = 'favorite_songs_paths';

final favoritesIdsProvider =
    StateNotifierProvider<FavoritesNotifier, List<String>>((ref) {
  return FavoritesNotifier();
});

class FavoritesNotifier extends StateNotifier<List<String>> {
  FavoritesNotifier() : super([]) {
    _loadFavoritesFromStorage();
  }

  Future<void> _loadFavoritesFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedFavorites = prefs.getStringList(_favoritesStorageKey) ?? [];
      state = savedFavorites;
      debugPrint(' avoritos cargados del almacenamiento: ${state.length} canciones');
    } catch (e) {
      debugPrint('Error al cargar favoritos: $e');
    }
  }

  Future<void> _saveFavoritesToStorage(List<String> favorites) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_favoritesStorageKey, favorites);
      debugPrint('Favoritos guardados exitosamente');
    } catch (e) {
      debugPrint('Error al guardar favoritos: $e');
    }
  }

  void toggleFavorite(String songPath) {
    if (songPath.isEmpty) return;

    if (state.contains(songPath)) {
      state = state.where((path) => path != songPath).toList();
      debugPrint('Eliminado de favoritos: $songPath');
    } else {
      state = [...state, songPath];
      debugPrint('Agregado a favoritos: $songPath');
    }
    _saveFavoritesToStorage(state);
  }
  bool isFavorite(String songPath) {
    return state.contains(songPath);
  }
}