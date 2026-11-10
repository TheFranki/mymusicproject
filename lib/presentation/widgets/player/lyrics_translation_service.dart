import 'dart:convert';
import 'package:http/http.dart' as http;

class LyricsTranslationService {
  static const Map<String, String> languages = {
    'es': 'Español',
    'en': 'Inglés',
    //'pt': 'Portugués',
    //'fr': 'Francés',
    //'de': 'Alemán',
    //'it': 'Italiano',
    //'ja': 'Japonés',
    //'ko': 'Coreano',
    //'zh-CN': 'Chino',
  };

  static final Map<String, List<String>> _cache = {};

  static String detectScript(String text) {
    if (RegExp(r'[\u3040-\u30ff]').hasMatch(text)) return 'ja';
    if (RegExp(r'[\uac00-\ud7af]').hasMatch(text)) return 'ko';
    if (RegExp(r'[\u0400-\u04ff]').hasMatch(text)) return 'ru';
    if (RegExp(r'[\u4e00-\u9fff]').hasMatch(text)) return 'zh-CN';
    return 'auto';
  }

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
      default:
        return 'Romanización';
    }
  }

  Future<List<String>> translate(
    List<String> lines,
    String to, {
    String from = 'auto',
  }) async {
    final key = '${lines.join('\n').hashCode}|tr|$to';
    final cached = _cache[key];
    if (cached != null) return cached;

    final result = List<String>.filled(lines.length, '');
    final idx = [
      for (var i = 0; i < lines.length; i++)
        if (lines[i].trim().isNotEmpty) i,
    ];

    var start = 0;
    while (start < idx.length) {
      var end = start;
      var len = 0;
      while (end < idx.length && len + lines[idx[end]].length + 1 <= 1500) {
        len += lines[idx[end]].length + 1;
        end++;
      }
      if (end == start) end = start + 1;

      final chunk = idx.sublist(start, end);
      final out = await _translateChunk(
        chunk.map((i) => lines[i].replaceAll('\n', ' ').trim()).toList(),
        to,
        from,
      );
      for (var k = 0; k < chunk.length; k++) {
        result[chunk[k]] = out[k];
      }
      start = end;
    }

    _cache[key] = result;
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

  Future<List<String>> romanize(
    List<String> lines, {
    required String from,
  }) async {
    final key = '${lines.join('\n').hashCode}|rom|$from';
    final cached = _cache[key];
    if (cached != null) return cached;

    final result = List<String>.filled(lines.length, '');
    final idx = [
      for (var i = 0; i < lines.length; i++)
        if (lines[i].trim().isNotEmpty) i,
    ];

    const parallel = 6;
    for (var s = 0; s < idx.length; s += parallel) {
      final batch = idx.skip(s).take(parallel).toList();
      final out = await Future.wait(
        batch.map((i) => _romanizeLine(lines[i], from)),
      );
      for (var k = 0; k < batch.length; k++) {
        result[batch[k]] = out[k];
      }
    }

    _cache[key] = result;
    return result;
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