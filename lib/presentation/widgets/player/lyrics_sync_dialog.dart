import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mymusicproject/presentation/providers/player_provider.dart';

void showLyricsSyncDialog(
  BuildContext context, {
  required String songId,
  required ValueChanged<int> onChangeOffset,
  required VoidCallback onEditLyrics,
  required VoidCallback onClearAnchors,
}) {
  showDialog(
    context: context,
    builder: (dialogContext) => Consumer(
      builder: (context, ref, _) {
        final offset = ref.watch(
          customSongMetadataProvider.select(
            (m) => m[songId]?.lyricsOffsetMs ?? 0,
          ),
        );
        final anchorCount = ref.watch(
          customSongMetadataProvider.select(
            (m) => m[songId]?.lyricsAnchors.length ?? 0,
          ),
        );

        Widget btn(String label, int delta) => OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: BorderSide(color: Colors.grey.shade700),
          ),
          onPressed: () => onChangeOffset(offset + delta),
          child: Text(label),
        );

        final sign = offset > 0 ? '+' : '';
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Ajustar sincronización',
            style: TextStyle(color: Colors.white, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Anclas: cuando una línea empiece a sonar, tócala y mantenla presionada \n'
                'Cada ancla corrige solo su tramo.\n'
                'Ajuste general: mueve toda la letra junta (+ si va adelantada, − si va atrasada).',
                style: TextStyle(color: Colors.grey, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              Text(
                '$sign${(offset / 1000).toStringAsFixed(1)} s',
                style: const TextStyle(
                  color: Colors.blueAccent,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  btn('−0.1', -100),
                  btn('−1', -1000),
                  btn('−5', -5000),
                  btn('+0.1', 100),
                  btn('+1', 1000),
                  btn('+5', 5000),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                onEditLyrics();
              },
              child: const Text(
                'Editar letra',
                //style: TextStyle(color: Colors.blueAccent),
              ),
            ),
            if (anchorCount > 0)
              TextButton(
                onPressed: onClearAnchors,
                child: Text(
                  'Quitar anclas ($anchorCount)',
                  //style: const TextStyle(color: Colors.amberAccent),
                ),
              ),
            TextButton(
              onPressed: () => onChangeOffset(0),
              child: const Text(
                'Restablecer',
                //style: TextStyle(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Listo'),
            ),
          ],
        );
      },
    ),
  );
}