import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mymusicproject/data/sources/persistent_image.dart';
import 'package:mymusicproject/presentation/providers/custom_artwork_provider.dart';
import 'package:mymusicproject/presentation/providers/player_provider.dart';
import 'package:mymusicproject/presentation/widgets/app_snack.dart';
import 'package:mymusicproject/presentation/widgets/discard_guard.dart';

import 'package:mymusicproject/presentation/providers/artwork_fit_provider.dart';
import 'package:mymusicproject/presentation/screens/adjust_artwork_screen.dart';
import 'package:mymusicproject/presentation/widgets/song_artwork.dart';

import 'package:mymusicproject/presentation/providers/player_controller.dart';

import 'package:mymusicproject/presentation/image_download.dart';

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

  final initialTitle = titleController.text;
  final initialArtist = artistController.text;
  final initialArtwork = currentArtwork;
  ArtworkFit? currentFit = ref.read(artworkFitProvider)[currentArtwork];
  final initialFit = currentFit;
  bool sameFit(ArtworkFit? a, ArtworkFit? b) =>
      (a ?? const ArtworkFit()) == (b ?? const ArtworkFit());

  bool isDirty() =>
      titleController.text != initialTitle ||
      artistController.text != initialArtist ||
      currentArtwork != initialArtwork ||
      !sameFit(currentFit, initialFit);

  final messenger = ScaffoldMessenger.of(context);

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => DiscardGuard(
      isDirty: isDirty,
      child: StatefulBuilder(
        builder: (context, setStateModal) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
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
                    hasImage: currentArtwork.isNotEmpty,
                    onAdjust: () => _adjustArtwork(
                      context,
                      currentArtwork,
                      currentFit,
                      (f) => setStateModal(() => currentFit = f),
                    ),
                    onImageSelected: (newPathOrUrl) {
                      setStateModal(() {
                        currentArtwork = newPathOrUrl;
                        currentFit = null;
                      });
                      if (newPathOrUrl.isNotEmpty) {
                        _adjustArtwork(
                          context,
                          newPathOrUrl,
                          null,
                          (f) => setStateModal(() => currentFit = f),
                        );
                      }
                    },
                  ),
                  child: _buildArtworkPreview(currentArtwork, currentFit),
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
                const SizedBox(height: 16),
                _buildTextField(controller: artistController, label: 'Artista'),
                const SizedBox(height: 4),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                if (!isDirty() || await confirmDiscard(dialogContext)) {
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                }
              },
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.grey),
              ),
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

                final artworkNotifier = ref.read(
                  customArtworkProvider.notifier,
                );
                if (currentArtwork.isNotEmpty) {
                  await ref
                      .read(artworkFitProvider.notifier)
                      .setFit(currentArtwork, currentFit ?? const ArtworkFit());
                  await ref.read(playerControllerProvider).refreshNowPlaying();
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
              child: const Text(
                'Guardar',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _buildArtworkPreview(String currentArtwork, ArtworkFit? fit) {
  return Stack(
    alignment: Alignment.center,
    children: [
      SongArtwork(
        artworkPathOrUrl: currentArtwork,
        width: 110,
        height: 110,
        borderRadius: 12,
        fitOverride: fit,
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
  String artist, {
  required bool hasImage,
  required VoidCallback onAdjust,
  required Function(String) onImageSelected,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.grey.shade900,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (modalContext) => SafeArea(
      child: Wrap(
        children: [
          if (hasImage)
            ListTile(
              title: const Text(
                'Ajustar posición y zoom',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(modalContext);
                onAdjust();
              },
            ),
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
              if (url == null) {
                if (context.mounted) {
                  context.snack(
                    'No se encontró imagen.',
                    kind: AppSnackKind.warning,
                  );
                }
                return;
              }
              final local = await downloadImageToLocal(url);
              if (local != null) {
                onImageSelected(local);
              } else if (context.mounted) {
                context.snack(
                  'No se pudo descargar la imagen. Revisa tu conexión.',
                  kind: AppSnackKind.error,
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

Future<void> _adjustArtwork(
  BuildContext context,
  String path,
  ArtworkFit? initial,
  void Function(ArtworkFit) onResult,
) async {
  if (path.isEmpty) return;
  final fit = await Navigator.push<ArtworkFit>(
    context,
    MaterialPageRoute(
      builder: (_) => AdjustArtworkScreen(path: path, initial: initial),
    ),
  );
  if (fit != null) onResult(fit);
}
