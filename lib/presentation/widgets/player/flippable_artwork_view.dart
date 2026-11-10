import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mymusicproject/presentation/providers/player_provider.dart';
import 'package:mymusicproject/presentation/widgets/app_snack.dart';
import 'package:mymusicproject/presentation/widgets/player/lrc_parser.dart';
import 'package:mymusicproject/presentation/widgets/player/lyrics_row.dart';
import 'package:mymusicproject/presentation/widgets/player/lyrics_actions_mixin.dart';
import 'package:mymusicproject/presentation/widgets/player/lyrics_menus.dart';
import 'package:mymusicproject/presentation/widgets/player/lyrics_timing.dart';
import 'package:mymusicproject/presentation/widgets/player/lyrics_translation_service.dart';
import 'package:mymusicproject/presentation/widgets/song_artwork.dart';

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
    with
        SingleTickerProviderStateMixin,
        LyricsActionsMixin<FlippableArtworkView> {
  static const double _lineExtent = 55.0;

  late final AnimationController _controller;
  late final Animation<double> _animation;
  bool _isFlipped = false;
  bool _needsInitialScroll = true;
  bool _songChanged = false;

  int _offsetMs = 0;
  Map<int, int> _anchors = const {};
  List<int> _effectiveMs = const [];
  bool _effectiveDirty = true;

  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<int> _activeIndex = ValueNotifier<int>(-1);

  String _parsedSource = '';
  List<LyricLine> _parsedLines = const [];
  String _script = 'auto';

  final LyricsTranslationService _translator = LyricsTranslationService();
  String _subMode = 'off';
  List<String> _subLines = const [];
  bool _isTranslating = false;
  final Map<int, GlobalKey> _lineKeys = {};

  @override
  String get lyricsSongId => widget.songId;
  @override
  String get lyricsTitle => widget.title;
  @override
  String get lyricsArtist => widget.artist;
  @override
  String get lyricsArtwork => widget.artwork;
  @override
  int get lyricsOffset => _offsetMs;
  @override
  Map<int, int> get lyricsAnchors => _anchors;
  @override
  int get lyricsLineCount => _parsedLines.length;

  @override
  void resetSubtitles() {
    setState(() {
      _subMode = 'off';
      _subLines = const [];
      _isTranslating = false;
    });
  }

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
      _anchors = const {};
      _effectiveMs = const [];
      _effectiveDirty = true;
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
      _script = raw.isEmpty
          ? 'auto'
          : LyricsTranslationService.detectScript(raw);
      _effectiveDirty = true;
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

  void _syncEffective() {
    if (!_effectiveDirty && _effectiveMs.length == _parsedLines.length) return;
    _effectiveMs = computeEffectiveTimes([
      for (final l in _parsedLines) l.timestamp.inMilliseconds,
    ], _anchors);
    _effectiveDirty = false;
  }

  int _indexFor(Duration pos) {
    if (_parsedLines.isEmpty) return -1;
    _syncEffective();
    return indexForTime(_effectiveMs, pos.inMilliseconds - _offsetMs);
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
      showAppSnack(
        ScaffoldMessenger.of(context),
        'No se pudo traducir: $e',
        color: Colors.red,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final offsetMs = ref.watch(
      customSongMetadataProvider.select(
        (m) => m[widget.songId]?.lyricsOffsetMs ?? 0,
      ),
    );
    final anchors = ref.watch(
      customSongMetadataProvider.select(
        (m) => m[widget.songId]?.lyricsAnchors ?? const <int, int>{},
      ),
    );

    var timingChanged = false;
    if (offsetMs != _offsetMs) {
      _offsetMs = offsetMs;
      timingChanged = true;
    }
    if (!mapEquals(anchors, _anchors)) {
      _anchors = anchors;
      _effectiveDirty = true;
      timingChanged = true;
    }
    if (timingChanged) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final pos = ref.read(positionProvider).value;
        if (pos != null && _parsedLines.isNotEmpty) _updateActive(pos);
      });
    }

    final rawLyrics = ref.watch(
      customSongMetadataProvider.select((m) => m[widget.songId]?.lyrics ?? ''),
    );
    final lines = _linesFor(rawLyrics);

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

  Widget _row(
    int index,
    String text, {
    bool isActive = false,
    double opacity = 1.0,
    bool compact = false,
    bool synced = false,
  }) {
    final sub = _subMode == 'off' || index >= _subLines.length
        ? ''
        : _subLines[index].trim();

    return LyricRow(
      text: text,
      sub: sub,
      isRomanization: _subMode == 'rom',
      isActive: isActive,
      opacity: opacity,
      compact: compact,
      minHeight: _lineExtent,
      hasAnchor: synced && _anchors.containsKey(index),
      lineKey: _lineKeys.putIfAbsent(index, () => GlobalKey()),
      onTouch: synced
          ? () => touchPos = ref.read(playerServiceProvider).player.position
          : null,
      onLongPress: synced ? () => onLineLongPress(index) : null,
    );
  }

  Widget _buildLyricsBack(String rawLyrics, List<LyricLine> lines) {
    final isSynced = lines.isNotEmpty;

    Widget content;
    if (isSearchingLyrics) {
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
              final distance = (index - activeIndex).abs();
              final opacity = distance == 0
                  ? 1.0
                  : distance == 1
                  ? 0.5
                  : 0.25;
              final text = lines[index].text;
              return _row(
                index,
                text.isEmpty ? '♪' : text,
                isActive: index == activeIndex,
                opacity: opacity,
                synced: true,
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
                    : _row(i, plain[i], compact: true),
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
                child: isSearchingLyrics
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
                          if (rawLyrics.isNotEmpty)
                            LyricsTranslateMenu(
                              mode: _subMode,
                              script: _script,
                              onSelected: _setSubMode,
                            ),
                          LyricsSearchMenu(
                            hasLyrics: rawLyrics.isNotEmpty,
                            isSynced: isSynced,
                            onAuto: fetchLyricsAutomatically,
                            onManual: showManualSheet,
                            onSync: showSyncDialog,
                            onEdit: editLyrics,
                            onDelete: deleteLyrics,
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