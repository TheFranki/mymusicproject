import 'dart:io';
import 'package:flutter/material.dart';

Widget buildSongArtwork({
  required String? artworkPathOrUrl,
  double width = 45,
  double height = 45,
  double borderRadius = 8,
}) =>
    SongArtwork(
      artworkPathOrUrl: artworkPathOrUrl,
      width: width,
      height: height,
      borderRadius: borderRadius,
    );

class SongArtwork extends StatelessWidget {
  const SongArtwork({
    super.key,
    required this.artworkPathOrUrl,
    this.width = 45,
    this.height = 45,
    this.borderRadius = 8,
  });

  final String? artworkPathOrUrl;
  final double width;
  final double height;
  final double borderRadius;

  Widget _placeholder(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Icon(Icons.music_note, color: accent, size: width * 0.5),
    );
  }

  @override
  Widget build(BuildContext context) {
    final src = artworkPathOrUrl;
    if (src == null || src.isEmpty) return _placeholder(context);
    final isUrl = src.startsWith('http://') || src.startsWith('https://');
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheW = width.isFinite ? (width * dpr).round() : null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: isUrl
          ? Image.network(
              src,
              width: width,
              height: height,
              cacheWidth: cacheW,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _placeholder(context),
            )
          : Image.file(
              File(src),
              width: width,
              height: height,
              cacheWidth: cacheW,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _placeholder(context),
            ),
    );
  }
}