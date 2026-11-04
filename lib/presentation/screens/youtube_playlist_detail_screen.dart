import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mymusicproject/presentation/providers/youtube_playlist_provider.dart';
import 'package:mymusicproject/presentation/providers/player_provider.dart';
import 'package:mymusicproject/presentation/screens/player_screen.dart';
import 'package:mymusicproject/presentation/providers/custom_artwork_provider.dart';
import 'package:mymusicproject/presentation/widgets/home/home_mini_player.dart';
import 'package:mymusicproject/data/sources/persistent_image.dart';

class YoutubePlaylistDetailScreen extends ConsumerWidget {
  final String playlistId;
  const YoutubePlaylistDetailScreen({super.key, required this.playlistId});

  void _showEditDialog(BuildContext context, WidgetRef ref, YoutubePlaylist playlist) {
  final controller = TextEditingController(text: playlist.name);
  String? newImagePath = playlist.imagePathOrUrl;
  var removeCover = false;

  showDialog(
    context: context,
    builder: (dialogCtx) => StatefulBuilder(
      builder: (context, setStateModal) {
        final hasImage = newImagePath != null && newImagePath!.isNotEmpty;
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('Editar Playlist de YouTube',
              style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () async {
                  final picked =
                      await ImagePicker().pickImage(source: ImageSource.gallery);
                  if (picked != null) {
                    final saved = await persistImage(picked.path);
                    setStateModal(() {
                      newImagePath = saved;
                      removeCover = false;
                    });
                  }
                },
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade800,
                    borderRadius: BorderRadius.circular(12),
                    image: hasImage
                        ? DecorationImage(
                            image: newImagePath!.startsWith('http')
                                ? NetworkImage(newImagePath!) as ImageProvider
                                : FileImage(File(newImagePath!)),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: hasImage
                      ? null
                      : const Icon(Icons.camera_alt,
                          color: Colors.white54, size: 30),
                ),
              ),
              if (hasImage)
                TextButton(
                  onPressed: () => setStateModal(() {
                    newImagePath = null;
                    removeCover = true;
                  }),
                  child: const Text('Quitar portada',
                      style: TextStyle(color: Colors.redAccent, fontSize: 12)),
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
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
              onPressed: () {
                ref.read(youtubePlaylistsProvider.notifier).updatePlaylist(
                      playlist.id,
                      newName: controller.text,
                      newImagePath: removeCover ? null : newImagePath,
                      removeImage: removeCover,
                    );
                Navigator.pop(dialogCtx);
              },
              child: const Text('Guardar', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    ),
  );
}

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(youtubePlaylistsProvider);
    final currentSong = ref.watch(effectiveCurrentSongProvider);
    final playlist = playlists.firstWhere(
      (p) => p.id == playlistId,
      orElse: () => YoutubePlaylist(id: '', name: 'No encontrada', songs: []),
    );

    if (playlist.id.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F0F0F),
        appBar: AppBar(backgroundColor: Colors.transparent),
        body: const Center(child: Text('La playlist ya no existe', style: TextStyle(color: Colors.white))),
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
            onPressed: () => _showEditDialog(context, ref, playlist),
            tooltip: 'Editar nombre o portada',
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.redAccent),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: const Color(0xFF1E1E1E),
                  title: const Text('Eliminar playlist', style: TextStyle(color: Colors.white)),
                  content: Text('¿Deseas eliminar "${playlist.name}"?', style: const TextStyle(color: Colors.white70)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar', style: TextStyle(color: Colors.redAccent))),
                  ],
                ),
              );
              if (confirm == true && context.mounted) {
                await ref.read(youtubePlaylistsProvider.notifier).deletePlaylist(playlist.id);
                if (!context.mounted) return;
                Navigator.pop(context);
              }
            },
            tooltip: 'Eliminar playlist',
          ),
        ],
      ),
      body: playlist.songs.isEmpty
          ? const Center(
              child: Text(
                'Esta playlist está vacía.\nAñade canciones usando la opción del reproductor.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: playlist.songs.length,
              itemBuilder: (context, index) {
                final song = playlist.songs[index];
                return ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      song['thumbnail'] ?? '',
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 48,
                        height: 48,
                        color: Colors.grey.shade800,
                        child: const Icon(Icons.music_note, color: Colors.white54),
                      ),
                    ),
                  ),
                  title: Text(song['title'] ?? '', style: const TextStyle(color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(song['author'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                    onPressed: () {
                      ref.read(youtubePlaylistsProvider.notifier).removeSongFromPlaylist(playlist.id, song['id'] ?? '');
                    },
                  ),
                  onTap: () async {
                    ref.read(currentSongProvider.notifier).state = song;
                    final extractor = ref.read(ytExtractorProvider);
                    final player = ref.read(playerServiceProvider);

                    final data = await extractor.getAudioUrl(song['id'] ?? '');
                    if (data != null && data['url'] != null) {
                      await player.playFromUrl(
                        data['url']!,
                        id: song['id'] ?? '',
                        title: song['title'] ?? '',
                        author: song['author'] ?? '',
                        thumbnailUrl: song['thumbnail'] ?? '',
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