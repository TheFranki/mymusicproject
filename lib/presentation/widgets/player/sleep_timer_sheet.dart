import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/sleep_timer_provider.dart';

Future<void> showSleepTimerSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const SleepTimerSheet(),
  );
}

class SleepTimerSheet extends ConsumerWidget {
  const SleepTimerSheet({super.key});

  static const _presets = [5, 10, 15, 30, 45, 60, 120];

  Future<Duration?> _askCustom(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<Duration>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Minutos'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(hintText: 'Ej. 25', suffixText: 'min'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final m = int.tryParse(controller.text.trim());
              if (m != null && m > 0 && m <= 1440) {
                Navigator.pop(ctx, Duration(minutes: m));
              }
            },
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timer = ref.watch(sleepTimerProvider);
    final notifier = ref.read(sleepTimerProvider.notifier);
    final theme = Theme.of(context);

    void pick(Duration d) {
      notifier.start(d);
      Navigator.pop(context);
    }

    final status = !timer.active
        ? 'Detén la música automáticamente'
        : timer.endOfSong
            ? 'Se detendrá al terminar la canción actual'
            : 'Se detendrá en ${formatTimer(timer.remaining!)}';

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Temporizador', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              status,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in _presets)
                  ActionChip(
                    label: Text(m >= 60 && m % 60 == 0 ? '${m ~/ 60} h' : '$m min'),
                    onPressed: () => pick(Duration(minutes: m)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.music_note),
              title: const Text('Al terminar la canción actual'),
              onTap: () {
                notifier.startEndOfSong();
                Navigator.pop(context);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Personalizado'),
              onTap: () async {
                final d = await _askCustom(context);
                if (d != null && context.mounted) pick(d);
              },
            ),
            if (timer.active) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () {
                    notifier.cancel();
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.timer_off_outlined),
                  label: const Text('Cancelar temporizador'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}