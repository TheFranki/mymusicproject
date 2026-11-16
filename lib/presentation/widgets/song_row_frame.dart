import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class SongRowFrame extends StatelessWidget {
  const SongRowFrame({
    super.key,
    required this.cfg,
    required this.isPlaying,
    required this.child,
  });

  final AppThemeConfig cfg;
  final bool isPlaying;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final line = cfg.lineColor;
    final content = Material(type: MaterialType.transparency, child: child);

    switch (cfg.rowStyle) {
      case RowStyle.plain:
        return Container(
          decoration: BoxDecoration(
            color: isPlaying ? line.withValues(alpha: 0.12) : null,
            border: isPlaying
                ? Border(left: BorderSide(color: line, width: 4))
                : null,
          ),
          child: content,
        );

      case RowStyle.lines:
        final side = BorderSide(
          color: isPlaying ? line : line.withValues(alpha: 0.45),
          width: isPlaying ? 1.5 : 1,
        );
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(
            color: isPlaying
                ? line.withValues(alpha: 0.14)
                : line.withValues(alpha: 0.04),
            border: Border(top: side, bottom: side),
          ),
          child: content,
        );

      case RowStyle.cards:
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: isPlaying
                ? line.withValues(alpha: 0.16)
                : Colors.black.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isPlaying ? line : line.withValues(alpha: 0.35),
              width: isPlaying ? 1.5 : 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: content,
          ),
        );
    }
  }
}