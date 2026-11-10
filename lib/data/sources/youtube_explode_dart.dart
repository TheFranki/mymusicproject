import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:flutter/foundation.dart' show debugPrint, debugPrintStack;
import 'package:http/http.dart' as http;

import 'dart:convert';

class YouTubeExtractorService {
  final YoutubeExplode _yt = YoutubeExplode();

  static const int _syncToleranceSec = 4;
  static const int _looseToleranceSec = 12;

  static final RegExp _longCompilationRegex = RegExp(
    r'\b(mix|album|full|compilaci[oó]n|set|playlist|hours?)\b',
    caseSensitive: false,
  );

  static const List<String> _blockedKeywords = [
    'tutorial',
    'gameplay',
    'react',
    'reacción',
    'unboxing',
    'review',
    'podcast',
    'opinion',
    'opini',
    'analysis',
    'analisis',
    'explained',
    'explicado',
    'critique',
    'crítica',
    'tier list',
    'ranking',
    'discussion',
    'discusión',
    'interview',
    'entrevista',
    'behind the scenes',
    'detrás de cámaras',
    'clips',
    'trailer',
  ];

  String _formatDuration(Duration? d) {
    if (d == null) return "00:00";
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final hours = d.inHours;
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    if (hours > 0) return "$hours:$minutes:$seconds";
    return "${d.inMinutes}:$seconds";
  }

  Map<String, String> _videoToMap(Video v) => {
    'id': v.id.value,
    'title': v.title,
    'author': v.author,
    'thumbnail': v.thumbnails.highResUrl,
    'duration': _formatDuration(v.duration),
  };

