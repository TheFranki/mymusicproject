import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mymusicproject/presentation/providers/player_provider.dart';
import 'package:mymusicproject/presentation/providers/favorites_provider.dart';
import 'package:mymusicproject/presentation/widgets/song_artwork.dart';
import 'package:mymusicproject/presentation/widgets/edit_song.dart';
import 'package:mymusicproject/presentation/providers/local_music_provider.dart';
import 'package:mymusicproject/presentation/providers/custom_artwork_provider.dart';
import 'package:mymusicproject/presentation/theme/app_theme.dart';
import 'package:mymusicproject/presentation/widgets/song_row_frame.dart';

class SongList extends ConsumerWidget {
  final List<Map<String, dynamic>> songs;
  final ValueChanged<Map<String, dynamic>> onSongTap;

  const SongList({super.key, required this.songs, required this.onSongTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfg = ref.watch(appThemeProvider);
    final customArtworks = ref.watch(customArtworkProvider);
    final customMetadata = ref.watch(customSongMetadataProvider);
    //final favoriteIds = ref.watch(favoritesIdsProvider);
    final currentSong = ref.watch(currentSongProvider);

    if (songs.isEmpty) {
      return const Center(
        child: Text(
          'No se encontraron canciones.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: songs.length,
      itemBuilder: (context, index) {
        final song = songs[index];

        final id = song['id']?.toString() ?? '';
        final songPath = song['data']?.toString() ?? '';
        //final isFav = favoriteIds.contains(songPath);

        final metadata = customMetadata[id];

        final title = metadata?.title.isNotEmpty == true
            ? metadata!.title
            : song['title']?.toString() ?? 'Sin título';

        final artist = metadata?.artist.isNotEmpty == true
            ? metadata!.artist
            : song['artist']?.toString() ??
                  song['author']?.toString() ??
                  'Artista desconocido';

        final metadataArtwork = metadata?.artworkPathOrUrl ?? '';

        final artwork = customArtworks[id]?.isNotEmpty == true
            ? customArtworks[id]
            : metadataArtwork.isNotEmpty
            ? metadataArtwork
            : song['thumbnail']?.toString();

        final isPlayingThisSong =
            currentSong != null && currentSong['id']?.toString() == id;

        return SongRowFrame(
          key: ValueKey(id),
          cfg: cfg,
          isPlaying: isPlayingThisSong,
          child: ListTile(
            leading: buildSongArtwork(
              artworkPathOrUrl: artwork,
              width: 45,
              height: 45,
              borderRadius: 8,
            ),
            title: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isPlayingThisSong ? cfg.lineTextColor : Colors.white,
                fontSize: 14,
                fontWeight: isPlayingThisSong
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
            subtitle: Text(
              artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            trailing: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.grey),
              color: Colors.grey.shade900,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onSelected: (value) async {
                switch (value) {
                  case 'favorite':
                    final wasFav = ref
                        .read(favoritesIdsProvider)
                        .contains(songPath);
                    ref
                        .read(favoritesIdsProvider.notifier)
                        .toggleFavorite(songPath);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          wasFav
                              ? '"$title" eliminado de favoritos'
                              : '"$title" añadido a favoritos',
                        ),
                        duration: const Duration(milliseconds: 1500),
                      ),
                    );
                    break;

                  case 'edit_info':
                    showEditSongInfoDialog(context, ref, song);
                    break;

                  case 'delete':
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        backgroundColor: Colors.grey.shade900,
                        title: const Text(
                          'Eliminar canción',
                          style: TextStyle(color: Colors.white),
                        ),
                        content: Text(
                          '¿Estás seguro de que deseas eliminar '
                          '"$title" del dispositivo?',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(dialogContext, false),
                            child: const Text('Cancelar'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext, true),
                            child: const Text(
                              'Eliminar',
                              style: TextStyle(color: Colors.redAccent),
                            ),
                          ),
                        ],
                      ),
                    );

                    if (confirm != true || !context.mounted) {
                      return;
                    }

                    try {
                      final success = await ref
                          .read(localAudioServiceProvider)
                          .deleteSongFile(id);

                      if (!context.mounted) return;

                      if (success) {
                        ref.invalidate(localSongsProvider);

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Archivo eliminado del dispositivo'),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('No se pudo eliminar el archivo'),
                          ),
                        );
                      }
                    } catch (e, stack) {
                      debugPrint('[SONG LIST] Error al eliminar: $e');
                      debugPrintStack(stackTrace: stack);

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Error al eliminar la canción'),
                          ),
                        );
                      }
                    }
                    break;

                  case 'share':
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Compartiendo "$title"...')),
                    );
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit_info',
                  child: _SongMenuItem(
                    color: Colors.white,
                    title: 'Editar Música',
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: _SongMenuItem(color: Colors.white, title: 'Eliminar'),
                ),
                const PopupMenuItem(
                  value: 'share',
                  child: _SongMenuItem(color: Colors.white, title: 'Compartir'),
                ),
              ],
            ),
            onTap: () => onSongTap(song),
          ),
        );
      },
    );
  }
}

class _SongMenuItem extends StatelessWidget {
  final Color color;
  final String title;

  const _SongMenuItem({required this.color, required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(title, style: TextStyle(color: color));
  }
}
