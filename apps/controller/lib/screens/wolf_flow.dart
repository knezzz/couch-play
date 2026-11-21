import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../connection.dart';
import '../strings.dart';
import '../theme.dart';
import 'wolf_screens.dart';

/// What the TV last told this phone during a Vukodlak game. Every message here
/// is private to this phone; the app keeps the latest of each.
class WolfInbox {
  RoleMsg? role;
  NightPrompt? night;
  Morning? morning;
  VotePrompt? vote;
  Farewell? farewell;
  WolfEnd? end;

  /// "Spreman" before night 1; null once night 1 has started.
  PlayWait? ready;

  /// The day's "Idemo glasati" state; null at night and during a vote.
  VoteWish? wish;

  /// Which screen is up now.
  String screen = 'idle'; // idle | night | vote | farewell | end

  /// Back in the lobby: forget the last game, so the next one starts on its
  /// role card (a rejoin mid-game is sent the lobby, then its role and stage).
  void reset() {
    role = null;
    night = null;
    morning = null;
    vote = null;
    farewell = null;
    end = null;
    ready = null;
    wish = null;
    screen = 'idle';
  }

  void on(Message m) {
    switch (m) {
      case RoleMsg():
        role = m;
      case NightPrompt():
        night = m;
        ready = null;
        morning = null; // the day is over
        wish = null;
        screen = 'night';
      case Morning():
        morning = m;
        screen = 'idle';
      case VotePrompt():
        vote = m;
        wish = null;
        screen = 'vote';
      case PlayWait():
        ready = m;
      case VoteWish():
        wish = m;
      case Farewell():
        farewell = m;
        screen = 'farewell';
      case WolfEnd():
        end = m;
        screen = 'end';
      default:
    }
  }
}

/// The phone's Vukodlak screens, picked from [phase].
class WolfFlow extends StatelessWidget {
  const WolfFlow(this.conn, this.lobby, this.myId, this.phase, {super.key});
  final Connection conn;
  final LobbyState lobby;
  final int myId;
  final WolfInbox phase;

  String _name(int id) =>
      lobby.players.where((p) => p.id == id).firstOrNull?.name ?? '?';

  void _roles(BuildContext context, Set<WolfRole> possible) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (c) => WolfRolesInfoScreen(
            players: lobby.players.length,
            enabled: {for (final r in possible) r.name},
            onBack: () => Navigator.of(c).pop(),
          ),
        ),
      );

  Widget? _wish(VoteWish? w) => w == null || !w.open
      ? null
      : VoteWishBar(
          ready: w.ready,
          want: w.want,
          needed: w.needed,
          onWish: (on) => conn.send(ReadyToVote(on)),
        );

  @override
  Widget build(BuildContext context) {
    final me = lobby.players.where((p) => p.id == myId).firstOrNull;
    switch (phase.screen) {
      case 'night':
        final n = phase.night!;
        return NightScreen(
          // A new prompt is a new screen: nothing carries over between nights.
          key: ValueKey(
            'night-${n.night}-${n.ids.join(',')}-${n.ids2.join(',')}-${n.done}',
          ),
          night: n.night,
          hint: n.text,
          special: n.special,
          picked: n.picked,
          picked2: n.picked2,
          done: n.done,
          targets: [
            for (var i = 0; i < n.ids.length; i++)
              NightItem(n.ids[i], n.choices[i]),
          ],
          targets2: [
            for (var i = 0; i < n.ids2.length; i++)
              NightItem(n.ids2[i], n.choices2[i]),
          ],
          onConfirm: (t, second, special) =>
              conn.send(NightPick(t, second: second, special: special)),
        );
      case 'vote':
        final v = phase.vote!;
        return VoteScreen(
          key: ValueKey('vote-${v.day}'),
          day: v.day,
          selfId: myId,
          canVote: v.canVote,
          picked: v.picked,
          targets: [
            for (final id in v.ids)
              if (lobby.players.any((p) => p.id == id))
                WolfTarget(
                  id,
                  _name(id),
                  lobby.players.firstWhere((p) => p.id == id).character,
                  lobby.players.firstWhere((p) => p.id == id).colorIndex,
                ),
          ],
          onVote: (t) => conn.send(Vote(t)),
          onSkip: () => conn.send(const Vote(null)),
        );
      case 'farewell':
        final f = phase.farewell!;
        return NightScreen(
          key: ValueKey('farewell-${f.ids.join(',')}'),
          night: phase.night?.night ?? 1,
          hint: Strings.farewellHint,
          showSpecial: false,
          targets: [for (final id in f.ids) NightItem(id, _name(id))],
          onConfirm: (t, _, _) => conn.send(Shoot(t)),
        );
      case 'end':
        return _End(phase.end!, lobby, _name);
      default:
        final r = phase.role;
        if (r == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final info = Strings.wolfRoles.firstWhere((e) => e.$1 == r.role.name);
        final mates = r.mates.map(_name).join(', ');
        final extra = [
          if (mates.isNotEmpty) Strings.wolfMates(mates),
          if (phase.morning != null) phase.morning!.text.trim(),
        ].join('\n');
        return RoleHoldScreen(
          name: me?.name ?? '',
          night: phase.night?.night ?? 1,
          header: phase.morning == null
              ? null
              : Strings.day(phase.morning!.day),
          role: info.$2,
          description: info.$3,
          extra: extra,
          bottom: phase.ready != null
              ? ReadyBar(
                  ready: phase.ready!.ready,
                  count: phase.ready!.count,
                  total: phase.ready!.total,
                  onReady: () => conn.send(const ReadyToPlay()),
                )
              : _wish(phase.wish),
          onRoles: () => _roles(context, r.possible.toSet()),
        );
    }
  }
}

class _End extends StatelessWidget {
  const _End(this.end, this.lobby, this.name);
  final WolfEnd end;
  final LobbyState lobby;
  final String Function(int) name;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              Strings.wolfWinner(end.winner),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  for (final e in end.roles.entries)
                    Padding(
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
                                name(e.key),
                                style: const TextStyle(fontSize: 20),
                              ),
                            ),
                            Text(
                              Strings.wolfRoles
                                  .firstWhere((r) => r.$1 == e.value.name)
                                  .$2,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
