import 'package:flutter/material.dart';

class LyricRow extends StatelessWidget {
  const LyricRow({
    super.key,
    required this.text,
    this.sub = '',
    this.isRomanization = false,
    this.isActive = false,
    this.opacity = 1.0,
    this.compact = false,
    this.hasAnchor = false,
    this.minHeight = 55.0,
    this.lineKey,
    this.onTouch,
    this.onLongPress,
  });

  final String text;
  final String sub;
  final bool isRomanization;
  final bool isActive;
  final double opacity;
  final bool compact;
  final bool hasAnchor;
  final double minHeight;
  final GlobalKey? lineKey;
  final VoidCallback? onTouch;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final showSub = sub.isNotEmpty && sub != text.trim();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: onTouch == null ? null : (_) => onTouch!(),
      onLongPress: onLongPress,
      child: Container(
        key: lineKey,
        constraints: BoxConstraints(minHeight: compact ? 0 : minHeight),
        alignment: Alignment.center,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 250),
          opacity: isActive ? 1.0 : opacity,
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: compact ? 3.0 : 4.0,
              horizontal: 8.0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasAnchor)
                      const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: Icon(
                          Icons.circle,
                          size: 6,
                          color: Colors.amberAccent,
                        ),
                      ),
                    Flexible(
                      child: Text(
                        text,
                        style: TextStyle(
                          color: isActive ? Colors.blueAccent : Colors.white,
                          fontSize: isActive ? 20 : 16,
                          fontWeight:
                              isActive ? FontWeight.bold : FontWeight.w500,
                          height: compact ? 1.4 : 1.25,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
                if (showSub)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      sub,
                      style: TextStyle(
                        color: isActive
                            ? Colors.lightBlueAccent
                            : Colors.white54,
                        fontSize: isActive ? 15 : 13,
                        fontStyle: isRomanization
                            ? FontStyle.italic
                            : FontStyle.normal,
                        height: 1.25,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}