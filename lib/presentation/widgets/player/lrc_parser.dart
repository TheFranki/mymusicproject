class LyricLine {
  final Duration timestamp;
  final String text;

  LyricLine({required this.timestamp, required this.text});
}

List<LyricLine> parseLrc(String lrcContent) {
  final parsed = <LyricLine>[];
  final tagRe = RegExp(r'\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]');
  final lineRe = RegExp(r'^((?:\[\d{1,3}:\d{2}(?:[.:]\d{1,3})?\])+)(.*)$');
  final offsetMatch = RegExp(r'\[offset:\s*([+-]?\d+)\s*\]',
    caseSensitive: false,
  ).firstMatch(lrcContent);
  final fileOffset = int.tryParse(offsetMatch?.group(1) ?? '') ?? 0;

  for (final raw in lrcContent.split('\n')) {
    final m = lineRe.firstMatch(raw.trim());
    if (m == null) continue;
    final text = m.group(2)!.trim();
    for (final t in tagRe.allMatches(m.group(1)!)) {
      final ms = int.parse((t.group(3) ?? '0').padRight(3, '0').substring(0, 3));
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