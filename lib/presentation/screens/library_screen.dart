import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/library_filter_provider.dart';
import '../widgets/app_scaffold.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  static const _options = <int, String>{
    0: 'Mostrar todo',
    30: '30 s',
    60: '1 min',
    120: '2 min',
  };

  String _fmt(int ms) {
    final s = ms ~/ 1000;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(libraryFilterProvider);
    final notifier = ref.read(libraryFilterProvider.notifier);
    final hidden = ref.watch(hiddenSongsProvider);
    final titleStyle = Theme.of(context)
        .textTheme
        .titleMedium
        ?.copyWith(fontWeight: FontWeight.bold);

    return AppScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Biblioteca'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Text('Duración mínima', style: titleStyle),
          const SizedBox(height: 4),
          const Text(
            'Los audios más cortos no se muestran como canciones (notas de '
            'voz, audios de mensajes, efectos).',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              for (final e in _options.entries)
                ChoiceChip(
                  label: Text(e.value),
                  selected: f.minSeconds == e.key,
                  onSelected: (_) => notifier.setMinSeconds(e.key),
                ),
            ],
          ),
          const Divider(height: 32, color: Colors.white12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Ocultar audios de mensajería y grabaciones'),
            subtitle: const Text(
              'WhatsApp, Telegram, Signal, grabadoras de voz, tonos, '
              'notificaciones y alarmas.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            value: f.hideMessaging,
            onChanged: notifier.setHideMessaging,
          ),
          const Divider(height: 32, color: Colors.white12),
          Text('Canciones ocultas (${hidden.length})', style: titleStyle),
          const SizedBox(height: 4),
          const Text(
            'Si una canción real quedó oculta, toca Mostrar y no se volverá a '
            'ocultar.',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 8),
          if (hidden.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Ninguna.', style: TextStyle(color: Colors.grey)),
            )
          else
            for (final s in hidden)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  s['title']?.toString() ?? 'Sin título',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${_fmt(int.tryParse(s['duration']?.toString() ?? '') ?? 0)}'
                  ' · ${hiddenReason(s, f) ?? ''}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                trailing: TextButton(
                  onPressed: () =>
                      notifier.showAlways(s['id']?.toString() ?? ''),
                  child: const Text('Mostrar'),
                ),
              ),
        ],
      ),
    );
  }
}