import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'player_provider.dart';
import 'local_music_provider.dart';
import 'custom_artwork_provider.dart';
import 'playlist_provider.dart';
import 'search_provider.dart';

const String _savedQueueKey = 'persisted_playback_queue';
String _s(Map m, String k) => m[k]?.toString().trim() ?? '';
String _first(Iterable<String?> values) {
  for (final v in values) {
    if (v != null && v.isNotEmpty) return v;
  }
  return '';
}

Map<String, String> resolveSong(
  Map<String, dynamic> raw, {
  required Map<String, Map<String, dynamic>> library,
  required Map<String, SongMetaData> metadata,
  required Map<String, String> artworks,
}) {
  final id = _s(raw, 'id');
  final live = library[id];
  final meta = metadata[id];
  final src = live ?? raw;
  final data = _first([_s(src, 'data'), _s(raw, 'data')]);
  final flag = _s(raw, 'isLocal');
  final isLocal =
      live != null || flag == 'true' || (flag.isEmpty && data.isNotEmpty);
  final title = _first([meta?.title, _s(src, 'title'), _s(raw, 'title')]);
  final artist = _first([
    meta?.artist,
    _s(src, 'artist'),
    _s(src, 'author'),
    _s(raw, 'author'),
    _s(raw, 'artist'),
  ]);
  final thumb = _first([
    artworks[id],
    meta?.artworkPathOrUrl,
    _s(raw, 'thumbnail'),
    _s(src, 'thumbnail'),
  ]);
  return {
    'id': id,
    'title': title.isEmpty ? 'Sin título' : title,
    'author': artist.isEmpty ? 'Desconocido' : artist,
    'artist': artist.isEmpty ? 'Desconocido' : artist,
    'thumbnail': thumb,
    'isLocal': isLocal ? 'true' : 'false',
    'data': data,
  };
}

final libraryByIdProvider = Provider<Map<String, Map<String, dynamic>>>((ref) {
  final songs =
      ref.watch(localSongsProvider).value ?? const <Map<String, dynamic>>[];
  return {for (final s in songs) s['id'].toString(): s};
});

class PlaybackQueue {
  final List<Map<String, String>> source;
  final List<Map<String, String>> order;
  final int index;
  final String? playlistId;
  final String origin;

  const PlaybackQueue({
    this.source = const [],
    this.order = const [],
    this.index = -1,
    this.playlistId,
    this.origin = 'library',
  });

  bool get isEmpty => order.isEmpty;
  bool get isPlaylist => playlistId != null;

  PlaybackQueue copyWith({List<Map<String, String>>? order, int? index}) =>
      PlaybackQueue(
        source: source,
        order: order ?? this.order,
        index: index ?? this.index,
        playlistId: playlistId,
        origin: origin,
      );
}

final playbackOriginLabelProvider = Provider<String?>((ref) {
  final q = ref.watch(playbackQueueProvider);
  final current = ref.watch(currentSongProvider);
  if (q.isEmpty || q.index < 0 || q.index >= q.order.length) return null;
  if (q.order[q.index]['id'] != current?['id']) return null;

  if (q.playlistId != null) {
    final playlists = ref.watch(playlistsProvider);
    final i = playlists.indexWhere((p) => p.id == q.playlistId);
    return i < 0 ? 'Playlist' : 'Playlist · ${playlists[i].name}';
  }
  return q.origin == 'favorites' ? 'Favoritos' : 'Biblioteca';
});

final playbackQueueProvider = StateProvider<PlaybackQueue>(
  (ref) => const PlaybackQueue(),
);

final upcomingSongsProvider = Provider<List<Map<String, String>>>((ref) {
  final q = ref.watch(playbackQueueProvider);
  if (q.isEmpty || q.index < 0) return const [];
  final library = ref.watch(libraryByIdProvider);
  final metadata = ref.watch(customSongMetadataProvider);
  final artworks = ref.watch(customArtworkProvider);
  final n = q.order.length;
  final result = <Map<String, String>>[];
  for (var k = 1; k < n && result.length < 10; k++) {
    result.add(
      resolveSong(
        q.order[(q.index + k) % n],
        library: library,
        metadata: metadata,
        artworks: artworks,
      ),
    );
  }
  return result;
});

final resolvedPlaylistSongsProvider =
    Provider.family<List<Map<String, String>>, String>((ref, playlistId) {
      final playlists = ref.watch(playlistsProvider);
      final idx = playlists.indexWhere((p) => p.id == playlistId);
      if (idx < 0) return const [];
      final playlist = playlists[idx];
      final library = ref.watch(libraryByIdProvider);
      final metadata = ref.watch(customSongMetadataProvider);
      final artworks = ref.watch(customArtworkProvider);
      final result = <Map<String, String>>[];
      for (final stored in playlist.songs) {
        final song = resolveSong(
          stored,
          library: library,
          metadata: metadata,
          artworks: artworks,
        );
        final missing =
            song['isLocal'] == 'true' &&
            library.isNotEmpty &&
            !library.containsKey(song['id']);
        if (!missing) result.add(song);
      }
      return result;
    });

