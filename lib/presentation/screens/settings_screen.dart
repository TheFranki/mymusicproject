import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';
import '../widgets/color_picker_dialog.dart';
import '../widgets/song_artwork.dart';
import '../widgets/song_row_frame.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  static const List<Color> _accents = [
    Colors.blueAccent,
    Colors.lightBlueAccent,
    Colors.cyanAccent,
    Colors.tealAccent,
    Colors.greenAccent,
    Colors.lightGreenAccent,
    Colors.yellowAccent,
    Colors.amberAccent,
    Colors.orangeAccent,
    Colors.deepOrangeAccent,
    Colors.redAccent,
    Colors.pinkAccent,
    Colors.purpleAccent,
    Colors.deepPurpleAccent,
    Colors.indigoAccent,
  ];

  late AppThemeConfig _saved; // lo que está guardado
  late AppThemeConfig _draft; // lo que se está editando

  @override
  void initState() {
    super.initState();
    _saved = ref.read(appThemeProvider);
    _draft = _saved;
  }

  bool get _dirty => !_draft.sameLook(_saved);

  void _set(AppThemeConfig c) {
    setState(() => _draft = c.copyWith(bg: c.bg.map(clampBg).toList()));
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    await ref.read(appThemeProvider.notifier).set(_draft);
    if (!mounted) return;
    setState(() => _saved = _draft);
    messenger.showSnackBar(const SnackBar(content: Text('Tema guardado')));
    nav.pop();
  }

  Future<void> _confirmExit() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Descartar cambios?'),
        content: const Text('Hiciste cambios que no se han guardado.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Seguir editando'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.pop(context);
  }

  Future<void> _pickAccent() async {
    final c = await showColorPickerDialog(context, initial: _draft.accent);
    if (c != null) _set(_draft.copyWith(name: 'Personalizado', accent: c));
  }

  Future<void> _pickBg(int i) async {
    final c = await showColorPickerDialog(
      context,
      initial: _draft.bg[i],
      maxValue: kMaxBgBrightness,
    );
    if (c == null) return;
    final list = [..._draft.bg]..[i] = c;
    _set(_draft.copyWith(name: 'Personalizado', bg: list));
  }

  void _setBgCount(int n) {
    final list = [..._draft.bg];
    while (list.length < n) {
      list.add(clampBg(Color.lerp(list.last, _draft.accent, 0.25)!));
    }
    _set(_draft.copyWith(name: 'Personalizado', bg: list.take(n).toList()));
  }

  Future<void> _pickRowColor() async {
    final c = await showColorPickerDialog(context, initial: _draft.lineColor);
    if (c != null) _set(_draft.copyWith(name: 'Personalizado', rowColor: c));
  }

  @override
  Widget build(BuildContext context) {
    final d = _draft;

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      // La pantalla entera usa el borrador como vista previa en vivo.
      child: Theme(
        data: buildAppTheme(d),
        child: DecoratedBox(
          decoration: d.decoration,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              title: const Text('Ajustes'),
            ),
            body: SafeArea(
              top: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    children: [
                      const _SectionTitle('Vista previa'),
                      _Preview(cfg: d),

                      const _SectionTitle('Paletas'),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (final p in AppThemePresets.all)
                            _PresetTile(
                              preset: p,
                              selected: p.sameColors(d),
                              // conserva tu estilo de filas al cambiar de paleta
                              onTap: () => _set(
                                p.copyWith(
                                  rowStyle: d.rowStyle,
                                  rowColor: d.rowColor,
                                  clearRowColor: d.rowColor == null,
                                ),
                              ),
                            ),
                        ],
                      ),

                      const _SectionTitle('Color de acento'),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final c in _accents)
                            _Dot(
                              color: c,
                              selected: c.toARGB32() == d.accent.toARGB32(),
                              onTap: () => _set(
                                d.copyWith(name: 'Personalizado', accent: c),
                              ),
                            ),
                          _CustomDot(onTap: _pickAccent),
                        ],
                      ),

                      const _SectionTitle('Fondo'),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final n in [1, 2, 3])
                            ChoiceChip(
                              label: Text(n == 1 ? 'Sólido' : '$n colores'),
                              selected: d.bg.length == n,
                              onSelected: (_) => _setBgCount(n),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          for (var i = 0; i < d.bg.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: _Dot(
                                color: d.bg[i],
                                selected: false,
                                size: 44,
                                outlined: true,
                                onTap: () => _pickBg(i),
                              ),
                            ),
                        ],
                      ),
                      if (d.isGradient) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final dir in GradientDir.values)
                              ChoiceChip(
                                label: Text(dir.label),
                                selected: d.dir == dir,
                                onSelected: (_) => _set(
                                  d.copyWith(name: 'Personalizado', dir: dir),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        TextButton.icon(
                          onPressed: () => _set(
                            d.copyWith(
                              name: 'Personalizado',
                              bg: d.bg.reversed.toList(),
                            ),
                          ),
                          icon: const Icon(Icons.swap_vert),
                          label: const Text('Invertir colores'),
                        ),
                      ],

                      const _SectionTitle('Lista de canciones'),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final s in RowStyle.values)
                            ChoiceChip(
                              label: Text(s.label),
                              selected: d.rowStyle == s,
                              onSelected: (_) => _set(
                                d.copyWith(name: 'Personalizado', rowStyle: s),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Color de las líneas',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          ChoiceChip(
                            label: const Text('Igual al acento'),
                            selected: d.rowColor == null,
                            onSelected: (_) => _set(
                              d.copyWith(
                                name: 'Personalizado',
                                clearRowColor: true,
                              ),
                            ),
                          ),
                          for (final c in _accents)
                            _Dot(
                              color: c,
                              selected:
                                  d.rowColor?.toARGB32() == c.toARGB32(),
                              size: 30,
                              onTap: () => _set(
                                d.copyWith(name: 'Personalizado', rowColor: c),
                              ),
                            ),
                          _CustomDot(onTap: _pickRowColor),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _RowPreview(cfg: d),

                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: () => _set(AppThemePresets.all.first),
                        icon: const Icon(Icons.restart_alt),
                        label: const Text('Restablecer valores por defecto'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            bottomNavigationBar: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _dirty
                            ? () => setState(() => _draft = _saved)
                            : null,
                        child: const Text('Descartar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _dirty ? _save : null,
                        icon: const Icon(Icons.check),
                        label: const Text('Guardar'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 10),
        child: Text(
          text,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      );
}

class _Preview extends StatelessWidget {
  const _Preview({required this.cfg});
  final AppThemeConfig cfg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cfg.decoration.copyWith(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: cfg.accent.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.music_note, color: cfg.accent),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Canción de ejemplo',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text('Artista', style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
              Icon(Icons.play_circle_fill, color: cfg.accent, size: 36),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: 0.4,
              minHeight: 4,
              color: cfg.accent,
              backgroundColor: Colors.white24,
            ),
          ),
        ],
      ),
    );
  }
}

