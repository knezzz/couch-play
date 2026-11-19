import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/session/objasni_match.dart';
import 'package:tv/session/session.dart';

import 'session_test.dart' show FakePeer, join;

/// Task 45f: in a game the phones get the players still in it, on their own.
void main() {
  late Session s;
  late List<FakePeer> ps;
  int idOf(FakePeer p) => p.sent.whereType<Welcome>().first.playerId;

  void setUpSession(int n) {
    s = Session(random: Random(1))
      ..uljezTvReady = true
      ..objasniTvReady = true;
    s.uljezPacks = [UljezPack('p', 'P', [for (var i = 0; i < 8; i++) WordPair('a$i', 'b$i')])];
    s.objasniPacks = [ObjasniPack('o', 'O', [for (var i = 0; i < 30; i++) 'w$i'])];
    ps = [for (var i = 0; i < n; i++) join(s, 'P$i', token: 't$i')];
  }

  test('nothing in the lobby; a game start tells everyone; a kick updates every phone the same', () {
    setUpSession(4);
    for (final p in ps) {
      expect(p.all<GamePlayers>(), isEmpty);
    }
    ps[0].say(const StartGame(GameKind.uljez, null));
    for (final p in ps) {
      expect(p.last<GamePlayers>()!.players.length, 4);
    }
    final gone = idOf(ps[3]);
    ps[0].say(Kick(gone));
    for (final p in ps.take(3)) {
      final l = p.last<GamePlayers>()!;
      expect([for (final x in l.players) x.id], isNot(contains(gone)));
      expect(l.players.length, 3);
      expect(l, ps[0].last<GamePlayers>());
    }
    s.dispose();
  });

  test('a dropped phone shows as not connected, and as connected again on return; a returning phone gets the list', () async {
    setUpSession(3);
    ps[0].say(const StartGame(GameKind.uljez, null));
    final id = idOf(ps[2]);
    ps[2].close();
    await Future<void>.delayed(Duration.zero);
    expect(ps[0].last<GamePlayers>()!.players.firstWhere((x) => x.id == id).connected, isFalse);
    final back = join(s, 'P2', token: 't2');
    expect(back.last<GamePlayers>()!.players.firstWhere((x) => x.id == id).connected, isTrue);
    final order = [for (final m in back.sent) m.type];
    expect(order.indexOf('lobby'), lessThan(order.indexOf('gamePlayers')));
    expect(ps[0].last<GamePlayers>()!.players.firstWhere((x) => x.id == id).connected, isTrue);
    s.dispose();
  });

  test('a TV kick of the host updates the list too; the dead are not listed', () {
    setUpSession(4);
    ps[0].say(const StartGame(GameKind.uljez, null));
    final host = s.hostId!;
    expect(s.kickFromTv(host), isTrue);
    final l = ps.last.last<GamePlayers>()!;
    expect(l.players.length, 3);
    expect([for (final x in l.players) x.id], isNot(contains(host)));
    s.dispose();
  });

  test('the list is plain JSON that round-trips', () {
    final m = GamePlayers([const PlayerInfo(1, 'A', 2, false, 0), const PlayerInfo(3, 'B', 1, true, 5, bot: true)]);
    expect(Message.decode(m.encode()), m);
  });

  test('Objasni setup: after a kick the guests get the teams without that player', () {
    setUpSession(4);
    ps[0].say(const StartGame(GameKind.objasni, null));
    final gone = idOf(ps[2]);
    final before = ps[1].last<ObjasniTeams>()!;
    expect(before.teams.expand((t) => t), contains(gone));
    ps[0].say(Kick(gone));
    for (final p in [ps[1], ps[3]]) {
      final t = p.last<ObjasniTeams>()!;
      expect(t.teams.expand((x) => x), isNot(contains(gone)));
      expect(t.teams.expand((x) => x).length, 3);
    }
    s.dispose();
  });

  test('Objasni setup: after kicks and any number of Promiješaj the teams differ by at most 1 and the kicked are never dealt', () {
    for (final n in [5, 6, 7]) {
      setUpSession(n);
      ps[0].say(const StartGame(GameKind.objasni, null));
      final gone = [idOf(ps[2]), if (n >= 6) idOf(ps[4])];
      for (final g in gone) {
        ps[0].say(Kick(g));
        final t = ps[1].last<ObjasniTeams>()!.teams;
        expect((t[0].length - t[1].length).abs(), lessThanOrEqualTo(1), reason: 'n=$n right after the kick');
      }
      for (var i = 0; i < 60; i++) {
        ps[0].say(const Reshuffle());
        final t = ps[1].last<ObjasniTeams>()!.teams;
        final all = t.expand((x) => x).toList();
        expect(all.length, n - gone.length);
        expect(all.toSet().intersection(gone.toSet()), isEmpty);
        expect((t[0].length - t[1].length).abs(), lessThanOrEqualTo(1), reason: 'n=$n reshuffle $i');
        expect(s.objasni!.teamMembers(0).toSet().intersection(gone.toSet()), isEmpty);
      }
      s.dispose();
    }
  });

  test('Objasni: kicking the explainer in the middle of a turn ends that turn at once', () {
    setUpSession(6);
    ps[0].say(const StartGame(GameKind.objasni, null));
    ps[0].say(const Go());
    final m = s.objasni!;
    final ex = m.explainer!;
    ps.firstWhere((x) => idOf(x) == ex).say(const Go());
    expect(m.stage, ObjasniStageTv.play);
    expect(s.kickFromTv(ex), isTrue);
    expect(m.stage, ObjasniStageTv.summary);
    s.dispose();
  });
}
