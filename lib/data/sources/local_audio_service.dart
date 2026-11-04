import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class LocalAudioService {
  static const platform = MethodChannel('com.mymusicproject/mediastore');

  Future<bool> _requestPermission() async {
    PermissionStatus status = await Permission.audio.request();
    if (!status.isGranted) {
      status = await Permission.storage.request();
    }
    return status.isGranted;
  }
  Future<List<Map<String, dynamic>>> getLocalSongs() async {
    final hasPermission = await _requestPermission();
    if (!hasPermission) return [];
    try {
      final List<dynamic> result =
          await platform.invokeMethod('getLocalSongs');
      return result
          .map((song) => Map<String, dynamic>.from(song))
          .toList();
    } catch (e, stack) {
      debugPrint('Error al obtener canciones locales: $e');
      debugPrintStack(stackTrace: stack);
      return [];
    }
  }
  Future<bool> deleteSongFile(String songId) async {
    try {
      final bool result = await platform.invokeMethod(
        'deleteSong',
        {'id': songId},
      );
      return result;
    } catch (e, stack) {
      debugPrint('Error al eliminar canción en nativo: $e');
      debugPrintStack(stackTrace: stack);
      return false;
    }
  }
}