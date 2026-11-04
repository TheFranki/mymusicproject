// lib/presentation/widgets/player/youtube_player_view.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import 'package:mymusicproject/presentation/providers/player_controller.dart';
import 'package:mymusicproject/presentation/providers/player_provider.dart';
import 'package:mymusicproject/presentation/providers/search_provider.dart';
import 'package:mymusicproject/presentation/providers/youtube_favorites_provider.dart';
import 'package:mymusicproject/presentation/widgets/song_artwork.dart';

String _formatDuration(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  final m = two(d.inMinutes.remainder(60));
  final s = two(d.inSeconds.remainder(60));
  return d.inHours > 0 ? '${two(d.inHours)}:$m:$s' : '$m:$s';
}

class YoutubePlayerView extends ConsumerStatefulWidget {
  const YoutubePlayerView({super.key});

  @override
  ConsumerState<YoutubePlayerView> createState() => _YoutubePlayerViewState();
}

class _YoutubePlayerViewState extends ConsumerState<YoutubePlayerView> {
  VideoPlayerController? _video;
  bool _videoReady = false;
  bool _handlingCompletion = false;
  int _videoToken = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(isVideoModeProvider.notifier).state = false;
      unawaited(ref.read(playerControllerProvider).ensureRelated());
    });
  }

  @override
  void dispose() {
    _videoToken++;
    _video?.removeListener(_onVideoTick);
    _video?.dispose();
    super.dispose();
  }

  // ---------------- MODO VIDEO ----------------
  void _disposeLater(VideoPlayerController? c) {
    if (c == null) return;
    c.removeListener(_onVideoTick);
    unawaited(c.pause());
    WidgetsBinding.instance.addPostFrameCallback((_) => c.dispose());
  }

  Future<void> _enterVideoMode(String videoId) async {
    final service = ref.read(playerServiceProvider);
    final startAt = service.player.position;
    final token = ++_videoToken;

    ref.read(isVideoModeProvider.notifier).state = true;
    await service.pause();
    if (mounted) setState(() => _videoReady = false);

    try {
      final url = await ref.read(ytExtractorProvider).getVideoUrl(videoId);
      if (!mounted || token != _videoToken) return;
      if (url == null || url.isEmpty) throw Exception('Sin URL de video');

      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await controller.initialize();
      if (!mounted || token != _videoToken) {
        await controller.dispose();
        return;
      }

      await controller.seekTo(startAt);
      controller.addListener(_onVideoTick);

      final old = _video;
      setState(() {
        _video = controller;
        _videoReady = true;
      });
      _disposeLater(old);
      await controller.play();
    } catch (e) {
      debugPrint('[YoutubePlayerView] Error al cargar video: $e');
      if (!mounted || token != _videoToken) return;
      ref.read(isVideoModeProvider.notifier).state = false;
      setState(() => _videoReady = false);
      await service.resume();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo cargar el video'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exitVideoMode({required bool resumeAudio}) async {
    final old = _video;
    final position = old?.value.position ?? Duration.zero;
    _videoToken++;

    ref.read(isVideoModeProvider.notifier).state = false;
    if (mounted) {
      setState(() {
        _video = null;
        _videoReady = false;
      });
    }
    _disposeLater(old);

    if (resumeAudio) {
      final service = ref.read(playerServiceProvider);
      if (old != null) await service.player.seek(position);
      await service.resume();
    }
  }

  void _onVideoTick() {
    final v = _video;
    if (v == null || _handlingCompletion) return;
    final value = v.value;
    if (value.isInitialized &&
        value.duration > Duration.zero &&
        value.position >= value.duration) {
      _handlingCompletion = true;
      _onVideoCompleted().whenComplete(() => _handlingCompletion = false);
    }
  }

  Future<void> _onVideoCompleted() async {
    final v = _video;
    if (ref.read(repeatModeProvider) == 2 && v != null) {
      await v.seekTo(Duration.zero);
      await v.play();
      return;
    }
    await _exitVideoMode(resumeAudio: false);
    await ref.read(playerControllerProvider).next(auto: true);
  }

  // ---------------- CONTROLES ----------------
  Future<void> _next() async {
    if (_video != null) await _exitVideoMode(resumeAudio: false);
    await ref.read(playerControllerProvider).next();
  }

  Future<void> _previous() async {
    final v = _video;
    if (v != null) {
      await v.seekTo(Duration.zero);
    } else {
      await ref.read(playerControllerProvider).previous();
    }
  }

  Widget _buildPlayPause(bool isVideoMode, bool audioPlaying) {
    Widget button(bool playing, VoidCallback? onPressed) => Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        iconSize: 50,
        color: Colors.black,
        icon: Icon(playing ? Icons.pause : Icons.play_arrow),
        onPressed: onPressed,
      ),
    );

    if (isVideoMode) {
      final video = _video;
      if (video == null || !_videoReady) return button(false, null);
      return ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: video,
        builder: (_, value, _) => button(
          value.isPlaying,
          () => value.isPlaying ? video.pause() : video.play(),
        ),
      );
    }

    return button(audioPlaying, () async {
      final service = ref.read(playerServiceProvider);
      if (audioPlaying) {
        await service.pause();
      } else {
        await service.resume();
      }
    });
  }

  // ---------------- BUILD ----------------
  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(currentSongProvider.select((s) => s?['id']), (
      prev,
      next,
    ) {
      if (prev != null && next != prev && _video != null) {
        _exitVideoMode(resumeAudio: false);
      }
    });

    final song = ref.watch(effectiveCurrentSongProvider);
    if (song == null) return const SizedBox.shrink();

    final isVideoMode = ref.watch(isVideoModeProvider);
    final audioPlaying = ref.watch(isPlayingProvider).value ?? false;
    final isLoading = ref.watch(isLoadingProvider);
    final related = ref.watch(relatedVideosProvider);
    final controller = ref.read(playerControllerProvider);

    final videoId = song['id'] ?? '';
    final thumbnail = song['thumbnail'] ?? '';
    final title = song['title'] ?? 'Desconocido';
    final author = song['author'] ?? 'Artista desconocido';

    return Column(
      children: [
        if (isLoading)
          const LinearProgressIndicator(
            minHeight: 2,
            backgroundColor: Colors.transparent,
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24.0, 10, 24.0, 60.0),
            children: [
              // ---- Carátula / video ----
              Stack(
                children: [
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 400,
                        height: 200,
                        child: isVideoMode
                            ? (_videoReady && _video != null
                                  ? VideoPlayer(_video!)
                                  : Container(
                                      color: Colors.black,
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ))
                            : buildSongArtwork(
                                artworkPathOrUrl: thumbnail,
                                width: 400,
                                height: 200,
                                borderRadius: 0,
                              ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(
                          isVideoMode ? Icons.music_note : Icons.videocam,
                          color: Colors.white,
                          size: 22,
                        ),
                        tooltip: isVideoMode
                            ? 'Cambiar a modo audio'
                            : 'Cambiar a modo video',
                        onPressed: videoId.isEmpty
                            ? null
                            : () => isVideoMode
                                  ? _exitVideoMode(resumeAudio: true)
                                  : _enterVideoMode(videoId),
                      ),
                    ),
                  ),
                ],
              ),

              // ---- Favorito ----
              Align(
                alignment: Alignment.center,
                child: Consumer(
                  builder: (context, ref, _) {
                    final isFav = ref.watch(
                      youtubeFavoritesProvider.select(
                        (list) => list.any((s) => s['id'] == videoId),
                      ),
                    );
                    return IconButton(
                      icon: Icon(
                        isFav ? Icons.favorite : Icons.favorite_border,
                        color: isFav ? Colors.redAccent : Colors.white,
                        size: 28,
                      ),
                      onPressed: () => ref
                          .read(youtubeFavoritesProvider.notifier)
                          .toggleFavorite(song),
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                author,
                style: TextStyle(fontSize: 16, color: Colors.grey[400]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),

              _YtProgressBar(video: isVideoMode ? _video : null),
              const SizedBox(height: 40),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Consumer(
                    builder: (context, ref, _) {
                      final isShuffle = ref.watch(isShuffleEnabledProvider);
                      return IconButton(
                        icon: Icon(
                          Icons.shuffle,
                          color: isShuffle ? Colors.blueAccent : Colors.white,
                        ),
                        onPressed: controller.toggleShuffle,
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.skip_previous,
                      size: 40,
                      color: Colors.white,
                    ),
                    onPressed: _previous,
                  ),
                  _buildPlayPause(isVideoMode, audioPlaying),
                  IconButton(
                    icon: const Icon(
                      Icons.skip_next,
                      size: 40,
                      color: Colors.white,
                    ),
                    onPressed: _next,
                  ),
                  Consumer(
                    builder: (context, ref, _) {
                      final mode = ref.watch(repeatModeProvider);
                      return IconButton(
                        icon: Icon(
                          mode == 2 ? Icons.repeat_one : Icons.repeat,
                          color: mode == 0 ? Colors.white54 : Colors.blueAccent,
                        ),
                        onPressed: controller.toggleRepeat,
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 20),
              const Divider(color: Colors.white24),

              // ---- Recomendaciones ----
              for (final video in related)
                ListTile(
                  key: ValueKey(video['id']),
                  contentPadding: EdgeInsets.zero,
                  leading: buildSongArtwork(
                    artworkPathOrUrl: video['thumbnail'],
                    width: 60,
                    height: 45,
                    borderRadius: 8,
                  ),
                  title: Text(
                    video['title'] ?? '',
                    style: const TextStyle(color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    video['author'] ?? '',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: (video['id'] ?? '').isEmpty
                      ? null
                      : () => controller.playYoutube(video),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================
// BARRA DE PROGRESO (audio o video)
// ============================================================
class _YtProgressBar extends ConsumerStatefulWidget {
  final VideoPlayerController? video;
  const _YtProgressBar({required this.video});

  @override
  ConsumerState<_YtProgressBar> createState() => _YtProgressBarState();
}

class _YtProgressBarState extends ConsumerState<_YtProgressBar> {
  double? _drag;

  Widget _bar(
    Duration position,
    Duration duration,
    Future<void> Function(Duration) onSeek,
  ) {
    final maxMs = duration.inMilliseconds > 0
        ? duration.inMilliseconds.toDouble()
        : 1.0;
    final posMs = (_drag ?? position.inMilliseconds.toDouble())
        .clamp(0.0, maxMs)
        .toDouble();

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            trackHeight: 4,
            activeTrackColor: Colors.white,
            inactiveTrackColor: Colors.white24,
            thumbColor: Colors.white,
          ),
          child: Slider(
            min: 0.0,
            max: maxMs,
            value: posMs,
            onChanged: duration.inMilliseconds > 0
                ? (v) => setState(() => _drag = v)
                : null,
            onChangeEnd: (v) async {
              await onSeek(Duration(milliseconds: v.round()));
              if (mounted) setState(() => _drag = null);
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _formatDuration(Duration(milliseconds: posMs.round())),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            Text(
              _formatDuration(duration),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final video = widget.video;
    if (video != null) {
      return ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: video,
        builder: (_, value, _) =>
            _bar(value.position, value.duration, video.seekTo),
      );
    }

    final position = ref.watch(positionProvider).value ?? Duration.zero;
    final duration = ref.watch(durationProvider).value ?? Duration.zero;
    return _bar(
      position,
      duration,
      (d) => ref.read(playerServiceProvider).player.seek(d),
    );
  }
}