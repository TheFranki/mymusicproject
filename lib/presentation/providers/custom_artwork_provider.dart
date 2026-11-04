import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mymusicproject/data/sources/persistent_image.dart';

final customArtworkProvider =
    StateNotifierProvider<CustomArtworkNotifier, Map<String, String>>((ref) {
      return CustomArtworkNotifier();
    });

class CustomArtworkNotifier extends StateNotifier<Map<String, String>> {
  CustomArtworkNotifier() : super({}) {
    _loadArtworks();
  }

  Future<void> _loadArtworks() async {
    final prefs = await SharedPreferences.getInstance();
    final map = <String, String>{};
    for (final key in prefs.getKeys()) {
      if (key.startsWith('art_')) {
        final songId = key.replaceFirst('art_', '');
        final urlOrPath = prefs.getString(key);
        if (urlOrPath == null) continue;

        final saved = await persistImage(urlOrPath, folder: 'artworks');
        if (saved != urlOrPath) await prefs.setString(key, saved);
        map[songId] = saved;
      }
    }
    state = map;
  }

  Future<void> setArtwork(String songId, String pathOrUrl) async {
    final prefs = await SharedPreferences.getInstance();
    final previous = state[songId];
    final saved = await persistImage(pathOrUrl, folder: 'artworks');
    await prefs.setString('art_$songId', saved);
    state = {...state, songId: saved};
    if (previous != null && previous != saved) {
      await deletePersistedImage(previous);
    }
  }

  Future<void> removeArtwork(String songId) async {
    final prefs = await SharedPreferences.getInstance();
    final previous = state[songId];
    await prefs.remove('art_$songId');
    state = {
      for (final e in state.entries)
        if (e.key != songId) e.key: e.value,
    };
    await deletePersistedImage(previous);
  }
}
