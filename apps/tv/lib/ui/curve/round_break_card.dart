import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../../strings.dart';
import '../tv_theme.dart';

/// One player's line on the card.
class BreakPlayer {
  const BreakPlayer({required this.name, required this.colorIndex, required this.score, this.character = ''});
  final String name;
  final int colorIndex;
  final String character;
  final int score;
}

/// What the TV shows for a few seconds after each Curve round, before the next countdown
/// (Task 37: no bar during play): who is ahead, how many points each has and how far they
/// are from the target. Leader first. [remaining] is the time until the next round, read
/// every quarter second.
class RoundBreakCard extends StatefulWidget {
  const RoundBreakCard({required this.round, required this.target, required this.players, required this.remaining, super.key});
  final int round, target;
  final List<BreakPlayer> players;
  final Duration Function() remaining;

  @override
  State<RoundBreakCard> createState() => _RoundBreakCardState();
}

class _RoundBreakCardState extends State<RoundBreakCard> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [...widget.players]..sort((a, b) => b.score.compareTo(a.score)); // stable: ties keep join order
    final seconds = (widget.remaining().inMilliseconds / 1000).ceil().clamp(0, 99);
    final many = sorted.length > 5;
    final rowH = many ? 72.0 : 96.0;
    return Container(
      color: tvBg,
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 1920,
          height: 1080,
          child: Center(
            child: Container(
              key: const ValueKey('round-break'),
              width: 1400,
              padding: const EdgeInsets.fromLTRB(64, 48, 64, 48),
              decoration: BoxDecoration(color: tvSurface, borderRadius: BorderRadius.circular(40)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Flexible(
                        child: Text(Strings.curveBreakTitle(widget.round),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w900, color: tvText)),
                      ),
                      const SizedBox(width: 32),
                      Flexible(
                        child: Text(Strings.curveBreakTarget(widget.target),
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 36, color: tvMuted)),
                      ),
                    ],
                  ),
                  SizedBox(height: many ? 20 : 32),
                  for (final p in sorted) _row(p, rowH),
                  SizedBox(height: many ? 16 : 28),
                  Text(Strings.curveBreakNext(seconds), style: const TextStyle(fontSize: 40, color: tvMuted)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(BreakPlayer p, double h) {
    final color = playerColors[p.colorIndex % playerColors.length];
    final fraction = widget.target <= 0 ? 0.0 : (p.score / widget.target).clamp(0.0, 1.0);
    return SizedBox(
      key: ValueKey('break-${p.colorIndex}'),
      height: h,
      child: Row(
        children: [
          PlayerDot(color, size: h - 16, character: p.character),
          const SizedBox(width: 20),
          SizedBox(
            width: 380,
            child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 44, color: tvText)),
          ),
          Expanded(
            child: Container(
              key: ValueKey('break-track-${p.colorIndex}'),
              height: 24,
              decoration: BoxDecoration(color: tvRaised, borderRadius: BorderRadius.circular(12)),
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: fraction,
                child: Container(
                  key: ValueKey('break-fill-${p.colorIndex}'),
                  height: 24,
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 120,
            child: Text('${p.score}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w900, color: tvText)),
          ),
        ],
      ),
    );
  }
}
