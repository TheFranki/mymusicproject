import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/artwork_fit_provider.dart';

const Color kArtBackdrop = Color(0xFF1E1E1E);

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

int _bucket(double px) {
  for (final b in const [128, 256, 384, 512, 768, 1024, 1536, 2048]) {
    if (px <= b) return b;
  }
  return 2048;
}

class SongArtwork extends ConsumerWidget {
  const SongArtwork({
    super.key,
    required this.artworkPathOrUrl,
    this.width = 45,
    this.height = 45,
    this.borderRadius = 8,
    this.fitOverride,
  });

  final String? artworkPathOrUrl;
  final double width;
  final double height;
  final double borderRadius;
  final ArtworkFit? fitOverride;

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

  Widget _image(
    BuildContext context,
    String src, {
    required double w,
    required double h,
    required BoxFit fit,
    required double dpr,
  }) {
    final cacheW = w.isFinite ? _bucket(w * dpr) : null;
    final isUrl = src.startsWith('http://') || src.startsWith('https://');
    return isUrl
        ? Image.network(
            src,
            width: w,
            height: h,
            fit: fit,
            cacheWidth: cacheW,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => _placeholder(context),
          )
        : Image.file(
            File(src),
            width: w,
            height: h,
            fit: fit,
            cacheWidth: cacheW,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => _placeholder(context),
          );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final src = artworkPathOrUrl;
    if (src == null || src.isEmpty) return _placeholder(context);

    final dpr = MediaQuery.devicePixelRatioOf(context);
    final fit =
        fitOverride ?? ref.watch(artworkFitProvider.select((m) => m[src]));
    final hasFit = fit != null && !fit.isIdentity;
    final aspect = hasFit ? ref.watch(artworkAspectProvider(src)).value : null;

    return LayoutBuilder(
      builder: (context, c) {
        final boxW = c.constrainWidth(width);
        final boxH = c.constrainHeight(height);

        if (!hasFit ||
            aspect == null ||
            aspect <= 0 ||
            !boxW.isFinite ||
            !boxH.isFinite) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: _image(
              context,
              src,
              w: boxW,
              h: boxH,
              fit: BoxFit.cover,
              dpr: dpr,
            ),
          );
        }

        final r = computeFitRect(
          boxW: boxW,
          boxH: boxH,
          aspect: aspect,
          fit: fit,
        );

        return ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: SizedBox(
            width: boxW,
            height: boxH,
            child: ColoredBox(
              color: kArtBackdrop,
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Positioned(
                    left: r.left,
                    top: r.top,
                    width: r.width,
                    height: r.height,
                    child: _image(
                      context,
                      src,
                      w: r.width,
                      h: r.height,
                      fit: BoxFit.fill,
                      dpr: dpr,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}