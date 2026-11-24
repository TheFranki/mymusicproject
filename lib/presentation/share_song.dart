/*import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'error_messages.dart';
import 'widgets/app_snack.dart';

const _channel = MethodChannel('com.mymusicproject/mediastore');

Future<void> shareSong(
  BuildContext context, {
  required String id,
  required String title,
  required String artist,
}) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.audio_file_outlined),
            title: const Text('Enviar el archivo de audio'),
            subtitle: const Text('Por WhatsApp, Telegram, correo…'),
            onTap: () => Navigator.pop(ctx, 'file'),
          ),
          ListTile(
            leading: const Icon(Icons.text_snippet_outlined),
            title: const Text('Compartir el nombre'),
            subtitle: Text(
              artist.isEmpty ? '"$title"' : '"$title - $artist"',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => Navigator.pop(ctx, 'text'),
          ),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return;

  try {
    await _channel.invokeMethod('shareSong', {
      'id': id,
      'title': title,
      'artist': artist,
      'asFile': choice == 'file',
    });
  } catch (e, st) {
    logError('Compartir', e, st);
    if (context.mounted) {
      context.snack(
        friendlyError(e, what: 'No se pudo compartir'),
        kind: AppSnackKind.error,
      );
    }
  }
}*/