class _PresetTile extends StatelessWidget {
  const _PresetTile({
    required this.preset,
    required this.selected,
    required this.onTap,
  });
  final AppThemeConfig preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 104,
        height: 72,
        padding: const EdgeInsets.all(8),
        decoration: preset.decoration.copyWith(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? preset.accent : Colors.white24,
            width: selected ? 2.5 : 1,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              right: 0,
              child: selected
                  ? Icon(Icons.check_circle, size: 18, color: preset.accent)
                  : CircleAvatar(radius: 7, backgroundColor: preset.accent),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              child: Text(
                preset.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({
    required this.color,
    required this.selected,
    required this.onTap,
    this.size = 36,
    this.outlined = false,
  });
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final double size;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? Colors.white
                : (outlined ? Colors.white54 : Colors.transparent),
            width: selected ? 3 : 1.5,
          ),
        ),
        child: selected
            ? Icon(
                Icons.check,
                size: 18,
                color: color.computeLuminance() > 0.5
                    ? Colors.black
                    : Colors.white,
              )
            : null,
      ),
    );
  }
}

class _CustomDot extends StatelessWidget {
  const _CustomDot({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: SweepGradient(
            colors: [
              Colors.red,
              Colors.yellow,
              Colors.green,
              Colors.cyan,
              Colors.blue,
              Colors.purple,
              Colors.red,
            ],
          ),
        ),
        child: const Icon(Icons.add, size: 18, color: Colors.white),
      ),
    );
  }
}

class _RowPreview extends StatelessWidget {
  const _RowPreview({required this.cfg});
  final AppThemeConfig cfg;

  Widget _row(String title, {required bool playing}) => SongRowFrame(
        cfg: cfg,
        isPlaying: playing,
        child: ListTile(
          leading: buildSongArtwork(artworkPathOrUrl: null),
          title: Text(
            title,
            style: TextStyle(
              color: playing ? cfg.lineTextColor : Colors.white,
              fontSize: 14,
              fontWeight: playing ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          subtitle: const Text(
            'Artista',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          trailing: const Icon(Icons.more_vert, color: Colors.grey),
        ),
      );

  @override
  Widget build(BuildContext context) => Column(
        children: [
          _row('Canción 1', playing: false),
          _row('Sonando ahora', playing: true),
          _row('Canción 3', playing: false),
        ],
      );
}