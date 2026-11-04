import 'dart:async';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

class PlayerService {
  final AudioPlayer player = AudioPlayer();
  Stream<bool> get playingStream => player.playingStream;
  Stream<PlayerState> get playerStateStream => player.playerStateStream;

  Future<void> playFromUrl(
    String url, {
    required String id,
    required String title,
    String? author,
    String? thumbnailUrl,
    Duration? initialPosition,
    bool autoPlay = true,
  }) async {
    try {
      await player.stop();
      final audioSource = AudioSource.uri(
        Uri.parse(url),
        tag: MediaItem(
          id: id,
          title: title,
          artist: author,
          artUri: thumbnailUrl != null && thumbnailUrl.isNotEmpty
              ? Uri.parse(thumbnailUrl)
              : null,
        ),
      );

      await player.setAudioSource(
        audioSource,
        initialPosition: initialPosition,
      );
      if (autoPlay) unawaited(player.play());
    } catch (e) {
      rethrow;
    }
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
    try {
      final uri = Uri.file(filePath);
      Uri? artUri;
      if (thumbnailUrl != null &&
          (thumbnailUrl.startsWith('http://') ||
              thumbnailUrl.startsWith('https://'))) {
        artUri = Uri.parse(thumbnailUrl);
      }

      final audioSource = AudioSource.uri(
        uri,
        tag: MediaItem(
          id: id,
          title: title,
          artist: author ?? 'Desconocido',
          artUri: artUri,
        ),
      );

      await player
          .setAudioSource(audioSource, initialPosition: initialPosition)
          .timeout(const Duration(seconds: 20));

      if (autoPlay) {
        unawaited(
          player.play().catchError((Object error, StackTrace stack) {}),
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> pause() async => player.pause();
  Future<void> resume() async => player.play();
  Future<void> stop() async {
    await player.stop();
  }
  void dispose() => player.dispose();
}
