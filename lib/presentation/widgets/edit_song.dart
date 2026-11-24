import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mymusicproject/data/sources/persistent_image.dart';
import 'package:mymusicproject/presentation/error_messages.dart';
import 'package:mymusicproject/presentation/image_download.dart';
import 'package:mymusicproject/presentation/providers/artwork_fit_provider.dart';
import 'package:mymusicproject/presentation/providers/custom_artwork_provider.dart';
import 'package:mymusicproject/presentation/providers/player_controller.dart';
import 'package:mymusicproject/presentation/providers/player_provider.dart';
import 'package:mymusicproject/presentation/screens/adjust_artwork_screen.dart';
import 'package:mymusicproject/presentation/widgets/app_scaffold.dart';
import 'package:mymusicproject/presentation/widgets/app_snack.dart';
import 'package:mymusicproject/presentation/widgets/discard_guard.dart';
import 'package:mymusicproject/presentation/widgets/song_artwork.dart';

void showEditSongInfoDialog(
  BuildContext context,
  WidgetRef ref,
  Map<String, dynamic> song,
) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => EditSongScreen(song: song)),
  );
}

class EditSongScreen extends ConsumerStatefulWidget {
  const EditSongScreen({super.key, required this.song});

  final Map<String, dynamic> song;

  @override
  ConsumerState<EditSongScreen> createState() => _EditSongScreenState();
}

class _EditSongScreenState extends ConsumerState<EditSongScreen> {
  late final String _songId = widget.song['id'].toString();
  late final TextEditingController _title;
  late final TextEditingController _artist;
  late String _artwork;
  ArtworkFit? _fit;

  late final String _initialTitle;
  late final String _initialArtist;
  late final String _initialArtwork;
  ArtworkFit? _initialFit;

  bool _busy = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final saved = ref.read(customSongMetadataProvider)[_songId];

    _title = TextEditingController(
      text: saved?.title.isNotEmpty == true
          ? saved!.title
          : (widget.song['title']?.toString() ?? ''),
    );
    _artist = TextEditingController(
      text: saved?.artist.isNotEmpty == true
          ? saved!.artist
          : (widget.song['artist']?.toString() ??
              widget.song['author']?.toString() ??
              ''),
    );

    var art = '';
    for (final v in [
      ref.read(customArtworkProvider)[_songId],
      saved?.artworkPathOrUrl,
    ]) {
      if (v != null && v.isNotEmpty) {
        art = v;
        break;
      }
    }
    _artwork = art;
    _fit = ref.read(artworkFitProvider)[art];

