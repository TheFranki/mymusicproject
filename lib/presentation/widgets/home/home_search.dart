import 'package:flutter/material.dart';

class HomeSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;
  final VoidCallback onClear;
  final String query;

  const HomeSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
    required this.query,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: TextField(
        controller: controller,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
        ),
        decoration: InputDecoration(
          hintText: 'Buscar en tu música...',
          hintStyle: const TextStyle(
            color: Colors.grey,
            fontSize: 13,
          ),
          prefixIcon: const Icon(
            Icons.search,
            color: Colors.grey,
            size: 18,
          ),
          suffixIcon: query.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    Icons.clear,
                    color: Colors.grey,
                    size: 16,
                  ),
                  onPressed: onClear,
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.grey.withValues(alpha: 0.15),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 0,
            horizontal: 8,
          ),
        ),
        onChanged: onChanged,
        onSubmitted: (_) => onSubmitted(),
      ),
    );
  }
}
