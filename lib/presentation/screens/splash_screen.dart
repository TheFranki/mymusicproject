import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app_locale.dart';
import '../providers/splash_config_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/lyvo_logo.dart';

const Duration kSplashMinDuration = Duration(milliseconds: 2600);
class SplashScreen extends StatelessWidget {
  const SplashScreen({
    super.key,
    required this.theme,
    required this.splash,
    required this.status,
  });

  final AppThemeConfig theme;
  final SplashConfig splash;
  final ValueListenable<String> status;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(theme),
      locale: kAppLocale,
      supportedLocales: kSupportedLocales,
      localizationsDelegates: kLocalizationsDelegates,
      home: SplashView(theme: theme, splash: splash, status: status),
    );
  }
}

class SplashView extends StatefulWidget {
  const SplashView({
    super.key,
    required this.theme,
    required this.splash,
    this.status,
  });

  final AppThemeConfig theme;
  final SplashConfig splash;
  final ValueListenable<String>? status;

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  )..forward();

  late final Animation<double> _textFade = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
  );

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.splash.accent ?? widget.theme.accent;
    final decoration = widget.splash.bgColor != null
        ? BoxDecoration(color: widget.splash.bgColor)
        : widget.theme.decoration;

    return DecoratedBox(
      decoration: decoration,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LyvoLogo(size: 190, glow: accent),
              const SizedBox(height: 18),
              FadeTransition(
                opacity: _textFade,
                child: const Text(
                  'Lyvo',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              FadeTransition(
                opacity: _textFade,
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 3.5,
                    color: accent,
                    backgroundColor: Colors.white12,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FadeTransition(
                opacity: _textFade,
                child: widget.status == null
                    ? const SizedBox(height: 16)
                    : ValueListenableBuilder<String>(
                        valueListenable: widget.status!,
                        builder: (_, text, _) => AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: Text(
                            text,
                            key: ValueKey(text),
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}