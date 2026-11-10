import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mymusicproject/presentation/widgets/player/lyrics_search_service.dart';

Future<LyricsCandidate?> showLyricsPicker(
  BuildContext context, {
  required LyricsSearchService service,
  required String initialQuery,
  required List<String> titles,
  required List<String> artists,
  int? durationSec,
}) {
  return showDialog<LyricsCandidate>(
    context: context,
    builder: (_) => _LyricsPickerDialog(
      service: service,
      initialQuery: initialQuery,
      titles: titles,
      artists: artists,
      durationSec: durationSec,
    ),
  );
}

class _LyricsPickerDialog extends StatefulWidget {
  const _LyricsPickerDialog({
    required this.service,
    required this.initialQuery,
    required this.titles,
    required this.artists,
    required this.durationSec,
  });

  final LyricsSearchService service;
  final String initialQuery;
  final List<String> titles;
  final List<String> artists;
  final int? durationSec;

  @override
  State<_LyricsPickerDialog> createState() => _LyricsPickerDialogState();
}

class _LyricsPickerDialogState extends State<_LyricsPickerDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialQuery);
  List<LyricsCandidate> _results = const [];
  bool _loading = true;
  String? _error;
  int _token = 0;

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _run({String? free}) async {
    final token = ++_token;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await widget.service.search(
        titles: widget.titles,
        artists: widget.artists,
        freeQuery: free,
        durationSec: widget.durationSec,
      );
      if (!mounted || token != _token) return;
      setState(() {
        _results = r;
        _loading = false;
      });
    } on LyricsNetworkError {
      if (!mounted || token != _token) return;
      setState(() {
        _error = 'Sin conexión con el servidor de letras. Intenta de nuevo.';
        _loading = false;
      });
    } catch (e) {
      if (!mounted || token != _token) return;
      setState(() {
        _error = 'Error al buscar: $e';
        _loading = false;
      });
    }
  }

  void _submit() {
    final q = _controller.text.trim();
    FocusScope.of(context).unfocus();
    _run(free: q.isEmpty ? null : q);
  }

  String _fmt(int seconds) =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

  Widget _tile(LyricsCandidate c) {
    final dur = c.duration;
    var durText = '';
    if (dur != null) {
      durText = _fmt(dur.round());
      final song = widget.durationSec;
      if (song != null) {
        final d = dur.round() - song;
        final sign = d > 0 ? '+' : '';
        durText += d == 0 ? ' (igual)' : ' ($sign${d}s)';
      }
    }

    final q = c.quality;
    final String status;
    final Color color;
    if (!c.hasSynced) {
      status = 'Solo texto (sin sincronizar)';
      color = Colors.orangeAccent;
    } else if (q != null && !q.isGood) {
      status = 'Sincronizada · posible fallo: ${q.summary}';
      color = Colors.amber;
    } else {
      status = 'Sincronizada';
      color = Colors.greenAccent;
    }

    final meta = [
      if (c.artist.isNotEmpty) c.artist,
      if (durText.isNotEmpty) durText,
    ].join(' · ');

    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(
        c.track.isEmpty ? '(sin título)' : c.track,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(meta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
          if (c.preview.isNotEmpty)
            Text('“${c.preview}”',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                )),
          Text(status, style: TextStyle(color: color, fontSize: 11)),
        ],
      ),
      onTap: () => Navigator.pop(context, c),
    );
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.5;

    Widget body;
    if (_loading) {
      body = const Center(
          child: CircularProgressIndicator(color: Colors.blueAccent));
    } else if (_error != null) {
      body = Center(
        child: Text(_error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
      );
    } else if (_results.isEmpty) {
      body = const Center(
        child: Text(
          'Sin resultados.\nPrueba con el título original (por ejemplo en '
          'japonés) o usa "Pegar letra".',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
      );
    } else {
      body = ListView.separated(
        itemCount: _results.length,
        separatorBuilder: (_, _) =>
            const Divider(height: 1, color: Colors.white12),
        itemBuilder: (_, i) => _tile(_results[i]),
      );
    }

    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Elegir letra',
          style: TextStyle(color: Colors.white, fontSize: 16)),
      content: SizedBox(
        width: double.maxFinite,
        height: height,
        child: Column(
          children: [
            TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: 'Artista y título',
                hintStyle: const TextStyle(color: Colors.grey),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search, color: Colors.grey),
                  onPressed: _submit,
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey.shade700),
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.blueAccent),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(child: body),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
        ),
      ],
    );
  }
}

