import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/youtube_playlist_provider.dart';

void showAddToYoutubePlaylistDialog(
  BuildContext context,
  WidgetRef ref,
  Map<String, String> song,
) {
  showDialog(
    context: context,
    builder: (context) {
      final playlists = ref.watch(youtubePlaylistsProvider);

      return AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Añadir a Playlist', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          child: playlists.isEmpty
              ? const Text(
                  'No existen Playlists creadas.\nCrea una desde la sección de Playlists.',
                  style: TextStyle(color: Colors.grey),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: playlists.length,
                  itemBuilder: (context, index) {
                    final playlist = playlists[index];
                    return ListTile(
                      leading: const Icon(Icons.folder_special, color: Colors.blueAccent),
                      title: Text(playlist.name, style: const TextStyle(color: Colors.white)),
                      subtitle: Text('${playlist.songs.length} videos', style: const TextStyle(color: Colors.grey)),
                      onTap: () async {
                        final success = await ref
                            .read(youtubePlaylistsProvider.notifier)
                            .addSongToPlaylist(playlist.id, song);

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                success
                                    ? 'Añadido a "${playlist.name}"'
                                    : 'El video ya estaba en "${playlist.name}"',
                              ),
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
        ],
      );
    },
  );
}