import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/splash_config_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/color_picker_dialog.dart';
import 'splash_screen.dart';
import '../widgets/lyvo_logo.dart';

class SplashSettingsScreen extends ConsumerWidget {
  const SplashSettingsScreen({super.key});

  static const List<Color> _accents = [
    Colors.blueAccent,
    Colors.lightBlueAccent,
    Colors.cyanAccent,
    Colors.tealAccent,
    Colors.greenAccent,
    Colors.lightGreenAccent,
    Colors.yellowAccent,
    Colors.amberAccent,
    Colors.orangeAccent,
    Colors.deepOrangeAccent,
    Colors.redAccent,
    Colors.pinkAccent,
    Colors.purpleAccent,
    Colors.deepPurpleAccent,
    Colors.indigoAccent,
  ];

  static const List<Color> _darks = [
    Color(0xFF000000),
    Color(0xFF0F0F0F),
    Color(0xFF0B132B),
    Color(0xFF1F1135),
    Color(0xFF0B1F17),
    Color(0xFF2A0F0F),
    Color(0xFF16120A),
    Color(0xFF1A0B1F),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(appThemeProvider);
    final splash = ref.watch(splashConfigProvider);
    final notifier = ref.read(splashConfigProvider.notifier);
    final titleStyle = Theme.of(context).textTheme.titleMedium
        ?.copyWith(fontWeight: FontWeight.bold);

    Future<void> pickBg() async {
      final c = await showColorPickerDialog(
        context,
        initial: splash.bgColor ?? theme.bg.first,
        maxValue: kMaxBgBrightness,
      );
      if (c != null) notifier.set(splash.copyWith(bgColor: c));
    }

    Future<void> pickAccent() async {
      final c = await showColorPickerDialog(
        context,
        initial: splash.accent ?? theme.accent,
      );
      if (c != null) notifier.set(splash.copyWith(accent: c));
    }

    return AppScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Pantalla de inicio'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _MiniSplash(theme: theme, splash: splash),
          const SizedBox(height: 12),
          Center(
            child: FilledButton.tonalIcon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _SplashTestPage(theme: theme, splash: splash),
                ),
              ),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Probar animación'),
            ),
          ),
          const SizedBox(height: 20),
          Text('Fondo', style: titleStyle),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Igual al tema'),
                selected: splash.bgColor == null,
                onSelected: (_) => notifier.set(splash.copyWith(clearBg: true)),
              ),
              ChoiceChip(
                label: const Text('Color propio'),
                selected: splash.bgColor != null,
                onSelected: (_) => notifier.set(
                  splash.copyWith(bgColor: splash.bgColor ?? theme.bg.first),
                ),
              ),
            ],
          ),
          if (splash.bgColor != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final c in _darks)
                  _ColorDot(
                    color: c,
                    selected: c.toARGB32() == splash.bgColor!.toARGB32(),
                    onTap: () => notifier.set(splash.copyWith(bgColor: c)),
                  ),
                _RainbowDot(onTap: pickBg),
              ],
            ),
          ],
          const SizedBox(height: 24),
          Text('Color del brillo y circulo de carga', style: titleStyle),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ChoiceChip(
                label: const Text('Igual al acento'),
                selected: splash.accent == null,
                onSelected: (_) =>
                    notifier.set(splash.copyWith(clearAccent: true)),
              ),
              for (final c in _accents)
                _ColorDot(
                  color: c,
                  selected: splash.accent?.toARGB32() == c.toARGB32(),
                  size: 30,
                  onTap: () => notifier.set(splash.copyWith(accent: c)),
                ),
              _RainbowDot(onTap: pickAccent),
            ],
          ),
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: () => notifier.set(const SplashConfig()),
            icon: const Icon(Icons.restart_alt),
            label: const Text('Restablecer (igual al tema)'),
          ),
        ],
      ),
    );
  }
}

class _MiniSplash extends StatelessWidget {
  const _MiniSplash({required this.theme, required this.splash});
  final AppThemeConfig theme;
  final SplashConfig splash;

  @override
Widget build(BuildContext context) {
  final accent = splash.accent ?? theme.accent;
  final base = splash.bgColor != null
      ? BoxDecoration(color: splash.bgColor)
      : theme.decoration;

  return Container(
    height: 210,
    width: double.infinity,
    decoration: base.copyWith(
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white24),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        LyvoLogo(size: 96, glow: accent, animate: false),
        const SizedBox(height: 6),
        const Text(
          'Lyvo',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            value: 0.65,
            strokeWidth: 3,
            color: accent,
            backgroundColor: Colors.white12,
            ),
          ),
        ],
      ),
    );
  }
}

class _SplashTestPage extends StatefulWidget {
  const _SplashTestPage({required this.theme, required this.splash});
  final AppThemeConfig theme;
  final SplashConfig splash;

  @override
  State<_SplashTestPage> createState() => _SplashTestPageState();
}

class _SplashTestPageState extends State<_SplashTestPage> {
  final ValueNotifier<String> _status = ValueNotifier('Probando…');
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(kSplashMinDuration + const Duration(milliseconds: 400), () {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _status.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: SplashView(
        theme: widget.theme,
        splash: widget.splash,
        status: _status,
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
    this.size = 36,
  });
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.white : Colors.white24,
            width: selected ? 3 : 1.5,
          ),
        ),
        child: selected
            ? Icon(
                Icons.check,
                size: 16,
                color: color.computeLuminance() > 0.5
                    ? Colors.black
                    : Colors.white,
              )
            : null,
      ),
    );
  }
}

class _RainbowDot extends StatelessWidget {
  const _RainbowDot({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: SweepGradient(
            colors: [
              Colors.red,
              Colors.yellow,
              Colors.green,
              Colors.cyan,
              Colors.blue,
              Colors.purple,
              Colors.red,
            ],
          ),
        ),
        child: const Icon(Icons.add, size: 18, color: Colors.white),
      ),
    );
  }
}
