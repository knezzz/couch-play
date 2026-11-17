import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../strings.dart';
import 'tv_theme.dart';

/// A running game is frozen, waiting for a player (docs/design/couchplay-screens/TvPause.dc.html):
/// a card with the missing player's face, who we wait for, how long is left and a bar that
/// empties. [who] null: waiting for everybody. [remaining] is read every half second.
class PauseCard extends StatefulWidget {
  const PauseCard({required this.who, required this.remaining, this.total = const Duration(seconds: 30), super.key});
  final PlayerInfo? who;
  final Duration Function() remaining;
  final Duration total;

  @override
  State<PauseCard> createState() => _PauseCardState();
}

class _PauseCardState extends State<PauseCard> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(milliseconds: 500), (_) {
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
    final left = widget.remaining();
    final seconds = (left.inMilliseconds / 1000).ceil().clamp(0, 999);
    final fraction = (left.inMilliseconds / widget.total.inMilliseconds).clamp(0.0, 1.0);
    final who = widget.who;
    // Material so the text never falls back to the yellow-underlined default (no Scaffold above in tests).
    return Material(
      type: MaterialType.transparency,
      child: Container(
      color: tvBg,
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 1920,
          height: 1080,
          child: Center(
            child: Container(
              key: const ValueKey('pause-card'),
              width: 1040,
              padding: const EdgeInsets.all(64),
              decoration: BoxDecoration(color: tvSurface, borderRadius: BorderRadius.circular(40)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (who != null && who.character.isNotEmpty) ...[
                    PlayerDot(playerColors[who.colorIndex % playerColors.length], size: 160, character: who.character),
                    const SizedBox(height: 28),
                  ],
                  Text(
                    who == null ? Strings.waitingForPlayers : Strings.waitingForReturn(who.name),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w900, color: tvText),
                  ),
                  const SizedBox(height: 28),
                  Text(Strings.pauseSub(seconds),
                      textAlign: TextAlign.center, style: const TextStyle(fontSize: 40, color: tvMuted)),
                  const SizedBox(height: 28),
                  Container(
                    key: const ValueKey('pause-track'),
                    width: double.infinity,
                    height: 16,
                    decoration: BoxDecoration(color: tvRaised, borderRadius: BorderRadius.circular(8)),
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: fraction.toDouble(),
                      child: Container(
                        key: const ValueKey('pause-fill'),
                        height: 16,
                        decoration: BoxDecoration(color: tvAccent, borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ));
  }
}
