import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../../session/objasni_match.dart';
import 'objasni_screen.dart';

/// Objasni on the TV: turns the running [ObjasniMatch] into the board.
///
/// PRIVACY: reads only the match's public getters (stage, teams, turnWords, scores, clock). It never
/// touches `ObjasniMatch.game`, which holds the word being explained.
class ObjasniView extends StatefulWidget {
  const ObjasniView({required this.match, required this.players, super.key});
  final ObjasniMatch match;
  final List<PlayerInfo> players;

  @override
  State<ObjasniView> createState() => _ObjasniViewState();
}

class _ObjasniViewState extends State<ObjasniView> {
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

  PlayerInfo? _info(int id) => widget.players.where((p) => p.id == id).firstOrNull;

  @override
  Widget build(BuildContext context) {
    final m = widget.match;
    final ex = m.explainer;
    return ObjasniScreen(ObjasniBoard(
      stage: m.stage,
      teams: [
        for (var t = 0; t < 2; t++) [for (final id in m.teamMembers(t)) ?_info(id)],
      ],
      scores: m.scores,
      target: m.target,
      turnTeam: m.turnTeam,
      explainer: ex == null ? null : _info(ex),
      words: m.turnWords,
      secondsLeft: m.secondsLeft,
      turnSeconds: m.turnSeconds,
      summarySeconds: (m.remaining.inMilliseconds / 1000).ceil(),
      winnerTeam: m.winnerTeam,
      pausedSeconds: m.paused ? (m.pauseRemaining.inMilliseconds / 1000).ceil() : null,
    ));
  }
}
