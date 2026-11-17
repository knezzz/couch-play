import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../../session/blef_match.dart';
import 'blef_screen.dart';

/// Blef on the TV: turns the running [BlefMatch] into the board.
///
/// PRIVACY: reads only the match's public getters. `sent` is who has written, never the texts; the
/// list (`listTexts`) holds no writers and no mark of the truth; `shown` reveals entry by entry. It never
/// touches `BlefMatch.game`.
class BlefView extends StatefulWidget {
  const BlefView({required this.match, required this.players, super.key});
  final BlefMatch match;
  final List<PlayerInfo> players;

  @override
  State<BlefView> createState() => _BlefViewState();
}

class _BlefViewState extends State<BlefView> {
  Timer? _clock;

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
    PlayerInfo? info(int id) => widget.players.where((p) => p.id == id).firstOrNull;
    List<PlayerInfo> some(Iterable<int> ids) => [for (final id in ids) ?info(id)];
    return BlefScreen(BlefBoard(
      stage: m.stage,
      number: m.number,
      total: m.total,
      question: m.q,
      players: [for (final p in widget.players) if (m.totals.containsKey(p.id)) p],
      sent: m.sent,
      picked: m.picked,
      secondsLeft: m.secondsLeft,
      seconds: m.stage == BlefStageTv.pick ? BlefMatch.pickTime.inSeconds : BlefMatch.writeTime.inSeconds,
      list: m.listTexts,
      shown: [for (final e in m.shown) BlefCard(e.text, e.isTruth, some(e.writers), some(e.pickers))],
      points: m.questionPoints,
    ));
  }
}
