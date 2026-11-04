import 'package:flutter/material.dart';

class YoutubeResultsView extends StatelessWidget {
  final List<Map<String, String>> results;
  final bool isGridView;
  final ValueChanged<Map<String, String>> onSongTap;

  const YoutubeResultsView({
    super.key,
    required this.results,
    required this.isGridView,
    required this.onSongTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isGridView) {
      return GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.8,
        ),
        itemCount: results.length,
        itemBuilder: (context, index) {
          final video = results[index];
          return GestureDetector(
            onTap: () => onSongTap(video),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      video['thumbnail'] ?? '',
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: Colors.grey.shade800,
                        child: const Center(child: Icon(Icons.music_note)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  video['title'] ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  '${video['author'] ?? ''} • ${video['duration'] ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          );
        },
      );
    }

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final video = results[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              video['thumbnail'] ?? '',
              width: 80,
              height: 60,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 80,
                height: 60,
                color: Colors.grey.shade800,
                child: const Icon(Icons.music_note),
              ),
            ),
          ),
          
          title: Text(
            video['title'] ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white),
          ),
          subtitle: Text(
            '${video['author'] ?? ''} • ${video['duration'] ?? ''}',
            style: const TextStyle(color: Colors.grey),
          ),
          onTap: () => onSongTap(video),
        );
      },
    );
  }
}