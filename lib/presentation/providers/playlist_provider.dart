import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mymusicproject/data/sources/persistent_image.dart';

const String _playlistsStorageKey = 'app_custom_playlists_v1';

class Playlist {
  final String id;
  final String name;
  final String? imagePathOrUrl;
  final List<Map<String, String>> songs;
  Playlist({
    required this.id,
    required this.name,
    this.imagePathOrUrl,
    required this.songs,
  });
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'imagePathOrUrl': imagePathOrUrl,
      'songs': songs,
    };
  }

  factory Playlist.fromMap(Map<String, dynamic> map) {
    return Playlist(
      id: map['id'] ?? '',
      name: map['name'] ?? 'Sin nombre',
      imagePathOrUrl: map['imagePathOrUrl'],
      songs:
          (map['songs'] as List<dynamic>?)
              ?.map((s) => Map<String, String>.from(s as Map))
              .toList() ??
          [],
    );
  }

  Playlist copyWith({
    String? name,
    String? imagePathOrUrl,
    List<Map<String, String>>? songs,
  }) {
    return Playlist(
      id: id,
      name: name ?? this.name,
      imagePathOrUrl: imagePathOrUrl ?? this.imagePathOrUrl,
      songs: songs ?? this.songs,
    );
  }
}

final playlistsProvider =
    StateNotifierProvider<PlaylistsNotifier, List<Playlist>>((ref) {
      return PlaylistsNotifier();
    });

class PlaylistsNotifier extends StateNotifier<List<Playlist>> {
  PlaylistsNotifier() : super([]) {
    _loadFromStorage();
  }
  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_playlistsStorageKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(jsonStr);
        var list = decoded.map((item) => Playlist.fromMap(item)).toList();
        state = list;

        // Migración: portadas viejas en caché -> almacenamiento permanente
        var changed = false;
        final migrated = <Playlist>[];
        for (final p in list) {
          final path = p.imagePathOrUrl;
          if (path != null && path.isNotEmpty) {
            final saved = await persistImage(path);
            if (saved != path) {
              changed = true;
              migrated.add(p.copyWith(imagePathOrUrl: saved));
              continue;
            }
          }
          migrated.add(p);
        }
        if (changed) {
          state = migrated;
          await _saveToStorage();
        }
      }
    } catch (_) {}
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(state.map((p) => p.toMap()).toList());
      await prefs.setString(_playlistsStorageKey, encoded);
    } catch (_) {}
  }

  Future<void> createPlaylist(String name, {String? imagePathOrUrl}) async {
    final newPlaylist = Playlist(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name.trim().isEmpty ? 'Nueva Playlist' : name.trim(),
      imagePathOrUrl: imagePathOrUrl,
      songs: [],
    );
    state = [...state, newPlaylist];
    await _saveToStorage();
  }

  Future<void> updatePlaylist(
    String id, {
    String? newName,
    String? newImagePath,
  }) async {
    String? oldImage;
    state = state.map((p) {
      if (p.id == id) {
        oldImage = p.imagePathOrUrl;
        return p.copyWith(
          name: newName ?? p.name,
          imagePathOrUrl: newImagePath ?? p.imagePathOrUrl,
        );
      }
      return p;
    }).toList();
    await _saveToStorage();
    if (newImagePath != null && newImagePath != oldImage) {
      await deletePersistedImage(oldImage);
    }
  }

  Future<void> deletePlaylist(String id) async {
    final idx = state.indexWhere((p) => p.id == id);
    final image = idx >= 0 ? state[idx].imagePathOrUrl : null;
    state = state.where((p) => p.id != id).toList();
    await _saveToStorage();
    await deletePersistedImage(image);
  }

  Future<bool> addSongToPlaylist(
    String playlistId,
    Map<String, String> song,
  ) async {
    final songId = song['id'] ?? '';
    if (songId.isEmpty) return false;
    final isLocal = song['isLocal'] == 'true';
    final slim = isLocal
        ? <String, String>{'id': songId, 'isLocal': 'true'}
        : <String, String>{
            'id': songId,
            'isLocal': 'false',
            'title': song['title'] ?? '',
            'author': song['author'] ?? '',
            'thumbnail': song['thumbnail'] ?? '',
          };

    bool added = false;
    state = state.map((p) {
      if (p.id == playlistId && !p.songs.any((s) => s['id'] == songId)) {
        added = true;
        return p.copyWith(songs: [...p.songs, slim]);
      }
      return p;
    }).toList();

    if (added) await _saveToStorage();
    return added;
  }

  Future<void> removeSongFromPlaylist(String playlistId, String songId) async {
    state = state.map((p) {
      if (p.id == playlistId) {
        return p.copyWith(
          songs: p.songs.where((s) => s['id'] != songId).toList(),
        );
      }
      return p;
    }).toList();
    await _saveToStorage();
  }
}

final isPlaylistActiveProvider = StateProvider<bool>((ref) => false);
final playlistQueueProvider = StateProvider<List<Map<String, String>>>(
  (ref) => [],
);
final playlistCurrentSongProvider = StateProvider<Map<String, String>?>(
  (ref) => null,
);
