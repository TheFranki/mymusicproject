import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:mymusicproject/data/sources/persistent_image.dart';
import 'package:mymusicproject/domain/services/audio_handler.dart';
import 'package:mymusicproject/presentation/app_messenger.dart';
import 'package:mymusicproject/presentation/error_messages.dart';
import 'package:mymusicproject/presentation/providers/artwork_fit_provider.dart';
import 'package:mymusicproject/presentation/providers/local_music_provider.dart';
import 'package:mymusicproject/presentation/providers/notification_sync_provider.dart';
import 'package:mymusicproject/presentation/providers/player_controller.dart';
import 'package:mymusicproject/presentation/providers/player_provider.dart';
import 'package:mymusicproject/presentation/providers/splash_config_provider.dart';
import 'package:mymusicproject/presentation/screens/home_screens.dart';
import 'package:mymusicproject/presentation/screens/splash_screen.dart';
import 'package:mymusicproject/presentation/theme/app_theme.dart';
import 'package:mymusicproject/presentation/widgets/error_view.dart';
import 'package:mymusicproject/presentation/app_locale.dart';
import 'package:mymusicproject/presentation/providers/library_refresh_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ErrorWidget.builder = (details) {
    if (kDebugMode) return ErrorWidget(details.exception);
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Algo salió mal en esta sección. Vuelve atrás e inténtalo de nuevo.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70),
        ),
      ),
    );
  };
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  final savedTheme = await AppThemeNotifier.loadSaved();
  final savedSplash = await SplashConfigNotifier.loadSaved();
  runApp(BootApp(initialTheme: savedTheme, initialSplash: savedSplash));
}

class BootApp extends StatefulWidget {
  const BootApp({
    super.key,
    required this.initialTheme,
    required this.initialSplash,
  });

  final AppThemeConfig initialTheme;
  final SplashConfig initialSplash;

  @override
  State<BootApp> createState() => _BootAppState();
}

class _BootAppState extends State<BootApp> {
  final ValueNotifier<String> _status = ValueNotifier('Iniciando…');
  ProviderContainer? _container;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final started = DateTime.now();
    try {
      _status.value = 'Preparando el reproductor…';
      final results = await Future.wait<Object>([
        AudioService.init<AppAudioHandler>(
          builder: () => AppAudioHandler(),
          config: const AudioServiceConfig(
            androidNotificationChannelId: 'com.mymusicproject.channel.audio',
            androidNotificationChannelName: 'Reproducción de música',
            androidNotificationOngoing: true,
            androidNotificationIcon: 'drawable/ic_notif_small',
          ),
        ),
        ArtworkFitNotifier.loadSaved(),
        SortOptionController.loadSaved(),
      ]);

      final handler = results[0] as AppAudioHandler;
      final fits = results[1] as Map<String, ArtworkFit>;
      final sort = results[2] as String;
      final container = ProviderContainer(
        overrides: [
          audioHandlerProvider.overrideWithValue(handler),
          appThemeProvider.overrideWith(
            (ref) => AppThemeNotifier(widget.initialTheme),
          ),
          splashConfigProvider.overrideWith(
            (ref) => SplashConfigNotifier(widget.initialSplash),
          ),
          artworkFitProvider.overrideWith((ref) => ArtworkFitNotifier(fits)),
          sortOptionProvider.overrideWith((ref) => SortOptionController(sort)),
        ],
      );

      _status.value = 'Cargando tu música…';
      try {
        await container
            .read(localSongsProvider.future)
            .timeout(const Duration(seconds: 6));
      } catch (_) {}
      final elapsed = DateTime.now().difference(started);
      if (elapsed < kSplashMinDuration) {
        await Future.delayed(kSplashMinDuration - elapsed);
      }

      if (!mounted) {
        container.dispose();
        return;
      }

      setState(() {
        _container?.dispose();
        _container = container;
        _error = null;
      });
    } catch (e, st) {
      logError('Inicio', e, st);
      if (mounted) {
        setState(() => _error = e);
      }
    }
  }

  void _retry() {
    _container?.dispose();
    setState(() {
      _container = null;
      _error = null;
    });
    _boot();
  }

  @override
  void dispose() {
    _status.dispose();
    _container?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget child;
    if (_error != null) {
      child = MaterialApp(
        key: const ValueKey('error'),
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(widget.initialTheme),
        locale: kAppLocale,
        supportedLocales: kSupportedLocales,
        localizationsDelegates: kLocalizationsDelegates,
        home: Scaffold(
          body: ErrorView(
            error: _error!,
            what: 'No se pudo iniciar la app',
            onRetry: _retry,
          ),
        ),
      );
    } else if (_container == null) {
      child = SplashScreen(
        key: const ValueKey('splash'),
        theme: widget.initialTheme,
        splash: widget.initialSplash,
        status: _status,
      );
    } else {
      child = UncontrolledProviderScope(
        key: const ValueKey('app'),
        container: _container!,
        child: const MyApp(),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      child: child,
    );
  }
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.read(libraryRefresherProvider).start();
    final handler = ref.read(audioHandlerProvider);
    final controller = ref.read(playerControllerProvider);
    handler.onNext = () => controller.next();
    handler.onPrevious = () => controller.previous();
    handler.onToggleShuffle = () async => controller.toggleShuffle();
    handler.onToggleRepeat = () async => controller.toggleRepeat();
    handler.onToggleFavorite = () async => controller.toggleCurrentFavorite();

    controller.restoreLastSession();

    Future.delayed(const Duration(seconds: 10), () {
      if (!mounted) return;
      runStorageMaintenance();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _askNotificationPermission();
    });
  }

  Future<void> _askNotificationPermission() async {
    if (!Platform.isAndroid || !mounted) return;
    var status = await Permission.notification.status;
    if (!mounted) return;
    if (status.isDenied) {
      status = await Permission.notification.request();
      if (!mounted) return;
    }
    if (status.isPermanentlyDenied) {
      showAppMessage(
        'Activa las notificaciones para controlar la música desde la barra.',
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(libraryRefresherProvider).refresh();
    } else {
      ref.read(playerControllerProvider).saveNow();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(playerStateListenerProvider);
    ref.watch(notificationSyncProvider);
    final themeCfg = ref.watch(appThemeProvider);

    return MaterialApp(
      title: 'Lyvo',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: appMessengerKey,
      theme: buildAppTheme(themeCfg),
      locale: kAppLocale,
      supportedLocales: kSupportedLocales,
      localizationsDelegates: kLocalizationsDelegates,
      home: const HomeScreen(),
    );
  }
}
