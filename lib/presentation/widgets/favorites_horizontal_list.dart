import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mymusicproject/presentation/providers/player_provider.dart';
import 'package:mymusicproject/presentation/providers/custom_artwork_provider.dart';
import 'package:mymusicproject/presentation/widgets/song_artwork.dart';
import 'package:mymusicproject/presentation/providers/youtube_favorites_provider.dart';

class FavoritesHorizontalList extends ConsumerWidget {
  const FavoritesHorizontalList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoriteSongs = ref.watch(youtubeFavoritesProvider);
    final customArtworks = ref.watch(customArtworkProvider);

    if (favoriteSongs.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            'Tus Favoritas',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            itemCount: favoriteSongs.length,
            itemBuilder: (context, index) {
              final song = favoriteSongs[index];
              final songId = song['id']?.toString() ?? '';
              final title = song['title']?.toString() ?? 'Sin título';
              final author =
                  song['author']?.toString() ??
                  song['artist']?.toString() ??
                  'Artista';
              final artwork =
                  customArtworks[songId] ?? song['thumbnail']?.toString() ?? '';

              return Container(
                width: 120,
                margin: const EdgeInsets.only(right: 14.0),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () async {
                    final isLocal = song['isLocal'] == 'true';

                    ref.read(currentSongProvider.notifier).state = song;

                    if (isLocal) {
                      await ref
                          .read(playerServiceProvider)
                          .playLocalFile(
                            song['data'].toString(),
                            id: songId,
                            title: title,
                            author: author,
                          );
                    } else {
                      final extractor = ref.read(ytExtractorProvider);
                      final data = await extractor.getAudioUrl(songId);
                      if (data != null && data['url'] != null) {
                        await ref
                            .read(playerServiceProvider)
                            .playFromUrl(
                              data['url'].toString(),
                              id: songId,
                              title: title,
                              author: author,
                              thumbnailUrl: artwork,
                            );
                      }
                    }
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 120,
                          height: 120,
                          child: buildSongArtwork(
                            artworkPathOrUrl: artwork,
                            width: 120,
                            height: 120,
                            borderRadius: 8,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        author,
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
              );
            },
          ),
        ),
      ],
    );
  }
}
