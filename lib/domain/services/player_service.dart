import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import 'audio_handler.dart';

class PlayerService {
  PlayerService(this.handler);

  final AppAudioHandler handler;
  AudioPlayer get player => handler.player;

  Stream<bool> get playingStream => player.playingStream;
  Stream<PlayerState> get playerStateStream => player.playerStateStream;

  // Canción local actual + la siguiente precargada (reproducción sin pausa).
  ConcatenatingAudioSource? _concat;
  Future<void> _preloadChain = Future.value();

  Future<void> publishMediaItem({
    required String id,
    required String title,
    String? author,
    String? thumbnailUrl,
    Duration? duration,
  }) async {
    handler.mediaItem.add(
      MediaItem(
        id: id,
        title: title,
        artist: author,
        duration: duration,
        artUri: await resolveNotificationArt(thumbnailUrl),
      ),
    );
  }

  Future<void> playFromUrl(
    String url, {
    required String id,
    required String title,
    String? author,
    String? thumbnailUrl,
    Duration? initialPosition,
    bool autoPlay = true,
  }) async {
    _concat = null;
    await player.stop();
    await publishMediaItem(
      id: id,
      title: title,
      author: author,
      thumbnailUrl: thumbnailUrl,
    );
    await player.setAudioSource(
      AudioSource.uri(Uri.parse(url)),
      initialPosition: initialPosition,
    );
    if (autoPlay) unawaited(player.play());
  }

  Future<void> playLocalFile(
    String filePath, {
    required String id,
    required String title,
    String? author,
    String? thumbnailUrl,
    Duration? initialPosition,
    bool autoPlay = true,
  }) async {
    await publishMediaItem(
      id: id,
      title: title,
      author: author ?? 'Desconocido',
      thumbnailUrl: thumbnailUrl,
    );

    // El tag (id) permite saber cuál canción está sonando en la lista.
    final concat = ConcatenatingAudioSource(
      useLazyPreparation: false,
      children: [AudioSource.uri(Uri.file(filePath), tag: id)],
    );
    _concat = concat;

    await player
        .setAudioSource(concat, initialPosition: initialPosition)
        .timeout(const Duration(seconds: 20));

    if (autoPlay) {
      unawaited(player.play().catchError((Object e, StackTrace s) {}));
    }
  }

  /// Deja exactamente UNA canción después de la actual (o ninguna si
  /// [id]/[path] son null). Las llamadas se hacen una tras otra.
  Future<void> setPreload(String? id, String? path) {
    final run = _preloadChain.then((_) => _applyPreload(id, path));
    _preloadChain = run.catchError((_) {});
    return run;
  }

  Future<void> _applyPreload(String? id, String? path) async {
    final c = _concat;
    if (c == null) return;
    final idx = player.currentIndex ?? 0;

    // Si ya está precargada la misma canción, no tocamos nada.
    if (c.length == idx + 2) {
      final existing = c.children[idx + 1];
      if (existing is IndexedAudioSource && existing.tag == id) return;
    }

    if (c.length > idx + 1) {
      await c.removeRange(idx + 1, c.length);
    }
    if (id != null && path != null && File(path).existsSync()) {
      await c.add(AudioSource.uri(Uri.file(path), tag: id));
    }
  }

  /// Actualiza título, artista e imagen de la notificación sin recargar audio.
  Future<void> updateNowPlaying({
    required String id,
    required String title,
    String? author,
    String? thumbnailUrl,
  }) async {
    final current = handler.mediaItem.value;
    if (current == null || current.id != id) return;
    handler.mediaItem.add(
      current.copyWith(
        title: title,
        artist: author,
        artUri: await resolveNotificationArt(thumbnailUrl),
      ),
    );
  }

  Future<void> pause() async => player.pause();
  Future<void> resume() async => player.play();
  Future<void> stop() async => player.stop();
  void dispose() => player.dispose();

  // ---- Imagen de la notificación (Paso 1) ----

  Future<Uri?> resolveNotificationArt(String? source) async {
    try {
      if (source != null && source.isNotEmpty) {
        if (source.startsWith('http://') || source.startsWith('https://')) {
          return Uri.parse(source);
        }
        final file = File(source);
        if (await file.exists()) {
          if (source.toLowerCase().endsWith('.gif')) {
            return await _gifFirstFrame(file) ?? Uri.file(source);
          }
          return Uri.file(source);
        }
      }
      return await _defaultArt();
    } catch (_) {
      return null;
    }
  }

  Future<Uri?> _gifFirstFrame(File gif) async {
    final cache = await getApplicationCacheDirectory();
    final dir = Directory('${cache.path}/notif_art');
    if (!await dir.exists()) await dir.create(recursive: true);
    final name = gif.uri.pathSegments.last.replaceAll('.gif', '.jpg');
    final target = File('${dir.path}/$name');
    if (await target.exists()) return target.uri;
    final out = await FlutterImageCompress.compressAndGetFile(
      gif.path,
      target.path,
      minWidth: 600,
      minHeight: 600,
      quality: 85,
      format: CompressFormat.jpeg,
    );
    return out == null ? null : Uri.file(out.path);
  }

  Future<Uri?> _defaultArt() async {
    final docs = await getApplicationDocumentsDirectory();
    final file = File('${docs.path}/default_cover.png');
    if (!await file.exists()) {
      final bytes = await rootBundle.load('assets/default_cover.png');
      await file.writeAsBytes(bytes.buffer.asUint8List());
    }
    return Uri.file(file.path);
  }
}