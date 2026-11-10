import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/player_provider.dart';
import '../providers/favorites_provider.dart';
import 'player_screen.dart';
import 'package:mymusicproject/presentation/providers/local_music_provider.dart';

class LocalMusicScreen extends ConsumerWidget {
  const LocalMusicScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songsAsync = ref.watch(localSongsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text(
          'Música Local',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: songsAsync.when(
        data: (songs) {
          if (songs.isEmpty) {
            return Center(
              child: Text(
                'No se encontraron canciones en el almacenamiento.',
                style: TextStyle(color: Colors.grey[500]),
              ),
            );
          }

          return ListView.builder(
            itemCount: songs.length,
            itemBuilder: (context, index) {
              final song = songs[index];
              final songPath = song['data']
                  .toString();

              return ListTile(
                leading: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade800,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.music_note, color: Colors.white54),
                ),
                title: Text(
                  song['title'] ?? 'Sin título',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  song['artist'] ?? 'Artista desconocido',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                
                trailing: Consumer(
                  builder: (context, ref, child) {
                    final isFav = ref
                        .watch(favoritesIdsProvider)
                        .contains(songPath);

                    return SizedBox(
                      width: 48,
                      height: 48,
                      child: IconButton(
                        icon: Icon(
                          isFav ? Icons.favorite : Icons.favorite_border,
                          color: isFav ? Colors.pinkAccent : Colors.grey,
                        ),
                        onPressed: () {
                          print(
                            'Favorito en la ruta: $songPath!',
                          );

                          ref
                              .read(favoritesIdsProvider.notifier)
                              .toggleFavorite(songPath);
                        },
                      ),
                    );
                  },
                ),

                onTap: () async {
                  ref.read(currentSongProvider.notifier).state = {
                    'id': song['id'].toString(),
                    'title': song['title']?.toString() ?? 'Sin título',
                    'author': song['artist']?.toString() ?? 'Desconocido',
                    'thumbnail': '',
                    'isLocal': 'true',
                    'data': songPath,
                  };

                  final playerService = ref.read(playerServiceProvider);
                  await playerService.playLocalFile(
                    songPath,
                    id: song['id'].toString(),
                    title: song['title'].toString(),
                    author: song['artist'].toString(),
                  );

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
        loading: () =>
            const Center(child: CircularProgressIndicator(color: Colors.white)),
        error: (err, stack) => Center(
          child: Text('Error: $err', style: const TextStyle(color: Colors.red)),
        ),
      ),
    );
  }
}
