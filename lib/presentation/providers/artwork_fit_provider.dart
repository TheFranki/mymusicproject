import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ArtworkFit {
  const ArtworkFit({this.scale = 1.0, this.cx = 0.5, this.cy = 0.5});

  final double scale;
  final double cx;
  final double cy;

  bool get isIdentity =>
      (scale - 1).abs() < 0.001 &&
      (cx - 0.5).abs() < 0.001 &&
      (cy - 0.5).abs() < 0.001;

  static double minScaleFor(double aspect) {
    if (aspect <= 0) return 1;
    return aspect >= 1 ? 1 / aspect : aspect;
  }

  ArtworkFit clampedFor(double aspect) {
    final a = aspect <= 0 ? 1.0 : aspect;
    final s = scale.clamp(minScaleFor(a), 5.0).toDouble();
    // Tamaño de la imagen en "lados del cuadro".
    final w = (a >= 1 ? a : 1.0) * s;
    final h = (a >= 1 ? 1.0 : 1 / a) * s;
    double axis(double c, double size) {
      if (size <= 1) return 0.5;
      final half = 0.5 / size;
      return c.clamp(half, 1 - half).toDouble();
    }

    return ArtworkFit(scale: s, cx: axis(cx, w), cy: axis(cy, h));
  }

  List<double> toJson() => [scale, cx, cy];

  factory ArtworkFit.fromJson(List<dynamic> l) => ArtworkFit(
        scale: (l[0] as num).toDouble().clamp(0.05, 5.0).toDouble(),
        cx: (l[1] as num).toDouble().clamp(0.0, 1.0).toDouble(),
        cy: (l[2] as num).toDouble().clamp(0.0, 1.0).toDouble(),
      );

  @override
  bool operator ==(Object other) =>
      other is ArtworkFit &&
      other.scale == scale &&
      other.cx == cx &&
      other.cy == cy;

  @override
  int get hashCode => Object.hash(scale, cx, cy);
}

class FitRect {
  const FitRect(this.left, this.top, this.width, this.height);
  final double left, top, width, height;
}

FitRect computeFitRect({
  required double boxW,
  required double boxH,
  required double aspect,
  required ArtworkFit fit,
}) {
  final boxAspect = boxW / boxH;
  final coverW = aspect >= boxAspect ? boxH * aspect : boxW;
  final coverH = aspect >= boxAspect ? boxH : boxW / aspect;
  final w = coverW * fit.scale;
  final h = coverH * fit.scale;

  double place(double c, double size, double box) {
    if (size <= box) return (box - size) / 2;
    final half = box / 2 / size;
    final cc = c.clamp(half, 1 - half).toDouble();
    return box / 2 - cc * size;
  }

  return FitRect(place(fit.cx, w, boxW), place(fit.cy, h, boxH), w, h);
}

Future<double?> measureArtworkAspect(String src) async {
  try {
    final ImageProvider base =
        src.startsWith('http://') || src.startsWith('https://')
            ? NetworkImage(src)
            : FileImage(File(src));
    final provider = ResizeImage(base, width: 256);
    final completer = Completer<double?>();
    final stream = provider.resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        if (!completer.isCompleted) {
          completer.complete(
            info.image.height == 0 ? null : info.image.width / info.image.height,
          );
        }
        stream.removeListener(listener);
      },
      onError: (_, _) {
        if (!completer.isCompleted) completer.complete(null);
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
    return await completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => null,
    );
  } catch (_) {
    return null;
  }
}

final artworkAspectProvider = FutureProvider.family<double?, String>(
  (ref, src) => measureArtworkAspect(src),
);

const _kFits = 'artwork_fits_v2';

final artworkFitProvider =
    StateNotifierProvider<ArtworkFitNotifier, Map<String, ArtworkFit>>(
  (ref) => ArtworkFitNotifier(),
);

class ArtworkFitNotifier extends StateNotifier<Map<String, ArtworkFit>> {
  ArtworkFitNotifier([Map<String, ArtworkFit>? initial]) : super(initial ?? {});
  static Future<Map<String, ArtworkFit>> loadSaved() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kFits);
      if (raw == null) return {};
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final e in data.entries)
          e.key: ArtworkFit.fromJson(e.value as List<dynamic>),
      };
    } catch (e) {
      debugPrint('[ArtworkFit] No se pudo leer: $e');
      return {};
    }
  }

  Future<void> setFit(String path, ArtworkFit fit) async {
    if (path.isEmpty) return;
    final next = {...state};
    if (fit.isIdentity) {
      next.remove(path);
    } else {
      next[path] = fit;
    }
    if (mapEquals(next, state)) return;
    state = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kFits,
        jsonEncode({for (final e in next.entries) e.key: e.value.toJson()}),
      );
    } catch (e) {
      debugPrint('[ArtworkFit] No se pudo guardar: $e');
    }
  }
}