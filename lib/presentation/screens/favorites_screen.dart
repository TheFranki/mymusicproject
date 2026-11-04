import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/local_music_provider.dart';
import '../providers/favorites_provider.dart';
import '../providers/player_provider.dart';
import '../providers/player_controller.dart';
import '../providers/custom_artwork_provider.dart';
import '../widgets/song_artwork.dart';
import 'player_screen.dart';
import '../widgets/home/home_mini_player.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localSongsAsync = ref.watch(localSongsProvider);
    final favoriteIds = ref.watch(favoritesIdsProvider);
    final metadata = ref.watch(customSongMetadataProvider);
    final artworks = ref.watch(customArtworkProvider);
    final library = ref.watch(libraryByIdProvider);
    final currentSong = ref.watch(effectiveCurrentSongProvider);

    return Scaffold(
      bottomNavigationBar:
          currentSong != null &&
              currentSong['id'] != null &&
              currentSong['id'].toString().isNotEmpty
          ? HomeMiniPlayer(
              song: Map<String, dynamic>.from(currentSong),
              artwork:
                  artworks[currentSong['id'].toString()] ??
                  currentSong['thumbnail']?.toString(),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PlayerScreen()),
                );
              },
            )
          : null,
      backgroundColor: Colors.black.withValues(alpha: 0.95),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Tus Favoritas',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: localSongsAsync.when(
        data: (songs) {
          final favoriteSongs = songs
              .where((s) => favoriteIds.contains(s['data']?.toString() ?? ''))
              .map(
                (s) => resolveSong(
                  s,
                  library: library,
                  metadata: metadata,
                  artworks: artworks,
                ),
              )
              .toList();

          if (favoriteSongs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_border, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No tienes canciones favoritas aún',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: favoriteSongs.length,
            itemBuilder: (context, index) {
              final song = favoriteSongs[index];
              final songPath = song['data'] ?? '';

              return ListTile(
                leading: buildSongArtwork(
                  artworkPathOrUrl: song['thumbnail'] ?? '',
                  width: 48,
                  height: 48,
                  borderRadius: 8,
                ),
                title: Text(
                  song['title']!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  song['author']!,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.favorite, color: Colors.pinkAccent),
                  onPressed: () => ref
                      .read(favoritesIdsProvider.notifier)
                      .toggleFavorite(songPath),
                ),
                onTap: () async {
                  await ref
                      .read(playerControllerProvider)
                      .playContext(favoriteSongs, song, origin: 'favorites');
                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PlayerScreen()),
                    );
                  }
                },
              );
            },
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.pinkAccent),
        ),
        error: (err, stack) => Center(
          child: Text(
            'Error al cargar favoritos: $err',
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ),
    );
  }
}