  Future<List<String>> getSearchSuggestions(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final results = await _yt.search.search(query);
      final suggestions = <String>[];
      for (final video in results.take(80)) {
        if (!suggestions.contains(video.title)) {
          suggestions.add(video.title);
        }
        if (suggestions.length >= 8) break;
      }
      return suggestions;
    } catch (e, st) {
      debugPrint('[YT SUGGEST] Error: $e');
      debugPrintStack(stackTrace: st);
      return [];
    }
  }

  Future<List<Map<String, String>>> searchVideos(String query) async {
    try {
      final searchResults = await _yt.search.search(query);

      return searchResults
          .take(80)
          .where((video) {
            final duration = video.duration;
            if (duration == null) return false;

            final seconds = duration.inSeconds;
            final titleLower = video.title.toLowerCase();

            final isLongCompilation = _longCompilationRegex.hasMatch(
              titleLower,
            );

            final maxAllowedSeconds = isLongCompilation ? 7200 : 900;
            if (seconds < 30 || seconds > maxAllowedSeconds) return false;

            for (final keyword in _blockedKeywords) {
              if (titleLower.contains(keyword)) return false;
            }

            return true;
          })
          .map(_videoToMap)
          .toList();
    } catch (e, st) {
      debugPrint('[YT SEARCH] Error: $e');
      debugPrintStack(stackTrace: st);
      return [];
    }
  }

  Future<List<Map<String, String>>> getRelatedVideos(String videoId) async {
    try {
      final video = await _yt.videos.get(videoId);
      final related = await _yt.videos.getRelatedVideos(video);
      if (related == null) return [];

      return related.take(15).map(_videoToMap).toList();
    } catch (e, st) {
      debugPrint('[YT RELATED] Error: $e');
      debugPrintStack(stackTrace: st);
      return [];
    }
  }

  Future<Map<String, String>?> getAudioUrl(String videoIdOrUrl) async {
    try {
      final video = await _yt.videos.get(videoIdOrUrl);
      final stream = await _pickPlayable(video.id, audioOnly: true);
      if (stream == null)
        throw Exception('Ningún cliente dio un stream válido');
      return {'title': video.title, 'url': stream.url.toString()};
    } catch (e, st) {
      debugPrint('ERROR OBTENIENDO AUDIO: $e');
      debugPrintStack(stackTrace: st);
      return null;
    }
  }

  Future<String?> getVideoUrl(String videoIdOrUrl) async {
    try {
      final video = await _yt.videos.get(videoIdOrUrl);
      final stream = await _pickPlayable(video.id, audioOnly: false);
      return stream?.url.toString();
    } catch (e) {
      debugPrint('Error obteniendo stream de video: $e');
      return null;
    }
  }

  Future<String?> searchThumbnailForSong(String title, String artist) async {
    try {
      final query = '$title $artist';
      final searchResults = await _yt.search.search(query);
      if (searchResults.isNotEmpty) {
        return searchResults.first.thumbnails.highResUrl;
      }
    } catch (e) {
      debugPrint('Error buscando carátula: $e');
    }
    return null;
  }

  void dispose() => _yt.close();

  bool _isUnknown(String s) {
    final v = s.trim().toLowerCase();
    return v.isEmpty ||
        v == '<unknown>' ||
        v == 'unknown' ||
        v == 'desconocido' ||
        v == 'artista desconocido' ||
        v == 'sin título';
  }

  String _clean(String input) {
    var r = input;
    r = r.replaceAll(
      RegExp(r'\.(mp3|m4a|flac|wav|ogg|aac|opus)$', caseSensitive: false),
      '',
    );
    r = r.replaceAll(RegExp(r'[「」『』]'), ' ');
    r = r.replaceAll(RegExp(r'[\[\(【（][^\]\)】）]*[\]\)】）]'), ' ');
    r = r.replaceAll(
      RegExp(
        r'\b(official\s*(music\s*)?(video|audio|mv)|lyrics?(\s*video)?|audio|video oficial|letra|hd|hq|4k|mv|tv size|full ver\.?)\b',
        caseSensitive: false,
      ),
      ' ',
    );
    r = r.replaceAll(RegExp(r'\s*[-–]\s*topic$', caseSensitive: false), '');
    r = r.replaceAll('_', ' ');
    r = r.replaceAll(RegExp(r'^\s*\d{1,3}\s*[-._)]\s*'), '');
    r = r.replaceAll(RegExp(r'\s+'), ' ').trim();
    return r;
  }

  Future<List<dynamic>?> _lrclibSearch(Map<String, String> params) async {
    final uri = Uri.https('lrclib.net', '/api/search', params);
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final res = await http
            .get(uri, headers: {'User-Agent': 'MiMusica/1.0'})
            .timeout(const Duration(seconds: 12));
        if (res.statusCode == 200) {
          final decoded = jsonDecode(utf8.decode(res.bodyBytes));
          return decoded is List ? decoded : <dynamic>[];
        }
        if (res.statusCode < 500 && res.statusCode != 429) return <dynamic>[];
      } catch (e) {
        debugPrint('[LYRICS] Error (intento ${attempt + 1}): $e');
      }
      await Future.delayed(const Duration(milliseconds: 600));
    }
    return null;
  }

  String _norm(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), '');

  bool _titleMatches(Map item, String title) {
    final t = _norm(title);
    final name = _norm(item['trackName']?.toString() ?? '');
    return t.isNotEmpty &&
        name.isNotEmpty &&
        (name.contains(t) || t.contains(name));
  }

  String? _pickLyrics(
    List<dynamic> results, {
    int? durationSec,
    bool strict = false,
    List<String> titles = const [],
    bool trustResults = false,
  }) {
    String? best;
    var bestDiff = double.infinity;
    String? plain;

    for (final item in results) {
      if (item is! Map) continue;
      final named = trustResults || titles.any((t) => _titleMatches(item, t));
      final d = (item['duration'] as num?)?.toDouble();
      final diff = (durationSec == null || d == null)
          ? null
          : (d - durationSec).abs();

      final synced = item['syncedLyrics']?.toString() ?? '';
      if (synced.isNotEmpty) {
        final tol = strict ? _syncToleranceSec : _looseToleranceSec;
        final ok = diff != null ? diff <= tol : named;
        final loose = !strict && named;
        final score = diff ?? _looseToleranceSec.toDouble();
        if ((ok || loose) && score < bestDiff) {
          bestDiff = score;
          best = synced;
        }
      }

      final pl = item['plainLyrics']?.toString() ?? '';
      if (plain == null && pl.isNotEmpty && named) plain = pl;
    }

    if (best != null) return best;
    return strict ? null : plain;
  }

  Future<String?> searchLyricsForSong(
    String title,
    String artist, {
    String? customQuery,
    int? durationSec,
  }) async {
    if (customQuery != null && customQuery.trim().isNotEmpty) {
      final res = await _lrclibSearch({'q': customQuery.trim()});
      if (res == null) {
        throw Exception('Sin conexión con el servidor de letras');
      }
      return _pickLyrics(res, durationSec: durationSec, trustResults: true);
    }

    final t = _clean(title);
    final a = _isUnknown(artist) ? '' : _clean(artist);
    String? splitArtist;
    String? splitTitle;
    final dash = RegExp(r'\s[-–]\s').firstMatch(t);
    if (dash != null) {
      splitArtist = t.substring(0, dash.start).trim();
      splitTitle = t.substring(dash.end).trim();
    }
    final hasSplit = splitTitle != null && splitTitle.isNotEmpty;
    final titles = [t, if (hasSplit) splitTitle];

    final attempts = <Map<String, String>>[];
    if (hasSplit) {
      attempts.add({
        'track_name': splitTitle,
        if (splitArtist != null && splitArtist.isNotEmpty)
          'artist_name': splitArtist,
      });
    }
    if (a.isNotEmpty) {
      attempts.add({'track_name': t, 'artist_name': a});
      attempts.add({'q': '$a $t'});
    }
    attempts.add({'track_name': t});
    attempts.add({'q': t});
    if (hasSplit) {
      attempts.add({'q': splitTitle});
    }

    final fetched = <List<dynamic>>[];
    var netFails = 0;
    for (final params in attempts) {
      if (params.values.any((v) => v.trim().isEmpty)) continue;
      final res = await _lrclibSearch(params);
      if (res == null) {
        netFails++;
        continue;
      }
      fetched.add(res);
      final exact = _pickLyrics(
        res,
        durationSec: durationSec,
        strict: true,
        titles: titles,
      );
      if (exact != null) return exact;
    }
    for (final res in fetched) {
      final any = _pickLyrics(res, durationSec: durationSec, titles: titles);
      if (any != null) return any;
    }
    if (netFails > 0 && fetched.isEmpty) {
      throw Exception('Sin conexión con el servidor de letras');
    }
    return null;
  }

  static final List<List<YoutubeApiClient>> _clientSets = [
    [YoutubeApiClient.androidVr],
    [YoutubeApiClient.ios],
    [YoutubeApiClient.tv],
    [YoutubeApiClient.safari],
  ];

  Future<bool> _isPlayable(Uri url) async {
    try {
      final res = await http
          .get(url, headers: {'Range': 'bytes=0-1'})
          .timeout(const Duration(seconds: 8));
      return res.statusCode == 200 || res.statusCode == 206;
    } catch (_) {
      return false;
    }
  }

  Future<StreamInfo?> _pickPlayable(
    VideoId id, {
    required bool audioOnly,
  }) async {
    for (var i = 0; i < _clientSets.length; i++) {
      final clients = _clientSets[i];
      try {
        final manifest = await _yt.videos.streamsClient.getManifest(
          id,
          ytClients: clients,
        );
        final candidates = <StreamInfo>[
          if (audioOnly && manifest.audioOnly.isNotEmpty)
            manifest.audioOnly.withHighestBitrate(),
          if (manifest.muxed.isNotEmpty) manifest.muxed.withHighestBitrate(),
        ];
        for (final s in candidates) {
          if (await _isPlayable(s.url)) return s;
        }
      } catch (e) {
        debugPrint('[YT] cliente #$i falló: $e');
      }
    }
    return null;
  }
}
