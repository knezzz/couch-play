import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../../session/tkobi_match.dart';
import 'tkobi_screen.dart';

/// Tko bi? on the TV: turns the running [TkobiMatch] into the board, and throws confetti when someone is crowned.
///
/// PRIVACY: reads only the match's public getters: `votedCount` is how many have voted, never who for whom.
/// It never touches `TkobiMatch.game`.
class TkobiView extends StatefulWidget {
  const TkobiView({required this.match, required this.players, super.key});
  final TkobiMatch match;
  final List<PlayerInfo> players;

  @override
  State<TkobiView> createState() => _TkobiViewState();
}

class _TkobiViewState extends State<TkobiView> {
  Timer? _clock;
  int? _confettiFor; // the prompt number already celebrated

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
    final inGame = [for (final p in widget.players) if (m.totals.containsKey(p.id)) p];
    if (rev != null && rev.crowned.isNotEmpty && _confettiFor != m.number) {
      _confettiFor = m.number;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) EffectLayer.play(context, EffectName.confetti);
      });
    }
    List<TkobiRow>? rows;
    if (rev != null) {
      rows = [
        for (final p in inGame) TkobiRow(p, rev.counts[p.id] ?? 0, rev.crowned.contains(p.id)),
      ]..sort((a, b) => b.votes.compareTo(a.votes)); // stable: ties keep join order
    }
    return TkobiScreen(TkobiBoard(
      number: m.number,
      total: m.total,
      prompt: m.text,
      players: inGame,
      votedCount: m.votedCount,
      secondsLeft: m.secondsLeft,
      seconds: TkobiMatch.voteTime.inSeconds,
      rows: rows,
    ));
  }
}
