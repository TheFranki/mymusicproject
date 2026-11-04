import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:flutter/foundation.dart' show debugPrint, debugPrintStack;
import 'package:http/http.dart' as http;

import 'dart:convert';

class YouTubeExtractorService {
  final YoutubeExplode _yt = YoutubeExplode();

  String _formatDuration(Duration? d) {
    if (d == null) return "00:00";
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return "${d.inMinutes}:${twoDigits(d.inSeconds.remainder(60))}";
  }

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
      debugPrint('[YT RELATED] Error: $e');
      debugPrintStack(stackTrace: st);
      return [];
    }
  }

  Future<List<Map<String, String>>> searchVideos(String query) async {
    try {
      var searchResults = await _yt.search.search(query);

      return searchResults
          .take(80)
          .where((video) {
            final duration = video.duration;
            if (duration == null) return false;

            final seconds = duration.inSeconds;
            final titleLower = video.title.toLowerCase();

            bool isLongCompilation =
                titleLower.contains('mix') ||
                titleLower.contains('album') ||
                titleLower.contains('full') ||
                titleLower.contains('compilación') ||
                titleLower.contains('set') ||
                titleLower.contains('playlist') ||
                titleLower.contains('hour');

            final maxAllowedSeconds = isLongCompilation ? 7200 : 900;
            if (seconds < 30 || seconds > maxAllowedSeconds) return false;

            final blockedKeywords = [
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
            ];

            for (var keyword in blockedKeywords) {
              if (titleLower.contains(keyword)) {
                return false;
              }
            }

            return true;
          })
          .map((video) {
            return {
              'id': video.id.value,
              'title': video.title,
              'author': video.author,
              'thumbnail': video.thumbnails.highResUrl,
              'duration': _formatDuration(video.duration),
            };
          })
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

      return related.take(15).map((v) {
        return {
          'id': v.id.value,
          'title': v.title,
          'author': v.author,
          'thumbnail': v.thumbnails.highResUrl,
          'duration': _formatDuration(v.duration),
        };
      }).toList();
    } catch (e, st) {
      debugPrint('[YT RELATED] Error: $e');
      debugPrintStack(stackTrace: st);
      return [];
    }
  }

  Future<Map<String, String>?> getAudioUrl(String videoIdOrUrl) async {
    try {
      final video = await _yt.videos.get(videoIdOrUrl);
      final manifest = await _yt.videos.streamsClient.getManifest(video.id);

      if (manifest.muxed.isEmpty) {
        throw Exception('No hay stream muxed disponible');
      }
      final stream = manifest.muxed.first;
      return {'title': video.title, 'url': stream.url.toString()};
    } catch (e, stackTrace) {
      debugPrint('ERROR OBTENIENDO VIDEO: $e');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  void dispose() => _yt.close();
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

  Future<String?> getVideoUrl(String videoIdOrUrl) async {
    try {
      final video = await _yt.videos.get(videoIdOrUrl);
      final manifest = await _yt.videos.streamsClient.getManifest(video.id);
      if (manifest.muxed.isEmpty) {
        return null;
      }
      final stream = manifest.muxed.withHighestBitrate();
      return stream.url.toString();
    } catch (e) {
      debugPrint('Error obteniendo stream de video: $e');
      return null;
    }
  }

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
    r = r.replaceAll(RegExp(r'[\[\(][^\]\)]*[\]\)]'), ' ');
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

  Future<List<dynamic>> _lrclibSearch(Map<String, String> params) async {
    try {
      final uri = Uri.https('lrclib.net', '/api/search', params);
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is List) return decoded;
      }
    } catch (e) {
      debugPrint('[LYRICS] Error: $e');
    }
    return [];
  }

  static const int _syncToleranceSec = 5;
  String? _pickLyrics(
    List<dynamic> results, {
    int? durationSec,
    bool strict = false,
  }) {
    String? bestSynced;
    double bestDiff = double.infinity;
    for (final item in results) {
      final synced = item['syncedLyrics']?.toString();
      if (synced == null || synced.isEmpty) continue;
      final d = (item['duration'] as num?)?.toDouble();
      final diff = (durationSec == null || d == null)
          ? 0.0
          : (d - durationSec).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        bestSynced = synced;
      }
    }

    if (bestSynced != null && bestDiff <= _syncToleranceSec) return bestSynced;
    if (strict) return null;
    for (final item in results) {
      final plain = item['plainLyrics']?.toString();
      if (plain != null && plain.isNotEmpty) return plain;
    }
    return bestSynced;
  }

  Future<String?> searchLyricsForSong(
    String title,
    String artist, {
    String? customQuery,
    int? durationSec,
  }) async {
    if (customQuery != null && customQuery.trim().isNotEmpty) {
      return _pickLyrics(
        await _lrclibSearch({'q': customQuery.trim()}),
        durationSec: durationSec,
      );
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

    final attempts = <Map<String, String>>[];
    if (splitTitle != null && splitTitle.isNotEmpty) {
      attempts.add({
        'track_name': splitTitle,
        if (splitArtist!.isNotEmpty) 'artist_name': splitArtist,
      });
    }
    if (a.isNotEmpty) {
      attempts.add({'track_name': t, 'artist_name': a});
      attempts.add({'q': '$a $t'});
    }
    attempts.add({'track_name': t});
    attempts.add({'q': t});
    if (splitTitle != null && splitTitle.isNotEmpty) {
      attempts.add({'q': splitTitle});
    }

    final fetched = <List<dynamic>>[];
    for (final params in attempts) {
      if (params.values.any((v) => v.trim().isEmpty)) continue;
      final res = await _lrclibSearch(params);
      fetched.add(res);
      final exact = _pickLyrics(res, durationSec: durationSec, strict: true);
      if (exact != null) return exact;
    }
    for (final res in fetched) {
      final any = _pickLyrics(res, durationSec: durationSec);
      if (any != null) return any;
    }
    return null;
  }
}
