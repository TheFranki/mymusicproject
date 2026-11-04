import 'dart:convert';
import 'package:http/http.dart' as http;

class LyricLine {
  final Duration time;
  final String text;
  LyricLine({required this.time, required this.text});
}

class LyricsService {
  static Future<List<LyricLine>> fetchLyrics({
    required String title,
    required String artist,
  }) async {
    try {
      final cleanTitle = Uri.encodeComponent(title);
      final cleanArtist = Uri.encodeComponent(artist);
      final url = Uri.parse(
        'https://lrclib.net/api/get?track_name=$cleanTitle&artist_name=$cleanArtist',
      );

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final syncedLyrics = data['syncedLyrics'] as String?;
        final plainLyrics = data['plainLyrics'] as String?;

        if (syncedLyrics != null && syncedLyrics.isNotEmpty) {
          return parseLrc(syncedLyrics);
        } else if (plainLyrics != null && plainLyrics.isNotEmpty) {
          return plainLyrics
              .split('\n')
              .map((line) => LyricLine(time: Duration.zero, text: line))
              .toList();
        }
      }
    } catch (_) {
    }
    return [];
  }

  static List<LyricLine> parseLrc(String lrcContent) {
    final List<LyricLine> lines = [];
    final RegExp regExp = RegExp(r'\[(\d+):(\d+\.\d+)\](.*)');
    for (var line in lrcContent.split('\n')) {
      final match = regExp.firstMatch(line.trim());
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        final seconds = double.parse(match.group(2)!);
        final text = match.group(3)!.trim();
        final duration = Duration(
          minutes: minutes,
          seconds: seconds.truncate(),
          milliseconds: ((seconds - seconds.truncate()) * 1000).round(),
        );
        lines.add(LyricLine(time: duration, text: text));
      }
    }
    return lines;
  }
}