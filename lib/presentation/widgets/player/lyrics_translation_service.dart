import 'dart:convert';
import 'package:http/http.dart' as http;
import 'lyrics_translation_store.dart';

class LyricsTranslationService {
  static const Map<String, String> languages = {
    'es': 'Español',
    'en': 'Inglés',
    'ko': 'Coreano',
  };
  final TranslationStore _store = TranslationStore.instance;
  bool lastPartial = false;

  static String _clean(String s) => s.replaceAll('\n', ' ').trim();

  static String _key(String kind, String to, String from, String text) =>
      '$kind|$to|$from|$text';

  static String scriptOf(String t, {bool songHasKana = false}) {
    if (RegExp(r'[\u3040-\u30ff]').hasMatch(t)) return 'ja';
    if (RegExp(r'[\uac00-\ud7af]').hasMatch(t)) return 'ko';
    if (RegExp(r'[\u0e00-\u0e7f]').hasMatch(t)) return 'th';
    if (RegExp(r'[\u0600-\u06ff\u0750-\u077f]').hasMatch(t)) return 'ar';
    if (RegExp(r'[\u0590-\u05ff]').hasMatch(t)) return 'he';
    if (RegExp(r'[\u0900-\u097f]').hasMatch(t)) return 'hi';
    if (RegExp(r'[\u0370-\u03ff]').hasMatch(t)) return 'el';
    if (RegExp(r'[\u0400-\u04ff]').hasMatch(t)) return 'ru';
    if (RegExp(r'[\u4e00-\u9fff]').hasMatch(t)) {
      return songHasKana ? 'ja' : 'zh-CN';
    }
    return 'auto';
  }

  static String detectScript(String text) => scriptOf(
        text,
        songHasKana: RegExp(r'[\u3040-\u30ff]').hasMatch(text),
      );

  static String romanizationLabel(String from) {
    switch (from) {
      case 'ja':
        return 'Romaji';
      case 'ko':
        return 'Romanización (coreano)';
      case 'zh-CN':
        return 'Pinyin';
      case 'ru':
        return 'Transliteración';
      case 'th':
        return 'Romanización (tailandés)';
      case 'ar':
        return 'Romanización (árabe)';
      case 'he':
        return 'Romanización (hebreo)';
      case 'hi':
        return 'Romanización (hindi)';
      case 'el':
        return 'Transliteración (griego)';
      default:
        return 'Romanización';
    }
  }

  Future<List<String>> translate(
    List<String> lines,
    String to, {
    String from = 'auto',
  }) async {
    lastPartial = false;
    await _store.ensureLoaded();

    final result = List<String>.filled(lines.length, '');
    final missing = <int>[];
    for (var i = 0; i < lines.length; i++) {
      final text = _clean(lines[i]);
      if (text.isEmpty) continue;
      final hit = _store.get(_key('tr', to, from, text));
      if (hit != null) {
        result[i] = hit;
      } else {
        missing.add(i);
      }
    }
    if (missing.isEmpty) return result;

    try {
      var start = 0;
      while (start < missing.length) {
        var end = start;
        var len = 0;
        while (end < missing.length &&
            len + _clean(lines[missing[end]]).length + 1 <= 1500) {
          len += _clean(lines[missing[end]]).length + 1;
          end++;
        }
        if (end == start) end = start + 1;

        final chunk = missing.sublist(start, end);
        final texts = [for (final i in chunk) _clean(lines[i])];
        final out = await _translateChunk(texts, to, from);
        for (var k = 0; k < chunk.length; k++) {
          result[chunk[k]] = out[k];
          if (out[k].isNotEmpty) {
            _store.put(_key('tr', to, from, texts[k]), out[k]);
          }
        }
        start = end;
      }
    } catch (e) {
      await _store.flush();
      if (!result.any((s) => s.isNotEmpty)) rethrow;
      lastPartial = true;
      return result;
    }

    await _store.flush();
    return result;
  }

  Future<List<String>> romanize(
    List<String> lines, {
    required String from,
  }) async {
    lastPartial = false;
    await _store.ensureLoaded();

    final result = List<String>.filled(lines.length, '');
    final missing = <int>[];
    for (var i = 0; i < lines.length; i++) {
      final text = _clean(lines[i]);
      if (text.isEmpty) continue;
      final hit = _store.get(_key('rom', '', from, text));
      if (hit != null) {
        result[i] = hit;
      } else {
        missing.add(i);
      }
    }
    if (missing.isEmpty) return result;

    try {
      const parallel = 6;
      for (var s = 0; s < missing.length; s += parallel) {
        final batch = missing.skip(s).take(parallel).toList();
        final out = await Future.wait(
          batch.map((i) => _romanizeLine(lines[i], from)),
        );
        for (var k = 0; k < batch.length; k++) {
          result[batch[k]] = out[k];
          if (out[k].isNotEmpty) {
            _store.put(
              _key('rom', '', from, _clean(lines[batch[k]])),
              out[k],
            );
          }
        }
      }
    } catch (e) {
      await _store.flush();
      if (!result.any((s) => s.isNotEmpty)) rethrow;
      lastPartial = true;
      return result;
    }

    await _store.flush();
    return result;
  }

  Future<List<String>> _translateChunk(
    List<String> texts,
    String to,
    String from,
  ) async {
    final data = await _gtx(texts.join('\n'), to: to, from: from);
    final joined = _joinSegments(data);
    final parts = joined.split('\n').map((s) => s.trim()).toList();
    if (parts.length == texts.length) return parts;

    final out = <String>[];
    for (final t in texts) {
      final d = await _gtx(t, to: to, from: from);
      out.add(_joinSegments(d).replaceAll('\n', ' ').trim());
    }
    return out;
  }

  String _joinSegments(dynamic data) {
    final segs = data[0] as List;
    final buf = StringBuffer();
    for (final s in segs) {
      if (s is List && s.isNotEmpty && s[0] is String) buf.write(s[0]);
    }
    return buf.toString();
  }

  Future<String> _romanizeLine(String text, String from) async {
    final data = await _gtx(
      text.replaceAll('\n', ' ').trim(),
      to: 'en',
      from: from,
      extraDt: const ['rm'],
    );
    final buf = StringBuffer();
    for (final s in (data[0] as List)) {
      if (s is List && s.length > 3 && s[3] is String) buf.write(s[3]);
    }
    return buf.toString().trim();
  }

  Future<dynamic> _gtx(
    String text, {
    required String to,
    String from = 'auto',
    List<String> extraDt = const [],
  }) async {
    final uri = Uri.https('translate.googleapis.com', '/translate_a/single', {
      'client': 'gtx',
      'sl': from,
      'tl': to,
      'dt': ['t', ...extraDt],
      'q': text,
    });
    final res = await http.get(uri).timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) {
      throw Exception('Traductor respondió ${res.statusCode}');
    }
    return jsonDecode(res.body);
  }
}