import 'package:flutter/material.dart';
import 'package:mymusicproject/presentation/widgets/player/lyrics_translation_service.dart';

class LyricsSearchMenu extends StatelessWidget {
  const LyricsSearchMenu({
    super.key,
    required this.hasLyrics,
    required this.isSynced,
    required this.onAuto,
    required this.onManual,
    required this.onSync,
    required this.onEdit,
    required this.onDelete,
  });

  final bool hasLyrics;
  final bool isSynced;
  final VoidCallback onAuto;
  final VoidCallback onManual;
  final VoidCallback onSync;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.search, color: Colors.white, size: 24),
      tooltip: 'Letra',
      color: const Color(0xFF2A2A2A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) {
        switch (value) {
          case 'auto':
            onAuto();
          case 'manual':
            onManual();
          case 'sync':
            onSync();
          case 'edit':
            onEdit();
          case 'delete':
            onDelete();
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'auto',
          child: Text('Automática', style: TextStyle(color: Colors.white)),
        ),
        const PopupMenuItem(
          value: 'manual',
          child: Text('Manual', style: TextStyle(color: Colors.white)),
        ),
        if (isSynced)
          const PopupMenuItem(
            value: 'sync',
            child: Text(
              'Ajustar sincronización',
              style: TextStyle(color: Colors.white),
            ),
          ),
        if (hasLyrics) ...[
          const PopupMenuItem(
            value: 'edit',
            child: Text('Editar letra', style: TextStyle(color: Colors.white)),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'delete',
            child: Text('Borrar letra', style: TextStyle(color: Colors.white)),
          ),
        ],
      ],
    );
  }
}

class LyricsTranslateMenu extends StatelessWidget {
  const LyricsTranslateMenu({
    super.key,
    required this.mode,
    required this.script,
    required this.onSelected,
  });

  final String mode;

  final String script;
  final ValueChanged<String> onSelected;

  PopupMenuItem<String> _item(String value, String label) {
    final selected = mode == value;
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(
            selected ? Icons.check : Icons.circle_outlined,
            color: selected ? Colors.blueAccent : Colors.white24,
            size: 16,
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: selected ? Colors.blueAccent : Colors.white,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canRomanize = script != 'auto';

    return PopupMenuButton<String>(
      icon: Icon(
        Icons.translate,
        color: mode == 'off' ? Colors.white : Colors.blueAccent,
        size: 22,
      ),
      tooltip: 'Traducción / romanización',
      color: const Color(0xFF2A2A2A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: onSelected,
      itemBuilder: (_) => [
        _item('off', 'Solo original'),
        if (canRomanize)
          _item('rom', LyricsTranslationService.romanizationLabel(script)),
        const PopupMenuDivider(),
        for (final e in LyricsTranslationService.languages.entries)
          _item('tr:${e.key}', e.value),
      ],
    );
  }
}