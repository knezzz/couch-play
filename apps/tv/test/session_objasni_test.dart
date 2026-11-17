import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/packs/party_packs.dart';
import 'package:tv/session/objasni_match.dart';
import 'package:tv/session/party_text.dart';
import 'package:tv/session/session.dart';

import 'session_test.dart' show FakePeer, join;

ObjasniPack pack(String id) => ObjasniPack(id, 'T $id', [for (var i = 0; i < 110; i++) '$id-w$i']);

/// Task 39: Objasni inside the Session.
void main() {
  late Session s;
  late List<FakePeer> ps;
  var at = Duration.zero;

  void setUpSession(int n, {int bots = 0, bool ready = true}) {
    at = Duration.zero;
    s = Session(random: Random(1), clock: () => at)
      ..objasniTvReady = ready
      ..objasniPacks = [pack('one'), pack('two')];
    ps = [for (var i = 0; i < n; i++) join(s, 'P$i', token: 't$i')];
    if (bots > 0) s.setBotCount(bots);
  }

  int idOf(FakePeer p) => p.sent.whereType<Welcome>().first.playerId;

  Future<void> wait(WidgetTester t, int seconds) async {
    for (var i = 0; i < seconds; i++) {
      await t.pump(const Duration(seconds: 1));
      at += const Duration(seconds: 1);
    }
  }

  testWidgets('the bundled packs load', (t) async {
    final packs = await loadObjasniPacks(rootBundle);
    expect(packs.length, 7);
    expect(packs.every((p) => p.words.length >= 100), isTrue);
  });

  test('refused with the soon text while the TV has no screens for it', () {
    setUpSession(5, ready: false);
    ps[0].say(const StartGame(GameKind.objasni, null));
    expect(s.phase, Phase.lobby);
    expect(ps[0].last<ErrorMsg>()!.message, PartyText.soon);
    s.dispose();
  });

  test('4 to 8 humans, no bots, only the host, a pack', () {
    setUpSession(3);
    ps[0].say(const StartGame(GameKind.objasni, null));
    expect(ps[0].last<ErrorMsg>()!.message, PartyText.objasniNeedPlayers);
    s.dispose();
    setUpSession(4, bots: 1);
    ps[0].say(const StartGame(GameKind.objasni, null));
    expect(ps[0].last<ErrorMsg>()!.message, PartyText.noBots);
    s.dispose();
    setUpSession(4);
    ps[1].say(const StartGame(GameKind.objasni, null));
    expect(s.phase, Phase.lobby);
    ps[0].say(const StartGame(GameKind.objasni, null));
    expect(s.phase, Phase.objasni);
    s.dispose();
    s = Session(random: Random(1))..objasniTvReady = true;
    ps = [for (var i = 0; i < 4; i++) join(s, 'P$i', token: 't$i')];
    ps[0].say(const StartGame(GameKind.objasni, null));
    expect(s.phase, Phase.lobby, reason: 'no pack loaded');
    s.dispose();
  });

  test('the host\'s pack is used; a missing saved pack falls back and keeps the other settings', () {
    setUpSession(4);
    ps[0].say(const SetSettings(GameSettings(objasniPackId: 'two', objasniSeconds: 90, wolfDiscussion: 60)));
    expect(s.settings.objasniPackId, 'two');
    ps[0].say(const SetSettings(GameSettings(objasniPackId: 'gone', objasniSeconds: 90, wolfDiscussion: 60)));
    expect(s.settings.objasniPackId, isNull);
    expect([s.settings.objasniSeconds, s.settings.wolfDiscussion], [90, 60]);
    ps[0].say(const SetSettings(GameSettings(objasniPackId: 'two')));
    ps[0].say(const StartGame(GameKind.objasni, null));
    expect(s.objasni!.pack.id, 'two');
    s.dispose();
  });

  test('the lobby lists the Objasni packs', () {
    setUpSession(4);
    expect([for (final p in ps[0].last<LobbyState>()!.objasniPacks) p.id], ['one', 'two']);
    s.dispose();
  });

  test('messages are the sending phone\'s own player: only the host reshuffles and starts, only the explainer presses Kreni', () {
    setUpSession(6);
    ps[0].say(const StartGame(GameKind.objasni, null));
    final m = s.objasni!;
    ps[1].say(const Go());
    expect(m.stage, ObjasniStageTv.setup);
    ps[0].say(const Go()); // the host is the first player
    expect(m.stage, ObjasniStageTv.ready);
    final ex = m.explainer!;
    final p = ps.firstWhere((x) => idOf(x) == ex);
    final not = ps.firstWhere((x) => idOf(x) != ex && x != ps[0]); // not the host: the host may press Kreni too
    not.say(const Go());
    expect(m.stage, ObjasniStageTv.ready);
    p.say(const Go());
    expect(m.stage, ObjasniStageTv.play);
    p.say(const ObjasniAction(ObjasniAct.correct));
    expect(m.scores[m.turnTeam], 1);
    s.dispose();
  });

  test('a phone that reloads gets the public lobby, then its teams and own turn state', () async {
    setUpSession(5);
    ps[0].say(const StartGame(GameKind.objasni, null));
    await ps[2].drop();
    final again = join(s, 'P2', token: 't2');
    final order = [for (final m in again.sent) m.type];
    expect(order, containsAll(['lobby', 'objasniTeams']));
    expect(order.indexOf('lobby'), lessThan(order.indexOf('objasniTeams')));
    s.dispose();
  });

  testWidgets('a disconnect is dropping out: the explainer leaving ends the turn; a whole team gone pauses, then the game ends', (t) async {
    setUpSession(4);
    ps[0].say(const StartGame(GameKind.objasni, null));
    final m = s.objasni!;
    ps[0].say(const Go());
    final ex = m.explainer!;
    final exPhone = ps.firstWhere((x) => idOf(x) == ex);
    exPhone.say(const Go());
    expect(m.stage, ObjasniStageTv.play);
    exPhone.close();
    await t.pump();
    expect(m.stage, ObjasniStageTv.summary);
    // the other team all leave
    final other = ps.where((x) => m.teamOf(idOf(x)) != m.teamOf(ex) && x != exPhone).toList();
    for (final p in other) {
      p.close();
      await t.pump();
    }
    final own = ps.where((x) => m.teamOf(idOf(x)) == m.teamOf(ex) && x != exPhone).toList();
    for (final p in own) {
      p.close();
      await t.pump();
    }
    expect(m.paused, isTrue);
    s.dispose();
  });

  testWidgets('a finished game gives placement points to the winning team and goes to the results', (t) async {
    setUpSession(4);
    ps[0].say(const StartGame(GameKind.objasni, null));
    final m = s.objasni!;
    ps[0].say(const Go());
    final ex = m.explainer!;
    ps.firstWhere((x) => idOf(x) == ex).say(const Go());
    final winners = m.teamMembers(m.turnTeam);
    for (var i = 0; i < 30; i++) {
      ps.firstWhere((x) => idOf(x) == ex).say(const ObjasniAction(ObjasniAct.correct));
    }
    await wait(t, 60 + 5);
    ps.firstWhere((x) => idOf(x) == m.explainer).say(const Go());
    await wait(t, 60 + 5);
    expect(s.phase, Phase.objasni, reason: 'the winner screen first');
    expect(m.stage, ObjasniStageTv.over);
    await wait(t, 8);
    expect(s.phase, Phase.results);
    expect(s.placements.length, 4);
    for (final p in s.placements) {
      expect(p.gameScore, winners.contains(p.playerId) ? 1 : 0);
    }
    expect(s.lastGameLabel, PartyText.objasniName);
    s.returnToLobby();
    expect(s.objasni, isNull);
    s.dispose();
  });

  test('kicking a player counts as them leaving for good', () {
    setUpSession(5);
    ps[0].say(const StartGame(GameKind.objasni, null));
    final kicked = idOf(ps[3]);
    ps[0].say(Kick(kicked));
    expect(s.objasni!.game.away, contains(kicked));
    s.dispose();
  });
}
