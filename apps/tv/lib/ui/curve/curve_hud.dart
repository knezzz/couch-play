import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../../strings.dart';
import '../tv_theme.dart';

/// One player's place in the bar.
class CurveHudPlayer {
  const CurveHudPlayer({required this.name, required this.colorIndex, required this.score, this.character = '', this.away = false});
  final String name;
  final int colorIndex;
  final String character;
  final int score;
  final bool away;
}

/// The bar above the arena (docs/design/couchplay-screens/TvCurve.dc.html): the round and
/// what it takes to win, each player's face, name and score (leader first), the mode.
/// 88 px tall on the 1920x1080 canvas; with many players or long names the middle part
/// scales down rather than wrapping.
class CurveHud extends StatelessWidget {
  const CurveHud({required this.round, required this.target, required this.modeName, required this.players, super.key});
  final int round, target;
  final String modeName;
  final List<CurveHudPlayer> players;

  @override
  Widget build(BuildContext context) {
    final sorted = [...players]..sort((a, b) => b.score.compareTo(a.score)); // stable: ties keep join order
    return LayoutBuilder(
      builder: (context, c) {
        // The bar is designed at 1920 wide and scaled to the width it gets.
        final k = c.maxWidth / 1920;
        return SizedBox(
          key: const ValueKey('curve-hud'),
          height: 88 * k,
          child: FittedBox(
            fit: BoxFit.fitWidth,
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 1920,
              height: 88,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Row(
                  children: [
                    Text(Strings.curveRound(round, target),
                        style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: tvMuted)),
                    const SizedBox(width: 36),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          children: [
                            for (final p in sorted) ...[_player(p), const SizedBox(width: 36)],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Text(modeName, style: const TextStyle(fontSize: 32, color: tvMuted)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _player(CurveHudPlayer p) {
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PlayerDot(playerColors[p.colorIndex % playerColors.length], size: 48, character: p.character),
        const SizedBox(width: 12),
        Text(p.name, maxLines: 1, style: const TextStyle(fontSize: 36, color: tvText)),
        const SizedBox(width: 12),
        Text('${p.score}', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: tvText)),
      ],
    );
    return Opacity(key: ValueKey('hud-${p.colorIndex}'), opacity: p.away ? 0.4 : 1, child: row);
  }
}
