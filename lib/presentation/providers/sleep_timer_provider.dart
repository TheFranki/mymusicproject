import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import 'player_controller.dart';
import 'player_provider.dart';

String formatTimer(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

class SleepTimerState {
  const SleepTimerState({this.remaining, this.endOfSong = false});
  final Duration? remaining;
  final bool endOfSong;
  bool get active => remaining != null || endOfSong;
}

final sleepTimerProvider =
    StateNotifierProvider<SleepTimerNotifier, SleepTimerState>(
      (ref) => SleepTimerNotifier(ref),
    );

class SleepTimerNotifier extends StateNotifier<SleepTimerState> {
  SleepTimerNotifier(this._ref) : super(const SleepTimerState());

  final Ref _ref;
  Timer? _ticker;
  DateTime _last = DateTime.now();
  static const _fade = Duration(seconds: 10);

  AudioPlayer get _player => _ref.read(playerServiceProvider).player;

  void _syncPreload() =>
      unawaited(_ref.read(playerControllerProvider).syncPreload());

  void start(Duration d) {
    _stopTicker();
    _restoreLoop();
    _player.setVolume(1);
    _last = DateTime.now();
    state = SleepTimerState(remaining: d);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _syncPreload();
  }

  void startEndOfSong() {
    _stopTicker();
    _player.setVolume(1);
    state = const SleepTimerState(endOfSong: true);
    _player.setLoopMode(LoopMode.off);
    _syncPreload();
  }

  void cancel() {
    _stopTicker();
    _restoreLoop();
    _player.setVolume(1);
    state = const SleepTimerState();
    _syncPreload();
  }

  bool consumeEndOfSong() {
    if (!state.endOfSong) return false;
    state = const SleepTimerState();
    _restoreLoop();
    return true;
  }

  void _tick() {
    final now = DateTime.now();
    final dt = now.difference(_last);
    _last = now;

    final left = state.remaining;
    if (left == null || !_player.playing) return;

    final next = left - dt;
    if (next <= Duration.zero) {
      _finish();
      return;
    }
    state = SleepTimerState(remaining: next);
    if (next <= _fade) {
      _player.setVolume(next.inMilliseconds / _fade.inMilliseconds);
    }
  }

  Future<void> _finish() async {
    _stopTicker();
    state = const SleepTimerState();
    await _ref.read(playerControllerProvider).pauseAndSave();
    await _player.setVolume(1);
  }

  void _restoreLoop() {
    final repeat = _ref.read(repeatModeProvider);
    _player.setLoopMode(repeat == 2 ? LoopMode.one : LoopMode.off);
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  @override
  void dispose() {
    _stopTicker();
    super.dispose();
  }
}
