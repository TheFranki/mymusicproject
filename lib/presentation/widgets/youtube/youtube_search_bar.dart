import 'package:flutter/material.dart';

class YoutubeSearchBar extends StatelessWidget implements PreferredSizeWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  const YoutubeSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: false,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: 'Buscar canciones...',
        hintStyle: const TextStyle(color: Colors.grey),
        prefixIcon: const Icon(Icons.search, color: Colors.grey),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: Colors.grey.withValues(alpha: 0.15),
        contentPadding: const EdgeInsets.symmetric(vertical: 0),
      ),
      onChanged: onChanged,
      onSubmitted: onSubmitted,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}