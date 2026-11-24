import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'local_music_provider.dart';

const _events = MethodChannel('com.mymusicproject/media_events');

final libraryRefresherProvider = Provider<LibraryRefresher>(
  (ref) => LibraryRefresher(ref),
);

class LibraryRefresher {
  LibraryRefresher(this._ref);

  final Ref _ref;
  bool _busy = false;
  bool _again = false;
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;
    _events.setMethodCallHandler((call) async {
      if (call.method == 'mediaChanged') refresh(scan: false);
      return null;
    });
  }
  Future<void> refresh({bool scan = true}) async {
    if (_busy) {
      _again = true;
      return;
    }
    _busy = true;
    try {
      if (scan) {
        try {
          await _events
              .invokeMethod<int>('scanNew')
              .timeout(const Duration(seconds: 6));
        } catch (_) {}
      }
      _ref.invalidate(localSongsProvider);
      await _ref.read(localSongsProvider.future);
    } catch (_) {
    } finally {
      _busy = false;
      if (_again) {
        _again = false;
        unawaited(refresh(scan: false));
      }
    }
  }
}