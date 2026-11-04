import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../providers/playlist_provider.dart';
import '../providers/player_provider.dart';
import '../widgets/song_artwork.dart';
import 'player_screen.dart';

import 'package:mymusicproject/presentation/widgets/home/home_mini_player.dart';
import 'package:mymusicproject/presentation/providers/custom_artwork_provider.dart';

import '../providers/player_controller.dart';
import '../providers/local_music_provider.dart';

import 'package:mymusicproject/data/sources/persistent_image.dart';

class PlaylistDetailScreen extends ConsumerWidget {
  final String playlistId;

  const PlaylistDetailScreen({super.key, required this.playlistId});

  void _showEditPlaylistDialog(
    BuildContext context,
    WidgetRef ref,
    Playlist playlist,
  ) {
    final controller = TextEditingController(text: playlist.name);
    String? newImagePath = playlist.imagePathOrUrl;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setStateModal) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text(
            'Editar Playlist',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () async {
                  final picked = await ImagePicker().pickImage(
                    source: ImageSource.gallery,
                  );
                  if (picked != null) {
                    final saved = await persistImage(picked.path);
                    setStateModal(() => newImagePath = saved);
                  }
                },
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade800,
                    borderRadius: BorderRadius.circular(12),
                    image: newImagePath != null && newImagePath!.isNotEmpty
                        ? DecorationImage(
                            image: newImagePath!.startsWith('http')
                                ? NetworkImage(newImagePath!) as ImageProvider
                                : FileImage(File(newImagePath!)),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: newImagePath == null || newImagePath!.isEmpty
                      ? const Icon(
                          Icons.camera_alt,
                          color: Colors.white54,
                          size: 30,
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  labelStyle: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purpleAccent,
              ),
              onPressed: () {
                ref
                    .read(playlistsProvider.notifier)
                    .updatePlaylist(
                      playlist.id,
                      newName: controller.text,
                      newImagePath: newImagePath,
                    );
                Navigator.pop(dialogCtx);
              },
              child: const Text(
                'Guardar',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSong = ref.watch(effectiveCurrentSongProvider);
    final playlists = ref.watch(playlistsProvider);
    final resolved = ref.watch(resolvedPlaylistSongsProvider(playlistId));
    final lib = ref.watch(localSongsProvider);
    final loadingLib = lib.isLoading && !lib.hasValue;
    final playlist = playlists.firstWhere(
      (p) => p.id == playlistId,
      orElse: () => Playlist(id: '', name: 'No encontrada', songs: []),
    );

    if (playlist.id.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F0F0F),
        appBar: AppBar(backgroundColor: Colors.transparent),
        body: const Center(
          child: Text(
            'La playlist ya no existe',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(playlist.name, style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _showEditPlaylistDialog(context, ref, playlist),
            tooltip: 'Editar nombre o portada',
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.redAccent),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: const Color(0xFF1E1E1E),
                  title: const Text(
                    'Eliminar playlist',
                    style: TextStyle(color: Colors.white),
                  ),
                  content: Text(
                    '¿Deseas eliminar "${playlist.name}"?',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancelar'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text(
                        'Eliminar',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  ],
                ),
              );

              if (confirm == true && context.mounted) {
                await ref
                    .read(playlistsProvider.notifier)
                    .deletePlaylist(playlist.id);
                if (!context.mounted) return;
                Navigator.pop(context);
              }
            },
            tooltip: 'Eliminar playlist',
          ),
        ],
      ),
      body: loadingLib
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : resolved.isEmpty
          ? const Center(
              child: Text(
                'Esta playlist está vacía.\nAñade canciones usando la opción del reproductor.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: resolved.length,
              itemBuilder: (context, index) {
                final song = resolved[index];

                return ListTile(
                  leading: buildSongArtwork(
                    artworkPathOrUrl: song['thumbnail'] ?? '',
                    width: 48,
                    height: 48,
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
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.remove_circle_outline,
                      color: Colors.redAccent,
                    ),
                    onPressed: () => ref
                        .read(playlistsProvider.notifier)
                        .removeSongFromPlaylist(playlist.id, song['id']!),
                  ),
                  onTap: () async {
                    await ref
                        .read(playerControllerProvider)
                        .playContext(resolved, song, playlistId: playlist.id);
                    if (context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PlayerScreen()),
                      );
                    }
                  },
                );
              },
            ),
      bottomNavigationBar:
          currentSong != null &&
              currentSong['id'] != null &&
              currentSong['id'].toString().isNotEmpty
          ? HomeMiniPlayer(
              song: Map<String, dynamic>.from(currentSong),
              artwork:
                  ref.watch(customArtworkProvider)[currentSong['id']
                      .toString()] ??
                  currentSong['thumbnail']?.toString(),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PlayerScreen()),
                );
              },
            )
          : null,
    );
  }
}
