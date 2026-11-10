import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mymusicproject/presentation/providers/youtube_favorites_provider.dart';
import 'package:mymusicproject/presentation/providers/player_provider.dart';
import 'package:mymusicproject/presentation/screens/player_screen.dart';
import 'package:mymusicproject/presentation/providers/custom_artwork_provider.dart';
import 'package:mymusicproject/presentation/widgets/home/home_mini_player.dart';

final youtubeFavoritesGridViewProvider = StateProvider<bool>((ref) => false);

class YoutubeFavoritesScreen extends ConsumerWidget {
  const YoutubeFavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoriteSongs = ref.watch(youtubeFavoritesProvider);
    final isGridView = ref.watch(youtubeFavoritesGridViewProvider);
    final currentSong = ref.watch(effectiveCurrentSongProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Favoritos de YouTube',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(
              isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
            ),
            onPressed: () {
              ref.read(youtubeFavoritesGridViewProvider.notifier).state = !isGridView;
            },
          ),
        ],
      ),
      body: favoriteSongs.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_border, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No tienes canciones de YouTube favoritas',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            )
          : isGridView
              ? GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: favoriteSongs.length,
                  itemBuilder: (context, index) {
                    final video = favoriteSongs[index];
                    return GestureDetector(
                      onTap: () async {
                        ref.read(currentSongProvider.notifier).state = video;
                        final extractor = ref.read(ytExtractorProvider);
                        final player = ref.read(playerServiceProvider);
                        final data = await extractor.getAudioUrl(video['id']!);
                        if (data != null && data['url'] != null) {
                          await player.playFromUrl(
                            data['url']!,
                            id: video['id']!,
                            title: video['title'] ?? '',
                            author: video['author'] ?? '',
                            thumbnailUrl: video['thumbnail'] ?? '',
                          );
                        }
                        if (context.mounted) {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const PlayerScreen()));
                        }
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                video['thumbnail'] ?? '',
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Container(
                                  color: Colors.grey.shade800,
                                  child: const Center(child: Icon(Icons.music_note)),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            video['title'] ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            video['author'] ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    );
                  },
                )
              : ListView.builder(
                  itemCount: favoriteSongs.length,
                  itemBuilder: (context, index) {
                    final video = favoriteSongs[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          video['thumbnail'] ?? '',
                          width: 80,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            width: 80,
                            height: 60,
                            color: Colors.grey.shade800,
                            child: const Icon(Icons.music_note),
                          ),
                        ),
                      ),
                      title: Text(
                        video['title'] ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        video['author'] ?? '',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.favorite, color: Colors.redAccent),
                        onPressed: () {
                          ref.read(youtubeFavoritesProvider.notifier).toggleFavorite(video);
                        },
                      ),
                      onTap: () async {
                        ref.read(currentSongProvider.notifier).state = video;
                        final extractor = ref.read(ytExtractorProvider);
                        final player = ref.read(playerServiceProvider);
                        final data = await extractor.getAudioUrl(video['id']!);
                        if (data != null && data['url'] != null) {
                          await player.playFromUrl(
                            data['url']!,
                            id: video['id']!,
                            title: video['title'] ?? '',
                            author: video['author'] ?? '',
                            thumbnailUrl: video['thumbnail'] ?? '',
                          );
                        }
                        if (context.mounted) {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const PlayerScreen()));
                        }
                      },
                    );
                  },
                ),
      bottomNavigationBar: currentSong != null && currentSong['id'] != null && currentSong['id'].toString().isNotEmpty
          ? HomeMiniPlayer(
              song: Map<String, dynamic>.from(currentSong),
              artwork: ref.watch(customArtworkProvider)[currentSong['id'].toString()] ?? currentSong['thumbnail']?.toString(),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const PlayerScreen()));
              },
            )
          : null,
    );
  }
}