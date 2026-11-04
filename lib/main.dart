import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:mymusicproject/presentation/screens/home_screens.dart';
import 'package:mymusicproject/presentation/providers/local_music_provider.dart';
import 'package:mymusicproject/presentation/providers/player_controller.dart';
import 'package:mymusicproject/data/sources/persistent_image.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.mymusicproject.channel.audio',
    androidNotificationChannelName: 'Reproducción de música',
    androidNotificationOngoing: true,
    androidNotificationIcon: 'mipmap/ic_launcher',
  );
  runApp(const ProviderScope(child: MyApp()));
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
    ref.read(playerControllerProvider).restoreLastSession();
    Future.delayed(const Duration(seconds: 10), runStorageMaintenance);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(playerStateListenerProvider);

    return MaterialApp(
      title: 'Mi Música',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
