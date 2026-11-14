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

/// A player-colour dot, as in the scoreboards.
class PlayerDot extends StatelessWidget {
  const PlayerDot(this.color, {this.size = 40, this.ring = false, super.key});
  final Color color;
  final double size;
  final bool ring;

  @override
  Widget build(BuildContext context) => Container(
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
