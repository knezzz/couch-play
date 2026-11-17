import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../connection.dart';
import '../strings.dart';
import '../theme.dart';
import 'uljez_screens.dart';
import 'wolf_screens.dart';

/// What the TV last told this phone during an Uljez game.
class UljezInbox {
  UljezWord? word;
  UljezTurn? turn;
  VotePrompt? vote;
  UljezGuess? guess;
  UljezEnd? end;
  String screen = 'word'; // word | vote | guess | end

  void on(Message m) {
    switch (m) {
      case UljezWord():
        word = m;
        screen = 'word';
      case UljezTurn():
        turn = m;
        // The vote screen stays up through the discussion text of the turn
        // that follows; only a new word card or vote changes it.
        if (screen == 'vote') screen = 'word';
      case VotePrompt():
        vote = m;
        screen = 'vote';
      case UljezGuess():
        guess = m;
        screen = 'guess';
      case UljezEnd():
        end = m;
        screen = 'end';
      default:
    }
  }
}

/// The phone's Uljez screens, picked from [inbox].
class UljezFlow extends StatelessWidget {
  const UljezFlow(this.conn, this.lobby, this.myId, this.inbox, {super.key});
  final Connection conn;
  final LobbyState lobby;
  final int myId;
  final UljezInbox inbox;

  String _name(int id) =>
      lobby.players.where((p) => p.id == id).firstOrNull?.name ?? '?';

  @override
  Widget build(BuildContext context) {
    switch (inbox.screen) {
      case 'vote':
        final v = inbox.vote!;
        return UljezVoteScreen(
          key: ValueKey('uljez-vote-${v.day}'),
          targets: [
            for (final id in v.ids)
              NightItem(
                id,
                _name(id),
                enabled: id != myId, // the core refuses a self-vote silently
                note: id == myId ? Strings.you : '',
              ),
          ],
          picked: v.picked,
          seconds: v.seconds,
          onVote: (t) => conn.send(Vote(t)),
        );
      case 'guess':
        final g = inbox.guess!;
        return UljezGuessScreen(
          key: ValueKey('uljez-guess-${g.options.join('|')}'),
          word: inbox.word?.word ?? '',
          seconds: g.seconds,
          options: [
            for (var i = 0; i < g.options.length; i++)
              NightItem(i, g.options[i]),
          ],
          onGuess: (i) => conn.send(Guess(i)),
        );
      case 'end':
        return _End(inbox.end!, _name);
      default:
        final w = inbox.word;
        if (w == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return UljezWordScreen(
          name:
              lobby.players.where((p) => p.id == myId).firstOrNull?.name ?? '',
          round: inbox.turn?.round ?? 1,
          stage: inbox.turn?.stage ?? '',
          word: w.word,
        );
    }
  }
}

class _End extends StatelessWidget {
  const _End(this.end, this.name);
  final UljezEnd end;
  final String Function(int) name;

  Widget _line(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 18, color: muted),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            Text(
              Strings.uljezWinner(end.winner),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            _line(Strings.villageWord, end.villageWord),
            _line(Strings.impostorWord, end.impostorWord),
            _line(Strings.impostorsAre, end.impostors.map(name).join(', ')),
          ],
        ),
      ),
    ),
  );
}
