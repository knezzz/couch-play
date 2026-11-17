import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../../session/koliko_match.dart';
import 'koliko_screen.dart';

/// Koliko? on the TV: turns the running [KolikoMatch] into the board.
///
/// PRIVACY: reads only the match's public getters. `answered` is who has answered; the numbers come only
/// from `reveal`, which is null while the question is open. It never touches `KolikoMatch.game`.
class KolikoView extends StatefulWidget {
  const KolikoView({required this.match, required this.players, super.key});
  final KolikoMatch match;
  final List<PlayerInfo> players;

  @override
  State<KolikoView> createState() => _KolikoViewState();
}

class _KolikoViewState extends State<KolikoView> {
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
    final inGame = [for (final p in widget.players) if (m.totals.containsKey(p.id)) p];
    final rev = m.reveal;
    if (rev != null && rev.entries.any((e) => e.rank == 1) && _confettiFor != m.number) {
      _confettiFor = m.number;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) EffectLayer.play(context, EffectName.confetti);
      });
    }
    PlayerInfo? info(int id) => widget.players.where((p) => p.id == id).firstOrNull;
    return KolikoScreen(KolikoBoard(
      number: m.number,
      total: m.total,
      question: m.q,
      unit: m.unit,
      players: inGame,
      answered: m.answered,
      secondsLeft: m.secondsLeft,
      seconds: m.seconds,
      answer: rev?.answer,
      rows: [
        if (rev != null)
          for (final e in rev.entries)
            if (info(e.id) case final p?) KolikoRow(p, e.value, e.rank, e.points, e.exact, m.totals[e.id] ?? 0),
      ],
    ));
  }
}
