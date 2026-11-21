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
      child: LayoutBuilder(
        builder: (_, box) => FittedBox(
          // Scales down only if the names cannot fit one line even ellipsised.
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: box.maxWidth,
            height: 64,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final n in names)
                  Flexible(
                    key: ValueKey('strip-${n.colorIndex}'),
                    child: Opacity(
                      opacity: n.alive ? 1 : 0.35,
                      child: Text(
                        n.alive ? n.name : '× ${n.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 44, fontWeight: FontWeight.w700, color: playerColors[n.colorIndex % playerColors.length]),
                      ),
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
