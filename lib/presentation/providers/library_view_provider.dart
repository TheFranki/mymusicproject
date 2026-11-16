import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'custom_artwork_provider.dart';
import 'local_music_provider.dart';
import 'player_provider.dart';

const _foldMap = {
  'a': 'áàäâãåāăą',
  'c': 'çćč',
  'd': 'ď',
  'e': 'éèëêēěę',
  'i': 'íìïîīı',
  'l': 'ł',
  'n': 'ñńň',
  'o': 'óòöôõøōő',
  'r': 'ŕř',
  's': 'śšş',
  't': 'ť',
  'u': 'úùüûūůű',
  'y': 'ýÿ',
  'z': 'źžż',
};

final Map<int, String> _fold = {
  for (final e in _foldMap.entries)
    for (final r in e.value.runes) r: e.key,
};

String normalizeSearch(String input) {
  final sb = StringBuffer();
  for (final r in input.toLowerCase().runes) {
    sb.write(_fold[r] ?? String.fromCharCode(r));
  }
  return sb.toString().trim();
}

final librarySearchQueryProvider = StateProvider<String>((ref) => '');

class LibraryView {
  const LibraryView(this.songs, this.keys);
  final List<Map<String, dynamic>> songs;
  final Map<String, String> keys;
}

class _Entry {
  _Entry(this.song, this.titleKey, this.artistKey, this.date);
  final Map<String, dynamic> song;
  final String titleKey;
  final String artistKey;
  final int date;
  String get searchKey => '$titleKey $artistKey';
}

int _compare(_Entry a, _Entry b, String option, Map<String, int> plays) {
  switch (option) {
    case 'name_desc':
      return b.titleKey.compareTo(a.titleKey);
    case 'author_asc':
      {
        final c = a.artistKey.compareTo(b.artistKey);
        return c != 0 ? c : a.titleKey.compareTo(b.titleKey);
      }
    case 'author_desc':
      {
        final c = b.artistKey.compareTo(a.artistKey);
        return c != 0 ? c : a.titleKey.compareTo(b.titleKey);
      }
    case 'date':
      return b.date.compareTo(a.date);
    case 'plays':
      {
        final ca = plays[a.song['id']?.toString()] ?? 0;
        final cb = plays[b.song['id']?.toString()] ?? 0;
        final c = cb.compareTo(ca);
        return c != 0 ? c : a.titleKey.compareTo(b.titleKey);
      }
    default:
      return a.titleKey.compareTo(b.titleKey);
  }
}

final sortedLibraryProvider = Provider<AsyncValue<LibraryView>>((ref) {
  final songsAsync = ref.watch(localSongsProvider);
  final metadata = ref.watch(customSongMetadataProvider);
  final sort = ref.watch(sortOptionProvider);
  final plays =
      sort == 'plays' ? ref.watch(playCountProvider) : const <String, int>{};

  return songsAsync.whenData((songs) {
    final entries = <_Entry>[];
    for (final song in songs) {
      final id = song['id']?.toString() ?? '';
      final meta = metadata[id];

      final title = meta?.title.isNotEmpty == true
          ? meta!.title
          : (song['title']?.toString() ?? '');
      final artist = meta?.artist.isNotEmpty == true
          ? meta!.artist
          : (song['artist']?.toString() ?? song['author']?.toString() ?? '');

      final date = int.tryParse(
            song['date']?.toString() ?? song['id']?.toString() ?? '0',
          ) ??
          0;

      entries.add(
        _Entry(
          {...song, 'effectiveTitle': title, 'effectiveArtist': artist},
          normalizeSearch(title),
          normalizeSearch(artist),
          date,
        ),
      );
    }

    entries.sort((a, b) => _compare(a, b, sort, plays));

    return LibraryView(
      [for (final e in entries) e.song],
      {for (final e in entries) e.song['id']?.toString() ?? '': e.searchKey},
    );
  });
});

final filteredSongsProvider =
    Provider<AsyncValue<List<Map<String, dynamic>>>>((ref) {
  final view = ref.watch(sortedLibraryProvider);
  final tokens = normalizeSearch(ref.watch(librarySearchQueryProvider))
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .toList();

  return view.whenData((v) {
    if (tokens.isEmpty) return v.songs;
    return v.songs.where((s) {
      final key = v.keys[s['id']?.toString() ?? ''] ?? '';
      return tokens.every((t) => key.contains(t));
    }).toList();
  });
});