Future<String?> showPasteLyricsDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (_) => const _PasteLyricsDialog(),
  );
}

class _PasteLyricsDialog extends StatefulWidget {
  const _PasteLyricsDialog();

  @override
  State<_PasteLyricsDialog> createState() => _PasteLyricsDialogState();
}

class _PasteLyricsDialogState extends State<_PasteLyricsDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _fromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text ?? '';
    if (text.isNotEmpty) setState(() => _controller.text = text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Pegar letra',
          style: TextStyle(color: Colors.white, fontSize: 16)),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pega la letra de cualquier página. Si trae tiempos '
              '[01:23.45] se usan tal cual; si no, se reparten '
              'automáticamente según la duración de la canción.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _controller,
              maxLines: 10,
              minLines: 6,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Pega aquí la letra…',
                hintStyle: const TextStyle(color: Colors.grey),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey.shade700),
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.blueAccent),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            /*TextButton.icon(
              onPressed: _fromClipboard,
              icon: const Icon(Icons.content_paste,
                  size: 16, color: Colors.blueAccent),
              label: const Text('Pegar del portapapeles',
                  style: TextStyle(color: Colors.blueAccent, fontSize: 12)),
            ),*/
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
          onPressed: () {
            final t = _controller.text.trim();
            Navigator.pop(context, t.isEmpty ? null : t);
          },
          child: const Text('Usar', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

Future<String?> showEditLyricsDialog(
  BuildContext context, {
  required String initial,
  required Duration Function() currentPosition,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _EditLyricsDialog(
      initial: initial,
      currentPosition: currentPosition,
    ),
  );
}

class _EditLyricsDialog extends StatefulWidget {
  const _EditLyricsDialog({
    required this.initial,
    required this.currentPosition,
  });

  final String initial;
  final Duration Function() currentPosition;

  @override
  State<_EditLyricsDialog> createState() => _EditLyricsDialogState();
}

class _EditLyricsDialogState extends State<_EditLyricsDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _tag(Duration d) {
    final cs = (d.inMilliseconds / 10).round();
    String two(int n) => n.toString().padLeft(2, '0');
    return '[${two(cs ~/ 6000)}:${two((cs % 6000) ~/ 100)}.${two(cs % 100)}]';
  }

  void _insertNote() {
    final text = _controller.text;
    final sel = _controller.selection;
    final pos =
        sel.isValid ? sel.start.clamp(0, text.length).toInt() : text.length;
    final synced = RegExp(r'\[\d{1,3}:\d{2}').hasMatch(text);
    final tag = synced ? _tag(widget.currentPosition()) : '';

    final before = text.substring(0, pos);
    final after = text.substring(pos);
    final prefix = before.isEmpty || before.endsWith('\n') ? '' : '\n';
    final insert = '$prefix$tag♪\n';

    _controller.value = TextEditingValue(
      text: '$before$insert$after',
      selection: TextSelection.collapsed(offset: before.length + insert.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Editar letra',
          style: TextStyle(color: Colors.white, fontSize: 16)),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cada línea con tiempo se ve como texto. '
              'Para marcar una pausa instrumental, escucha la canción hasta '
              'ese punto, pon el cursor y toca "Insertar ♪": se guarda con '
              'el tiempo actual.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _controller,
              maxLines: 12,
              minLines: 8,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey.shade700),
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.blueAccent),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _insertNote,
              icon: const Icon(Icons.music_note,
                  size: 16, color: Colors.blueAccent),
              label: const Text('Insertar ♪',
                  style: TextStyle(color: Colors.blueAccent, fontSize: 12)),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('Guardar', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}