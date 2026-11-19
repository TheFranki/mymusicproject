import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/lyrics_language_provider.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/player/lyrics_translation_store.dart';
import '../providers/library_view_provider.dart';

class LanguagesScreen extends ConsumerWidget {
  const LanguagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(lyricsLangSettingsProvider);
    final notifier = ref.read(lyricsLangSettingsProvider.notifier);
    final titleStyle = Theme.of(context).textTheme.titleMedium
        ?.copyWith(fontWeight: FontWeight.bold);

    return AppScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Idiomas'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Text('Idiomas para traducir', style: titleStyle),
          const SizedBox(height: 4),
          const Text(
            'Los que marques aparecen en el menú de traducción de la letra. '
            'Los demás siguen disponibles en "Más idiomas…".',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 8),
          const _LanguageList(),
          const Divider(height: 32, color: Colors.white12),
          Text('Automático', style: titleStyle),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Ocultar el idioma de la canción'),
            subtitle: const Text(
              'Si la letra está en inglés, no ofrece traducir al inglés.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            value: s.hideOriginal,
            onChanged: notifier.setHideOriginal,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Mostrar romanización'),
            subtitle: const Text(
              'Romaji, pinyin, etc. cuando la letra no usa alfabeto latino.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            value: s.showRomanization,
            onChanged: notifier.setShowRomanization,
          ),
          const _SavedTranslations(),
          const Divider(height: 32, color: Colors.white12),
          Text('Traducción propia', style: titleStyle),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Permitir "Mi traducción"'),
            subtitle: const Text(
              'Muestra en el menú de la letra la opción de pegar tu propia '
              'traducción (por ejemplo, de canciones de videojuegos). Lo que '
              'ya guardaste no se borra si lo apagas.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            value: s.customTranslationEnabled,
            onChanged: notifier.setCustomTranslationEnabled,
          ),
        ],
      ),
    );
  }
}

class _SavedTranslations extends StatefulWidget {
  const _SavedTranslations();

  @override
  State<_SavedTranslations> createState() => _SavedTranslationsState();
}

class _SavedTranslationsState extends State<_SavedTranslations> {
  final _store = TranslationStore.instance;
  int _count = 0;
  int _bytes = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    await _store.ensureLoaded();
    final bytes = await _store.fileSize();
    if (!mounted) return;
    setState(() {
      _count = _store.count;
      _bytes = bytes;
    });
  }

  String get _sizeText => _bytes < 1024 * 1024
      ? '${(_bytes / 1024).round()} KB'
      : '${(_bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Borrar traducciones guardadas?'),
        content: const Text(
          'Las letras traducidas dejarán de estar disponibles sin internet '
          'hasta que las vuelvas a traducir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _store.clear();
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Traducciones guardadas',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Lo que traduces se guarda en el teléfono y se puede ver sin internet.',
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('$_count líneas guardadas'),
          subtitle: Text(
            _sizeText,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          trailing: TextButton(
            onPressed: _count == 0 ? null : _confirmClear,
            child: const Text('Borrar'),
          ),
        ),
      ],
    );
  }
}

class _LanguageList extends ConsumerStatefulWidget {
  const _LanguageList();

  @override
  ConsumerState<_LanguageList> createState() => _LanguageListState();
}

class _LanguageListState extends ConsumerState<_LanguageList> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(lyricsLangSettingsProvider);
    final notifier = ref.read(lyricsLangSettingsProvider.notifier);
    final q = normalizeSearch(_query);
    final entries = kLyricsLanguageCatalog.entries
        .where((e) => q.isEmpty || normalizeSearch(e.value).contains(q))
        .toList();

    return Column(
      children: [
        TextField(
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: 'Buscar idioma',
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
        const SizedBox(height: 8),
        if (entries.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Sin resultados.',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        for (final e in entries)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(e.value),
            value: s.enabled.contains(e.key),
            onChanged: (v) => notifier.toggleLanguage(e.key, v),
          ),
      ],
    );
  }
}
