import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mymusicproject/presentation/widgets/player/lrc_parser.dart';

class LyricsNetworkError implements Exception {
  @override
  String toString() => 'Sin conexión con el servidor de letras';
}

class LyricsCandidate {
  LyricsCandidate({
    required this.id,
    required this.track,
    required this.artist,
    required this.album,
    required this.duration,
    required this.synced,
    required this.plain,
  });

  final int id;
  final String track;
  final String artist;
  final String album;
  final double? duration;
  final String synced;
  final String plain;

  int score = 0;
  LrcQuality? quality;
  bool get hasSynced =>
      synced.isNotEmpty && (quality == null || quality!.isSynced);
  String get lyrics => hasSynced ? synced : plain;
  String get preview {
    for (final raw in lyrics.split('\n')) {
      final t = raw.replaceAll(RegExp(r'\[[^\]]*\]|<[^>]*>'), '').trim();
      if (t.isNotEmpty) return t;
    }
    return '';
  }
}

class LyricsSearchService {
  static const int autoAcceptScore = 55;
  static const int _confidentScore = 85;

  static String norm(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), '');

  static bool _isUnknown(String s) {
    final v = s.trim().toLowerCase();
    return v.isEmpty ||
        v == '<unknown>' ||
        v == 'unknown' ||
        v == 'desconocido' ||
        v == 'artista desconocido' ||
        v == 'sin título';
  }

  static String cleanText(String input) {
    var r = input;
    r = r.replaceAll(
      RegExp(r'\.(mp3|m4a|flac|wav|ogg|aac|opus)$', caseSensitive: false),
      '',
    );
    r = r.replaceAll(RegExp(r'[\[\(【（][^\]\)】）]*[\]\)】）]'), ' ');
    r = r.replaceAll(RegExp(r'[「」『』“”"]'), ' ');
    r = r.replaceAll(
      RegExp(
        r'\b(official\s*(music\s*)?(video|audio|mv)|lyrics?(\s*video)?|audio|video oficial|letra|hd|hq|4k|mv|tv size|full ver\.?)\b',
        caseSensitive: false,
      ),
      ' ',
    );
    r = r.replaceAll(
      RegExp(
        r'\b(\d{4}\s*)?(ver\.?|version|remaster(ed)?)\b',
        caseSensitive: false,
      ),
      ' ',
    );
    r = r.replaceAll(RegExp(r'\b(ED|OP)\b'), ' ');
    r = r.replaceAll(RegExp(r'\s*[-–]\s*topic$', caseSensitive: false), '');
    r = r.replaceAll(
      RegExp(r'\b(feat\.?|ft\.?)\s.*$', caseSensitive: false),
      '',
    );
    r = r.replaceAll('_', ' ');
    r = r.replaceAll(RegExp(r'^\s*\d{1,3}\s*[-._)]\s*'), '');
    r = r.replaceAll(RegExp(r'\s+'), ' ').trim();
    return r;
  }

  static List<String> titleVariants(String raw) {
    final out = <String>[];
    void add(String s) {
      final c = cleanText(s);
      if (c.isEmpty || c.length > 120) return;
      if (out.any((o) => norm(o) == norm(c))) return;
      out.add(c);
    }

    for (final m in RegExp(r'[『「“"”]([^』」”"“]{1,80})[』」”"“]').allMatches(raw)) {
      add(m.group(1)!);
    }

    final parts = raw.split(
      RegExp(r'\s[-–—/|]\s|／|\s(?:\|\||ll)\s', caseSensitive: false),
    );
    if (parts.length > 1) {
      parts.forEach(add);
    } else {
      add(raw);
    }
    return out.take(5).toList();
  }

  Future<List<dynamic>?> _fetch(Map<String, String> params) async {
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

  Future<List<LyricsCandidate>> search({
    required List<String> titles,
    required List<String> artists,
    String? freeQuery,
    int? durationSec,
    bool earlyStop = false,
  }) async {
    final free = freeQuery?.trim() ?? '';

    final scoringTitles = <String>[];
    void addTitle(String raw) {
      for (final v in titleVariants(raw)) {
        if (!scoringTitles.any((o) => norm(o) == norm(v))) scoringTitles.add(v);
      }
    }

    titles.forEach(addTitle);
    final searchTitles = List<String>.of(scoringTitles);
    if (free.isNotEmpty) addTitle(free);

    final cleanArtists = <String>[];
    for (final a in artists) {
      final c = cleanText(a);
      if (c.isEmpty || _isUnknown(c)) continue;
      if (!cleanArtists.any((o) => norm(o) == norm(c))) cleanArtists.add(c);
    }
    final artistsN = cleanArtists
        .map(norm)
        .where((a) => a.length >= 2)
        .toList();
    final haystack = norm([...titles, ...cleanArtists, free].join(' '));
    final attempts = <Map<String, String>>[];
    final seen = <String>{};
    void addAttempt(Map<String, String> m) {
      if (seen.add(jsonEncode(m))) attempts.add(m);
    }

    if (free.isNotEmpty) {
      addAttempt({'q': free});
      addAttempt({'track_name': free});
    } else {
      final a0 = cleanArtists.isNotEmpty ? cleanArtists.first : '';
      for (final t in searchTitles.take(4)) {
        if (a0.isNotEmpty) addAttempt({'track_name': t, 'artist_name': a0});
        addAttempt({'track_name': t});
      }
      if (a0.isNotEmpty) {
        for (final t in searchTitles.take(2)) {
          addAttempt({'q': '$a0 $t'});
        }
      }
      for (final t in searchTitles.take(2)) {
        addAttempt({'q': t});
      }
      if (a0.isNotEmpty) addAttempt({'q': a0});
    }

    final found = <String, LyricsCandidate>{};
    var okCount = 0;
    var netFails = 0;

    for (var i = 0; i < attempts.length; i += 3) {
      final batch = attempts.skip(i).take(3).toList();
      final results = await Future.wait(batch.map(_fetch));
      for (final res in results) {
        if (res == null) {
          netFails++;
          continue;
        }
        okCount++;
        for (final j in res) {
          final c = _build(j);
          if (c == null) continue;
          c.quality = c.synced.isEmpty
              ? null
              : analyzeLrc(c.synced, durationSec: durationSec);
          if (c.lyrics.isEmpty) continue;
          c.score = _score(
            c,
            titles: scoringTitles,
            artistsN: artistsN,
            haystack: haystack,
            durationSec: durationSec,
          );
          found.putIfAbsent(
            c.id != 0 ? '${c.id}' : '${c.track}|${c.artist}|${c.duration}',
            () => c,
          );
        }
      }
      if (earlyStop &&
          found.values.any(
            (c) =>
                c.score >= _confidentScore &&
                c.hasSynced &&
                (c.quality?.isGood ?? false),
          )) {
        break;
      }
    }

    if (okCount == 0 && netFails > 0) throw LyricsNetworkError();

    final list = found.values.toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    return list.take(20).toList();
  }

  LyricsCandidate? pickConfident(List<LyricsCandidate> list) {
    LyricsCandidate? best;
    for (final c in list) {
      if (best == null || c.score > best.score) best = c;
    }
    return (best != null && best.score >= autoAcceptScore) ? best : null;
  }

  LyricsCandidate? _build(dynamic j) {
    if (j is! Map) return null;
    if (j['instrumental'] == true) return null;
    final synced = (j['syncedLyrics'] ?? '').toString();
    final plain = (j['plainLyrics'] ?? '').toString();
    if (synced.isEmpty && plain.isEmpty) return null;
    return LyricsCandidate(
      id: (j['id'] as num?)?.toInt() ?? 0,
      track: (j['trackName'] ?? j['name'] ?? '').toString(),
      artist: (j['artistName'] ?? '').toString(),
      album: (j['albumName'] ?? '').toString(),
      duration: (j['duration'] as num?)?.toDouble(),
      synced: synced,
      plain: plain,
    );
  }

  int _score(
    LyricsCandidate c, {
    required List<String> titles,
    required List<String> artistsN,
    required String haystack,
    required int? durationSec,
  }) {
    var score = 0;
    final ct = norm(c.track);
    var titleScore = 0;
    for (final t in titles) {
      final n = norm(t);
      if (n.isEmpty || ct.isEmpty) continue;
      if (n == ct) {
        titleScore = math.max(titleScore, 40);
      } else if (math.min(n.length, ct.length) >= 2 &&
          (n.contains(ct) || ct.contains(n))) {
        titleScore = math.max(titleScore, 30);
      }
    }
    score += titleScore;

    var artistMatched = false;
    final ca = norm(c.artist);
    if (artistsN.isNotEmpty && ca.isNotEmpty) {
      final match =
          (ca.length >= 3 && haystack.contains(ca)) ||
          artistsN.any((a) => a.contains(ca) || ca.contains(a));
      artistMatched = match;
      score += match ? 25 : -35;
    }

    // Duración
    if (durationSec != null && c.duration != null) {
      final d = (c.duration! - durationSec).abs();
      score += d <= 2
          ? 25
          : d <= 5
          ? 15
          : d <= 10
          ? 5
          : d <= 20
          ? -10
          : -25;
    }
    if (c.hasSynced) {
      score += 5;
      score += (c.quality?.isGood ?? false) ? 10 : -15;
    }
    if (titleScore == 0) {
      final exact =
          durationSec != null &&
          c.duration != null &&
          (c.duration! - durationSec).abs() <= 2;
      if (!(artistMatched && exact)) score -= 30;
    }
    return score;
  }
}