final playerControllerProvider = Provider<PlayerController>((ref) {
  final controller = PlayerController(ref);
  ref.onDispose(controller.dispose);
  ref.listen<bool>(isShuffleEnabledProvider, (prev, next) {
    if (prev != next) controller.rebuildForShuffle(next);
  });
  return controller;
});

class PlayerController {
  String? _pendingCountId;
  PlayerController(this.ref);
  final Ref ref;
  int _token = 0;
  bool _restored = false;
  final List<String> _recentYoutube = [];
  String? _relatedFor;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<bool>? _playSub;
  void dispose() {
    _posSub?.cancel();
    _playSub?.cancel();
  }

  Map<String, String> _resolve(Map<String, dynamic> raw) => resolveSong(
    raw,
    library: ref.read(libraryByIdProvider),
    metadata: ref.read(customSongMetadataProvider),
    artworks: ref.read(customArtworkProvider),
  );
  PlaybackQueue _build(
    List<Map<String, String>> source,
    String startId,
    bool shuffle,
    String? playlistId, {
    String origin = 'library',
  }) {
    var idx = source.indexWhere((s) => s['id'] == startId);
    if (idx < 0) idx = 0;
    if (!shuffle) {
      return PlaybackQueue(
        source: source,
        order: source,
        index: idx,
        playlistId: playlistId,
        origin: origin,
      );
    }
    final rest = [...source]..removeAt(idx);
    rest.shuffle();
    return PlaybackQueue(
      source: source,
      order: [source[idx], ...rest],
      index: 0,
      playlistId: playlistId,
      origin: origin,
    );
  }

  void _setQueue(PlaybackQueue q) {
    ref.read(playbackQueueProvider.notifier).state = q;
    ref.read(isPlaylistActiveProvider.notifier).state = q.isPlaylist;
    ref.read(playlistQueueProvider.notifier).state = q.isPlaylist
        ? q.order
        : <Map<String, String>>[];
    unawaited(_persistQueue());
  }

  Map<String, String> _slim(Map<String, String> s) =>
      s['isLocal'] == 'true' ? {'id': s['id']!, 'isLocal': 'true'} : {...s};

  Future<void> _persistQueue() async {
    try {
      final q = ref.read(playbackQueueProvider);
      final prefs = await SharedPreferences.getInstance();
      if (q.isEmpty) {
        await prefs.remove(_savedQueueKey);
        return;
      }
      await prefs.setString(
        _savedQueueKey,
        jsonEncode({
          'source': q.source.map(_slim).toList(),
          'order': q.order.map((s) => s['id']).toList(),
          'playlist': q.playlistId,
          'origin': q.origin,
        }),
      );
    } catch (e) {
      debugPrint('[PlayerController] Error guardando cola: $e');
    }
  }

  Future<PlaybackQueue?> _loadQueue(String currentId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_savedQueueKey);
      if (raw == null) return null;

      final m = jsonDecode(raw) as Map<String, dynamic>;
      final source = (m['source'] as List)
          .map((e) => _resolve(Map<String, dynamic>.from(e as Map)))
          .toList();
      final byId = {for (final s in source) s['id']!: s};
      final order = (m['order'] as List)
          .map((id) => byId[id.toString()])
          .whereType<Map<String, String>>()
          .toList();

      final index = order.indexWhere((s) => s['id'] == currentId);
      if (index < 0) return null;

