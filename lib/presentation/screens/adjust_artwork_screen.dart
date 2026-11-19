import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../providers/artwork_fit_provider.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/discard_guard.dart';
import '../widgets/song_artwork.dart';

class AdjustArtworkScreen extends StatefulWidget {
  const AdjustArtworkScreen({super.key, required this.path, this.initial});
  final String path;
  final ArtworkFit? initial;

  @override
  State<AdjustArtworkScreen> createState() => _AdjustArtworkScreenState();
}

class _AdjustArtworkScreenState extends State<AdjustArtworkScreen> {
  double? _aspect;
  late ArtworkFit _fit = widget.initial ?? const ArtworkFit();
  late ArtworkFit _start = widget.initial ?? const ArtworkFit();
  double _s0 = 1, _cx0 = 0.5, _cy0 = 0.5;
  Offset _f0 = Offset.zero;
  bool _interacting = false;
  bool get _dirty => _fit != _start;
  bool get _isGif => widget.path.toLowerCase().endsWith('.gif');

  @override
  void initState() {
    super.initState();
    measureArtworkAspect(widget.path).then((a) {
      if (!mounted) return;
      final aspect = (a == null || a <= 0) ? 1.0 : a;
      setState(() {
        _aspect = aspect;
        _fit = _fit.clampedFor(aspect);
        _start = _fit;
      });
    });
  }

  void _update(ArtworkFit f) {
    final aspect = _aspect;
    if (aspect == null) return;
    setState(() => _fit = f.clampedFor(aspect));
  }

  Widget _preview(String label, double w, double h, double r) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SongArtwork(
          artworkPathOrUrl: widget.path,
          width: w,
          height: h,
          borderRadius: r,
          fitOverride: _fit,
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final side = math.min(math.min(size.width - 48, 320.0), size.height * 0.38);
    final aspect = _aspect;
    final minScale = aspect == null ? 1.0 : ArtworkFit.minScaleFor(aspect);

    return DiscardGuard(
      isDirty: () => _dirty,
      child: AppScaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('Ajustar imagen'),
          actions: [
            TextButton(
              onPressed:
                  aspect == null ? null : () => Navigator.pop(context, _fit),
              child: const Text('Listo'),
            ),
          ],
        ),
        body: SingleChildScrollView(
          physics: _interacting ? const NeverScrollableScrollPhysics() : null,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            children: [
              Listener(
                onPointerDown: (_) => setState(() => _interacting = true),
                onPointerUp: (_) => setState(() => _interacting = false),
                onPointerCancel: (_) => setState(() => _interacting = false),
                child: GestureDetector(
                  onScaleStart: (d) {
                    _s0 = _fit.scale;
                    _cx0 = _fit.cx;
                    _cy0 = _fit.cy;
                    _f0 = d.localFocalPoint;
                  },
                  onScaleUpdate: (d) {
                    final a = _aspect;
                    if (a == null) return;
                    final s = _s0 * d.scale;
                    final w = (a >= 1 ? side * a : side) * s;
                    final h = (a >= 1 ? side : side / a) * s;
                    _update(
                      ArtworkFit(
                        scale: s,
                        cx: _cx0 - (d.localFocalPoint.dx - _f0.dx) / w,
                        cy: _cy0 - (d.localFocalPoint.dy - _f0.dy) / h,
                      ),
                    );
                  },
                  child: Container(
                    width: side,
                    height: side,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: aspect == null
                        ? const Center(child: CircularProgressIndicator())
                        : SongArtwork(
                            artworkPathOrUrl: widget.path,
                            width: side,
                            height: side,
                            borderRadius: 16,
                            fitOverride: _fit,
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Arrastra para mover y pellizca para acercar o alejar.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              Row(
                children: [
                  const Icon(Icons.zoom_out, size: 20),
                  Expanded(
                    child: Slider(
                      value: _fit.scale.clamp(minScale, 5.0).toDouble(),
                      min: minScale,
                      max: 5,
                      onChanged: aspect == null
                          ? null
                          : (v) => _update(
                                ArtworkFit(scale: v, cx: _fit.cx, cy: _fit.cy),
                              ),
                    ),
                  ),
                  const Icon(Icons.zoom_in, size: 20),
                ],
              ),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 4,
                children: [
                  TextButton.icon(
                    onPressed: () => _update(const ArtworkFit()),
                    icon: const Icon(Icons.crop_free, size: 18),
                    label: const Text('Rellenar'),
                  ),
                  TextButton.icon(
                    onPressed: () => _update(ArtworkFit(scale: minScale)),
                    icon: const Icon(Icons.fit_screen, size: 18),
                    label: const Text('Ver completa'),
                  ),
                  TextButton.icon(
                    onPressed: () => _update(ArtworkFit(scale: _fit.scale)),
                    icon: const Icon(Icons.center_focus_strong, size: 18),
                    label: const Text('Centrar'),
                  ),
                ],
              ),
              const Divider(height: 28, color: Colors.white12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Así se verá',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 24,
                runSpacing: 14,
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [
                  _preview('Lista', 45, 45, 8),
                  _preview('Reproductor', 112, 98, 12),
                  _preview('Notificación', 56, 56, 6),
                ],
              ),
              if (_isGif) ...[
                const SizedBox(height: 12),
                const Text(
                  'Los GIF se mueven en la app. En la notificación se verá un '
                  'solo fotograma.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}