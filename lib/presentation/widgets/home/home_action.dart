import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mymusicproject/presentation/providers/player_provider.dart';
import 'package:mymusicproject/presentation/providers/player_controller.dart';
import 'package:mymusicproject/presentation/providers/local_music_provider.dart';
import 'package:mymusicproject/presentation/screens/player_screen.dart';

class HomeAction {
  bool _isStartingPlayback = false;

  Future<void> playSongAndNavigate({
    required WidgetRef ref,
    required BuildContext context,
    required Map<String, dynamic> song,
    List<Map<String, dynamic>>? queue,
  }) async {
    if (_isStartingPlayback) return;
    _isStartingPlayback = true;

    try {
      final id = song['id']?.toString() ?? '';
      final path = song['data']?.toString() ?? '';
      if (id.isEmpty || path.isEmpty) {
        throw Exception('El ID o la ruta del archivo están vacíos');
      }

      final songs = queue ??
          await ref
              .read(localSongsProvider.future)
              .timeout(const Duration(seconds: 15));

      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PlayerScreen()),
      );

      await ref.read(playerControllerProvider).playContext(songs, song);
    } catch (e, stack) {
      debugPrint('[HOME ACTION] Error al reproducir: $e');
      debugPrintStack(stackTrace: stack);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al reproducir: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      _isStartingPlayback = false;
    }
  }

  Future<void> playRandomSong({
    required WidgetRef ref,
    required BuildContext context,
    required List<Map<String, dynamic>> songs,
  }) async {
    if (songs.isEmpty) return;
    ref.read(isShuffleEnabledProvider.notifier).state = true;
    final start = songs[Random().nextInt(songs.length)];
    await playSongAndNavigate(
      ref: ref,
      context: context,
      song: start,
      queue: songs,
    );
  }
}
