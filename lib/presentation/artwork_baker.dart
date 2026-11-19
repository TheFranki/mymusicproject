import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'providers/artwork_fit_provider.dart';

Future<File?> bakeArtwork(String path, ArtworkFit fit, {int size = 600}) async {
  try {
    final cache = await getApplicationCacheDirectory();
    final dir = Directory('${cache.path}/notif_art');
    if (!await dir.exists()) await dir.create(recursive: true);

    final name = '${path.hashCode.abs()}'
        '_${fit.scale.toStringAsFixed(3)}'
        '_${fit.cx.toStringAsFixed(3)}'
        '_${fit.cy.toStringAsFixed(3)}.png';
    final target = File('${dir.path}/$name');
    if (await target.exists()) return target;

    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final img = frame.image;

    final r = computeFitRect(
      boxW: size.toDouble(),
      boxH: size.toDouble(),
      aspect: img.width / img.height,
      fit: fit,
    );

    final recorder = ui.PictureRecorder();
    final box = ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble());
    final canvas = ui.Canvas(recorder, box);
    canvas.drawRect(box, ui.Paint()..color = const ui.Color(0xFF1E1E1E));
    canvas.drawImageRect(
      img,
      ui.Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      ui.Rect.fromLTWH(r.left, r.top, r.width, r.height),
      ui.Paint()..filterQuality = ui.FilterQuality.high,
    );

    final out = await recorder.endRecording().toImage(size, size);
    final data = await out.toByteData(format: ui.ImageByteFormat.png);
    img.dispose();
    out.dispose();
    codec.dispose();
    if (data == null) return null;

    await target.writeAsBytes(data.buffer.asUint8List());
    return target;
  } catch (e) {
    debugPrint('[artwork_baker] No se pudo recortar: $e');
    return null;
  }
}