    _initialTitle = _title.text;
    _initialArtist = _artist.text;
    _initialArtwork = _artwork;
    _initialFit = _fit;
  }

  @override
  void dispose() {
    _title.dispose();
    _artist.dispose();
    super.dispose();
  }

  bool get _dirty =>
      _title.text != _initialTitle ||
      _artist.text != _initialArtist ||
      _artwork != _initialArtwork ||
      (_fit ?? const ArtworkFit()) != (_initialFit ?? const ArtworkFit());

  Future<void> _chooseImage() async {
    if (_busy) return;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_artwork.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.crop_outlined),
                title: const Text('Ajustar posición y zoom'),
                onTap: () => Navigator.pop(ctx, 'adjust'),
              ),
            ListTile(
              leading: const Icon(Icons.search),
              title: const Text('Búsqueda automática'),
              onTap: () => Navigator.pop(ctx, 'auto'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir imagen local'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.hide_image_outlined),
              title: const Text('Imagen predeterminada'),
              onTap: () => Navigator.pop(ctx, 'none'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;

    switch (choice) {
      case 'adjust':
        await _adjust();
      case 'auto':
        await _pick(_searchAutomatically);
      case 'gallery':
        await _pick(_pickFromGallery);
      case 'none':
        setState(() {
          _artwork = '';
          _fit = null;
        });
    }
  }

  Future<String?> _searchAutomatically() async {
    final url = await ref
        .read(ytExtractorProvider)
        .searchThumbnailForSong(_title.text, _artist.text);
    if (!mounted) return null;
    if (url == null) {
      context.snack('No se encontró imagen.', kind: AppSnackKind.warning);
      return null;
    }
    final local = await downloadImageToLocal(url);
    if (!mounted) return null;
    if (local == null) {
      context.snack(
        'No se pudo descargar la imagen. Revisa tu conexión.',
        kind: AppSnackKind.error,
      );
    }
    return local;
  }

  Future<String?> _pickFromGallery() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null) return null;
    return persistImage(file.path, folder: 'artworks');
  }

  Future<void> _pick(Future<String?> Function() task) async {
    setState(() => _busy = true);
    String? picked;
    try {
      picked = await task();
    } catch (e, st) {
      logError('Imagen de portada', e, st);
      if (mounted) {
        context.snack(
          friendlyError(e, what: 'No se pudo cargar la imagen'),
          kind: AppSnackKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }

    final path = picked;
    if (!mounted || path == null) return;
    setState(() {
      _artwork = path;
      _fit = null;
    });
    await _adjust();
  }

  Future<void> _adjust() async {
    if (_artwork.isEmpty) return;
    final navigator = Navigator.of(context);
    final fit = await navigator.push<ArtworkFit>(
      MaterialPageRoute(
        builder: (_) => AdjustArtworkScreen(path: _artwork, initial: _fit),
      ),
    );
    if (fit != null && mounted) setState(() => _fit = fit);
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final latest = ref.read(customSongMetadataProvider)[_songId];
      final base = latest ??
          SongMetaData(
            title: '',
            artist: '',
            artworkPathOrUrl: '',
            lyrics: '',
          );
      final newMeta = base.copyWith(
        title: _title.text.trim(),
        artist: _artist.text.trim(),
        artworkPathOrUrl: _artwork,
      );
      await ref
          .read(customSongMetadataProvider.notifier)
          .saveMetadata(_songId, newMeta);

      final artworkNotifier = ref.read(customArtworkProvider.notifier);
      if (_artwork.isEmpty) {
        await artworkNotifier.removeArtwork(_songId);
      } else {
        await artworkNotifier.setArtwork(_songId, _artwork);
        await ref
            .read(artworkFitProvider.notifier)
            .setFit(_artwork, _fit ?? const ArtworkFit());
      }
      await ref.read(playerControllerProvider).refreshNowPlaying();

      navigator.pop();
      showAppSnack(
        messenger,
        'Información guardada',
        kind: AppSnackKind.success,
      );
    } catch (e, st) {
      logError('Guardar canción', e, st);
      if (mounted) {
        setState(() => _saving = false);
        context.snack(
          friendlyError(e, what: 'No se pudo guardar'),
          kind: AppSnackKind.error,
        );
      }
    }
  }

  Widget _field(TextEditingController c, String label) {
    return TextField(
      controller: c,
      onChanged: (_) => setState(() {}),
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey.shade700),
          borderRadius: BorderRadius.circular(10),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DiscardGuard(
      isDirty: () => _dirty,
      child: AppScaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('Editar música'),
          actions: [
            TextButton(
              onPressed: (_dirty && !_saving && !_busy) ? _save : null,
              child: const Text('Guardar'),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Center(
              child: GestureDetector(
                onTap: _busy ? null : _chooseImage,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SongArtwork(
                      artworkPathOrUrl: _artwork,
                      width: 140,
                      height: 140,
                      borderRadius: 14,
                      fitOverride: _fit,
                    ),
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: _busy
                          ? const Padding(
                              padding: EdgeInsets.all(52),
                              child: CircularProgressIndicator(strokeWidth: 3),
                            )
                          : const Icon(
                              Icons.camera_alt,
                              color: Colors.white70,
                              size: 32,
                            ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Toca la imagen para cambiarla.',
                style: TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ),
            const SizedBox(height: 24),
            _field(_title, 'Nombre de la canción'),
            const SizedBox(height: 16),
            _field(_artist, 'Artista'),
          ],
        ),
      ),
    );
  }
}