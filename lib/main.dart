import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mymusicproject/presentation/screens/home_screens.dart';
import 'package:mymusicproject/presentation/providers/local_music_provider.dart';
import 'package:mymusicproject/presentation/providers/player_controller.dart';
import 'package:mymusicproject/data/sources/persistent_image.dart';
import 'package:audio_service/audio_service.dart';
import 'package:mymusicproject/domain/services/audio_handler.dart';
import 'package:mymusicproject/presentation/providers/player_provider.dart';
import 'package:mymusicproject/presentation/providers/notification_sync_provider.dart';
import 'package:mymusicproject/presentation/app_messenger.dart';

import 'dart:io' show Platform;

import 'package:permission_handler/permission_handler.dart';
import 'package:mymusicproject/presentation/theme/app_theme.dart';
import 'package:flutter/services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final handler = await AudioService.init<AppAudioHandler>(
    builder: () => AppAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.mymusicproject.channel.audio',
      androidNotificationChannelName: 'Reproducción de música',
      androidNotificationOngoing: true,
      androidNotificationIcon: 'drawable/ic_notif_small',
    ),
  );

  final savedTheme = await AppThemeNotifier.loadSaved();
  runApp(
    ProviderScope(
      overrides: [
        audioHandlerProvider.overrideWithValue(handler),
        appThemeProvider.overrideWith((ref) => AppThemeNotifier(savedTheme)),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});
  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    final handler = ref.read(audioHandlerProvider);
    final controller = ref.read(playerControllerProvider);
    handler.onNext = () => controller.next();
    handler.onPrevious = () => controller.previous();
    handler.onToggleShuffle = () async => controller.toggleShuffle();
    handler.onToggleRepeat = () async => controller.toggleRepeat();
    handler.onToggleFavorite = () async => controller.toggleCurrentFavorite();
    controller.restoreLastSession();
    Future.delayed(const Duration(seconds: 10), runStorageMaintenance);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _askNotificationPermission(),
    );
  }

  Future<void> _askNotificationPermission() async {
    if (!Platform.isAndroid) return;
    var status = await Permission.notification.status;
    if (status.isDenied) status = await Permission.notification.request();
    if (status.isPermanentlyDenied) {
      showAppMessage(
        'Activa las notificaciones para controlar la música desde la barra.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(playerStateListenerProvider);
    ref.watch(notificationSyncProvider);
    final themeCfg = ref.watch(appThemeProvider);

    return MaterialApp(
      title: 'Mi Música',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: appMessengerKey,
      theme: buildAppTheme(themeCfg),
      home: const HomeScreen(),
    );
  }
}
