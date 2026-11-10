import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'player_provider.dart';
import 'player_controller.dart';

final sortOptionProvider = StateProvider<String>((ref) => 'name_asc');

final playCountProvider =
    StateNotifierProvider<PlayCountNotifier, Map<String, int>>((ref) {
      return PlayCountNotifier();
    });

class PlayCountNotifier extends StateNotifier<Map<String, int>> {
  PlayCountNotifier() : super({}) {
    _ready = _load();
  }

  static const _key = 'play_counts_v1';
  late final Future<void> _ready;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      state = decoded.map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {}
  }

  Future<void> increment(String songId) async {
    await _ready;
    state = {...state, songId: (state[songId] ?? 0) + 1};
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(state));
    } catch (_) {}
  }
}

final localSongsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  try {
    final service = ref.watch(localAudioServiceProvider);
    final songs = await service.getLocalSongs();
    if (songs.isEmpty) return [];

    songs.sort((a, b) {
      final ta = (a['title'] ?? a['name'] ?? '')
          .toString()
          .toLowerCase()
          .trim();
      final tb = (b['title'] ?? b['name'] ?? '')
          .toString()
          .toLowerCase()
          .trim();
      return ta.compareTo(tb);
    });
    return songs;
  } catch (e, st) {
    debugPrint('[LOCAL SONGS] Error: $e');
    debugPrintStack(stackTrace: st);
    rethrow;
  }
});

final playerStateListenerProvider = Provider<void>((ref) {
  ref.read(playerStateListenerServiceProvider);
});

final playerStateListenerServiceProvider = Provider<PlayerStateListenerService>(
  (ref) {
    final service = PlayerStateListenerService(ref);
    ref.onDispose(service.dispose);
    return service;
  },
);

class PlayerStateListenerService {
  final Ref ref;
  late final StreamSubscription<PlayerState> _sub;

  PlayerStateListenerService(this.ref) {
    _sub = ref.read(playerServiceProvider).playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        ref.read(playerControllerProvider).next(auto: true);
      }
    });
  }

  void dispose() => _sub.cancel();
}
