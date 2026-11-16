import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

class AppAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer player = AudioPlayer();

  Future<void> Function()? onNext;
  Future<void> Function()? onPrevious;
  Future<void> Function()? onToggleShuffle;
  Future<void> Function()? onToggleRepeat;
  Future<void> Function()? onToggleFavorite;

  bool _shuffle = false;
  int _repeat = 0;
  bool _favorite = false;

  AppAudioHandler() {
    player.playbackEventStream.listen((_) => _broadcast());
    player.durationStream.listen((d) {
      final item = mediaItem.value;
      if (item != null && d != null && item.duration != d) {
        mediaItem.add(item.copyWith(duration: d));
      }
    });
  }

  void updateExtras({bool? shuffle, int? repeat, bool? favorite}) {
    final changed = (shuffle != null && shuffle != _shuffle) ||
        (repeat != null && repeat != _repeat) ||
        (favorite != null && favorite != _favorite);
    _shuffle = shuffle ?? _shuffle;
    _repeat = repeat ?? _repeat;
    _favorite = favorite ?? _favorite;
    if (changed) _broadcast();
  }

  MediaControl _custom(String name, String icon, String label) =>
      MediaControl.custom(
        androidIcon: 'drawable/$icon',
        label: label,
        name: name,
      );

  void _broadcast() {
    final repeatIcon = switch (_repeat) {
      1 => 'ic_notif_repeat_all',
      2 => 'ic_notif_repeat_one',
      _ => 'ic_notif_repeat_off',
    };

    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          _custom('toggleShuffle',
              _shuffle ? 'ic_notif_shuffle_on' : 'ic_notif_shuffle_off',
              'Aleatorio'),
          MediaControl.skipToPrevious,
          player.playing ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
          _custom('toggleFavorite',
              _favorite ? 'ic_notif_fav_on' : 'ic_notif_fav_off',
              'Favorito'),
        ],
        androidCompactActionIndices: const [1, 2, 3],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        processingState: const {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[player.processingState]!,
        playing: player.playing,
        updatePosition: player.position,
        bufferedPosition: player.bufferedPosition,
        speed: player.speed,
      ),
    );
  }

  @override
  Future<void> play() => player.play();
  @override
  Future<void> pause() => player.pause();
  @override
  Future<void> seek(Duration position) => player.seek(position);
  @override
  Future<void> skipToNext() async => await onNext?.call();
  @override
  Future<void> skipToPrevious() async => await onPrevious?.call();

  @override
  Future<dynamic> customAction(String name, [Map<String, dynamic>? extras]) async {
    switch (name) {
      case 'toggleShuffle':
        await onToggleShuffle?.call();
      case 'toggleRepeat':
        await onToggleRepeat?.call();
      case 'toggleFavorite':
        await onToggleFavorite?.call();
    }
  }

  @override
  Future<void> stop() async {
    await player.stop();
    return super.stop();
  }
}