import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/app_scaffold.dart';
import '../widgets/discard_guard.dart';
import '../widgets/player/lyrics_custom_translation.dart';

class CustomTranslationScreen extends StatefulWidget {
  const CustomTranslationScreen({
    super.key,
    required this.sourceLines,
    required this.initial,
  });

  final List<String> sourceLines;
  final String initial;

  @override
  State<CustomTranslationScreen> createState() =>
      _CustomTranslationScreenState();
}

class _CustomTranslationScreenState extends State<CustomTranslationScreen> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  bool get _dirty => _controller.text.trim() != widget.initial.trim();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text ?? '';
    if (text.trim().isEmpty) return;
    _controller.text = text;
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Borrar mi traducción?'),
        content: const Text('Se eliminará la traducción guardada de esta canción.'),
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
    if (ok == true && mounted) Navigator.pop(context, '');
  }

  Widget _countBar(int src, int tr) {
    final match = src == tr;
    final color = match ? Colors.greenAccent : Colors.amberAccent;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        match
            ? 'Letra: $src líneas · Traducción: $tr líneas ✓'
            : 'Letra: $src líneas · Traducción: $tr líneas. Las que sobran '
                'se ignoran y las que faltan quedan vacías.',
        style: TextStyle(color: color, fontSize: 12),
      ),
    );
  }

  Widget _editTab() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _paste,
              icon: const Icon(Icons.content_paste, size: 16),
              label: const Text('Pegar del portapapeles'),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              expands: true,
              maxLines: null,
              minLines: null,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Pega aquí la traducción: una línea por cada línea '
                    'de la letra.\nLas líneas vacías y los ♪ se ignoran.',
                hintStyle: const TextStyle(color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewTab() {
    final tr = customTranslationLines(_controller.text);
    final pairs = <(String, String?)>[];
    var k = 0;
    for (final s in widget.sourceLines) {
      if (!isLyricTextLine(s)) continue;
      pairs.add((s.trim(), k < tr.length ? tr[k] : null));
      k++;
    }
    final extra =
        tr.length > pairs.length ? tr.sublist(pairs.length) : const <String>[];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        for (var i = 0; i < pairs.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${i + 1}. ${pairs[i].$1}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                Text(
                  pairs[i].$2 ?? '— sin traducción —',
                  style: TextStyle(
                    color: pairs[i].$2 == null
                        ? Colors.amberAccent
                        : Colors.white,
                    fontSize: 14,
                    fontStyle: pairs[i].$2 == null
                        ? FontStyle.italic
                        : FontStyle.normal,
                  ),
                ),
              ],
            ),
          ),
        if (extra.isNotEmpty) ...[
          const Divider(height: 24, color: Colors.white12),
          const Text(
            'Líneas que sobran (se ignoran):',
            style: TextStyle(color: Colors.amberAccent, fontSize: 12),
          ),
          const SizedBox(height: 4),
          for (final e in extra)
            Text(e, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final src = lyricTextLineCount(widget.sourceLines);
    final tr = customTranslationLines(_controller.text).length;

    return DiscardGuard(
      isDirty: () => _dirty,
      child: DefaultTabController(
        length: 2,
        child: AppScaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: const Text('Mi traducción'),
            actions: [
              if (widget.initial.trim().isNotEmpty)
                IconButton(
                  tooltip: 'Borrar traducción',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _delete,
                ),
              TextButton(
                onPressed: _dirty
                    ? () => Navigator.pop(context, _controller.text.trim())
                    : null,
                child: const Text('Guardar'),
              ),
            ],
            bottom: const TabBar(
              tabs: [Tab(text: 'Editar'), Tab(text: 'Vista previa')],
            ),
          ),
          body: Column(
            children: [
              _countBar(src, tr),
              Expanded(
                child: TabBarView(children: [_editTab(), _previewTab()]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}