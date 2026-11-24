import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';
import 'colors_screen.dart';
import 'languages_screen.dart';

import 'background_screen.dart';

import 'package:mymusicproject/presentation/screens/splash_screen.dart';

import 'splash_settings_screen.dart';
import 'library_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tint = ref.watch(appThemeProvider).lineColor;
    final primary = Theme.of(context).colorScheme.primary;

    Widget entry({
      required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap,
    }) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: tint.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: tint.withValues(alpha: 0.45)),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            leading: Icon(icon, color: primary),
            title: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              subtitle,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.white54),
            onTap: onTap,
          ),
        ),
      );
    }

    return AppScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Ajustes'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          entry(
            icon: Icons.palette_outlined,
            title: 'Colores',
            subtitle: 'Paletas, acento, fondo y lista de canciones',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ColorsScreen()),
            ),
          ),
          entry(
            icon: Icons.rocket_launch_outlined,
            title: 'Pantalla de inicio',
            subtitle: 'Color de la animación al abrir la app',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SplashSettingsScreen()),
            ),
          ),
          entry(
            icon: Icons.translate,
            title: 'Idiomas',
            subtitle: 'Idiomas que aparecen al traducir las letras',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LanguagesScreen()),
            ),
          ),
          entry(
            icon: Icons.library_music_outlined,
            title: 'Biblioteca',
            subtitle: 'Ocultar audios cortos, de mensajería y grabaciones',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LibraryScreen()),
            ),
          ),
          entry(
            icon: Icons.battery_saver_outlined,
            title: 'Segundo plano',
            subtitle: 'Evita cierres de la música y ve por qué se cerró la app',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BackgroundScreen()),
            ),
          ),
        ],
      ),
    );
  }
}
