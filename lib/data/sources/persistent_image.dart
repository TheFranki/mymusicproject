import 'dart:convert';
import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const int _quality = 80;
const int _maxGifBytes = 10 * 1024 * 1024;
const Map<String, int> _maxSideByFolder = {'covers': 600, 'artworks': 800};
const List<String> _folders = ['covers', 'artworks'];
const String _shrinkFlag = 'images_shrunk_v1';

Future<Directory> _dirFor(String folder) async {
  final docs = await getApplicationDocumentsDirectory();
  final dir = Directory('${docs.path}/$folder');
  if (!await dir.exists()) await dir.create(recursive: true);
  return dir;
}

String _ext(String path) {
  final dot = path.lastIndexOf('.');
  final slash = path.lastIndexOf('/');
  return (dot > slash && dot != -1) ? path.substring(dot) : '.jpg';
}

Future<String?> _compress(String src, String target, int side) async {
  try {
    final out = await FlutterImageCompress.compressAndGetFile(
      src,
      target,
      minWidth: side,
      minHeight: side,
      quality: _quality,
      format: CompressFormat.jpeg,
    );
    return out?.path;
  } catch (_) {
    return null;
  }
}

Future<String> persistImage(
  String sourcePath, {
  String folder = 'covers',
}) async {
  if (sourcePath.isEmpty || sourcePath.startsWith('http')) return sourcePath;

  final src = File(sourcePath);
  if (!await src.exists()) return sourcePath;

  final dir = await _dirFor(folder);
  if (src.path.startsWith(dir.path)) return sourcePath;

  final stamp = DateTime.now().microsecondsSinceEpoch;
  final side = _maxSideByFolder[folder] ?? 800;
  final isGif = sourcePath.toLowerCase().endsWith('.gif');
  final keepGif = isGif && await src.length() <= _maxGifBytes;

  String result;
  if (keepGif) {
    result = (await src.copy('${dir.path}/$stamp.gif')).path;
  } else {
    result =
        await _compress(sourcePath, '${dir.path}/$stamp.jpg', side) ??
        (await src.copy('${dir.path}/$stamp${_ext(sourcePath)}')).path;
  }

  await _deleteIfTemp(src);
  return result;
}

Future<void> _deleteIfTemp(File f) async {
  try {
    final tmp = await getTemporaryDirectory();
    if (f.path.startsWith(tmp.path) && await f.exists()) await f.delete();
  } catch (_) {}
}

Future<void> deletePersistedImage(String? path) async {
  if (path == null || path.isEmpty || path.startsWith('http')) return;
  try {
    final docs = await getApplicationDocumentsDirectory();
    if (!path.startsWith(docs.path)) return;
    final f = File(path);
    if (await f.exists()) await f.delete();
  } catch (_) {}
}

Future<void> cleanupOrphanImages() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final used = <String>{};

    void add(String? p) {
      if (p != null && p.isNotEmpty) used.add(p);
    }

    for (final key in const [
      'app_custom_playlists_v1',
      'app_youtube_custom_playlists_v1',
    ]) {
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) continue;
      try {
        for (final p in jsonDecode(raw) as List) {
          add((p as Map)['imagePathOrUrl']?.toString());
        }
      } catch (_) {
        return;
      }
    }

    for (final key in prefs.getKeys()) {
      try {
        if (key.startsWith('art_')) {
          add(prefs.getString(key));
        } else if (key.startsWith('meta_')) {
          final raw = prefs.getString(key);
          if (raw == null || raw.isEmpty) continue;
          add((jsonDecode(raw) as Map)['artworkPathOrUrl']?.toString());
        }
      } catch (_) {
        return;
      }
    }

    final limit = DateTime.now().subtract(const Duration(hours: 1));
    for (final folder in _folders) {
      final dir = await _dirFor(folder);
      await for (final entity in dir.list()) {
        if (entity is! File || used.contains(entity.path)) continue;
        if ((await entity.lastModified()).isBefore(limit)) {
          await entity.delete();
        }
      }
    }
  } catch (_) {}
}

Future<void> shrinkExistingImages() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_shrinkFlag) == true) return;

    final tmp = await getTemporaryDirectory();
    for (final folder in _folders) {
      final dir = await _dirFor(folder);
      final side = _maxSideByFolder[folder] ?? 800;
      final files = await dir.list().where((e) => e is File).toList();

      for (final e in files) {
        final file = e as File;
        final isGif = file.path.toLowerCase().endsWith('.gif');
        if (isGif && await file.length() <= _maxGifBytes) continue;
        final before = await file.length();
        if (before < 150 * 1024) continue;

        final target =
            '${tmp.path}/shrink_${DateTime.now().microsecondsSinceEpoch}.jpg';
        final out = await _compress(file.path, target, side);
        if (out == null) continue;

        final outFile = File(out);
        if (await outFile.length() < before) await outFile.copy(file.path);
        await outFile.delete();
      }
    }
    await prefs.setBool(_shrinkFlag, true);
  } catch (_) {}
}

Future<void> cleanupTempCache() async {
  try {
    final tmp = await getTemporaryDirectory();
    final limit = DateTime.now().subtract(const Duration(hours: 1));
    final files = await tmp
        .list(recursive: true, followLinks: false)
        .where((e) => e is File)
        .toList();
    for (final e in files) {
      try {
        if ((await (e as File).lastModified()).isBefore(limit))
          await e.delete();
      } catch (_) {}
    }
  } catch (_) {}
}

Future<void> runStorageMaintenance() async {
  await cleanupOrphanImages();
  await shrinkExistingImages();
  await cleanupTempCache();
}
