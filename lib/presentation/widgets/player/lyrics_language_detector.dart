import 'package:mymusicproject/presentation/widgets/player/lyrics_translation_service.dart';
const Map<String, Set<String>> _stopWords = {
  'es': {
    'el', 'los', 'las', 'una', 'pero', 'cuando', 'como', 'está', 'soy', 'eres',
    'yo', 'mi', 'tu', 'te', 'quiero', 'contigo', 'porque', 'nada', 'todo',
    'muy', 'sin', 'del', 'al', 'qué', 'más', 'que', 'por', 'con', 'para',
    'amor', 'corazón', 'vida',
  },
  'en': {
    'the', 'and', 'you', 'i', 'to', 'of', 'in', 'is', 'it', 'that', 'my',
    'me', 'your', 'we', 'be', 'are', 'was', "don't", "can't", 'with', 'for',
    'on', 'all', 'just', 'love', 'know', 'like', 'but', 'now', 'baby', 'got',
    "i'm", "it's", 'oh',
  },
  'pt': {
    'não', 'você', 'uma', 'meu', 'minha', 'mais', 'mas', 'também', 'então',
    'muito', 'estou', 'são', 'nós', 'coração', 'os', 'um', 'eu', 'que', 'com',
    'para', 'por', 'amor', 'vida', 'quando',
  },
  'fr': {
    'le', 'les', 'une', 'des', 'est', 'je', 'il', 'nous', 'vous', 'pas',
    'dans', 'avec', 'mon', 'mes', 'suis', 'ça', 'très', 'pour', 'qui', 'et',
    'tu', 'elle', "c'est", 'mais', 'tout',
  },
  'de': {
    'der', 'die', 'das', 'und', 'ich', 'du', 'nicht', 'ist', 'ein', 'eine',
    'zu', 'mit', 'den', 'dem', 'sie', 'wir', 'auf', 'für', 'mein', 'dich',
    'mich', 'wie', 'was', 'aber', 'noch', 'nur', 'wenn', 'bin',
  },
  'it': {
    'il', 'gli', 'uno', 'una', 'che', 'non', 'per', 'con', 'mi', 'ti', 'io',
    'sei', 'sono', 'ma', 'come', 'più', 'tutto', 'amore', 'cuore', 'questo',
    'quando', 'anche', 'della', 'nel', 'è', 'di',
  },
};

String? detectLyricsLanguage(String text) {
  final script = LyricsTranslationService.detectScript(text);
  if (script != 'auto') return script;

  final lower = text.toLowerCase();
  final words = RegExp(r"[a-záéíóúüñçãõâêôàèìòùäöß']+")
      .allMatches(lower)
      .map((m) => m.group(0)!)
      .toList();
  if (words.length < 12) return null;

  final scores = <String, int>{for (final k in _stopWords.keys) k: 0};
  for (final w in words) {
    for (final e in _stopWords.entries) {
      if (e.value.contains(w)) scores[e.key] = scores[e.key]! + 1;
    }
  }

  if (lower.contains('ñ') || lower.contains('¿') || lower.contains('¡')) {
    scores['es'] = scores['es']! + 3;
  }
  if (RegExp('[ãõ]').hasMatch(lower)) scores['pt'] = scores['pt']! + 3;
  if (RegExp('[ßäöü]').hasMatch(lower)) scores['de'] = scores['de']! + 3;

  final sorted = scores.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final top = sorted[0], second = sorted[1];
  if (top.value < 4) return null;
  if (top.value < second.value * 1.3) return null;
  return top.key;
}

String? guessLatinLine(String line) {
  final lower = line.toLowerCase();
  final words = RegExp(r"[a-záéíóúüñçãõâêôàèìòùäöß']+")
      .allMatches(lower)
      .map((m) => m.group(0)!)
      .toList();
  if (words.length < 2) return null;

  final scores = <String, int>{for (final k in _stopWords.keys) k: 0};
  for (final w in words) {
    for (final e in _stopWords.entries) {
      if (e.value.contains(w)) scores[e.key] = scores[e.key]! + 1;
    }
  }
  if (lower.contains('ñ') || lower.contains('¿') || lower.contains('¡')) {
    scores['es'] = scores['es']! + 2;
  }
  if (RegExp('[ãõ]').hasMatch(lower)) scores['pt'] = scores['pt']! + 2;
  if (RegExp('[ßäöü]').hasMatch(lower)) scores['de'] = scores['de']! + 2;

  final sorted = scores.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final top = sorted[0], second = sorted[1];
  if (top.value >= 2 && top.value >= second.value + 1) return top.key;
  return null;
}