import 'dart:math' show max;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mymusicproject/presentation/providers/player_controller.dart';
import 'package:mymusicproject/presentation/providers/player_provider.dart';
import 'package:mymusicproject/presentation/widgets/app_snack.dart';
import 'package:mymusicproject/presentation/widgets/player/lrc_parser.dart';
import 'package:mymusicproject/presentation/widgets/player/lyrics_dialogs.dart';
import 'package:mymusicproject/presentation/widgets/player/lyrics_search_service.dart';
import 'package:mymusicproject/presentation/widgets/player/lyrics_sheets.dart';
import 'package:mymusicproject/presentation/widgets/player/lyrics_sync_dialog.dart';

const int _reactionMs = 250;

mixin LyricsActionsMixin<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  String get lyricsSongId;
  String get lyricsTitle;
  String get lyricsArtist;
  String get lyricsArtwork;
  int get lyricsOffset;
  Map<int, int> get lyricsAnchors;
  int get lyricsLineCount;

  void resetSubtitles();

  bool isSearchingLyrics = false;
  Duration? touchPos;

  SongMetaData baseMeta() =>
      ref.read(customSongMetadataProvider)[lyricsSongId] ??
      SongMetaData(
        title: lyricsTitle,
        artist: lyricsArtist,
        artworkPathOrUrl: lyricsArtwork,
        lyrics: '',
      );

  int? _songDurationSec() =>
      ref.read(playerServiceProvider).player.duration?.inSeconds;

  Future<void> _saveMeta(SongMetaData meta) => ref
      .read(customSongMetadataProvider.notifier)
      .saveMetadata(lyricsSongId, meta);

  Future<void> saveLyrics(String lyrics, {String? query}) => _saveMeta(
    baseMeta().copyWith(
      lyrics: lyrics,
      lyricsOffsetMs: 0,
      lyricsQuery: query,
      lyricsAnchors: const {},
    ),
  );

  Future<void> changeOffset(int ms) {
    final clamped = ms.clamp(-60000, 60000).toInt();
    return _saveMeta(baseMeta().copyWith(lyricsOffsetMs: clamped));
  }

  Future<void> _saveAnchors(Map<int, int> anchors) =>
      _saveMeta(baseMeta().copyWith(lyricsAnchors: anchors));

  Future<void> onLineLongPress(int index) async {
    if (lyricsAnchors.containsKey(index)) {
      touchPos = null;
      showAnchorSheet(
        context,
        onRefix: () => _setAnchor(index),
        onRemove: () => _removeAnchor(index),
      );
    } else {
      await _setAnchor(index);
    }
  }

  Future<void> _setAnchor(int index) async {
    if (index < 0 || index >= lyricsLineCount) return;
    final messenger = ScaffoldMessenger.of(context);
    final anchors = lyricsAnchors;
    final pos = touchPos ?? ref.read(playerServiceProvider).player.position;
    final target = max(0, pos.inMilliseconds - lyricsOffset - _reactionMs);

    int? prevKey, nextKey;
    for (final k in anchors.keys) {
      if (k < index && (prevKey == null || k > prevKey)) prevKey = k;
      if (k > index && (nextKey == null || k < nextKey)) nextKey = k;
    }
    final prevT = prevKey == null ? null : anchors[prevKey];
    final nextT = nextKey == null ? null : anchors[nextKey];
    if ((prevT != null && target <= prevT) ||
        (nextT != null && target >= nextT)) {
      showAppSnack(
        messenger,
        'No se pudo: esa línea quedaría fuera de orden respecto a otra ya '
        'fijada. Quita o mueve esa ancla primero.',
        color: Colors.red,
        duration: const Duration(seconds: 5),
      );
      return;
    }

    final previous = Map<int, int>.of(anchors);
    final next = {...anchors, index: target};
    await _saveAnchors(next);
    showAppSnack(
      messenger,
      'Ancla fijada (${next.length} en total)',
      actionLabel: 'Deshacer',
      onAction: () => _saveAnchors(previous),
      duration: const Duration(seconds: 4),
    );
  }

  Future<void> _removeAnchor(int index) async {
    final messenger = ScaffoldMessenger.of(context);
    final previous = Map<int, int>.of(lyricsAnchors);
    final next = Map<int, int>.of(lyricsAnchors)..remove(index);
    await _saveAnchors(next);
    showAppSnack(
      messenger,
      'Ancla quitada',
      actionLabel: 'Deshacer',
      onAction: () => _saveAnchors(previous),
      duration: const Duration(seconds: 4),
    );
  }

  Future<void> clearAnchors() async {
    if (lyricsAnchors.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final previous = Map<int, int>.of(lyricsAnchors);
    await _saveAnchors(const {});
    showAppSnack(
      messenger,
      'Anclas quitadas',
      actionLabel: 'Deshacer',
      onAction: () => _saveAnchors(previous),
      duration: const Duration(seconds: 4),
    );
  }

  void showSyncDialog() => showLyricsSyncDialog(
    context,
    songId: lyricsSongId,
    onChangeOffset: changeOffset,
    onEditLyrics: editLyrics,
    onClearAnchors: clearAnchors,
  );

  Future<void> editLyrics() async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final previous = baseMeta();
    final current = previous.lyrics;

    final edited = await showEditLyricsDialog(
      context,
      initial: current,
      currentPosition: () {
        final p =
            ref.read(playerServiceProvider).player.position -
            Duration(milliseconds: lyricsOffset);
        return p.isNegative ? Duration.zero : p;
      },
    );
    if (edited == null || edited.isEmpty || edited == current.trim()) return;
    final sameShape = parseLrc(edited).length == parseLrc(current).length;
    await _saveMeta(
      previous.copyWith(
        lyrics: edited,
        lyricsAnchors: sameShape ? previous.lyricsAnchors : const {},
      ),
    );
    showAppSnack(
      messenger,
      'Letra actualizada',
      actionLabel: 'Deshacer',
      onAction: () => _saveMeta(previous),
      duration: const Duration(seconds: 4),
    );
  }

  Future<void> deleteLyrics() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Borrar letra',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: const Text(
          'Se quitará la letra de esta canción.\n Podrás buscarla de nuevo '
          'desde la lupa.',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Borrar',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final previous = baseMeta();
    final messenger = ScaffoldMessenger.of(context);

    resetSubtitles();
    await _saveMeta(
      previous.copyWith(
        lyrics: '',
        lyricsOffsetMs: 0,
        lyricsAnchors: const {},
      ),
    );

    showAppSnack(
      messenger,
      'Letra borrada',
      actionLabel: 'Deshacer',
      onAction: () => _saveMeta(previous),
      duration: const Duration(seconds: 4),
    );
  }

  List<String> _searchTitles() {
    final meta = ref.read(customSongMetadataProvider)[lyricsSongId];
    final lib = ref.read(libraryByIdProvider)[lyricsSongId];
    final out = <String>[];
    void add(String? s) {
      final t = s?.trim() ?? '';
      if (t.isNotEmpty && !out.contains(t)) out.add(t);
    }

    add(meta?.lyricsQuery);
    add(lib?['title']?.toString());
    add(lyricsTitle);
    return out;
  }

  List<String> _searchArtists() {
    final lib = ref.read(libraryByIdProvider)[lyricsSongId];
    final out = <String>[];
    void add(String? s) {
      final t = s?.trim() ?? '';
      if (t.isNotEmpty && !out.contains(t)) out.add(t);
    }

    add(lyricsArtist);
    add(lib?['artist']?.toString());
    add(lib?['author']?.toString());
    return out;
  }

  String _defaultQuery() {
    final meta = ref.read(customSongMetadataProvider)[lyricsSongId];
    if (meta?.lyricsQuery.isNotEmpty == true) return meta!.lyricsQuery;
    final a = lyricsArtist.trim().toLowerCase();
    final unknown =
        a.isEmpty || a.contains('desconocido') || a.contains('unknown');
    return unknown ? lyricsTitle : '$lyricsArtist $lyricsTitle';
  }

  Future<void> fetchLyricsAutomatically() async {
    if (isSearchingLyrics) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => isSearchingLyrics = true);

    try {
      final service = ref.read(lyricsSearchProvider);
      final results = await service.search(
        titles: _searchTitles(),
        artists: _searchArtists(),
        durationSec: _songDurationSec(),
        earlyStop: true,
      );
      final best = service.pickConfident(results);

      if (best == null) {
        showAppSnack(
          messenger,
          results.isEmpty
              ? 'No se encontró la letra'
              : 'No hay una coincidencia segura. Elige una a mano.',
          color: Colors.red,
          actionLabel: 'Elegir',
          onAction: openLyricsPicker,
          duration: const Duration(seconds: 6),
        );
        return;
      }

      await saveLyrics(best.lyrics, query: best.track);

      final q = best.quality;
      if (!best.hasSynced) {
        showAppSnack(
          messenger,
          'Letra encontrada, pero sin sincronizar',
          actionLabel: 'Elegir otra',
          onAction: openLyricsPicker,
          duration: const Duration(seconds: 6),
        );
      } else if (q != null && !q.isGood) {
        showAppSnack(
          messenger,
          'Letra encontrada, pero puede estar mal sincronizada (${q.summary})',
          actionLabel: 'Elegir otra',
          onAction: openLyricsPicker,
          duration: const Duration(seconds: 6),
        );
      } else {
        showAppSnack(messenger, 'Letra encontrada y sincronizada');
      }
    } on LyricsNetworkError {
      showAppSnack(
        messenger,
        'No se pudo conectar con el servidor de letras. Intenta de nuevo.',
        color: Colors.red,
      );
    } catch (e) {
      showAppSnack(
        messenger,
        'Error al buscar la letra: $e',
        color: Colors.red,
      );
    } finally {
      if (mounted) setState(() => isSearchingLyrics = false);
    }
  }

  Future<void> openLyricsPicker() async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);

    final picked = await showLyricsPicker(
      context,
      service: ref.read(lyricsSearchProvider),
      initialQuery: _defaultQuery(),
      titles: _searchTitles(),
      artists: _searchArtists(),
      durationSec: _songDurationSec(),
    );
    if (picked == null || !mounted) return;

    await saveLyrics(picked.lyrics, query: picked.track);
    showAppSnack(
      messenger,
      picked.hasSynced
          ? 'Letra guardada y sincronizada'
          : 'Letra guardada, pero sin sincronizar',
    );
  }

  Future<void> pasteLyrics() async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final text = await showPasteLyricsDialog(context);
    if (text == null || !mounted) return;

    final r = lyricsFromPastedText(text, durationSec: _songDurationSec());
    if (r == null) {
      showAppSnack(messenger, 'No hay texto para guardar', color: Colors.red);
      return;
    }

    await saveLyrics(r.text);
    showAppSnack(
      messenger,
      r.approximate
          ? 'Letra agregada con sincronización aproximada. Mantén presionada '
                'la línea donde empieza la voz para ajustarla.'
          : r.timed
          ? 'Letra con tiempos agregada'
          : 'Letra agregada sin sincronizar',
      duration: Duration(seconds: r.approximate ? 7 : 3),
    );
  }

  void showManualSheet() => showManualLyricsSheet(
    context,
    onSearch: openLyricsPicker,
    onPaste: pasteLyrics,
  );
}