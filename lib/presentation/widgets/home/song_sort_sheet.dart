import 'package:flutter/material.dart';

class SongSortBottomSheet extends StatelessWidget {
  final String selectedOption;
  final ValueChanged<String> onSelected;

  const SongSortBottomSheet({
    super.key,
    required this.selectedOption,
    required this.onSelected,
  });

  static Future<void> show({
    required BuildContext context,
    required String selectedOption,
    required ValueChanged<String> onSelected,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey.shade900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (_) => SongSortBottomSheet(
        selectedOption: selectedOption,
        onSelected: onSelected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final options = [
      (
        value: 'name_asc',
        title: 'Nombre (A - Z)',
        icon: Icons.sort_by_alpha,
        color: Colors.blueAccent,
      ),
      (
        value: 'name_desc',
        title: 'Nombre (Z - A)',
        icon: Icons.sort_by_alpha,
        color: Colors.blueAccent,
      ),
      (
        value: 'author_asc',
        title: 'Autor (A - Z)',
        icon: Icons.sort_by_alpha,
        color: Colors.blueAccent,
      ),
      (
        value: 'author_desc',
        title: 'Autor (Z - A)',
        icon: Icons.sort_by_alpha,
        color: Colors.blueAccent,
      ),
      (
        value: 'date',
        title: 'Por fecha',
        icon: Icons.calendar_today,
        color: Colors.greenAccent,
      ),
      (
        value: 'plays',
        title: 'Más reproducidas',
        icon: Icons.trending_up,
        color: Colors.pinkAccent,
      ),
    ];

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 15),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade700,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Ordenar música',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              ...options.map(
                (option) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    option.icon,
                    color: option.color,
                  ),
                  title: Text(
                    option.title,
                    style: const TextStyle(color: Colors.white),
                  ),
                  trailing: selectedOption == option.value
                      ? const Icon(
                          Icons.check,
                          color: Colors.blueAccent,
                        )
                      : null,
                  onTap: () {
                    onSelected(option.value);
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
