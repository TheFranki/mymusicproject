import 'dart:async';

import 'package:mymusicproject/presentation/widgets/home/home_mini_player.dart';
import 'package:mymusicproject/presentation/providers/custom_artwork_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/player_provider.dart';
import '../providers/search_provider.dart';
import '../widgets/youtube/youtube_search_bar.dart';
import '../widgets/youtube/youtube_history_view.dart';
import '../widgets/youtube/youtube_results_view.dart';
import '../screens/player_screen.dart';

import 'package:mymusicproject/presentation/screens/youtube_favorites_screen.dart';
import 'package:mymusicproject/presentation/screens/youtube_playlists_screen.dart';
import 'package:mymusicproject/presentation/widgets/youtube/youtube_category_cards.dart';

import '../providers/player_controller.dart';

class YoutubeSearchScreen extends ConsumerStatefulWidget {
  const YoutubeSearchScreen({super.key});

  @override
  ConsumerState<YoutubeSearchScreen> createState() =>
      _YoutubeSearchScreenState();
}

class _YoutubeSearchScreenState extends ConsumerState<YoutubeSearchScreen> {
  final TextEditingController searchController = TextEditingController();
  Timer? _suggestionTimer;

  @override
  void dispose() {
    _suggestionTimer?.cancel();
    searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _suggestionTimer?.cancel();
    final query = value.trim();

    if (query.isEmpty) {
      ref.read(searchSuggestionsProvider.notifier).state = [];
      ref.read(isFetchingSuggestionsProvider.notifier).state = false;
      return;
    }

    _suggestionTimer = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;
      ref.read(isFetchingSuggestionsProvider.notifier).state = true;
      final extractor = ref.read(ytExtractorProvider);
      try {
        final suggestions = await extractor.getSearchSuggestions(query);
        if (!mounted) return;
        ref.read(searchSuggestionsProvider.notifier).state = suggestions;
      } catch (_) {
        if (!mounted) return;
        ref.read(searchSuggestionsProvider.notifier).state = [];
      } finally {
        if (mounted) {
          ref.read(isFetchingSuggestionsProvider.notifier).state = false;
        }
      }
    });
  }

  Future<void> performSearch(String query) async {
    if (query.trim().isEmpty) return;
    final cleanQuery = query.trim();
    FocusScope.of(context).unfocus();
    _suggestionTimer?.cancel();
    ref.read(searchSuggestionsProvider.notifier).state = [];
    ref.read(isSearchingProvider.notifier).state = true;

    final extractor = ref.read(ytExtractorProvider);
    try {
      final results = await extractor.searchVideos(cleanQuery);
      if (!mounted) return;
      ref.read(searchResultsProvider.notifier).state = results;
      if (results.isNotEmpty) {
        await ref.read(searchHistoryProvider.notifier).addSearch(cleanQuery);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo realizar la búsqueda.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        ref.read(isSearchingProvider.notifier).state = false;
      }
    }
  }

  Future<void> _playSelectedSong(Map<String, String> video) async {
    final playing = ref.read(playerControllerProvider).playYoutube(video);

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PlayerScreen()),
      );
    }
    await playing;
  }

  @override
  Widget build(BuildContext context) {
    final searchResults = ref.watch(searchResultsProvider);
    final isSearching = ref.watch(isSearchingProvider);
    final isGridView = ref.watch(isGridViewProvider);
    final history = ref.watch(searchHistoryProvider);
    final currentSong = ref.watch(effectiveCurrentSongProvider);

    //final isPlayingStream = ref.watch(isPlayingProvider);
    //final isPlaying = isPlayingStream.value ?? false;
    //final isLoadingAudio = ref.watch(isLoadingProvider);
    final hasSearchResults = searchResults.isNotEmpty;

    return PopScope(
      canPop: !hasSearchResults,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && hasSearchResults) {
          ref.read(searchResultsProvider.notifier).state = [];
          searchController.clear();
          ref.read(searchSuggestionsProvider.notifier).state = [];
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F0F),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F0F0F),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (searchResults.isNotEmpty) {
                ref.read(searchResultsProvider.notifier).state = [];
                searchController.clear();
                ref.read(searchSuggestionsProvider.notifier).state = [];
                return;
              }
              Navigator.pop(context);
            },
          ),
          title: YoutubeSearchBar(
            controller: searchController,
            onChanged: _onSearchChanged,
            onSubmitted: performSearch,
          ),
          actions: [
            IconButton(
              icon: Icon(
                isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
              ),
              onPressed: () {
                ref.read(isGridViewProvider.notifier).state = !isGridView;
              },
            ),
          ],
        ),
        body: SafeArea(
          child: isSearching
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : searchResults.isEmpty
              ? _buildSearchHome(history)
              : YoutubeResultsView(
                  results: searchResults,
                  isGridView: isGridView,
                  onSongTap: _playSelectedSong,
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
      ),
    );
  }

  Widget _buildSearchHome(List<String> history) {
    final suggestions = ref.watch(searchSuggestionsProvider);
    final isFetching = ref.watch(isFetchingSuggestionsProvider);
    final query = searchController.text.trim();

    if (query.isNotEmpty) {
      if (isFetching && suggestions.isEmpty) {
        return const Center(
          child: CircularProgressIndicator(color: Colors.white),
        );
      }
      if (suggestions.isNotEmpty) {
        return ListView.builder(
          itemCount: suggestions.length,
          itemBuilder: (context, index) {
            final suggestion = suggestions[index];
            return ListTile(
              leading: const Icon(Icons.search, color: Colors.grey),
              title: Text(
                suggestion,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () {
                searchController.text = suggestion;
                searchController.selection = TextSelection.fromPosition(
                  TextPosition(offset: searchController.text.length),
                );
                ref.read(searchSuggestionsProvider.notifier).state = [];
                performSearch(suggestion);
              },
            );
          },
        );
      }
    }

    // PANTALLA PRINCIPAL DE BÚSQUEDA
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        YoutubeCategoryCards(
          onFavorites: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const YoutubeFavoritesScreen()),
            );
          },
          onPlaylists: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const YoutubePlaylistsScreen()),
            );
          },
        ),
        const SizedBox(height: 4),
        Expanded(
          child: YoutubeHistoryView(
            history: history,
            onItemSelected: (item) {
              searchController.text = item;
              searchController.selection = TextSelection.fromPosition(
                TextPosition(offset: searchController.text.length),
              );
              performSearch(item);
            },
          ),
        ),
      ],
    );
  }
}
