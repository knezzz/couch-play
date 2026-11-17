import 'package:core/core.dart';
import 'package:flutter/material.dart';

// Tokens from docs/design/couchplay-screens/canvas.json.
const tvBg = Color(0xFF14141E);
const tvSurface = Color(0xFF1F1F2C);
const tvRaised = Color(0xFF2A2A3A);
const tvText = Color(0xFFF4F4F8);
const tvMuted = Color(0xFFA9A9BC);

/// Ink on player-colour chips and quiz tiles.
const tvInk = Color(0xFF14141E);

/// The one highlight colour on the TV: a focused button gets a 3 px ring of it,
/// and it fills progress bars.
const tvAccent = Color(0xFF4DD9FF);

/// 12345 -> "12 345" (no-break space): score numbers in the mockups.
String grouped(int n) {
  final digits = n.abs().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+$)'), (_) => '\u00A0');
  return n < 0 ? '-$digits' : digits;
}

/// A player-colour dot, as in the scoreboards. With a [character] (a core
/// character id) the player's animal takes the dot's place, same size; [ring]
/// then puts it on a white disc so it never melts into a tile of its own colour.
class PlayerDot extends StatelessWidget {
  const PlayerDot(this.color, {this.size = 40, this.ring = false, this.character = '', super.key});
  final Color color;
  final double size;
  final bool ring;
  final String character;

  @override
  Widget build(BuildContext context) {
    if (character.isNotEmpty) {
      if (!ring) return CharacterFace(character, size, color);
      final pad = size * 0.1;
      return Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(pad),
        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        child: CharacterFace(character, size - 2 * pad, color),
      );
    }
    return _dot();
  }

  Widget _dot() => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          // White so a dot never melts into a tile of its own colour.
          border: ring ? Border.all(color: Colors.white, width: 5) : null,
        ),
      );
}

/// Dark theme with couch-sized buttons whose focus ring is always visible.
ThemeData tvTheme() {
  final style = ButtonStyle(
    backgroundColor: const WidgetStatePropertyAll(tvRaised),
    foregroundColor: const WidgetStatePropertyAll(tvText),
    shape: const WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16)))),
    textStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 40, fontWeight: FontWeight.w500)),
    padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 32, vertical: 16)),
    side: WidgetStateProperty.resolveWith(
      (s) => s.contains(WidgetState.focused) ? const BorderSide(color: tvAccent, width: 3) : null,
    ),
  );
  return ThemeData.dark().copyWith(
    scaffoldBackgroundColor: tvBg,
    filledButtonTheme: FilledButtonThemeData(style: style),
  );
}

/// Lays [child] out on the TV's 1920x1080 design canvas and scales it to the window (any 16:9 size),
/// like the quiz and the home do.
class TvCanvas extends StatelessWidget {
  const TvCanvas({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: tvBg,
        child: FittedBox(child: SizedBox(width: 1920, height: 1080, child: child)),
      );
}
