import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SongMetaData {
  final String title;
  final String artist;
  final String artworkPathOrUrl;
  final String lyrics;

  SongMetaData({
    required this.title,
    required this.artist,
    required this.artworkPathOrUrl,
    required this.lyrics,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'artist': artist,
      'artworkPathOrUrl': artworkPathOrUrl,
      'lyrics': lyrics,
    };
  }

  factory SongMetaData.fromMap(Map<String, dynamic> map) {
    return SongMetaData(
      title: map['title'] ?? '',
      artist: map['artist'] ?? '',
      artworkPathOrUrl: map['artworkPathOrUrl'] ?? '',
      lyrics: map['lyrics'] ?? '',
    );
  }
}

final customSongMetadataProvider = StateNotifierProvider<CustomSongMetadataNotifier, Map<String, SongMetaData>>((ref) {
  return CustomSongMetadataNotifier();
});
class CustomSongMetadataNotifier extends StateNotifier<Map<String, SongMetaData>> {
  CustomSongMetadataNotifier() : super({}) {
    _loadMetadata();
  }

  Future<void> _loadMetadata() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    final map = <String, SongMetaData>{};

    for (final key in keys) {
      if (key.startsWith('meta_')) {
        final songId = key.replaceFirst('meta_', '');
        final jsonStr = prefs.getString(key);
        if (jsonStr != null) {
          try {
            final decoded = jsonDecode(jsonStr);
            map[songId] = SongMetaData.fromMap(decoded);
          } catch (_) {}
        }
      }
    }
    state = map;
  }

  Future<void> saveMetadata(String songId, SongMetaData data) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(data.toMap());
    await prefs.setString('meta_$songId', jsonStr);
    state = {...state, songId: data};
  }
}