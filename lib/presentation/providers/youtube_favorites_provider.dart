import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _youtubeFavoritesStorageKey = 'favorite_youtube_songs_json';

final youtubeFavoritesProvider =
    StateNotifierProvider<YoutubeFavoritesNotifier, List<Map<String, String>>>((ref) {
  return YoutubeFavoritesNotifier();
});

class YoutubeFavoritesNotifier extends StateNotifier<List<Map<String, String>>> {
  YoutubeFavoritesNotifier() : super([]) {
    _loadFavoritesFromStorage();
  }

  Future<void> _loadFavoritesFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedList = prefs.getStringList(_youtubeFavoritesStorageKey) ?? [];
      final decodedFavorites = savedList.map((item) {
        final Map<String, dynamic> decoded = jsonDecode(item);
        return decoded.map((key, value) => MapEntry(key, value.toString()));
      }).toList();

      state = decodedFavorites;
      debugPrint('Cargados: ${state.length} videos');
    } catch (e) {
      debugPrint('Error al cargar favoritos: $e');
    }
  }

  Future<void> _saveFavoritesToStorage(List<Map<String, String>> favorites) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encodedList = favorites.map((song) => jsonEncode(song)).toList();
      await prefs.setStringList(_youtubeFavoritesStorageKey, encodedList);
      debugPrint('Guardados exitosamente');
    } catch (e) {
      debugPrint('Error al guardar favoritos: $e');
    }
  }

  void toggleFavorite(Map<String, dynamic> song) {
    final songId = song['id']?.toString() ?? '';
    if (songId.isEmpty) return;

    final Map<String, String> cleanSong = {
      'id': songId,
      'title': song['title']?.toString() ?? 'Sin título',
      'author': song['author']?.toString() ?? song['artist']?.toString() ?? 'Artista desconocido',
      'thumbnail': song['thumbnail']?.toString() ?? '',
    };

    final exists = state.any((s) => s['id'] == songId);

    if (exists) {
      state = state.where((s) => s['id'] != songId).toList();
      debugPrint('Eliminado de favoritos: $songId');
    } else {
      state = [...state, cleanSong];
      debugPrint('Agregado a favoritos: $songId');
    }
    _saveFavoritesToStorage(state);
  }

  bool isFavorite(String songId) {
    return state.any((s) => s['id'] == songId);
  }
}