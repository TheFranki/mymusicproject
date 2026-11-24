import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import 'audio_handler.dart';

import 'package:mymusicproject/presentation/artwork_baker.dart';
import 'package:mymusicproject/presentation/providers/artwork_fit_provider.dart';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

class PlayerService {
  PlayerService(this.handler, {this.fitFor});

  final AppAudioHandler handler;
  final ArtworkFit? Function(String path)? fitFor;

  AudioPlayer get player => handler.player;

  Stream<bool> get playingStream => player.playingStream;
  Stream<PlayerState> get playerStateStream => player.playerStateStream;

  ConcatenatingAudioSource? _concat;
  Future<void> _preloadChain = Future.value();

  int _publishSeq = 0;

  Future<void> publishMediaItem({
    required String id,
    required String title,
    String? author,
    String? thumbnailUrl,
    Duration? duration,
  }) async {
    final seq = ++_publishSeq;
    final art = await resolveNotificationArt(thumbnailUrl);
    if (seq != _publishSeq) return;
    handler.mediaItem.add(
      MediaItem(
        id: id,
        title: title,
        artist: author,
        duration: duration,
        artUri: art,
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

  Future<void> setPreload(String? id, String? path) {
    final run = _preloadChain.then((_) => _applyPreload(id, path));
    _preloadChain = run.catchError((_) {});
    return run;
  }

  Future<void> _applyPreload(String? id, String? path) async {
    final c = _concat;
    if (c == null) return;
    final idx = player.currentIndex ?? 0;
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

  Future<void> updateNowPlaying({
    required String id,
    required String title,
    String? author,
    String? thumbnailUrl,
    bool Function()? isStale,
  }) async {
    final seq = ++_publishSeq;
    final art = await resolveNotificationArt(thumbnailUrl);
    if (seq != _publishSeq || (isStale?.call() ?? false)) return;
    final current = handler.mediaItem.value;
    handler.mediaItem.add(
      MediaItem(
        id: id,
        title: title,
        artist: author,
        artUri: art,
        duration: current?.id == id ? current?.duration : player.duration,
      ),
    );
  }

  Future<void> pause() async => player.pause();
  Future<void> resume() async => player.play();
  Future<void> stop() async => player.stop();
  void dispose() => player.dispose();

    Future<Uri?> resolveNotificationArt(String? source) async {
    try {
      if (source != null && source.isNotEmpty) {
        File? file;
        if (source.startsWith('http://') || source.startsWith('https://')) {
          file = await _cachedRemote(source);
        } else {
          final f = File(source);
          if (await f.exists()) file = f;
        }

        if (file != null) {
          final fit = fitFor?.call(source);
          debugPrint('[Art] $source -> ajuste: ${fit?.toJson()}');
          if (fit != null && !fit.isIdentity) {
            final baked = await bakeArtwork(file.path, fit);
            debugPrint('[Art] recorte: ${baked?.path}');
            if (baked != null) return baked.uri;
          }
          if (file.path.toLowerCase().endsWith('.gif')) {
            return await _gifFirstFrame(file) ?? Uri.file(file.path);
          }
          return Uri.file(file.path);
        }
      }
      return await _defaultArt();
    } catch (_) {
      return null;
    }
  }

  Future<File?> _cachedRemote(String url) async {
    try {
      final cache = await getApplicationCacheDirectory();
      final dir = Directory('${cache.path}/notif_remote');
      if (!await dir.exists()) await dir.create(recursive: true);
      final file = File('${dir.path}/${url.hashCode.abs()}');
      if (await file.exists() && await file.length() > 0) return file;

      final res =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200 || res.bodyBytes.isEmpty) return null;
      await file.writeAsBytes(res.bodyBytes);
      return file;
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
