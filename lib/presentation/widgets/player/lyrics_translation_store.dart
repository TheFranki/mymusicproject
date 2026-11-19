import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class TranslationStore {
  TranslationStore._();
  static final TranslationStore instance = TranslationStore._();

  static const int _maxEntries = 20000;

  final LinkedHashMap<String, String> _map = LinkedHashMap<String, String>();
  Future<void>? _loading;
  bool _dirty = false;

  int get count => _map.length;

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/translations_cache.json');
  }

  Future<void> ensureLoaded() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final f = await _file();
      if (await f.exists()) {
        final data = jsonDecode(await f.readAsString());
        if (data is Map) {
          data.forEach((k, v) {
            if (k is String && v is String) _map[k] = v;
          });
        }
      }
    } catch (e) {
      debugPrint('[TranslationStore] No se pudo leer: $e');
    }
  }

  String? get(String key) {
    final v = _map.remove(key);
    if (v != null) _map[key] = v;
    return v;
  }

  void put(String key, String value) {
    _map.remove(key);
    _map[key] = value;
    while (_map.length > _maxEntries) {
      _map.remove(_map.keys.first);
    }
    _dirty = true;
  }

  Future<void> flush() async {
    if (!_dirty) return;
    _dirty = false;
    try {
      final f = await _file();
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(jsonEncode(_map));
      await tmp.rename(f.path);
    } catch (e) {
      _dirty = true;
      debugPrint('[TranslationStore] No se pudo guardar: $e');
    }
  }

  Future<int> fileSize() async {
    try {
      final f = await _file();
      return await f.exists() ? await f.length() : 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> clear() async {
    _map.clear();
    _dirty = false;
    try {
      final f = await _file();
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}