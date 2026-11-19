import 'package:mymusicproject/presentation/widgets/player/lyrics_language_detector.dart';
import 'package:mymusicproject/presentation/widgets/player/lyrics_translation_service.dart';

List<String> lineScripts(List<String> lines) {
  final hasKana = RegExp(r'[\u3040-\u30ff]').hasMatch(lines.join(' '));
  return [
    for (final l in lines)
      LyricsTranslationService.scriptOf(l, songHasKana: hasKana),
  ];
}

String scriptSummary(String text) {
  final set = lineScripts(text.split('\n')).where((s) => s != 'auto').toSet();
  if (set.isEmpty) return 'auto';
  return set.length == 1 ? set.first : 'multi';
}

extension SmartTranslation on LyricsTranslationService {
  Future<List<String>> translateSmart(List<String> lines, String to) async {
    final scripts = lineScripts(lines);
    final result = List<String>.filled(lines.length, '');
    final groups = <String, List<int>>{};

    for (var i = 0; i < lines.length; i++) {
      final text = lines[i].trim();
      if (text.isEmpty) continue;
      final lang = scripts[i] != 'auto'
          ? scripts[i]
          : (guessLatinLine(text) ?? 'auto');
      if (lang == to) {
        result[i] = text;
        continue;
      }
      groups.putIfAbsent(lang, () => []).add(i);
    }

    var partial = false;
    Object? firstError;
    for (final e in groups.entries) {
      try {
        final out = await translate(
          [for (final i in e.value) lines[i]],
          to,
          from: e.key,
        );
        if (lastPartial) partial = true;
        for (var k = 0; k < e.value.length; k++) {
          result[e.value[k]] = out[k];
        }
      } catch (err) {
        firstError ??= err;
        partial = true;
      }
    }

    if (firstError != null && !result.any((s) => s.isNotEmpty)) {
      throw firstError;
    }
    lastPartial = partial;
    return result;
  }

  Future<List<String>> romanizeSmart(List<String> lines) async {
    final scripts = lineScripts(lines);
    final result = List<String>.filled(lines.length, '');
    final groups = <String, List<int>>{};

    for (var i = 0; i < lines.length; i++) {
      if (lines[i].trim().isEmpty || scripts[i] == 'auto') continue;
      groups.putIfAbsent(scripts[i], () => []).add(i);
    }

    var partial = false;
    Object? firstError;
    for (final e in groups.entries) {
      try {
        final out = await romanize([
          for (final i in e.value) lines[i],
        ], from: e.key);
        if (lastPartial) partial = true;
        for (var k = 0; k < e.value.length; k++) {
          result[e.value[k]] = out[k];
        }
      } catch (err) {
        firstError ??= err;
        partial = true;
      }
    }

    if (firstError != null && !result.any((s) => s.isNotEmpty)) {
      throw firstError;
    }
    lastPartial = partial;
    return result;
  }
}
