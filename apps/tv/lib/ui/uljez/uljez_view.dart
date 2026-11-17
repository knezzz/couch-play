import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../../session/uljez_match.dart';
import '../../strings.dart';
import 'uljez_screen.dart';

/// Uljez on the TV: turns the running [UljezMatch] into the table screen.
///
/// PRIVACY: reads only the match's public getters (`phase`, `speaker`, `round`,
/// `order`, `alive`, `winner`, `votedCount`, `lastVotes`, `lastOut`,
/// `remaining`, and the words/impostors, which the match only gives once the
/// game is over). It never touches `UljezMatch.game`, which holds both words and
/// who the impostors are.
class UljezView extends StatefulWidget {
  const UljezView({required this.match, required this.players, super.key});
  final UljezMatch match;
  final List<PlayerInfo> players;

  @override
  State<UljezView> createState() => _UljezViewState();
}

class _UljezViewState extends State<UljezView> {
  static const _holdFor = Duration(seconds: 6);

  Timer? _clock, _hold;
  late Map<int, int?> _seenVotes = widget.match.lastVotes;
  var _holding = false;

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
    _hold?.cancel();
    super.dispose();
  }

  PlayerInfo? _info(int id) => widget.players.where((p) => p.id == id).firstOrNull;
  String _name(int id) => _info(id)?.name ?? '';

  static String _clockText(Duration d) {
    final s = d.inSeconds;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  /// A vote's result (a tie, or someone who was not the impostor) stays up a
  /// few seconds even though the next vote or discussion starts at once.
  void _watchVotes() {
    final m = widget.match;
    if (identical(m.lastVotes, _seenVotes)) return;
    _seenVotes = m.lastVotes;
    if (m.phase == UljezPhase.guess || m.phase == UljezPhase.over) return; // those screens show it already
    _holding = true;
    _hold?.cancel();
    _hold = Timer(_holdFor, () {
      if (mounted) setState(() => _holding = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.match;
    _watchVotes();
    final phase = m.phase;
    final showVotes = phase == UljezPhase.guess || (_holding && phase != UljezPhase.over);
    final speakerIndex = phase == UljezPhase.clues && m.speaker != null ? m.order.indexOf(m.speaker!) : -1;
    final impostors = phase == UljezPhase.over ? m.impostors : (phase == UljezPhase.guess && m.lastOut != null ? [m.lastOut!] : const <int>[]);

    final seats = [
      for (final id in m.ids)
        UljezSeat(
          id: id,
          name: _name(id),
          colorIndex: _info(id)?.colorIndex ?? 0,
          character: _info(id)?.character ?? '',
          turn: phase == UljezPhase.clues && m.speaker == id,
          done: speakerIndex >= 0 && m.alive.contains(id) && m.order.indexOf(id) < speakerIndex,
          impostor: impostors.contains(id),
          out: !m.alive.contains(id),
          voters: showVotes ? [for (final e in m.lastVotes.entries) if (e.value == id) e.key] : const [],
        ),
    ];

    if (phase == UljezPhase.over) {
      return UljezScreen(
        seats: seats,
        kicker: Strings.uljezEndKicker,
        headline: m.winner == UljezWinner.village ? Strings.uljezVillageWins : Strings.uljezImpostorWins,
        villageWord: m.villageWord,
        impostorWord: m.impostorWord,
      );
    }
    if (phase == UljezPhase.guess) {
      final out = m.lastOut;
      return UljezScreen(
        seats: seats,
        kicker: Strings.uljezRoundOver,
        headline: Strings.uljezCaught(out == null ? '' : _name(out)),
        clockLabel: Strings.uljezGuesses(out == null ? '' : _name(out)),
        clock: _clockText(m.remaining),
        showVotes: true,
      );
    }
    if (_holding) {
      final out = m.lastOut;
      return UljezScreen(
        seats: seats,
        kicker: Strings.uljezRoundOver,
        headline: out == null ? Strings.uljezNobodyOut : Strings.uljezNotImpostor(_name(out)),
        showVotes: true,
      );
    }
    switch (phase) {
      case UljezPhase.clues:
        return UljezScreen(
          seats: seats,
          kicker: Strings.uljezRoundClues(m.round),
          headline: Strings.uljezClueFor(m.speaker == null ? '' : _name(m.speaker!)),
          clockLabel: Strings.uljezClueClock,
          clock: _clockText(m.remaining),
          hint: Strings.uljezClueHint,
        );
      case UljezPhase.discussion:
        return UljezScreen(
          seats: seats,
          kicker: Strings.uljezDiscussKicker,
          headline: Strings.uljezWho,
          clockLabel: Strings.uljezDiscussClock,
          clock: _clockText(m.remaining),
          hint: Strings.uljezDiscussHint,
        );
      default: // vote
        return UljezScreen(
          seats: seats,
          kicker: Strings.uljezVoteKicker,
          headline: Strings.uljezWho,
          clockLabel: Strings.uljezVoted(m.votedCount, m.alive.length),
          clock: _clockText(m.remaining),
        );
    }
  }
}
