import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final isSearchingProvider = StateProvider<bool>((ref) => false);
final searchResultsProvider = StateProvider<List<Map<String, String>>>((ref) => []);
final searchSuggestionsProvider = StateProvider<List<String>>((ref) => []);
final isFetchingSuggestionsProvider = StateProvider<bool>((ref) => false);
final recentSearchesProvider = StateProvider<List<String>>((ref) => []);
final isGridViewProvider = StateProvider<bool>((ref) => false);
final relatedVideosProvider = StateProvider<List<Map<String, String>>>((ref) => []);
final isLoadingRelatedProvider = StateProvider<bool>((ref) => false);
final searchHistoryProvider = StateNotifierProvider<SearchHistoryNotifier, List<String>>((ref) {
  return SearchHistoryNotifier();
});

class SearchHistoryNotifier extends StateNotifier<List<String>> {
  SearchHistoryNotifier() : super([]) {
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getStringList('search_history') ?? [];
  }

  Future<void> addSearch(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return;
    
    final newList = [clean, ...state.where((item) => item != clean)];
    if (newList.length > 20) newList.removeRange(20, newList.length);

    state = newList;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('search_history', state);
  }

  Future<void> removeSearch(String query) async {
    state = state.where((item) => item != query).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('search_history', state);
  }

  Future<void> clearHistory() async {
    state = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('search_history');
  }
}