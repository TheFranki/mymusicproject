import 'package:flutter/material.dart';
import 'package:mymusicproject/presentation/widgets/player/lyrics_translation_service.dart';
import 'package:mymusicproject/presentation/providers/lyrics_language_provider.dart';
import 'package:mymusicproject/presentation/providers/library_view_provider.dart';

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
    required this.languages,
    required this.showRomanization,
    required this.onSelected,
    required this.onMore,
    required this.onSettings,
    required this.hasCustom,
    required this.onEditCustom,
    required this.customEnabled,
  });

  final String mode;
  final String script;
  final Map<String, String> languages;
  final bool showRomanization;
  final ValueChanged<String> onSelected;
  final VoidCallback onMore;
  final VoidCallback onSettings;
  final bool hasCustom;
  final VoidCallback onEditCustom;
  final bool customEnabled;

  PopupMenuItem<String> _item(
    BuildContext context,
    String value,
    String label,
  ) {
    final selected = mode == value;
    final primary = Theme.of(context).colorScheme.primary;
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(
            selected ? Icons.check : Icons.circle_outlined,
            color: selected ? primary : Colors.white24,
            size: 16,
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: selected ? primary : Colors.white,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _action(String value, IconData icon, String label) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: Colors.white54, size: 16),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canRomanize = script != 'auto' && showRomanization;
    final activeCode = mode.startsWith('tr:') ? mode.substring(3) : null;
    final extraLabel = activeCode != null && !languages.containsKey(activeCode)
        ? kLyricsLanguageCatalog[activeCode]
        : null;

    return PopupMenuButton<String>(
      icon: Icon(
        Icons.translate,
        color: mode == 'off'
            ? Colors.white
            : Theme.of(context).colorScheme.primary,
        size: 22,
      ),
      tooltip: 'Traducción / romanización',
      color: const Color(0xFF2A2A2A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (v) {
        if (v == 'more') {
          onMore();
        } else if (v == 'settings') {
          onSettings();
        } else if (v == 'myedit') {
          onEditCustom();
        } else {
          onSelected(v);
        }
      },
      itemBuilder: (_) => [
        _item(context, 'off', 'Solo original'),
        if (canRomanize)
          _item(
            context,
            'rom',
            LyricsTranslationService.romanizationLabel(script),
          ),
        if (customEnabled && hasCustom) _item(context, 'my', 'Mi traducción'),
        if (languages.isNotEmpty || extraLabel != null)
          const PopupMenuDivider(),
        for (final e in languages.entries)
          _item(context, 'tr:${e.key}', e.value),
        if (extraLabel != null) _item(context, 'tr:$activeCode', extraLabel),
        const PopupMenuDivider(),
        _action('more', Icons.add, 'Más idiomas…'),
        if (customEnabled)
          _action(
            'myedit',
            Icons.edit_note,
            hasCustom ? 'Editar mi traducción…' : 'Agregar mi traducción…',
          ),
        _action('settings', Icons.tune, 'Configurar idiomas'),
      ],
    );
  }
}

Future<String?> showMoreLanguagesSheet(
  BuildContext context, {
  required Map<String, String> languages,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _MoreLanguagesSheet(languages: languages),
  );
}

class _MoreLanguagesSheet extends StatefulWidget {
  const _MoreLanguagesSheet({required this.languages});
  final Map<String, String> languages;

  @override
  State<_MoreLanguagesSheet> createState() => _MoreLanguagesSheetState();
}

class _MoreLanguagesSheetState extends State<_MoreLanguagesSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final height = (mq.size.height - mq.viewInsets.bottom) * 0.7;
    final q = normalizeSearch(_q);
    final entries = widget.languages.entries
        .where((e) => q.isEmpty || normalizeSearch(e.value).contains(q))
        .toList();

    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: SizedBox(
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Traducir a…',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Buscar idioma',
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onChanged: (v) => setState(() => _q = v),
              ),
            ),
            Expanded(
              child: entries.isEmpty
                  ? const Center(child: Text('Sin resultados.'))
                  : ListView(
                      children: [
                        for (final e in entries)
                          ListTile(
                            title: Text(e.value),
                            onTap: () => Navigator.pop(context, e.key),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
