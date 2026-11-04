import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mymusicproject/presentation/widgets/song_artwork.dart';
import 'package:mymusicproject/presentation/providers/player_provider.dart';
import 'package:mymusicproject/presentation/widgets/player/lrc_parser.dart';
import 'package:mymusicproject/presentation/widgets/player/lyrics_translation_service.dart';

class FlippableArtworkView extends ConsumerStatefulWidget {
  final String songId;
  final String artwork;
  final String title;
  final String artist;

  const FlippableArtworkView({
    super.key,
    required this.songId,
    required this.artwork,
    required this.title,
    required this.artist,
  });

  @override
  ConsumerState<FlippableArtworkView> createState() =>
      _FlippableArtworkViewState();
}

class _FlippableArtworkViewState extends ConsumerState<FlippableArtworkView>
    with SingleTickerProviderStateMixin {
  static const double _lineExtent = 55.0;

  late final AnimationController _controller;
  late final Animation<double> _animation;
  bool _isFlipped = false;
  bool _isSearchingLyrics = false;
  bool _needsInitialScroll = true;
  int _offsetMs = 0;
  bool _songChanged = false;

  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<int> _activeIndex = ValueNotifier<int>(-1);

  String _parsedSource = '';
  List<LyricLine> _parsedLines = const [];

  final LyricsTranslationService _translator = LyricsTranslationService();
  String _subMode = 'off';
  List<String> _subLines = const [];
  bool _isTranslating = false;
  final Map<int, GlobalKey> _lineKeys = {};

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(covariant FlippableArtworkView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.songId != widget.songId) {
      _songChanged = true;
      _parsedSource = '\u0000';
      _parsedLines = const [];
      _offsetMs = 0;
      _subMode = 'off';
      _subLines = const [];
      _isTranslating = false;
      _lineKeys.clear();
      _needsInitialScroll = true;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _activeIndex.dispose();
    super.dispose();
  }

  void _toggleFlip() {
    setState(() {
      _isFlipped = !_isFlipped;
      _needsInitialScroll = true;
      _isFlipped ? _controller.forward() : _controller.reverse();
    });
  }

  List<LyricLine> _linesFor(String raw) {
    if (raw != _parsedSource) {
      _parsedSource = raw;
      _parsedLines = raw.isEmpty ? const [] : parseLrc(raw);
      _subLines = const [];
      _lineKeys.clear();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _needsInitialScroll = true;
        if (_scrollController.hasClients) _scrollController.jumpTo(0);
        final pos = _songChanged
            ? Duration.zero
            : ref.read(playerServiceProvider).player.position;
        _songChanged = false;

        final idx = _parsedLines.isEmpty ? -1 : _indexFor(pos);
        _activeIndex.value = idx;
        if (idx >= 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _scrollToIndex(idx, animate: false);
          });
        }

        if (_subMode != 'off' && raw.isNotEmpty) _setSubMode(_subMode);
      });
    }
    return _parsedLines;
  }

  List<String> _sourceTexts() {
    if (_parsedLines.isNotEmpty) {
      return _parsedLines.map((l) => l.text).toList();
    }
    return _parsedSource.split('\n');
  }

  int _indexFor(Duration pos) {
    final adj = pos - Duration(milliseconds: _offsetMs);
    var lo = 0, hi = _parsedLines.length - 1, ans = -1;
    while (lo <= hi) {
      final mid = (lo + hi) ~/ 2;
      if (_parsedLines[mid].timestamp <= adj) {
        ans = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return ans;
  }

  void _updateActive(Duration pos) {
    final i = _indexFor(pos);
    if (i == _activeIndex.value) return;
    _activeIndex.value = i;
    if (i >= 0) {
      _scrollToIndex(i);
    } else if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  void _scrollToIndex(int i, {bool animate = true}) {
    if (!_scrollController.hasClients) return;
    final duration = animate
        ? const Duration(milliseconds: 350)
        : Duration.zero;

    void center() {
      final ctx = _lineKeys[i]?.currentContext;
      if (ctx != null && ctx.mounted) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.5,
          duration: duration,
          curve: Curves.easeInOut,
        );
      }
    }

    if (_lineKeys[i]?.currentContext != null) {
      center();
      return;
    }

    final est = (i * _lineExtent)
        .clamp(0.0, _scrollController.position.maxScrollExtent)
        .toDouble();
    _scrollController.jumpTo(est);
    WidgetsBinding.instance.addPostFrameCallback((_) => center());
  }

  Future<void> _setSubMode(String mode) async {
    if (mode == 'off') {
      setState(() {
        _subMode = 'off';
        _subLines = const [];
        _isTranslating = false;
      });
      return;
    }

    final texts = _sourceTexts();
    if (texts.every((t) => t.trim().isEmpty)) return;

    setState(() {
      _subMode = mode;
      _subLines = const [];
      _isTranslating = true;
    });

    try {
      final from = LyricsTranslationService.detectScript(texts.join(' '));
      final result = mode == 'rom'
          ? await _translator.romanize(texts, from: from)
          : await _translator.translate(texts, mode.substring(3), from: from);

      if (!mounted || _subMode != mode) return;
      setState(() {
        _subLines = result;
        _isTranslating = false;
      });
    } catch (e) {
      if (!mounted || _subMode != mode) return;
      setState(() {
        _subMode = 'off';
        _subLines = const [];
        _isTranslating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo traducir: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  SongMetaData _baseMeta() =>
      ref.read(customSongMetadataProvider)[widget.songId] ??
      SongMetaData(
        title: widget.title,
        artist: widget.artist,
        artworkPathOrUrl: widget.artwork,
        lyrics: '',
      );

  Future<void> _changeOffset(int ms) async {
    final clamped = ms.clamp(-60000, 60000).toInt();
    await ref
        .read(customSongMetadataProvider.notifier)
        .saveMetadata(
          widget.songId,
          _baseMeta().copyWith(lyricsOffsetMs: clamped),
        );
  }

  static const int _reactionMs = 250;
  Future<void> _syncToLine(int index) async {
    if (index < 0 || index >= _parsedLines.length) return;
    final pos = ref.read(playerServiceProvider).player.position;
    final newOffset =
        (pos - _parsedLines[index].timestamp).inMilliseconds - _reactionMs;
    final previous = _offsetMs;
    final messenger = ScaffoldMessenger.of(context);

    await _changeOffset(newOffset);

    messenger.showSnackBar(
      SnackBar(
        content: const Text('Letra sincronizada con esta línea'),
        action: SnackBarAction(
          label: 'Deshacer',
          onPressed: () => _changeOffset(previous),
        ),
      ),
    );
  }

  void _showSyncDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => Consumer(
        builder: (context, dialogRef, _) {
          final offset = dialogRef.watch(
            customSongMetadataProvider.select(
              (m) => m[widget.songId]?.lyricsOffsetMs ?? 0,
            ),
          );

          Widget btn(String label, int delta) => OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.grey.shade700),
            ),
            onPressed: () => _changeOffset(offset + delta),
            child: Text(label),
          );

          final sign = offset > 0 ? '+' : '';
          return AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Ajustar sincronización',
              style: TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Forma rápida: mantén presionando la letra con el inicio de la voz.'
                  'Ajuste fino: si va adelantada sube el valor (+), si va atrasada bájalo (−).',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                Text(
                  '$sign${(offset / 1000).toStringAsFixed(1)} s',
                  style: const TextStyle(
                    color: Colors.blueAccent,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    btn('−5', -5000),
                    btn('−1', -1000),
                    btn('−0.1', -100),
                    btn('+0.1', 100),
                    btn('+1', 1000),
                    btn('+5', 5000),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => _changeOffset(0),
                child: const Text(
                  'Restablecer',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Listo'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteLyrics() async {
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

    final previous = _baseMeta();
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(customSongMetadataProvider.notifier);

    setState(() {
      _subMode = 'off';
      _subLines = const [];
      _isTranslating = false;
    });
    await notifier.saveMetadata(
      widget.songId,
      previous.copyWith(lyrics: '', lyricsOffsetMs: 0),
    );

    messenger.showSnackBar(
      SnackBar(
        content: const Text('Letra borrada'),
        action: SnackBarAction(
          label: 'Deshacer',
          onPressed: () => notifier.saveMetadata(widget.songId, previous),
        ),
      ),
    );
  }

  Future<void> _fetchLyricsAutomatically({String? customQuery}) async {
    setState(() => _isSearchingLyrics = true);

    try {
      final extractor = ref.read(ytExtractorProvider);
      final durationSec = ref
          .read(playerServiceProvider)
          .player
          .duration
          ?.inSeconds;

      final fetchedLyrics = await extractor.searchLyricsForSong(
        widget.title,
        widget.artist,
        customQuery: customQuery,
        durationSec: durationSec,
      );

      if (fetchedLyrics != null && fetchedLyrics.isNotEmpty) {
        final updatedMeta = _baseMeta().copyWith(
          lyrics: fetchedLyrics,
          lyricsOffsetMs: 0,
        );

        await ref
            .read(customSongMetadataProvider.notifier)
            .saveMetadata(widget.songId, updatedMeta);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Letra encontrada y sincronizada con éxito!'),
            ),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se encontró la letra con esa consulta'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al buscar la letra: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSearchingLyrics = false);
    }
  }

  void _showCustomSearchDialog() {
    final artistText =
        (widget.artist.trim().isEmpty ||
            widget.artist.toLowerCase().contains('desconocido') ||
            widget.artist.toLowerCase().contains('unknown'))
        ? ''
        : '${widget.artist} ';
    final controller = TextEditingController(
      text: '$artistText${widget.title}',
    );

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Buscar letra por nombre',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Escribir el nombre exacto:',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Artista y Título',
                hintStyle: const TextStyle(color: Colors.grey),
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
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            onPressed: () {
              final query = controller.text.trim();
              Navigator.pop(dialogContext);
              if (query.isNotEmpty) {
                _fetchLyricsAutomatically(customQuery: query);
              }
            },
            child: const Text('Buscar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rawLyrics = ref.watch(
      customSongMetadataProvider.select((m) => m[widget.songId]?.lyrics ?? ''),
    );
    final lines = _linesFor(rawLyrics);
    final offsetMs = ref.watch(
      customSongMetadataProvider.select(
        (m) => m[widget.songId]?.lyricsOffsetMs ?? 0,
      ),
    );
    if (offsetMs != _offsetMs) {
      _offsetMs = offsetMs;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final pos = ref.read(positionProvider).value;
        if (pos != null && _parsedLines.isNotEmpty) _updateActive(pos);
      });
    }

    ref.listen(positionProvider, (_, next) {
      final pos = next.value;
      if (pos != null && _parsedLines.isNotEmpty) _updateActive(pos);
    });

    return GestureDetector(
      onTap: _toggleFlip,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final angle = _animation.value * pi;
          final isBackVisible = angle >= pi / 2;

          return Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            alignment: Alignment.center,
            child: isBackVisible
                ? Transform(
                    transform: Matrix4.identity()..rotateY(pi),
                    alignment: Alignment.center,
                    child: _buildLyricsBack(rawLyrics, lines),
                  )
                : _buildArtworkFront(),
          );
        },
      ),
    );
  }

  Widget _buildArtworkFront() {
    return Container(
      width: 400,
      height: 350,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: buildSongArtwork(
          artworkPathOrUrl: widget.artwork,
          width: 400,
          height: 350,
          borderRadius: 12,
        ),
      ),
    );
  }

  Widget _buildSearchMenu({required bool hasLyrics, required bool isSynced}) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.search, color: Colors.white, size: 24),
      tooltip: 'Letra',
      color: const Color(0xFF2A2A2A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) {
        switch (value) {
          case 'auto':
            _fetchLyricsAutomatically();
          case 'manual':
            _showCustomSearchDialog();
          case 'sync':
            _showSyncDialog();
          case 'delete':
            _deleteLyrics();
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'auto',
          child: Text('Automática', style: TextStyle(color: Colors.white)),
        ),
        const PopupMenuItem(
          value: 'manual',
          child: Text('Por nombre', style: TextStyle(color: Colors.white)),
        ),
        if (isSynced)
          const PopupMenuItem(
            value: 'sync',
            child: Text(
              'Ajustar sincronización',
              style: TextStyle(color: Colors.white),
            ),
          ),
        if (hasLyrics) ...[
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'delete',
            child: Text('Borrar letra', style: TextStyle(color: Colors.white)),
          ),
        ],
      ],
    );
  }

  PopupMenuItem<String> _subMenuItem(String value, String label) {
    final selected = _subMode == value;
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(
            selected ? Icons.check : Icons.circle_outlined,
            color: selected ? Colors.blueAccent : Colors.white24,
            size: 16,
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: selected ? Colors.blueAccent : Colors.white,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTranslateMenu() {
    final from = LyricsTranslationService.detectScript(_parsedSource);
    final canRomanize = from != 'auto';

    return PopupMenuButton<String>(
      icon: Icon(
        Icons.translate,
        color: _subMode == 'off' ? Colors.white : Colors.blueAccent,
        size: 22,
      ),
      tooltip: 'Traducción / romanización',
      color: const Color(0xFF2A2A2A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: _setSubMode,
      itemBuilder: (_) => [
        _subMenuItem('off', 'Solo original'),
        if (canRomanize)
          _subMenuItem('rom', LyricsTranslationService.romanizationLabel(from)),
        const PopupMenuDivider(),
        for (final e in LyricsTranslationService.languages.entries)
          _subMenuItem('tr:${e.key}', e.value),
      ],
    );
  }

  Widget _lyricRow(
    int index,
    String text, {
    bool isActive = false,
    double opacity = 1.0,
    bool compact = false,
    VoidCallback? onLongPress,
  }) {
    final sub = index < _subLines.length ? _subLines[index].trim() : '';
    final showSub = _subMode != 'off' && sub.isNotEmpty && sub != text.trim();
    final isRom = _subMode == 'rom';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: onLongPress,
      child: Container(
        key: _lineKeys.putIfAbsent(index, () => GlobalKey()),
        constraints: BoxConstraints(minHeight: compact ? 0 : _lineExtent),
        alignment: Alignment.center,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 250),
          opacity: isActive ? 1.0 : opacity,
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: compact ? 3.0 : 4.0,
              horizontal: 8.0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  text,
                  style: TextStyle(
                    color: isActive ? Colors.blueAccent : Colors.white,
                    fontSize: isActive ? 20 : 16,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                    height: compact ? 1.4 : 1.25,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (showSub)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      sub,
                      style: TextStyle(
                        color: isActive
                            ? Colors.lightBlueAccent
                            : Colors.white54,
                        fontSize: isActive ? 15 : 13,
                        fontStyle: isRom ? FontStyle.italic : FontStyle.normal,
                        height: 1.25,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLyricsBack(String rawLyrics, List<LyricLine> lines) {
    final isSynced = lines.isNotEmpty;

    Widget content;
    if (_isSearchingLyrics) {
      content = const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.blueAccent),
            SizedBox(height: 12),
            Text(
              'Buscando letra...',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      );
    } else if (rawLyrics.isEmpty) {
      content = const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'No hay letra disponible',
              style: TextStyle(color: Colors.grey, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Toca la lupa para buscarla',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      );
    } else if (isSynced) {
      content = ValueListenableBuilder<int>(
        valueListenable: _activeIndex,
        builder: (context, activeIndex, _) {
          if (_needsInitialScroll) {
            _needsInitialScroll = false;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              final i = _activeIndex.value;
              if (i >= 0) _scrollToIndex(i, animate: false);
            });
          }
          return ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(vertical: 120),
            itemCount: lines.length,
            itemBuilder: (context, index) {
              final isActive = index == activeIndex;
              final distance = (index - activeIndex).abs();
              double opacity = 1.0;
              if (distance == 1) opacity = 0.5;
              if (distance > 1) opacity = 0.25;

              return _lyricRow(
                index,
                lines[index].text,
                isActive: isActive,
                opacity: opacity,
                onLongPress: () => _syncToLine(index),
              );
            },
          );
        },
      );
    } else {
      final plain = rawLyrics.split('\n');
      content = SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            children: [
              for (var i = 0; i < plain.length; i++)
                plain[i].trim().isEmpty
                    ? const SizedBox(height: 14)
                    : _lyricRow(i, plain[i], compact: true),
            ],
          ),
        ),
      );
    }

    return Container(
      width: 400,
      height: 350,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          children: [
            SizedBox(
              height: 40,
              child: Align(
                alignment: Alignment.centerRight,
                child: _isSearchingLyrics
                    ? const SizedBox.shrink()
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isTranslating)
                            const Padding(
                              padding: EdgeInsets.only(right: 8),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.blueAccent,
                                ),
                              ),
                            ),
                          if (rawLyrics.isNotEmpty) _buildTranslateMenu(),
                          _buildSearchMenu(
                            hasLyrics: rawLyrics.isNotEmpty,
                            isSynced: isSynced,
                          ),
                        ],
                      ),
              ),
            ),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }
}
