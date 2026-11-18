import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../../session/kaosvi_match.dart';
import 'kaosvi_screen.dart';

/// Kao svi on the TV: turns the running [KaosviMatch] into the board, and throws confetti for the largest group.
///
/// PRIVACY: reads only the match's public getters. `sent` is who has answered, never what; the answers appear
/// only in `reveal`, which is null before the reveal. During the merge the TV shows nothing of them. It never
/// touches `KaosviMatch.game`.
class KaosviView extends StatefulWidget {
  const KaosviView({required this.match, required this.players, super.key});
  final KaosviMatch match;
  final List<PlayerInfo> players;

  @override
  State<KaosviView> createState() => _KaosviViewState();
}

class _KaosviViewState extends State<KaosviView> {
  Timer? _clock;
  int? _confettiFor; // the question number already celebrated

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.match;
    final rev = m.reveal;
    PlayerInfo? info(int id) => widget.players.where((p) => p.id == id).firstOrNull;
    final inGame = [for (final p in widget.players) if (m.totals.containsKey(p.id)) p];
    final stacks = <KaosviStack>[
      if (rev != null)
        for (final g in rev.groups)
          KaosviStack(g.text, [for (final id in g.members) ?info(id)], points: g.members.isEmpty ? 0 : (rev.points[g.members.first] ?? 0)),
    ];
    if (rev != null && !rev.largestTie && stacks.any((s) => s.points > 0) && _confettiFor != m.number) {
      _confettiFor = m.number;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) EffectLayer.play(context, EffectName.confetti);
      });
    }
    final stage = switch (m.stage) {
      KaosviStageTv.answer => KaosviShow.ask,
      KaosviStageTv.merge => KaosviShow.merge,
      _ => KaosviShow.reveal,
    };
    return KaosviScreen(KaosviBoard(
      stage: stage,
      number: m.number,
      total: m.total,
      question: m.q,
      players: inGame,
      answered: m.sent,
      secondsLeft: m.stage == KaosviStageTv.merge ? (m.remaining.inMilliseconds / 1000).ceil() : m.secondsLeft,
      seconds: m.stage == KaosviStageTv.merge ? KaosviMatch.mergeTime.inSeconds : KaosviMatch.answerTime.inSeconds,
      groups: stacks,
      tie: rev?.largestTie ?? false,
    ));
  }
}