      return PlaybackQueue(
        source: source,
        order: order,
        index: index,
        playlistId: m['playlist'] as String?,
        origin: (m['origin'] as String?) ?? 'library',
      );
    } catch (e) {
      debugPrint('[PlayerController] Error cargando cola: $e');
      return null;
    }
  }

  // ---------------- GUARDADO DE POSICIÓN ----------------
  void _startPositionSaver() {
    _posSub?.cancel();
    _playSub?.cancel();
    final player = ref.read(playerServiceProvider).player;

    void save(Duration pos) {
      final song = ref.read(currentSongProvider);
      if (song == null || player.processingState != ProcessingState.ready) {
        return;
      }
      savePlaybackState(song, pos);
    }

    var last = DateTime.fromMillisecondsSinceEpoch(0);
    _posSub = player.positionStream.listen((pos) {
      if (!player.playing) return;

      final pending = _pendingCountId;
      if (pending != null &&
          pending == ref.read(currentSongProvider)?['id']?.toString()) {
        final total = player.duration;
        var threshold = const Duration(seconds: 30);
        if (total != null && total < const Duration(seconds: 60)) {
          threshold = total ~/ 2;
        }
        if (pos >= threshold) {
          _pendingCountId = null;
          unawaited(ref.read(playCountProvider.notifier).increment(pending));
        }
      }

      final now = DateTime.now();
      if (now.difference(last) < const Duration(seconds: 3)) return;
      last = now;
      save(pos);
    });

    _playSub = player.playingStream.listen((playing) {
      if (!playing) save(player.position);
    });
  }

  // ---------------- RESTAURAR SESIÓN ----------------
  Future<void> restoreLastSession() async {
    if (_restored) return;
    _restored = true;

    final saved = await getSavedPlaybackState();
    if (saved == null) {
      _startPositionSaver();
      return;
    }
    try {
      await ref.read(localSongsProvider.future);
    } catch (_) {}

    final song = _resolve(Map<String, dynamic>.from(saved['song'] as Map));
    final position = saved['position'] as Duration;

    final q = await _loadQueue(song['id']!);
    if (q != null) _setQueue(q);
    await _play(song, startAt: position, autoPlay: false);
    _startPositionSaver();
    unawaited(ensureRelated());
  }

  Future<void> playContext(
    List<Map<String, dynamic>> songs,
    Map<String, dynamic> start, {
    String? playlistId,
    String origin = 'library',
  }) async {
    try {
      await ref.read(localSongsProvider.future);
    } catch (_) {}

    final source = songs.map(_resolve).toList();
    final startSong = _resolve(start);
    if (!source.any((s) => s['id'] == startSong['id'])) {
      source.insert(0, startSong);
    }
    final q = _build(
      source,
      startSong['id']!,
      ref.read(isShuffleEnabledProvider),
      playlistId,
      origin: origin,
    );
    _setQueue(q);

    if (_isAlreadyLoaded(startSong['id']!)) return;

    await _play(q.order[q.index]);
  }

  Future<void> playFromQueue(String id) async {
    final q = ref.read(playbackQueueProvider);
    final i = q.order.indexWhere((s) => s['id'] == id);
    if (i < 0) return;
    ref.read(playbackQueueProvider.notifier).state = q.copyWith(index: i);
    await _play(q.order[i]);
  }

  Future<void> next({bool auto = false}) async {
    final q = _validQueue();
    if (q == null) {
      await _nextRelated();
      return;
    }

    final service = ref.read(playerServiceProvider);
    final repeat = ref.read(repeatModeProvider);

    if (auto && repeat == 2) {
      await service.player.seek(Duration.zero);
      await service.player.play();
      return;
    }

    var i = q.index + 1;
    if (i >= q.order.length) {
      if (auto && repeat == 0) {
        await service.pause();
        await service.player.seek(Duration.zero);
        return;
      }
      i = 0;
    }
    ref.read(playbackQueueProvider.notifier).state = q.copyWith(index: i);
    await _play(q.order[i]);
  }

  Future<void> previous() async {
    final q = _validQueue();
    final service = ref.read(playerServiceProvider);

    if (q == null || service.player.position > const Duration(seconds: 3)) {
      await service.player.seek(Duration.zero);
      return;
    }
    final i = q.index - 1 < 0 ? q.order.length - 1 : q.index - 1;
    ref.read(playbackQueueProvider.notifier).state = q.copyWith(index: i);
    await _play(q.order[i]);
  }

  void toggleShuffle() {
    final notifier = ref.read(isShuffleEnabledProvider.notifier);
    notifier.state = !notifier.state;
  }

  void rebuildForShuffle(bool enabled) {
    final q = _validQueue();
    if (q == null) return;
    _setQueue(
      _build(
        q.source,
        q.order[q.index]['id']!,
        enabled,
        q.playlistId,
        origin: q.origin,
      ),
    );
  }

  void toggleRepeat() {
    final mode = (ref.read(repeatModeProvider) + 1) % 3;
    ref.read(repeatModeProvider.notifier).state = mode;
    ref
        .read(playerServiceProvider)
        .player
        .setLoopMode(mode == 2 ? LoopMode.one : LoopMode.off);
  }

  PlaybackQueue? _validQueue() {
    final q = ref.read(playbackQueueProvider);
    if (q.isEmpty || q.index < 0 || q.index >= q.order.length) return null;
    final currentId = ref.read(currentSongProvider)?['id']?.toString();
    return q.order[q.index]['id'] == currentId ? q : null;
  }

  /// True si esa canción ya está cargada (sonando o en pausa) y no terminó.
  bool _isAlreadyLoaded(String id) {
    final currentId = ref.read(currentSongProvider)?['id']?.toString();
    final state = ref.read(playerServiceProvider).player.processingState;
    return currentId == id &&
        state != ProcessingState.idle &&
        state != ProcessingState.completed;
  }

  void _rememberYoutube(Map<String, String> song) {
    if (song['isLocal'] == 'true') return;
    final id = song['id']!;
    _recentYoutube
      ..remove(id)
      ..add(id);
    if (_recentYoutube.length > 15) _recentYoutube.removeAt(0);
  }

  /// Reproduce un video de YouTube. Si ya es la canción actual, NO la reinicia.
  Future<void> playYoutube(Map<String, dynamic> video) async {
    final id = video['id']?.toString() ?? '';
    if (id.isEmpty) return;
    if (_isAlreadyLoaded(id)) {
      unawaited(ensureRelated());
      return;
    }

    final author =
        video['author']?.toString() ??
        video['artist']?.toString() ??
        'Artista desconocido';

    final song = <String, String>{
      'id': id,
      'title': video['title']?.toString() ?? 'Sin título',
      'author': author,
      'artist': author,
      'thumbnail': video['thumbnail']?.toString() ?? '',
      'isLocal': 'false',
      'data': '',
    };

    // Un video de YouTube no pertenece a la cola local
    _setQueue(const PlaybackQueue());
    await _play(song);
    unawaited(_refreshRelated(id));
  }

  // ---------- YouTube: recomendaciones ----------
  Future<void> _nextRelated() async {
    final current = ref.read(currentSongProvider);
    if (current == null || current['isLocal'] == 'true') return;

    final related = ref.read(relatedVideosProvider);
    if (related.isEmpty) return;

    final video = Map<String, String>.from(
      related.firstWhere(
        (v) => !_recentYoutube.contains(v['id']),
        orElse: () => related.first,
      ),
    );
    final id = video['id'] ?? '';
    if (id.isEmpty) return;

    video['isLocal'] = 'false';
    video['data'] = '';
    await _play(video);
    unawaited(_refreshRelated(id));
  }

  Future<void> _refreshRelated(String id) async {
    final list = await ref.read(ytExtractorProvider).getRelatedVideos(id);
    if (ref.read(currentSongProvider)?['id'] != id) return;
    if (list.isNotEmpty) {
      ref.read(relatedVideosProvider.notifier).state = list;
      _relatedFor = id;
    }
  }

  Future<void> ensureRelated() async {
    final current = ref.read(currentSongProvider);
    if (current == null || current['isLocal'] == 'true') return;
    final id = current['id'] ?? '';
    if (id.isEmpty) return;

    final hasRelated = ref.read(relatedVideosProvider).isNotEmpty;
    if (hasRelated && _relatedFor == id) return;
    await _refreshRelated(id);
  }

  Future<void> _play(
    Map<String, String> raw, {
    Duration startAt = Duration.zero,
    bool autoPlay = true,
  }) async {
    final song = _resolve(raw);
    final id = song['id']!;
    final token = ++_token;
    _rememberYoutube(song);
    _pendingCountId = autoPlay ? id : null;

    ref.read(currentSongProvider.notifier).state = song;
    await savePlaybackState(song, startAt);

    if (ref.read(isPlaylistActiveProvider)) {
      ref.read(playlistCurrentSongProvider.notifier).state = song;
    }
    ref.read(isLoadingProvider.notifier).state = true;

    try {
      final service = ref.read(playerServiceProvider);
      final initial = startAt == Duration.zero ? null : startAt;

      if (song['isLocal'] == 'true') {
        if (song['data']!.isEmpty) throw Exception('Ruta de archivo vacía');
        await service.playLocalFile(
          song['data']!,
          id: id,
          title: song['title']!,
          author: song['author']!,
          thumbnailUrl: song['thumbnail'],
          initialPosition: initial,
          autoPlay: autoPlay,
        );
      } else {
        final data = await ref.read(ytExtractorProvider).getAudioUrl(id);
        if (data == null || data['url'] == null) {
          throw Exception('No se pudo obtener el audio');
        }
        await service.playFromUrl(
          data['url']!,
          id: id,
          title: song['title']!,
          author: song['author']!,
          thumbnailUrl: song['thumbnail'],
          initialPosition: initial,
          autoPlay: autoPlay,
        );
      }
    } catch (e, st) {
      debugPrint('[PlayerController] Error al reproducir "$id": $e');
      debugPrintStack(stackTrace: st);
    } finally {
      if (token == _token) {
        ref.read(isLoadingProvider.notifier).state = false;
      }
    }
  }

  Future<void> pauseAndSave() async {
    final service = ref.read(playerServiceProvider);
    await service.pause();
    final currentSong = ref.read(currentSongProvider);
    await savePlaybackState(currentSong, service.player.position);
  }
}
