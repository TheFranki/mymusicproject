import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomeCategoryCards extends ConsumerWidget {
  final VoidCallback onFavorites;
  final VoidCallback onSearch;
  final VoidCallback onPlayLists;

  const HomeCategoryCards({
    super.key,
    required this.onFavorites,
    required this.onSearch,
    required this.onPlayLists,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: _buildCategoryCard(
              title: 'Favoritos',
              icon: Icons.favorite,
              accentColor: Colors.pinkAccent,
              onTap: onFavorites,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildCategoryCard(
              title: 'Playlists',
              icon: Icons.folder_special,
              accentColor: Colors.purpleAccent,
              onTap: onPlayLists,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildCategoryCard(
              title: 'Buscar Online',
              icon: Icons.search,
              accentColor: Colors.blueAccent,
              onTap: onSearch,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard({
    required String title,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 85,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              /*decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),*/
              child: Icon(icon, color: accentColor, size: 22),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}