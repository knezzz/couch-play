import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../connection.dart';
import 'tkobi_screens.dart';

/// What the TV last told this phone during a Tko bi? game.
class TkobiInbox {
  TkobiAsk? ask;
  TkobiResult? result;

  void on(Message m) {
    switch (m) {
      case TkobiAsk():
        ask = m;
        result = null;
      case TkobiResult():
        result = m;
      default:
    }
  }
}

/// The phone's Tko bi? screens: the vote, then the result.
class TkobiFlow extends StatelessWidget {
  const TkobiFlow(this.conn, this.lobby, this.inbox, {super.key});
  final Connection conn;
  final LobbyState lobby;
  final TkobiInbox inbox;

  List<TkobiPlayer> _players(Iterable<int> ids) => [
    for (final id in ids)
      if (lobby.players.where((p) => p.id == id).firstOrNull case final p?)
        TkobiPlayer(p.id, p.name, p.character, p.colorIndex),
  ];

  @override
  Widget build(BuildContext context) {
    final a = inbox.ask, r = inbox.result;
    if (r != null) {
      return TkobiResultScreen(
        key: ValueKey('tkobi-result-${a?.number}'),
        players: _players(a?.ids ?? r.counts.keys),
        counts: r.counts,
        crowned: r.crowned,
        votedRight: r.votedRight,
        points: r.points,
        total: r.total,
      );
    }
    if (a == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return TkobiAskScreen(
      key: ValueKey('tkobi-${a.number}'),
      number: a.number,
      total: a.total,
      seconds: a.seconds,
      text: a.text,
      players: _players(a.ids),
      picked: a.picked,
      onVote: (id) => conn.send(Vote(id)),
    );
  }
}
