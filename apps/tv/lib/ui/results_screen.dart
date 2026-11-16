import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter/material.dart';

import 'tv_theme.dart';
import '../strings.dart';

/// How long the results stay up before the TV goes back to the lobby.
const resultsHold = Duration(seconds: 8);

const _green = Color(0xFF2ECC71);

/// Shown for [resultsHold] after a game (TvResults): the placements and the
/// session scores. Reads only [Placement]s and [PlayerInfo]s, so Curve and the
/// quiz share it; [label] says which game it was. Designed on 1920x1080 and
/// scaled to fit, like the lobby.
class ResultsScreen extends StatefulWidget {
  const ResultsScreen({
    required this.placements,
    required this.players,
    this.label = '',
    super.key,
  });
  final List<Placement> placements;
  final List<PlayerInfo> players;
  final String label;

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  static const _tick = Duration(milliseconds: 100);
  Timer? _timer;
  var _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_tick, (_) {
      if (_elapsed >= resultsHold) return _timer?.cancel();
      setState(() => _elapsed += _tick);
    });
    // After the first frame, never during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) EffectLayer.play(context, EffectName.confetti);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final byId = {for (final p in widget.players) p.id: p};
    final byScore = [...widget.players]..sort((a, b) => b.sessionScore.compareTo(a.sessionScore));
    final winners = [
      for (final pl in widget.placements)
        if (pl.place == 1) byId[pl.playerId]?.name ?? Strings.unknownPlayer,
    ];
    final dense = widget.placements.length > 4;
    final left = (resultsHold - _elapsed).inMilliseconds;
    return Scaffold(
      backgroundColor: tvBg,
      body: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 1920,
          height: 1080,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 96, vertical: 64),
            child: Column(
              children: [
                // The label sits beside the headline if there is room, else below it.
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.end,
                    spacing: 48,
                    runSpacing: 4,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1728),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            Strings.wins(winners),
                            maxLines: 1,
                            style: const TextStyle(
                              fontSize: 96,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -2,
                              color: tvText,
                            ),
                          ),
                        ),
                      ),
                      if (widget.label.isNotEmpty)
                        Text(widget.label, style: const TextStyle(fontSize: 44, color: tvMuted)),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        // Only scales if a big tie would not fit.
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.topLeft,
                          child: SizedBox(
                            width: 1104,
                            child: Column(
                              children: [
                                for (final pl in widget.placements) ...[
                                  _PlaceRow(pl, byId[pl.playerId], dense: dense),
                                  SizedBox(height: dense ? 12 : 20),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 64),
                      _Tonight(byScore),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                Row(
                  children: [
                    Container(
                      width: 360,
                      height: 12,
                      decoration: BoxDecoration(color: tvRaised, borderRadius: BorderRadius.circular(999)),
                      child: FractionallySizedBox(
                        key: const ValueKey('countdown-bar'),
                        alignment: Alignment.centerLeft,
                        widthFactor: (1 - left / resultsHold.inMilliseconds).clamp(0.0, 1.0),
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: tvAccent, borderRadius: BorderRadius.circular(999)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Text(
                      Strings.backToLobby((left / 1000).ceil().clamp(0, 99)),
                      style: const TextStyle(fontSize: 40, color: tvMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaceRow extends StatelessWidget {
  const _PlaceRow(this.pl, this.p, {required this.dense});
  final Placement pl;
  final PlayerInfo? p;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final name = Expanded(
      child: Text(p?.name ?? Strings.unknownPlayer, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
    if (pl.place == 1) {
      return Container(
        key: ValueKey('place-${pl.playerId}'),
        padding: EdgeInsets.symmetric(horizontal: 40, vertical: dense ? 16 : 28),
        decoration: BoxDecoration(
          color: playerColors[(p?.colorIndex ?? 0) % playerColors.length],
          borderRadius: BorderRadius.circular(28),
        ),
        child: DefaultTextStyle.merge(
          style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w900, color: tvInk),
          child: Row(
            children: [
              SizedBox(width: 120, child: Text(Strings.place(pl.place), maxLines: 1, softWrap: false)),
              if (p != null && p!.character.isNotEmpty) ...[
                const SizedBox(width: 12),
                PlayerDot(playerColors[p!.colorIndex % playerColors.length],
                    size: dense ? 56 : 72, ring: true, character: p!.character),
              ],
              const SizedBox(width: 28),
              name,
              const SizedBox(width: 28),
              Text(grouped(pl.gameScore), style: const TextStyle(fontSize: 44)),
              const SizedBox(width: 28),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                decoration: BoxDecoration(color: tvInk, borderRadius: BorderRadius.circular(999)),
                child: Text('+${pl.sessionPoints}',
                    style: const TextStyle(fontSize: 44, color: tvText)),
              ),
            ],
          ),
        ),
      );
    }
    return Container(
      key: ValueKey('place-${pl.playerId}'),
      padding: EdgeInsets.symmetric(horizontal: 40, vertical: dense ? 8 : 24),
      decoration: BoxDecoration(color: tvSurface, borderRadius: BorderRadius.circular(24)),
      child: DefaultTextStyle.merge(
        style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w700, color: tvText),
        child: Row(
          children: [
            SizedBox(
              width: 120,
              child: Text(Strings.place(pl.place), maxLines: 1, softWrap: false, style: const TextStyle(color: tvMuted)),
            ),
            PlayerDot(playerColors[(p?.colorIndex ?? 0) % playerColors.length], character: p?.character ?? ''),
            const SizedBox(width: 28),
            name,
            const SizedBox(width: 28),
            Text(grouped(pl.gameScore), style: const TextStyle(fontSize: 40)),
            const SizedBox(width: 28),
            Text('+${pl.sessionPoints}', style: const TextStyle(fontSize: 40, color: _green)),
          ],
        ),
      ),
    );
  }
}

class _Tonight extends StatelessWidget {
  const _Tonight(this.byScore);
  final List<PlayerInfo> byScore;

  @override
  Widget build(BuildContext context) => Container(
        key: const ValueKey('tonight'),
        width: 560,
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(color: tvSurface, borderRadius: BorderRadius.circular(32)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(Strings.tonight, style: TextStyle(fontSize: 44, fontWeight: FontWeight.w700, color: tvText)),
            for (final p in byScore) ...[
              SizedBox(height: byScore.length > 5 ? 8 : 20),
              Row(
                children: [
                  PlayerDot(playerColors[p.colorIndex % playerColors.length], character: p.character),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Text(p.name,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 40, color: tvText)),
                  ),
                  Text(grouped(p.sessionScore),
                      style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w700, color: tvText)),
                ],
              ),
            ],
          ],
        ),
      );
}
