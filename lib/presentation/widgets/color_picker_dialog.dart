import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<Color?> showColorPickerDialog(
  BuildContext context, {
  required Color initial,
  double maxValue = 1.0,
}) {
  return showDialog<Color>(
    context: context,
    builder: (_) => _ColorPickerDialog(initial: initial, maxValue: maxValue),
  );
}

class _ColorPickerDialog extends StatefulWidget {
  const _ColorPickerDialog({required this.initial, required this.maxValue});
  final Color initial;
  final double maxValue;

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late HSVColor _hsv;
  late final TextEditingController _hex;

  static String _toHex(Color c) =>
      c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();

  @override
  void initState() {
    super.initState();
    _hsv = _limit(HSVColor.fromColor(widget.initial));
    _hex = TextEditingController(text: _toHex(_hsv.toColor()));
  }

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  HSVColor _limit(HSVColor c) =>
      c.value > widget.maxValue ? c.withValue(widget.maxValue) : c;

  void _setHsv(HSVColor c, {bool updateHex = true}) {
    setState(() {
      _hsv = _limit(c);
      if (updateHex) _hex.text = _toHex(_hsv.toColor());
    });
  }

  Widget _slider(
    String label,
    double value,
    double max,
    List<Color> colors,
    ValueChanged<double> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        SizedBox(
          height: 32,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    gradient: LinearGradient(colors: colors),
                  ),
                ),
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 10,
                  activeTrackColor: Colors.transparent,
                  inactiveTrackColor: Colors.transparent,
                  thumbColor: Colors.white,
                  overlayColor: Colors.white24,
                ),
                child: Slider(
                  value: value.clamp(0.0, max),
                  min: 0,
                  max: max,
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final h = _hsv.hue, s = _hsv.saturation, v = _hsv.value;
    return AlertDialog(
      title: const Text('Elegir color'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 56,
              decoration: BoxDecoration(
                color: _hsv.toColor(),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
            ),
            const SizedBox(height: 12),
            _slider(
              'Tono',
              h,
              360,
              [
                for (var d = 0; d <= 360; d += 60)
                  HSVColor.fromAHSV(1, d.toDouble(), 1, 1).toColor(),
              ],
              (x) => _setHsv(_hsv.withHue(x)),
            ),
            _slider(
              'Saturación',
              s,
              1,
              [
                HSVColor.fromAHSV(1, h, 0, v).toColor(),
                HSVColor.fromAHSV(1, h, 1, v).toColor(),
              ],
              (x) => _setHsv(_hsv.withSaturation(x)),
            ),
            _slider(
              'Brillo',
              v,
              widget.maxValue,
              [
                Colors.black,
                HSVColor.fromAHSV(1, h, s, widget.maxValue).toColor(),
              ],
              (x) => _setHsv(_hsv.withValue(x)),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _hex,
              maxLength: 6,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[0-9a-fA-F]')),
              ],
              decoration: const InputDecoration(
                prefixText: '#',
                labelText: 'Hexadecimal',
                counterText: '',
              ),
              onChanged: (t) {
                if (t.length == 6) {
                  final n = int.tryParse(t, radix: 16);
                  if (n != null) {
                    _setHsv(
                      HSVColor.fromColor(Color(0xFF000000 | n)),
                      updateHex: false,
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _hsv.toColor()),
          child: const Text('Aceptar'),
        ),
      ],
    );
  }
}