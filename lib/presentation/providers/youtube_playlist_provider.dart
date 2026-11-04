import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mymusicproject/data/sources/persistent_image.dart';

const String _youtubePlaylistsStorageKey = 'app_youtube_custom_playlists_v1';

class YoutubePlaylist {
  final String id;
  final String name;
  final String? imagePathOrUrl;
  final List<Map<String, String>> songs;
  YoutubePlaylist({
    required this.id,
    required this.name,
    this.imagePathOrUrl,
    required this.songs,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'imagePathOrUrl': imagePathOrUrl,
    'songs': songs,
  };

  factory YoutubePlaylist.fromMap(Map<String, dynamic> map) {
    return YoutubePlaylist(
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

  YoutubePlaylist copyWith({
    String? name,
    String? imagePathOrUrl,
    bool clearImage = false,
    List<Map<String, String>>? songs,
  }) {
    return YoutubePlaylist(
      id: id,
      name: name ?? this.name,
      imagePathOrUrl: clearImage
          ? null
          : (imagePathOrUrl ?? this.imagePathOrUrl),
      songs: songs ?? this.songs,
    );
  }
}

final youtubePlaylistsProvider =
    StateNotifierProvider<YoutubePlaylistsNotifier, List<YoutubePlaylist>>((
      ref,
    ) {
      return YoutubePlaylistsNotifier();
    });

class YoutubePlaylistsNotifier extends StateNotifier<List<YoutubePlaylist>> {
  YoutubePlaylistsNotifier() : super([]) {
    _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_youtubePlaylistsStorageKey);
      if (jsonStr == null || jsonStr.isEmpty) return;

      final List<dynamic> decoded = jsonDecode(jsonStr);
      final list = decoded
          .map((item) => YoutubePlaylist.fromMap(item))
          .toList();
      state = list;

      var changed = false;
      final migrated = <YoutubePlaylist>[];
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
    } catch (_) {}
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(state.map((p) => p.toMap()).toList());
      await prefs.setString(_youtubePlaylistsStorageKey, encoded);
    } catch (_) {}
  }

  Future<void> createPlaylist(String name, {String? imagePathOrUrl}) async {
    final newPlaylist = YoutubePlaylist(
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
  bool removeImage = false,
}) async {
  String? oldImage;
  state = state.map((p) {
    if (p.id != id) return p;
    oldImage = p.imagePathOrUrl;
    final name = (newName ?? '').trim();
    return p.copyWith(
      name: name.isEmpty ? p.name : name,
      imagePathOrUrl: removeImage ? null : newImagePath,
      clearImage: removeImage,
    );
  }).toList();
  await _saveToStorage();

  final replaced = newImagePath != null && newImagePath != oldImage;
  if (removeImage || replaced) await deletePersistedImage(oldImage);
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

    final cleanSong = <String, String>{
      'id': songId,
      'isLocal': 'false',
      'title': song['title'] ?? '',
      'author': song['author'] ?? song['artist'] ?? '',
      'thumbnail': song['thumbnail'] ?? '',
    };

    bool added = false;
    state = state.map((p) {
      if (p.id == playlistId && !p.songs.any((s) => s['id'] == songId)) {
        added = true;
        return p.copyWith(songs: [...p.songs, cleanSong]);
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
