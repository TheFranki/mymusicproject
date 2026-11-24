import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'local_music_provider.dart';

const List<String> _nonMusicFolders = [
  'com.whatsapp', '/whatsapp',
  'org.telegram', '/telegram',
  'org.thoughtcrime', '/signal/',
  '/recordings/', '/recorder', 'voice recorder', 'voicerecorder',
  'sound_recorder', 'soundrecorder', 'call_rec', 'callrecord',
  '/notifications/', '/ringtones/', '/alarms/',
];

class LibraryFilter {
  const LibraryFilter({
    this.minSeconds = 60,
    this.hideMessaging = true,
    this.alwaysShow = const {},
    this.alwaysHide = const {},
  });

  final int minSeconds;
  final bool hideMessaging;
  final Set<String> alwaysShow;
  final Set<String> alwaysHide;

  LibraryFilter copyWith({
    int? minSeconds,
    bool? hideMessaging,
    Set<String>? alwaysShow,
    Set<String>? alwaysHide,
  }) =>
      LibraryFilter(
        minSeconds: minSeconds ?? this.minSeconds,
        hideMessaging: hideMessaging ?? this.hideMessaging,
        alwaysShow: alwaysShow ?? this.alwaysShow,
        alwaysHide: alwaysHide ?? this.alwaysHide,
      );
}

String? hiddenReason(Map<String, dynamic> song, LibraryFilter f) {
  final id = song['id']?.toString() ?? '';
  if (f.alwaysShow.contains(id)) return null;
  if (f.alwaysHide.contains(id)) return 'Ocultada por ti';

  final ms = int.tryParse(song['duration']?.toString() ?? '') ?? 0;
  if (f.minSeconds > 0 && ms > 0 && ms < f.minSeconds * 1000) {
    final limit = f.minSeconds >= 60
        ? '${f.minSeconds ~/ 60} min'
        : '${f.minSeconds} s';
    return 'Dura menos de $limit';
  }

  if (f.hideMessaging) {
    final path = (song['data']?.toString() ?? '').toLowerCase();
    if (_nonMusicFolders.any(path.contains)) {
      return 'Carpeta de mensajería, grabaciones o tonos';
    }
  }
  return null;
}

bool isHiddenSong(Map<String, dynamic> song, LibraryFilter f) =>
    hiddenReason(song, f) != null;

const _kMin = 'lib_min_seconds';
const _kMsg = 'lib_hide_messaging';
const _kShow = 'lib_always_show';
const _kHide = 'lib_always_hide';

final libraryFilterProvider =
    StateNotifierProvider<LibraryFilterNotifier, LibraryFilter>(
  (ref) => LibraryFilterNotifier(),
);

class LibraryFilterNotifier extends StateNotifier<LibraryFilter> {
  LibraryFilterNotifier() : super(const LibraryFilter()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      state = LibraryFilter(
        minSeconds: p.getInt(_kMin) ?? 60,
        hideMessaging: p.getBool(_kMsg) ?? true,
        alwaysShow: (p.getStringList(_kShow) ?? const []).toSet(),
        alwaysHide: (p.getStringList(_kHide) ?? const []).toSet(),
      );
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt(_kMin, state.minSeconds);
      await p.setBool(_kMsg, state.hideMessaging);
      await p.setStringList(_kShow, state.alwaysShow.toList());
      await p.setStringList(_kHide, state.alwaysHide.toList());
    } catch (_) {}
  }

  void setMinSeconds(int v) {
    state = state.copyWith(minSeconds: v);
    _save();
  }

  void setHideMessaging(bool v) {
    state = state.copyWith(hideMessaging: v);
    _save();
  }

  void showAlways(String id) {
    state = state.copyWith(
      alwaysShow: {...state.alwaysShow, id},
      alwaysHide: {...state.alwaysHide}..remove(id),
    );
    _save();
  }

  void hideAlways(String id) {
    state = state.copyWith(
      alwaysHide: {...state.alwaysHide, id},
      alwaysShow: {...state.alwaysShow}..remove(id),
    );
    _save();
  }
}

final hiddenSongsProvider = Provider<List<Map<String, dynamic>>>((ref) {
  final songs =
      ref.watch(localSongsProvider).value ?? const <Map<String, dynamic>>[];
  final f = ref.watch(libraryFilterProvider);
  final list = [
    for (final s in songs)
      if (isHiddenSong(s, f)) s,
  ];
  list.sort(
    (a, b) => (a['title']?.toString() ?? '')
        .toLowerCase()
        .compareTo((b['title']?.toString() ?? '').toLowerCase()),
  );
  return list;
});