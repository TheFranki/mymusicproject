import 'package:flutter/material.dart';

const _sheetShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
);

void showManualLyricsSheet(
  BuildContext context, {
  required VoidCallback onSearch,
  required VoidCallback onPaste,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.grey.shade900,
    shape: _sheetShape,
    builder: (sheetContext) => SafeArea(
      child: Wrap(
        children: [
          ListTile(
            //leading: const Icon(Icons.search, color: Colors.blueAccent),
            title: const Text(
              'Buscar y elegir resultado',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              'Escribe el nombre (también en japonés)',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            onTap: () {
              Navigator.pop(sheetContext);
              onSearch();
            },
          ),
          ListTile(
            //leading: const Icon(Icons.content_paste, color: Colors.blueAccent),
            title: const Text(
              'Pegar letra',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              'Copia la letra de una página, se sincroniza automáticamente',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            onTap: () {
              Navigator.pop(sheetContext);
              onPaste();
            },
          ),
        ],
      ),
    ),
  );
}

void showAnchorSheet(
  BuildContext context, {
  required VoidCallback onRefix,
  required VoidCallback onRemove,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.grey.shade900,
    shape: _sheetShape,
    builder: (sheetContext) => SafeArea(
      child: Wrap(
        children: [
          ListTile(
            //leading: const Icon(Icons.my_location, color: Colors.blueAccent),
            title: const Text(
              'Fijar aquí de nuevo',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              'Usa la posición actual de la canción',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            onTap: () {
              Navigator.pop(sheetContext);
              onRefix();
            },
          ),
          ListTile(
            //leading: const Icon(Icons.location_off, color: Colors.redAccent),
            title: const Text(
              'Quitar ancla',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () {
              Navigator.pop(sheetContext);
              onRemove();
            },
          ),
        ],
      ),
    ),
  );
}