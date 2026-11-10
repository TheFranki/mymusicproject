class LyricLine {
  final Duration timestamp;
  final String text;

  LyricLine({required this.timestamp, required this.text});
}

List<LyricLine> parseLrc(String lrcContent) {
  final parsed = <LyricLine>[];
  final tagRe = RegExp(r'\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]');
  final lineRe = RegExp(r'^((?:\[\d{1,3}:\d{2}(?:[.:]\d{1,3})?\])+)(.*)$');
  final offsetMatch = RegExp(
    r'\[offset:\s*([+-]?\d+)\s*\]',
    caseSensitive: false,
  ).firstMatch(lrcContent);
  final fileOffset = int.tryParse(offsetMatch?.group(1) ?? '') ?? 0;

  for (final raw in lrcContent.split('\n')) {
    final m = lineRe.firstMatch(raw.trim());
    if (m == null) continue;
    final text = m
        .group(2)!
        .replaceAll(RegExp(r'<\d{1,3}:\d{2}(?:[.:]\d{1,3})?>'), '')
        .trim();
    for (final t in tagRe.allMatches(m.group(1)!)) {
      final ms = int.parse(
        (t.group(3) ?? '0').padRight(3, '0').substring(0, 3),
      );
      var time = Duration(
        minutes: int.parse(t.group(1)!),
        seconds: int.parse(t.group(2)!),
        milliseconds: ms,
      );
      time -= Duration(milliseconds: fileOffset);
      if (time.isNegative) time = Duration.zero;
      parsed.add(LyricLine(timestamp: time, text: text));
    }
  }
  parsed.sort((a, b) => a.timestamp.compareTo(b.timestamp));
  return parsed;
}

bool hasLrcTimestamps(String s) => RegExp(r'\[\d{1,3}:\d{2}').hasMatch(s);

class LrcQuality {
  const LrcQuality({required this.lines, required this.problems});
  final int lines;
  final List<String> problems;

  bool get isSynced => lines > 0;
  bool get isGood => isSynced && problems.isEmpty;
  String get summary => problems.join(', ');
}

LrcQuality analyzeLrc(String raw, {int? durationSec}) {
  final parsed = parseLrc(raw);
  if (parsed.isEmpty) {
    return const LrcQuality(lines: 0, problems: ['sin tiempos']);
  }
  final problems = <String>[];
  final spoken = parsed.where((l) => l.text.trim().isNotEmpty).toList();

  if (spoken.length < 4) problems.add('muy pocas líneas');
  if (1 - spoken.length / parsed.length > 0.4) {
    problems.add('muchas líneas vacías');
  }
  final distinct = spoken.map((l) => l.timestamp.inMilliseconds).toSet().length;
  if (spoken.isNotEmpty && distinct < spoken.length * 0.8) {
    problems.add('tiempos repetidos');
  }
  if (durationSec != null && durationSec > 0 && spoken.isNotEmpty) {
    final last = spoken.last.timestamp.inSeconds;
    if (last > durationSec + 8) {
      problems.add('dura más que la canción');
    } else if (last < durationSec * 0.5) {
      problems.add('termina muy pronto');
    }
  }
  return LrcQuality(lines: parsed.length, problems: problems);
}

class PastedLyrics {
  const PastedLyrics({
    required this.text,
    required this.timed,
    required this.approximate,
  });
  final String text;
  final bool timed;
  final bool approximate;
}

String _lrcTag(double seconds) {
  final cs = (seconds * 100).round();
  final m = cs ~/ 6000;
  final s = (cs % 6000) ~/ 100;
  final c = cs % 100;
  String two(int n) => n.toString().padLeft(2, '0');
  return '[${two(m)}:${two(s)}.${two(c)}]';
}

PastedLyrics? lyricsFromPastedText(String input, {int? durationSec}) {
  final normalized =
      input.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
  if (normalized.isEmpty) return null;

  if (hasLrcTimestamps(normalized)) {
    return PastedLyrics(text: normalized, timed: true, approximate: false);
  }

  final section = RegExp(
    r'^[\[\(](verse|chorus|intro|outro|bridge|pre-?chorus|hook|refrain|interlude|instrumental|estribillo|coro|verso|puente)[^\]\)]*[\]\)]$',
    caseSensitive: false,
  );
  final lines = <String>[];
  for (final raw in normalized.split('\n')) {
    final t = raw.trim();
    if (section.hasMatch(t)) continue;
    if (t.isEmpty && (lines.isEmpty || lines.last.isEmpty)) continue;
    lines.add(t);
  }
  while (lines.isNotEmpty && lines.last.isEmpty) {
    lines.removeLast();
  }
  if (lines.isEmpty) return null;

  if (durationSec == null || durationSec <= 0) {
    return PastedLyrics(
      text: lines.join('\n'),
      timed: false,
      approximate: false,
    );
  }

  double weight(String l) =>
      l.isEmpty ? 10.0 : l.length.clamp(6, 60).toDouble();
  final total = lines.fold<double>(0, (a, l) => a + weight(l));
  final start = (durationSec * 0.07).clamp(5.0, 20.0).toDouble();
  final end = durationSec * 0.94;
  final span = (end - start) < 10.0 ? 10.0 : (end - start);

  final buf = StringBuffer();
  var acc = 0.0;
  for (final l in lines) {
    if (l.isNotEmpty) {
      buf.writeln('${_lrcTag(start + acc / total * span)}$l');
    }
    acc += weight(l);
  }
  return PastedLyrics(
    text: buf.toString().trim(),
    timed: true,
    approximate: true,
  );
}