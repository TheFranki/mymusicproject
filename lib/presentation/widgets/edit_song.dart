import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mymusicproject/data/sources/persistent_image.dart';
import 'package:mymusicproject/presentation/providers/custom_artwork_provider.dart';
import 'package:mymusicproject/presentation/providers/player_provider.dart';

void showEditSongInfoDialog(
  BuildContext context,
  WidgetRef ref,
  Map<String, dynamic> song,
) {
  final songId = song['id'].toString();
  final currentSaved = ref.read(customSongMetadataProvider)[songId];

  final titleController = TextEditingController(
    text: currentSaved?.title.isNotEmpty == true
        ? currentSaved!.title
        : (song['title']?.toString() ?? ''),
  );
  final artistController = TextEditingController(
    text: currentSaved?.artist.isNotEmpty == true
        ? currentSaved!.artist
        : (song['artist']?.toString() ?? ''),
  );

  String currentArtwork = '';
  for (final v in [
    ref.read(customArtworkProvider)[songId],
    currentSaved?.artworkPathOrUrl,
  ]) {
    if (v != null && v.isNotEmpty) {
      currentArtwork = v;
      break;
    }
  }

  final messenger = ScaffoldMessenger.of(context);

  showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setStateModal) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Editar Música',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () => _showImageOptionsBottomSheet(
                  context,
                  ref,
                  titleController.text,
                  artistController.text,
                  (newPathOrUrl) =>
                      setStateModal(() => currentArtwork = newPathOrUrl),
                ),
                child: _buildArtworkPreview(currentArtwork),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tocar la imagen para cambiarla.',
                style: TextStyle(color: Colors.grey, fontSize: 11),
              ),
              const SizedBox(height: 20),
              _buildTextField(
                controller: titleController,
                label: 'Nombre de la canción',
              ),
              const SizedBox(height: 14),
              _buildTextField(controller: artistController, label: 'Artista'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              final latest = ref.read(customSongMetadataProvider)[songId];
              final base =
                  latest ??
                  SongMetaData(
                    title: '',
                    artist: '',
                    artworkPathOrUrl: '',
                    lyrics: '',
                  );

              final newMeta = base.copyWith(
                title: titleController.text.trim(),
                artist: artistController.text.trim(),
                artworkPathOrUrl: currentArtwork,
              );

              await ref
                  .read(customSongMetadataProvider.notifier)
                  .saveMetadata(songId, newMeta);

              final artworkNotifier = ref.read(customArtworkProvider.notifier);
              if (currentArtwork.isEmpty) {
                await artworkNotifier.removeArtwork(songId);
              } else {
                await artworkNotifier.setArtwork(songId, currentArtwork);
              }

              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Información guardada correctamente'),
                ),
              );
            },
            child: const Text('Guardar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ),
  );
}

Widget _buildArtworkPreview(String currentArtwork) {
  return Stack(
    alignment: Alignment.center,
    children: [
      Container(
        width: 110,
        height: 110,
        decoration: BoxDecoration(
          color: Colors.grey.shade800,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: currentArtwork.isNotEmpty
              ? (currentArtwork.startsWith('http')
                    ? Image.network(
                        currentArtwork,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.music_note,
                          color: Colors.white54,
                          size: 50,
                        ),
                      )
                    : Image.file(
                        File(currentArtwork),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.music_note,
                          color: Colors.white54,
                          size: 50,
                        ),
                      ))
              : const Icon(Icons.music_note, color: Colors.white54, size: 50),
        ),
      ),
      Container(
        width: 110,
        height: 110,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.camera_alt, color: Colors.white70, size: 30),
      ),
    ],
  );
}

Widget _buildTextField({
  required TextEditingController controller,
  required String label,
  int maxLines = 1,
  double fontSize = 14,
}) {
  return TextField(
    controller: controller,
    maxLines: maxLines,
    style: TextStyle(color: Colors.white, fontSize: fontSize),
    decoration: InputDecoration(
      labelText: label,
      alignLabelWithHint: maxLines > 1,
      labelStyle: const TextStyle(color: Colors.grey),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.grey.shade700),
        borderRadius: BorderRadius.circular(10),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.blueAccent),
        borderRadius: BorderRadius.circular(10),
      ),
    ),
  );
}

void _showImageOptionsBottomSheet(
  BuildContext context,
  WidgetRef ref,
  String title,
  String artist,
  Function(String) onImageSelected,
) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.grey.shade900,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (modalContext) => SafeArea(
      child: Wrap(
        children: [
          ListTile(
            title: const Text(
              'Búsqueda automática',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () async {
              Navigator.pop(modalContext);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Buscando imagen...')),
              );
              final url = await ref
                  .read(ytExtractorProvider)
                  .searchThumbnailForSong(title, artist);
              if (url != null) {
                onImageSelected(url);
              } else if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('No se encontró imagen.'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),
          ListTile(
            title: const Text(
              'Elegir imagen local',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () async {
              Navigator.pop(modalContext);
              final pickedFile = await ImagePicker().pickImage(
                source: ImageSource.gallery,
              );
              if (pickedFile != null) {
                final saved = await persistImage(
                  pickedFile.path,
                  folder: 'artworks',
                );
                onImageSelected(saved);
              }
            },
          ),
          ListTile(
            title: const Text(
              'Imagen Predeterminada',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () {
              Navigator.pop(modalContext);
              onImageSelected('');
            },
          ),
        ],
      ),
    ),
  );
}