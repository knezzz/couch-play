import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/session/session.dart';
import 'package:tv/session/wolf_text.dart';
import 'package:tv/strings.dart';

import 'session_test.dart' show FakePeer, join;

/// Task 33 step 2: Vukodlak inside the Session.
void main() {
  late Session s;
  late List<FakePeer> ps;

  void setUpSession(int n, {int bots = 0}) {
    s = Session(random: Random(1))..wolfTvReady = true;
    ps = [for (var i = 0; i < n; i++) join(s, 'P$i', token: 't$i')];
    if (bots > 0) s.setBotCount(bots);
  }

  test('five to eight humans, no bots: otherwise the host is told', () {
    setUpSession(4);
    ps[0].say(const StartGame(GameKind.vukodlak, null));
    expect(s.phase, Phase.lobby);
    expect(ps[0].last<ErrorMsg>()!.message, WolfText.needPlayers);
    s.dispose();

    setUpSession(5, bots: 1);
    ps[0].say(const StartGame(GameKind.vukodlak, null));
    expect(s.phase, Phase.lobby, reason: 'a bot is in the lobby');
    expect(ps[0].last<ErrorMsg>()!.message, WolfText.noBots);
    s.dispose();
  });

  test('only the host starts it, and only from the lobby', () {
    setUpSession(5);
    ps[1].say(const StartGame(GameKind.vukodlak, null));
    expect(s.phase, Phase.lobby);
    ps[0].say(const StartGame(GameKind.vukodlak, null));
    expect(s.phase, Phase.wolf);
    ps[0].say(const StartGame(GameKind.quiz, null));
    expect(s.phase, Phase.wolf);
    s.dispose();
  });

  test('every player gets exactly their own role, and nothing private is in the lobby', () {
    setUpSession(6);
    ps[0].say(const StartGame(GameKind.vukodlak, null));
    final roles = <int, WolfRole>{};
    for (final p in ps) {
      final m = p.sent.whereType<RoleMsg>().single;
      roles[(p.sent.whereType<Welcome>().first).playerId] = m.role;
    }
    expect(roles.length, 6);
    expect(roles.values.where((r) => r.isWolf).length, 1);
    for (final p in ps) {
      for (final m in p.sent) {
        if (m is LobbyState) {
          // the possible roles are public settings; no player carries a role
          for (final pl in m.toJson()['players'] as List) {
            expect((pl as Map).keys.toSet().intersection({'role', 'roles', 'wolf'}), isEmpty);
          }
          expect(m.toJson().containsKey('role'), isFalse);
        }
      }
    }
    expect(s.wolf, isNotNull);
    s.dispose();
  });

  test('messages go to the right connection: a role message arrives only on its own phone', () {
    setUpSession(5);
    ps[0].say(const StartGame(GameKind.vukodlak, null));
    final byPhone = {for (final p in ps) p: p.sent.whereType<RoleMsg>().single};
    for (final p in ps) {
      final id = p.sent.whereType<Welcome>().first.playerId;
      expect(byPhone[p]!.role, s.wolf!.game.roleOf(id));
    }
    s.dispose();
  });

  test('night picks, votes and shots from a phone are the phone\'s own player', () {
    setUpSession(5);
    ps[0].say(const StartGame(GameKind.vukodlak, null));
    final w = s.wolf!;
    final id1 = ps[1].sent.whereType<Welcome>().first.playerId;
    ps[1].say(const NightPick(null));
    expect(w.game.done, {id1});
    s.dispose();
  });

  test('a phone that reconnects gets its own state again', () async {
    setUpSession(5);
    ps[0].say(const StartGame(GameKind.vukodlak, null));
    final id = ps[2].sent.whereType<Welcome>().first.playerId;
    await ps[2].drop();
    final again = join(s, 'P2', token: 't2');
    expect(again.sent.whereType<RoleMsg>().single.role, s.wolf!.game.roleOf(id));
    expect(again.sent.whereType<NightPrompt>(), isNotEmpty);
    expect(again.sent.whereType<RoleMsg>().length, 1);
    s.dispose();
  });

  test('the game over brings everyone back to the lobby', () {
    setUpSession(5);
    ps[0].say(const StartGame(GameKind.vukodlak, null));
    s.endGame();
    expect(s.phase, Phase.lobby);
    expect(s.wolf, isNull);
    expect(ps[1].last<LobbyState>(), isNotNull);
    s.dispose();
  });

  testWidgets('a finished game shows the end screen to phones, then returns to the lobby', (t) async {
    setUpSession(5);
    ps[0].say(const StartGame(GameKind.vukodlak, null));
    final w = s.wolf!;
    // everyone votes out the wolf at once: skip the night by force
    for (final id in w.alive) {
      w.onNightPick(id, const NightPick(null));
    }
    await t.pump(const Duration(seconds: 4));
    await t.pump(const Duration(seconds: 130));
    final wolf = w.alive.firstWhere((i) => w.game.roleOf(i).isWolf);
    for (final id in w.alive) {
      w.onVote(id, Vote(id == wolf ? w.alive.firstWhere((x) => x != id) : wolf));
    }
    await t.pump(const Duration(seconds: 16));
    expect(w.winner, WolfWinner.village);
    expect(ps[1].sent.whereType<WolfEnd>().single.winner, WolfWinner.village);
    await t.pump(const Duration(seconds: 12));
    expect(s.phase, Phase.lobby);
    s.dispose();
  });

  test('a phone that reloads mid-game gets the public lobby (names, colours) with its own state', () async {
    setUpSession(5);
    ps[0].say(const StartGame(GameKind.vukodlak, null));
    await ps[2].drop();
    final again = join(s, 'P2', token: 't2');
    expect(again.sent.whereType<LobbyState>(), isNotEmpty);
    final order = [for (final m in again.sent) m.type];
    expect(order.indexOf('lobby'), lessThan(order.indexOf('role')));
    s.dispose();
  });

  test('a kicked player is out of the match', () {
    setUpSession(6);
    ps[0].say(const StartGame(GameKind.vukodlak, null));
    final id = ps[3].sent.whereType<Welcome>().first.playerId;
    ps[0].say(Kick(id));
    expect(s.wolf!.isAlive(id), isFalse);
    s.dispose();
  });

  test('refused with the soon text while the TV has no screens for it', () {
    s = Session(random: Random(1));
    ps = [for (var i = 0; i < 6; i++) join(s, 'P$i', token: 't$i')];
    ps[0].say(const StartGame(GameKind.vukodlak, null));
    expect(s.phase, Phase.lobby);
    expect(ps[0].last<ErrorMsg>()!.message, Strings.vukodlakSoon);
    s.dispose();
  });
}
