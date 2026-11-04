import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mymusicproject/presentation/providers/player_provider.dart';
import 'package:mymusicproject/presentation/providers/player_controller.dart';
import 'package:mymusicproject/presentation/providers/custom_artwork_provider.dart';
import 'package:mymusicproject/presentation/widgets/song_artwork.dart';
import 'package:mymusicproject/presentation/widgets/player/flippable_artwork_view.dart';

String _formatDuration(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  final m = two(d.inMinutes.remainder(60));
  final s = two(d.inSeconds.remainder(60));
  return d.inHours > 0 ? '${two(d.inHours)}:$m:$s' : '$m:$s';
}

String _firstNonEmpty(List<String?> values) {
  for (final v in values) {
    if (v != null && v.isNotEmpty) return v;
  }
  return '';
}

class LocalPlayerView extends ConsumerWidget {
  const LocalPlayerView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final origin = ref.watch(playbackOriginLabelProvider);
    final song = ref.watch(effectiveCurrentSongProvider);
    if (song == null) return const SizedBox.shrink();

    final isLoadingAudio = ref.watch(isLoadingProvider);
    final customArtworks = ref.watch(customArtworkProvider);
    final customMetadata = ref.watch(customSongMetadataProvider);

    final songId = song['id']?.toString() ?? '';
    final metadata = customMetadata[songId];

    final thumbnail = _firstNonEmpty([
      customArtworks[songId],
      metadata?.artworkPathOrUrl,
      song['thumbnail']?.toString(),
    ]);
    final title = metadata?.title.isNotEmpty == true
        ? metadata!.title
        : (song['title']?.toString() ?? 'Desconocido');
    final author = metadata?.artist.isNotEmpty == true
        ? metadata!.artist
        : (song['author']?.toString() ?? 'Artista desconocido');

    return Column(
      children: [
        if (isLoadingAudio)
          const LinearProgressIndicator(
            minHeight: 2,
            backgroundColor: Colors.transparent,
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24.0, 10, 24.0, 60.0),
            children: [
              Center(
                child: FlippableArtworkView(
                  songId: songId,
                  artwork: thumbnail,
                  title: title,
                  artist: author,
                ),
              ),
              const SizedBox(height: 30),
              if (origin != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      origin == 'Favoritos'
                          ? Icons.favorite
                          : origin.startsWith('Playlist')
                          ? Icons.queue_music
                          : Icons.library_music,
                      size: 14,
                      color: origin == 'Favoritos'
                          ? Colors.pinkAccent
                          : Colors.white54,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        origin.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 11,
                          letterSpacing: 1.2,
                          color: Colors.white54,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
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
              const _ProgressBar(),
              const SizedBox(height: 40),
              const _Controls(),
              const SizedBox(height: 20),
              const Divider(color: Colors.white24),
              const _UpcomingQueue(),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProgressBar extends ConsumerStatefulWidget {
  const _ProgressBar();

  @override
  ConsumerState<_ProgressBar> createState() => _ProgressBarState();
}

class _ProgressBarState extends ConsumerState<_ProgressBar> {
  double? _drag;

  @override
  Widget build(BuildContext context) {
    final position = ref.watch(positionProvider).value ?? Duration.zero;
    final duration = ref.watch(durationProvider).value ?? Duration.zero;

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
              await ref
                  .read(playerServiceProvider)
                  .player
                  .seek(Duration(milliseconds: v.round()));
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
}

class _Controls extends ConsumerWidget {
  const _Controls();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(playerControllerProvider);
    final isShuffle = ref.watch(isShuffleEnabledProvider);
    final repeatMode = ref.watch(repeatModeProvider);
    final isPlaying = ref.watch(isPlayingProvider).value ?? false;

    final repeatIcon = repeatMode == 2 ? Icons.repeat_one : Icons.repeat;
    final repeatColor = repeatMode == 0 ? Colors.white54 : Colors.blueAccent;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          icon: Icon(
            Icons.shuffle,
            color: isShuffle ? Colors.blueAccent : Colors.white,
          ),
          onPressed: controller.toggleShuffle,
        ),
        IconButton(
          icon: const Icon(Icons.skip_previous, size: 40, color: Colors.white),
          onPressed: controller.previous,
        ),
        Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            iconSize: 50,
            color: Colors.black,
            icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
            onPressed: () async {
              final player = ref.read(playerServiceProvider);
              if (isPlaying) {
                await player.pause();
              } else {
                await player.resume();
              }
            },
          ),
        ),
        IconButton(
          icon: const Icon(Icons.skip_next, size: 40, color: Colors.white),
          onPressed: controller.next,
        ),
        IconButton(
          icon: Icon(repeatIcon, color: repeatColor),
          onPressed: controller.toggleRepeat,
        ),
      ],
    );
  }
}

class _UpcomingQueue extends ConsumerWidget {
  const _UpcomingQueue();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upcoming = ref.watch(upcomingSongsProvider);
    return Column(
      children: [
        for (final song in upcoming)
          ListTile(
            key: ValueKey(song['id']),
            contentPadding: EdgeInsets.zero,
            leading: buildSongArtwork(
              artworkPathOrUrl: song['thumbnail']!,
              width: 60,
              height: 45,
              borderRadius: 8,
            ),
            title: Text(
              song['title']!,
              style: const TextStyle(color: Colors.white),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              song['author']!,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () =>
                ref.read(playerControllerProvider).playFromQueue(song['id']!),
          ),
      ],
    );
  }
}
