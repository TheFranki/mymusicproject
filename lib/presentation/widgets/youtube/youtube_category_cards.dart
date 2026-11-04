import 'package:flutter/material.dart';

class YoutubeCategoryCards extends StatelessWidget {
  final VoidCallback onFavorites;
  final VoidCallback onPlaylists;

  const YoutubeCategoryCards({
    super.key,
    required this.onFavorites,
    required this.onPlaylists,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: _buildCard(
              title: 'Favoritos',
              icon: Icons.favorite,
              accentColor: Colors.redAccent,
              onTap: onFavorites,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildCard(
              title: 'Playlists',
              icon: Icons.folder_special,
              accentColor: Colors.blueAccent,
              onTap: onPlaylists,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 80,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10, width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accentColor, size: 20),
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