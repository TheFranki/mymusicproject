import 'dart:math' as math;

import 'package:flutter/material.dart';

const _kHeadphones = 'assets/logo/headphones.png';
const _kEarL = 'assets/logo/ear_l.png';
const _kEarR = 'assets/logo/ear_r.png';
const _kPlay = 'assets/logo/play.png';
const _pivotEarL = Alignment(-0.352, -0.254);
const _pivotEarR = Alignment(0.352, -0.254);
const _pivotPlay = Alignment(0.0, 0.30);

class LyvoLogo extends StatefulWidget {
  const LyvoLogo({super.key, this.size = 160, this.glow, this.animate = true});
  final double size;
  final Color? glow;
  final bool animate;

  @override
  State<LyvoLogo> createState() => _LyvoLogoState();
}

class _LyvoLogoState extends State<LyvoLogo> with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _intro.forward();
      _loop.repeat();
    } else {
      _intro.value = 1;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    for (final p in const [_kHeadphones, _kEarL, _kEarR, _kPlay]) {
      precacheImage(AssetImage(p), context);
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _loop.dispose();
    super.dispose();
  }

  static double _seg(double t, double a, double b, Curve c) =>
      c.transform(((t - a) / (b - a)).clamp(0.0, 1.0));

  static double _twitch(double l, double start) {
    final x = (l - start) / 0.12;
    if (x < 0 || x > 1) return 0;
    return math.sin(x * math.pi * 3) * (1 - x) * 0.16;
  }

  Widget _img(String asset) => Image.asset(
        asset,
        width: widget.size,
        height: widget.size,
        filterQuality: FilterQuality.high,
        gaplessPlayback: true,
      );

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final glow = widget.glow ?? const Color(0xFF7C6CFF);

    return SizedBox(
      width: s,
      height: s,
      child: AnimatedBuilder(
        animation: Listenable.merge([_intro, _loop]),
        builder: (context, _) {
          final t = _intro.value;
          final l = _loop.value;
          final done = t >= 1.0;
          final beat = done ? (math.sin(l * 2 * math.pi) * 0.5 + 0.5) : 0.0;

          final band = _seg(t, 0.00, 0.40, Curves.easeOutBack);
          final earL = _seg(t, 0.30, 0.75, Curves.elasticOut);
          final earR = _seg(t, 0.38, 0.83, Curves.elasticOut);
          final play = _seg(t, 0.55, 0.95, Curves.easeOutBack);
          final glowT = _seg(t, 0.15, 1.0, Curves.easeOut);

          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Brillo de fondo
              Positioned(
                left: -0.2 * s,
                top: -0.15 * s,
                width: 1.4 * s,
                height: 1.4 * s,
                child: Opacity(
                  opacity: (glowT * (0.55 + 0.35 * beat)).clamp(0.0, 1.0),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          glow.withValues(alpha: 0.40),
                          glow.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Diadema y copas
              Opacity(
                opacity: band.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: 0.78 + 0.22 * band,
                  child: _img(_kHeadphones),
                ),
              ),
              // Orejas
              Transform.scale(
                scale: earL,
                alignment: _pivotEarL,
                child: Transform.rotate(
                  angle: done ? _twitch(l, 0.05) : 0,
                  alignment: _pivotEarL,
                  child: _img(_kEarL),
                ),
              ),
              Transform.scale(
                scale: earR,
                alignment: _pivotEarR,
                child: Transform.rotate(
                  angle: done ? -_twitch(l, 0.55) : 0,
                  alignment: _pivotEarR,
                  child: _img(_kEarR),
                ),
              ),
              // Botón de play
              Transform.scale(
                scale: play * (1 + 0.07 * beat),
                alignment: _pivotPlay,
                child: _img(_kPlay),
              ),
            ],
          );
        },
      ),
    );
  }
}