import 'package:core/core.dart';
import 'package:flutter/material.dart';

/// One player of the match: a name for the strip or the winner banner.
class StripName {
  const StripName({required this.name, required this.colorIndex, required this.alive, this.character = '', this.points, this.place});
  final String name, character;
  final int colorIndex;
  final bool alive;

  /// The winner screen's rows: points made in the round, and the place (equal points share one).
  final int? points, place;
}

/// The names under the Curve field in their line colours (Task 52). Names only, no scores. A
/// crashed player keeps place and colour, dimmed, with a small x before the name. It is built
/// when a round starts and on each crash, never per frame.
class NameStrip extends StatelessWidget {
  const NameStrip({required this.names, super.key});
  final List<StripName> names;

  @override
  Widget build(BuildContext context) {
    // Material so the text never falls back to the yellow-underlined default.
    return Material(
      type: MaterialType.transparency,
      // 44 px and whole names while they fit; 8 long names scale the whole line down a little
      // instead of cutting names (a cut name is not the player's name any more).
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (i, n) in names.indexed) ...[
                if (i > 0) const SizedBox(width: 28),
                Opacity(
                  key: ValueKey('strip-${n.colorIndex}'),
                  opacity: n.alive ? 1 : 0.35,
                  child: Text(
                    n.alive ? n.name : '× ${n.name}',
                    maxLines: 1,
                    style: TextStyle(fontSize: 44, fontWeight: FontWeight.w700, color: playerColors[n.colorIndex % playerColors.length]),
                  ),
                ),
              ],
            ],
          ),
        ),
        ),
      ),
    );
  }
}
