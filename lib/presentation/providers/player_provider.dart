import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/sources/local_audio_service.dart';
import '../../data/sources/youtube_explode_dart.dart';
import '../../domain/services/player_service.dart';
final playerServiceProvider = Provider((ref) => PlayerService());
final localAudioServiceProvider = Provider((ref) => LocalAudioService());
final ytExtractorProvider = Provider((ref) => YouTubeExtractorService());
final currentSongProvider = StateProvider<Map<String, String>?>((ref) => null);
final isPlayingProvider = StreamProvider<bool>((ref) {
  return ref.watch(playerServiceProvider).playingStream.cast<bool>();
});
final positionProvider = StreamProvider<Duration>((ref) {
  return ref.watch(playerServiceProvider).player.positionStream;
});
final durationProvider = StreamProvider<Duration?>((ref) {
  return ref.watch(playerServiceProvider).player.durationStream;
});
final isLoadingProvider = StateProvider<bool>((ref) => false);
final isChangingSongProvider = StateProvider<bool>((ref) => false);
final isShuffleEnabledProvider = StateProvider<bool>((ref) => false);
final repeatModeProvider = StateProvider<int>(
  (ref) => 0,
);
final isVideoModeProvider = StateProvider<bool>((ref) => false);
final effectiveCurrentSongProvider = Provider<Map<String, String>?>((ref) {
  final currentSong = ref.watch(currentSongProvider);
  if (currentSong == null) return null;
  final songId = currentSong['id'];
  final meta = ref.watch(customSongMetadataProvider)[songId];
  if (meta != null) {
    return {
      ...currentSong,
      if (meta.title.isNotEmpty) 'title': meta.title,
      if (meta.artist.isNotEmpty) 'author': meta.artist,
    };
  }
  return currentSong;
});

class SongMetaData {
  final String title;
  final String artist;
  final String artworkPathOrUrl;
  final String lyrics;
  final int lyricsOffsetMs;

  SongMetaData({
    required this.title,
    required this.artist,
    required this.artworkPathOrUrl,
    required this.lyrics,
    this.lyricsOffsetMs = 0,
  });

  SongMetaData copyWith({
    String? title,
    String? artist,
    String? artworkPathOrUrl,
    String? lyrics,
    int? lyricsOffsetMs,
  }) => SongMetaData(
    title: title ?? this.title,
    artist: artist ?? this.artist,
    artworkPathOrUrl: artworkPathOrUrl ?? this.artworkPathOrUrl,
    lyrics: lyrics ?? this.lyrics,
    lyricsOffsetMs: lyricsOffsetMs ?? this.lyricsOffsetMs,
  );

  Map<String, dynamic> toMap() => {
    'title': title,
    'artist': artist,
    'artworkPathOrUrl': artworkPathOrUrl,
    'lyrics': lyrics,
    'lyricsOffsetMs': lyricsOffsetMs,
  };

  factory SongMetaData.fromMap(Map<String, dynamic> map) {
    return SongMetaData(
      title: map['title'] ?? '',
      artist: map['artist'] ?? '',
      artworkPathOrUrl: map['artworkPathOrUrl'] ?? '',
      lyrics: map['lyrics'] ?? '',
      lyricsOffsetMs: (map['lyricsOffsetMs'] as num?)?.toInt() ?? 0,
    );
  }
}

final customSongMetadataProvider =
    StateNotifierProvider<
      CustomSongMetadataNotifier,
      Map<String, SongMetaData>
    >((ref) => CustomSongMetadataNotifier());

class CustomSongMetadataNotifier
    extends StateNotifier<Map<String, SongMetaData>> {
  CustomSongMetadataNotifier() : super({}) {
    _loadMetadata();
  }

  Future<void> _loadMetadata() async {
    final prefs = await SharedPreferences.getInstance();
    final map = <String, SongMetaData>{};
    for (final key in prefs.getKeys()) {
      if (key.startsWith('meta_')) {
        final songId = key.replaceFirst('meta_', '');
        final jsonStr = prefs.getString(key);
        if (jsonStr != null) {
          try {
            map[songId] = SongMetaData.fromMap(jsonDecode(jsonStr));
          } catch (_) {}
        }
      }
    }
    state = map;
  }

  Future<void> saveMetadata(String songId, SongMetaData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('meta_$songId', jsonEncode(data.toMap()));
    state = {...state, songId: data};
  }
}

const String _savedSongKey = 'persisted_current_song';
const String _savedPositionKey = 'persisted_playback_position';
Future<void> savePlaybackState(
  Map<String, String>? song,
  Duration position,
) async {
  final prefs = await SharedPreferences.getInstance();
  if (song == null || song.isEmpty) {
    await prefs.remove(_savedSongKey);
    await prefs.remove(_savedPositionKey);
    return;
  }
  await prefs.setString(_savedSongKey, jsonEncode(song));
  await prefs.setInt(_savedPositionKey, position.inMilliseconds);
}

Future<Map<String, dynamic>?> getSavedPlaybackState() async {
  final prefs = await SharedPreferences.getInstance();
  final songJson = prefs.getString(_savedSongKey);
  final positionMs = prefs.getInt(_savedPositionKey) ?? 0;
  if (songJson == null) return null;
  final Map<String, dynamic> songMap = jsonDecode(songJson);
  return {
    'song': songMap.map((key, value) => MapEntry(key, value.toString())),
    'position': Duration(milliseconds: positionMs),
  };
}
