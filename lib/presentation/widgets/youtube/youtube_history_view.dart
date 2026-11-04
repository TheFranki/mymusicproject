import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mymusicproject/presentation/providers/search_provider.dart';

class YoutubeHistoryView extends ConsumerWidget {
  final List<String> history;
  final ValueChanged<String> onItemSelected;

  const YoutubeHistoryView({
    super.key,
    required this.history,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (history.isEmpty) {
      return Center(
        child: Text(
          'Busca tu música',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Búsquedas recientes',
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
              GestureDetector(
                onTap: () {
                  ref.read(searchHistoryProvider.notifier).clearHistory();
                },
                child: const Text(
                  'BORRAR TODO',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: history.length,
            itemBuilder: (context, index) {
              final item = history[index];
              return ListTile(
                leading: const Icon(Icons.history, color: Colors.grey),
                title: Text(item, style: const TextStyle(color: Colors.white)),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                  onPressed: () {
                    ref.read(searchHistoryProvider.notifier).removeSearch(item);
                  },
                ),
                onTap: () => onItemSelected(item),
              );
            },
          ),
        ),
      ],
    );
  }
}