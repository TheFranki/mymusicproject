import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mymusicproject/presentation/providers/youtube_playlist_provider.dart';

import 'youtube_playlist_detail_screen.dart';

import 'package:mymusicproject/presentation/providers/player_provider.dart';
import 'package:mymusicproject/presentation/providers/custom_artwork_provider.dart';
import 'package:mymusicproject/presentation/widgets/home/home_mini_player.dart';
import 'package:mymusicproject/presentation/screens/player_screen.dart';
import 'package:mymusicproject/data/sources/persistent_image.dart';

class YoutubePlaylistsScreen extends ConsumerWidget {
  const YoutubePlaylistsScreen({super.key});

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    String? selectedImagePath;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setStateModal) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text(
            'Crear Playlist de YouTube',
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
                    setStateModal(() => selectedImagePath = saved);
                  }
                },
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade800,
                    borderRadius: BorderRadius.circular(12),
                    image: selectedImagePath != null
                        ? DecorationImage(
                            image: FileImage(File(selectedImagePath!)),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: selectedImagePath == null
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_a_photo,
                              color: Colors.white54,
                              size: 28,
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Portada',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Nombre de la playlist',
                  labelStyle: const TextStyle(color: Colors.grey),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey.shade700),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.blueAccent),
                    borderRadius: BorderRadius.circular(8),
                  ),
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
                backgroundColor: Colors.blueAccent,
              ),
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  ref
                      .read(youtubePlaylistsProvider.notifier)
                      .createPlaylist(
                        controller.text,
                        imagePathOrUrl: selectedImagePath,
                      );
                  Navigator.pop(dialogCtx);
                }
              },
              child: const Text('Crear', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(youtubePlaylistsProvider);
    final currentSong = ref.watch(effectiveCurrentSongProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Playlists de YouTube',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton.icon(
            onPressed: () => _showCreateDialog(context, ref),
            icon: const Icon(Icons.add, color: Colors.blueAccent, size: 20),
            label: const Text(
              'Nueva',
              style: TextStyle(color: Colors.blueAccent),
            ),
          ),
        ],
      ),
      body: playlists.isEmpty
    ? const Center(
        child: Text(
          'No tienes playlists de YouTube creadas.\nToca "Nueva" para crear una.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 15),
        ),
      )
    : GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.85,
        ),
        itemCount: playlists.length,
        itemBuilder: (context, index) {
          final playlist = playlists[index];
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => YoutubePlaylistDetailScreen(
                    playlistId: playlist.id,
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: (playlist.imagePathOrUrl != null && 
                            playlist.imagePathOrUrl!.isNotEmpty)
                          ? Image.file(
                              File(playlist.imagePathOrUrl!),
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const _YtFolderPlaceholder(),
                            )
                          : const _YtFolderPlaceholder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    playlist.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${playlist.songs.length} videos',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
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
class _YtFolderPlaceholder extends StatelessWidget {
  const _YtFolderPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.grey.shade800,
      child: const Center(
        child: Icon(Icons.folder_special, size: 48, color: Colors.blueAccent),
      ),
    );
  }
}
