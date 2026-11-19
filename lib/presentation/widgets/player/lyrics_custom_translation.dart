bool isLyricTextLine(String s) => s.replaceAll('♪', '').trim().isNotEmpty;

List<String> customTranslationLines(String raw) => [
      for (final l in raw.split('\n'))
        if (isLyricTextLine(l)) l.trim(),
    ];

int lyricTextLineCount(List<String> source) =>
    source.where(isLyricTextLine).length;

List<String> alignCustomTranslation(List<String> source, String custom) {
  final tr = customTranslationLines(custom);
  final out = List<String>.filled(source.length, '');
  var k = 0;
  for (var i = 0; i < source.length; i++) {
    if (!isLyricTextLine(source[i])) continue;
    if (k < tr.length) out[i] = tr[k];
    k++;
  }
  return out;
}