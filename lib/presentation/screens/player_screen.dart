import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mymusicproject/presentation/providers/player_provider.dart';
import 'package:mymusicproject/presentation/providers/favorites_provider.dart';
import 'package:mymusicproject/presentation/providers/youtube_favorites_provider.dart';
import 'package:mymusicproject/presentation/widgets/player/local_player_view.dart';
import 'package:mymusicproject/presentation/widgets/player/youtube_player_view.dart';
import 'package:mymusicproject/presentation/widgets/add_to_playlist_dialog.dart';
import 'package:mymusicproject/presentation/widgets/show_add_to_youtube_playlist_dialog.dart';
class PlayerScreen extends ConsumerWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSong = ref.watch(currentSongProvider);
    final song = ref.watch(effectiveCurrentSongProvider);
    final songPath = song?['data']?.toString() ?? '';

    if (currentSong == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF121212),
        body: Center(
          child: Text('Nada sonando', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    final isLocal = currentSong['isLocal'] == 'true';

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.keyboard_arrow_down,
            size: 32,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (songPath.isNotEmpty || currentSong['id'] != null) 
            _buildOptionsMenu(context, ref, songPath, isLocal),
        ],
      ),
      body: isLocal ? const LocalPlayerView() : const YoutubePlayerView(),
    );
  }

  Widget _buildOptionsMenu(
    BuildContext context,
    WidgetRef ref,
    String songPath,
    bool isLocal,
  ) {
    final currentSong = ref.watch(currentSongProvider);
    final videoId = currentSong?['id']?.toString() ?? '';
    final isFav = isLocal
        ? ref.watch(favoritesIdsProvider).contains(songPath)
        : ref.watch(youtubeFavoritesProvider.notifier).isFavorite(videoId);

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.white),
      color: const Color(0xFF2C2C2C),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) {
        if (value == 'favorite') {
          if (isLocal) {
            ref.read(favoritesIdsProvider.notifier).toggleFavorite(songPath);
          } else {
            if (currentSong != null) {
              ref.read(youtubeFavoritesProvider.notifier).toggleFavorite(currentSong);
            }
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isFav ? 'Eliminado de favoritos' : 'Añadido a favoritos',
              ),
              duration: const Duration(seconds: 1),
            ),
          );
        } else if (value == 'playlist') {
          final effectiveSong = ref.read(effectiveCurrentSongProvider);
          
          if (currentSong != null) {
            final songData = {
              'id': currentSong['id'] ?? '',
              'title': effectiveSong?['title'] ?? currentSong['title'] ?? 'Sin título',
              'author': effectiveSong?['author'] ?? currentSong['author'] ?? 'Desconocido',
              'thumbnail': currentSong['thumbnail'] ?? '',
              'isLocal': currentSong['isLocal'] ?? 'false',
              'data': songPath,
            };

            if (isLocal) {
              showAddToPlaylistDialog(context, ref, songData);
            } else {
              showAddToYoutubePlaylistDialog(context, ref, songData);
            }
          }
        }
      },
      itemBuilder: (context) => [
        if (isLocal)
          PopupMenuItem(
            value: 'favorite',
            child: Row(
              children: [
                Icon(
                  isFav ? Icons.favorite : Icons.favorite_border,
                  color: isFav ? Colors.pinkAccent : Colors.white70,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Text(
                  isFav ? 'Quitar de favoritos' : 'Añadir a favoritos',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ],
            ),
          ),

        const PopupMenuItem(
          value: 'playlist',
          child: Row(
            children: [
              Icon(Icons.playlist_add, color: Colors.white70, size: 18),
              SizedBox(width: 10),
              Text(
                'Añadir a playlist',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}