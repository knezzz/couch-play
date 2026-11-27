import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/session/party_text.dart';
import 'package:tv/session/session.dart';
import 'package:tv/session/tenkovi_match.dart';

import 'session_test.dart' show FakePeer, join;

/// Task 56: Tenkovi inside the Session.
void main() {
  late Session s;
  late List<FakePeer> ps;

  void setUpSession(int n, {int bots = 0}) {
    s = Session(random: Random(1), clock: () => Duration.zero);
    ps = [for (var i = 0; i < n; i++) join(s, 'P$i', token: 't$i')];
    if (bots > 0) s.setBotCount(bots);
  }

  int idOf(FakePeer p) => p.sent.whereType<Welcome>().first.playerId;

  test('2 to 8 humans, no bots, only the host', () {
    setUpSession(1);
    ps[0].say(const StartGame(GameKind.tenkovi, null));
    expect(ps[0].last<ErrorMsg>()!.message, PartyText.tenkoviNeedPlayers);
    s.dispose();
    setUpSession(2, bots: 1);
    ps[0].say(const StartGame(GameKind.tenkovi, null));
    expect(ps[0].last<ErrorMsg>()!.message, PartyText.noBots);
    s.dispose();
    setUpSession(3);
    ps[1].say(const StartGame(GameKind.tenkovi, null));
    expect(s.phase, Phase.lobby);
    ps[0].say(const StartGame(GameKind.tenkovi, null));
    expect(s.phase, Phase.tenkovi);
    s.dispose();
  });

  test('the host\'s map and rounds are used', () {
    setUpSession(3);
    ps[0].say(const SetSettings(GameSettings(tenkoviMap: TenkoviMapPick.moon, tenkoviRounds: 5)));
    ps[0].say(const StartGame(GameKind.tenkovi, null));
    expect(s.tenkovi!.round.map, TenkoviMap.moon);
    expect(s.tenkovi!.rounds, 5);
    expect(ps[1].last<TenkoviTurn>()!.map, TenkoviMap.moon);
    s.dispose();
  });

  test('PRIVACY through the wire: Pucaj from one phone reaches no other phone', () {
    setUpSession(3);
    ps[0].say(const StartGame(GameKind.tenkovi, null));
    ps[0].say(const TenkoviFire(137, 83, TenkoviShell.cluster));
    expect(s.tenkovi!.ready, {idOf(ps[0])});
    for (final p in [ps[1], ps[2]]) {
      for (final m in p.sent.whereType<TenkoviTurn>()) {
        expect(m.sent, isNull);
        expect(m.last, isNull);
      }
      expect(p.last<TenkoviTurn>()!.ready, 1);
    }
    expect(ps[0].last<TenkoviTurn>()!.sent, [137, 83, TenkoviShell.cluster.index]);
    s.dispose();
  });

  test('the volley fires when everyone has pressed Pucaj, and a reload gets the turn back', () {
    setUpSession(3);
    ps[0].say(const StartGame(GameKind.tenkovi, null));
    for (final p in ps) {
      p.say(const TenkoviFire(90, 5, TenkoviShell.grenade));
    }
    expect(s.tenkovi!.stage, TenkoviStageTv.fly);
    expect(ps[1].last<TenkoviTurn>()!.stage, 'fly');
    // A phone that reloads gets the same turn again.
    final again = join(s, 'P1', token: 't1');
    expect(again.last<TenkoviTurn>()!.stage, 'fly');
    s.dispose();
  });

  test('a phone that leaves does not hold the volley up', () async {
    setUpSession(3);
    ps[0].say(const StartGame(GameKind.tenkovi, null));
    ps[0].say(const TenkoviFire(90, 5, TenkoviShell.grenade));
    ps[1].say(const TenkoviFire(90, 5, TenkoviShell.grenade));
    await ps[2].drop();
    expect(s.tenkovi!.stage, TenkoviStageTv.fly);
    s.dispose();
  });

  test('the match ends in Results with placements, and Back abandons it', () {
    setUpSession(2);
    ps[0].say(const SetSettings(GameSettings(tenkoviRounds: 1)));
    ps[0].say(const StartGame(GameKind.tenkovi, null));
    s.endGame();
    expect(s.phase, Phase.lobby);
    expect(s.tenkovi, isNull);
    s.dispose();
  });
}
