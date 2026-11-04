import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mymusicproject/presentation/providers/player_provider.dart';
import 'package:mymusicproject/presentation/providers/player_controller.dart';
import 'package:mymusicproject/presentation/providers/custom_artwork_provider.dart';
import 'package:mymusicproject/presentation/widgets/song_artwork.dart';

class HomeMiniPlayer extends ConsumerWidget {
  final Map<String, dynamic> song;
  final String? artwork;
  final VoidCallback onTap;

  const HomeMiniPlayer({
    super.key,
    required this.song,
    required this.artwork,
    required this.onTap,
  });

  String _firstNonEmpty(List<String?> values) {
    for (final v in values) {
      if (v != null && v.isNotEmpty) return v;
    }
    return '';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songId = song['id']?.toString() ?? '';
    final origin = ref.watch(playbackOriginLabelProvider);
    final metadata = ref.watch(customSongMetadataProvider)[songId];
    final title = metadata?.title.isNotEmpty == true
        ? metadata!.title
        : (song['title']?.toString() ?? 'Sin título');
    final artist = metadata?.artist.isNotEmpty == true
        ? metadata!.artist
        : (song['author'] ?? song['artist'] ?? 'Desconocido').toString();
    final customArtworks = ref.watch(customArtworkProvider);
    final activeArtwork = _firstNonEmpty([
      customArtworks[songId],
      metadata?.artworkPathOrUrl,
      artwork,
      song['thumbnail']?.toString(),
    ]);
    final isPlaying = ref.watch(isPlayingProvider).value ?? false;
    final controller = ref.read(playerControllerProvider);

    return Material(
      color: const Color(0xFF202020),
      child: InkWell(
        onTap: onTap,
        child: SafeArea(
          top: false,
          child: Container(
            height: 72,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.grey.shade800, width: 0.7),
              ),
            ),
            child: Row(
              children: [
                buildSongArtwork(
                  artworkPathOrUrl: activeArtwork,
                  width: 48,
                  height: 48,
                  borderRadius: 6,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (origin != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            origin.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 9,
                              letterSpacing: 1.1,
                              fontWeight: FontWeight.w600,
                              color: origin == 'Favoritos'
                                  ? Colors.pinkAccent
                                  : Colors.white54,
                            ),
                          ),
                        ),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(
                    Icons.skip_previous,
                    color: Colors.white,
                    size: 24,
                  ),
                  onPressed: controller.previous,
                ),
                IconButton(
                  icon: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 26,
                  ),
                  onPressed: () async {
                    final player = ref.read(playerServiceProvider);
                    if (isPlaying) {
                      await player.pause();
                    } else {
                      await player.resume();
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(
                    Icons.skip_next,
                    color: Colors.white,
                    size: 24,
                  ),
                  onPressed: controller.next,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
