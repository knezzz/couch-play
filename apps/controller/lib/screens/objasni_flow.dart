import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../connection.dart';
import 'objasni_screens.dart';

/// What the TV last told this phone during an Objasni game.
class ObjasniInbox {
  ObjasniTeams? teams;
  ObjasniTurn? turn;

  void on(Message m) {
    switch (m) {
      case ObjasniTeams():
        teams = m;
        turn = null; // a new draw is the setup again
      case ObjasniTurn():
        turn = m;
      default:
    }
  }
}

/// The phone's Objasni screens: the setup until the first ObjasniTurn, then
/// the turn for this phone's role.
class ObjasniFlow extends StatelessWidget {
  const ObjasniFlow(
    this.conn,
    this.lobby,
    this.myId,
    this.inbox, {
    required this.hostId,
    super.key,
  });
  final Connection conn;
  final LobbyState lobby;
  final int myId;

  /// The current host (HostIs mid-game), not LobbyState's, which goes stale.
  final int hostId;
  final ObjasniInbox inbox;

  PlayerInfo? _p(int id) => lobby.players.where((p) => p.id == id).firstOrNull;

  @override
  Widget build(BuildContext context) {
    final t = inbox.turn;
    if (t != null) {
      return ObjasniTurnScreen(
        stage: t.stage,
        role: t.role,
        team: t.team,
        explainerName: _p(t.explainer)?.name ?? '?',
        word: t.word,
        seconds: t.seconds,
        scores: t.scores,
        onGo: () => conn.send(const Go()),
        // The word number says which word the press is about, so a double tap
        // or a racing foul never lands on the next word.
        onAct: (a) => conn.send(ObjasniAction(a, wordNo: t.wordNo)),
      );
    }
    final teams = inbox.teams;
    if (teams == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return ObjasniSetupScreen(
      teams: [
        for (final team in teams.teams)
          [
            for (final id in team)
              if (_p(id) != null)
                TeamMember(
                  id,
                  _p(id)!.name,
                  _p(id)!.character,
                  _p(id)!.colorIndex,
                ),
          ],
      ],
      myTeam: teams.team,
      isHost: hostId == myId,
      hostName: _p(hostId)?.name,
      onReshuffle: () => conn.send(const Reshuffle()),
      onGo: () => conn.send(const Go()),
    );
  }
}
