import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../../strings.dart';
import '../tv_theme.dart';
import 'name_strip.dart';

/// Over the frozen field for 1.5 s after the last crash (Task 52): who won the round (or the match),
/// or "Neriješeno" with the colours of those who crashed together. The winner's head is ringed by the game.
class WinnerBanner extends StatelessWidget {
  const WinnerBanner({required this.who, this.others = const [], this.match = false, this.tie = false, super.key});
  final List<StripName> who;

  /// Everyone else, best first, with their points of the round ("+N") and their place.
  final List<StripName> others;
  final bool match, tie;

  @override
  Widget build(BuildContext context) {
    final kicker = match ? Strings.curveMatchWinner : Strings.curveRoundWinner;
    return Material(
      type: MaterialType.transparency,
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 1920,
          height: 1080,
          child: Align(
            alignment: const Alignment(0, -0.6),
            child: Container(
              key: const ValueKey('winner-banner'),
              padding: const EdgeInsets.symmetric(horizontal: 72, vertical: 32),
              decoration: BoxDecoration(color: tvSurface.withValues(alpha: 0.94), borderRadius: BorderRadius.circular(40)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (tie)
                    const Text(Strings.curveTie, style: TextStyle(fontSize: 72, fontWeight: FontWeight.w900, color: tvText))
                  else
                    Text(kicker, style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w700, color: tvMuted)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final (i, p) in who.indexed) ...[
                        if (i > 0) const SizedBox(width: 56),
                        PlayerDot(playerColors[p.colorIndex % playerColors.length], size: 96, character: p.character),
                        const SizedBox(width: 24),
                        Text(p.name,
                            maxLines: 1,
                            style: TextStyle(fontSize: 80, fontWeight: FontWeight.w900, color: playerColors[p.colorIndex % playerColors.length])),
                      ],
                    ],
                  ),
                  if (others.isNotEmpty) const SizedBox(height: 20),
                  for (final p in others) _row(p),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(StripName p) {
    final color = playerColors[p.colorIndex % playerColors.length];
    return SizedBox(
      key: ValueKey('moment-row-${p.colorIndex}'),
      height: 56,
      width: 760,
      child: Row(
        children: [
          SizedBox(width: 80, child: Text('${p.place ?? ''}.', style: const TextStyle(fontSize: 40, color: tvMuted))),
          Expanded(child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 44, fontWeight: FontWeight.w700, color: color))),
          Text('+${p.points ?? 0}', style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w900, color: tvText)),
        ],
      ),
    );
  }
}
