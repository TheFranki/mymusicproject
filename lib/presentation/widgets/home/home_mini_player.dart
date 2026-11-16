import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mymusicproject/presentation/providers/player_provider.dart';
import 'package:mymusicproject/presentation/providers/player_controller.dart';
import 'package:mymusicproject/presentation/providers/custom_artwork_provider.dart';
import 'package:mymusicproject/presentation/widgets/song_artwork.dart';
import 'package:mymusicproject/presentation/theme/app_theme.dart';

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

  Widget _miniButton(IconData icon, VoidCallback onPressed) => IconButton(
        icon: Icon(icon, color: Colors.white, size: 26),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        onPressed: onPressed,
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfg = ref.watch(appThemeProvider);
    final accent = cfg.accent;

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

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: Container(
          // misma decoración que la vista previa de Ajustes
          decoration: cfg.decoration.copyWith(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        buildSongArtwork(
                          artworkPathOrUrl: activeArtwork,
                          width: 52,
                          height: 52,
                          borderRadius: 10,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
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
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        _miniButton(Icons.skip_previous, () => controller.previous()),
                        IconButton(
                          icon: Icon(
                            isPlaying
                                ? Icons.pause_circle_filled
                                : Icons.play_circle_fill,
                            color: accent,
                            size: 40,
                          ),
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 44, minHeight: 44),
                          onPressed: () async {
                            final player = ref.read(playerServiceProvider);
                            if (isPlaying) {
                              await player.pause();
                            } else {
                              await player.resume();
                            }
                          },
                        ),
                        _miniButton(Icons.skip_next, () => controller.next()),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _MiniProgress(accent: accent),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  }  // <- cierra HomeMiniPlayer

class _MiniProgress extends ConsumerWidget {
  const _MiniProgress({required this.accent});
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.read(playerServiceProvider).player;
    return StreamBuilder<Duration?>(
      stream: player.durationStream,
      initialData: player.duration,
      builder: (context, durSnap) {
        final total = durSnap.data?.inMilliseconds ?? 0;
        return StreamBuilder<Duration>(
          stream: player.positionStream,
          builder: (context, posSnap) {
            final pos = posSnap.data?.inMilliseconds ?? 0;
            final double value =
                total > 0 ? (pos / total).clamp(0.0, 1.0).toDouble() : 0.0;
            return ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 4,
                color: accent,
                backgroundColor: Colors.white24,
              ),
            );
          },
        );
      },
    );
  }
}