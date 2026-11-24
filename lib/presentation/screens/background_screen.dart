import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/app_scaffold.dart';

const _channel = MethodChannel('com.mymusicproject/diagnostics');
const _kClearedAt = 'exit_log_cleared_at';
const _kResume = 'resume_on_open';

String _reasonText(int r) => switch (r) {
      1 => 'La app se cerró a sí misma',
      2 => 'Cerrada por el sistema (señal de cierre)',
      3 => 'Cerrada por falta de memoria',
      4 => 'Error de la app (crash)',
      5 => 'Error nativo de la app (crash)',
      6 => 'La app dejó de responder (ANR)',
      7 => 'Fallo al iniciar',
      8 => 'Cambio de permisos',
      9 => 'Uso excesivo de recursos',
      10 => 'Cerrada por el usuario (deslizar en recientes o forzar detención)',
      11 => 'Detenida por el usuario',
      12 => 'Cerrada porque otro servicio del que dependía se detuvo',
      13 => 'Cerrada por el sistema (ahorro de batería u optimización)',
      14 => 'Congelada por el sistema',
      15 => 'Cambio en el paquete',
      16 => 'App actualizada',
      _ => 'Motivo desconocido',
    };

String _fmt(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(t.day)}/${two(t.month)} ${two(t.hour)}:${two(t.minute)}';
}

class BackgroundScreen extends StatefulWidget {
  const BackgroundScreen({super.key});

  @override
  State<BackgroundScreen> createState() => _BackgroundScreenState();
}

class _BackgroundScreenState extends State<BackgroundScreen> {
  List<Map<String, dynamic>>? _records;
  String? _problem;
  bool _resume = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _load();
  }

  Future<void> _loadSettings() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _resume = p.getBool(_kResume) ?? false);
  }

  Future<void> _setResume(bool v) async {
    setState(() => _resume = v);
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kResume, v);
  }

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final clearedAt = p.getInt(_kClearedAt) ?? 0;
      final raw = await _channel.invokeMethod<List<dynamic>>('exitReasons');

      final list = <Map<String, dynamic>>[];
      for (final e in raw ?? const []) {
        final m = Map<String, dynamic>.from(e as Map);
        if ((m['time'] as int) > clearedAt) list.add(m);
      }
      if (!mounted) return;
      setState(() => _records = list);
    } on MissingPluginException {
      if (!mounted) return;
      setState(() => _problem =
          'Falta agregar el código de Android (MainActivity.kt) y reinstalar la app.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _problem = 'No se pudo leer el diagnóstico.');
    }
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Borrar el historial de cierres?'),
        content: const Text(
          'Se ocultarán los registros actuales. Los cierres nuevos seguirán '
          'apareciendo.',
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
    if (ok != true) return;
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kClearedAt, DateTime.now().millisecondsSinceEpoch);
    if (!mounted) return;
    setState(() => _records = const []);
  }

  Widget _step(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('•  '),
            Expanded(child: Text(text)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context)
        .textTheme
        .titleMedium
        ?.copyWith(fontWeight: FontWeight.bold);
    final records = _records;

    return AppScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Segundo plano'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Text('Evitar que el sistema cierre la música', style: titleStyle),
          const SizedBox(height: 8),
          const Text(
            'Algunos teléfonos (Xiaomi, Samsung, Huawei…) cierran las apps en '
            'segundo plano para ahorrar batería. Los nombres de las opciones '
            'cambian según la versión:',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 10),
          _step('Ajustes del teléfono → Aplicaciones → esta app → Ahorro de '
              'batería → "Sin restricciones".'),
          _step('Activa "Inicio automático" para esta app.'),
          _step('En la pantalla de apps recientes, mantén pulsada la tarjeta '
              'de la app y toca el candado para fijarla.'),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: openAppSettings,
            icon: const Icon(Icons.settings_applications_outlined),
            label: const Text('Abrir ajustes de la app'),
          ),
          const Divider(height: 36, color: Colors.white12),
          Text('Si la app se cierra', style: titleStyle),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Continuar la música al abrir la app'),
            subtitle: const Text(
              'Al abrirla vuelve la misma canción, en el mismo punto, y sigue '
              'sonando. Si está apagado, queda en pausa.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            value: _resume,
            onChanged: _setResume,
          ),
          const Divider(height: 36, color: Colors.white12),
          Row(
            children: [
              Expanded(child: Text('Últimos cierres', style: titleStyle)),
              IconButton(
                tooltip: 'Actualizar',
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  setState(() {
                    _records = null;
                    _problem = null;
                  });
                  _load();
                },
              ),
              if (records != null && records.isNotEmpty)
                IconButton(
                  tooltip: 'Borrar',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _clear,
                ),
            ],
          ),
          const Text(
            'Cuando la app se cierre sola, ábrela de nuevo y entra aquí para '
            'ver por qué ocurrió.',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 8),
          if (_problem != null)
            Text(_problem!, style: const TextStyle(color: Colors.amberAccent))
          else if (records == null)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (records.isEmpty)
            const Text('Sin registros.')
          else
            for (final r in records)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_reasonText(r['reason'] as int)),
                subtitle: Text(
                  _fmt(DateTime.fromMillisecondsSinceEpoch(r['time'] as int)),
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
        ],
      ),
    );
  }
}