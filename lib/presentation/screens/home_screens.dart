import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mymusicproject/presentation/providers/player_provider.dart';
import 'package:mymusicproject/presentation/screens/playlists_screen.dart';
import 'package:mymusicproject/presentation/widgets/home/home_category_cards.dart';
import 'package:mymusicproject/presentation/widgets/home/home_search.dart';
import 'package:mymusicproject/presentation/widgets/home/home_mini_player.dart';
import 'package:mymusicproject/presentation/widgets/home/song_sort_sheet.dart';
import 'package:mymusicproject/presentation/widgets/home/home_action.dart';
import 'package:mymusicproject/presentation/widgets/home/song_list.dart';

import 'player_screen.dart';
import 'youtube_search_screen.dart';

import 'package:mymusicproject/presentation/screens/favorites_screen.dart';
import 'package:mymusicproject/presentation/providers/local_music_provider.dart';
import 'package:mymusicproject/presentation/providers/custom_artwork_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final HomeAction _homeAction = HomeAction();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int _compare(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
    String option,
    Map<String, int> playCountMap,
  ) {
    final titleA = a['effectiveTitle'].toString().toLowerCase();
    final titleB = b['effectiveTitle'].toString().toLowerCase();
    final artistA = a['effectiveArtist'].toString().toLowerCase();
    final artistB = b['effectiveArtist'].toString().toLowerCase();

    switch (option) {
      case 'name_desc':
        return titleB.compareTo(titleA);
      case 'author_asc':
        final c = artistA.compareTo(artistB);
        return c != 0 ? c : titleA.compareTo(titleB);
      case 'author_desc':
        final c = artistB.compareTo(artistA);
        return c != 0 ? c : titleA.compareTo(titleB);
      case 'date':
        final dateA =
            int.tryParse(a['date']?.toString() ?? a['id']?.toString() ?? '0') ??
            0;
        final dateB =
            int.tryParse(b['date']?.toString() ?? b['id']?.toString() ?? '0') ??
            0;
        return dateB.compareTo(dateA);
      case 'plays':
        final countA = playCountMap[a['id']?.toString()] ?? 0;
        final countB = playCountMap[b['id']?.toString()] ?? 0;
        final c = countB.compareTo(countA);
        return c != 0 ? c : titleA.compareTo(titleB);
      default:
        return titleA.compareTo(titleB);
    }
  }

  @override
  Widget build(BuildContext context) {
    final songsAsync = ref.watch(localSongsProvider);
    final currentSong = ref.watch(effectiveCurrentSongProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: HomeSearchBar(
          controller: _searchController,
          query: _searchQuery,
          onChanged: (value) {
            setState(() => _searchQuery = value.trim().toLowerCase());
          },
          onSubmitted: () => FocusScope.of(context).unfocus(),
          onClear: () {
            _searchController.clear();
            setState(() => _searchQuery = '');
            FocusScope.of(context).unfocus();
          },
        ),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          FocusManager.instance.primaryFocus?.unfocus();
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HomeCategoryCards(
              onFavorites: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FavoritesScreen()),
                );
              },
              onSearch: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const YoutubeSearchScreen(),
                  ),
                );
              },
              onPlayLists: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PlaylistsScreen()),
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 4.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(120, 36),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.shuffle, size: 16),
                    label: const Text(
                      'Aleatorio',
                      style: TextStyle(fontSize: 12),
                    ),
                    onPressed: () {
                      songsAsync.whenData((songs) {
                        _homeAction.playRandomSong(
                          ref: ref,
                          context: context,
                          songs: List<Map<String, dynamic>>.from(songs),
                        );
                      });
                    },
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.grey.shade700),
                      minimumSize: const Size(110, 36),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.sort, size: 16, color: Colors.grey),
                    label: const Text(
                      'Ordenar',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    onPressed: () {
                      SongSortBottomSheet.show(
                        context: context,
                        selectedOption: ref.read(sortOptionProvider),
                        onSelected: (option) {
                          ref.read(sortOptionProvider.notifier).state = option;
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: songsAsync.when(
                data: (songs) {
                  final metadataMap = ref.watch(customSongMetadataProvider);
                  final sortOption = ref.watch(sortOptionProvider);
                  final playCountMap = ref.watch(playCountProvider);
                  final processedSongs = songs.map((song) {
                    final id = song['id']?.toString() ?? '';
                    final metadata = metadataMap[id];

                    final title = metadata?.title.isNotEmpty == true
                        ? metadata!.title
                        : (song['title']?.toString() ?? '');

                    final artist = metadata?.artist.isNotEmpty == true
                        ? metadata!.artist
                        : (song['artist']?.toString() ??
                              song['author']?.toString() ??
                              '');

                    return <String, dynamic>{
                      ...song,
                      'effectiveTitle': title,
                      'effectiveArtist': artist,
                    };
                  }).toList();

                  processedSongs.sort(
                    (a, b) => _compare(a, b, sortOption, playCountMap),
                  );

                  final filteredSongs = processedSongs.where((song) {
                    final title = song['effectiveTitle']
                        .toString()
                        .toLowerCase();
                    final artist = song['effectiveArtist']
                        .toString()
                        .toLowerCase();
                    return title.contains(_searchQuery) ||
                        artist.contains(_searchQuery);
                  }).toList();

                  return SongList(
                    songs: filteredSongs,
                    onSongTap: (song) async {
                      await _homeAction.playSongAndNavigate(
                        ref: ref,
                        context: context,
                        song: song,
                        queue: filteredSongs,
                      );
                    },
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
                error: (error, stack) => Center(
                  child: Text(
                    'Error: $error',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar:
          currentSong != null &&
              currentSong['id'] != null &&
              currentSong['id'].toString().isNotEmpty
          ? HomeMiniPlayer(
              song: Map<String, dynamic>.from(currentSong),
              artwork:
                  ref.watch(customArtworkProvider)[currentSong['id']
                      .toString()] ??
                  currentSong['thumbnail']?.toString(),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PlayerScreen()),
                );
              },
            )
          : null,
    );
  }
}
