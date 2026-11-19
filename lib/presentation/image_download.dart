import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:mymusicproject/data/sources/persistent_image.dart';
import 'package:mymusicproject/presentation/error_messages.dart';
import 'package:path_provider/path_provider.dart';

Future<String?> downloadImageToLocal(String url) async {
  try {
    final res =
        await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200 || res.bodyBytes.isEmpty) return null;

    final dir = await getTemporaryDirectory();
    final segments = Uri.parse(url).pathSegments;
    final last = segments.isEmpty ? '' : segments.last.toLowerCase();
    final ext = ['jpg', 'jpeg', 'png', 'webp', 'gif']
        .firstWhere((e) => last.endsWith('.$e'), orElse: () => 'jpg');

    final tmp = File(
      '${dir.path}/dl_${DateTime.now().microsecondsSinceEpoch}.$ext',
    );
    await tmp.writeAsBytes(res.bodyBytes);
    final saved = await persistImage(tmp.path, folder: 'artworks');
    if (saved != tmp.path) {
      try {
        await tmp.delete();
      } catch (_) {}
    }
    return saved;
  } catch (e, st) {
    logError('Descarga de imagen', e, st);
    return null;
  }
}