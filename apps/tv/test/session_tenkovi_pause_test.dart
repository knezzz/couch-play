import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/session/session.dart';
import 'package:tv/session/tenkovi_match.dart';
import 'package:tv/strings.dart';

import 'session_test.dart' show FakePeer, join;

/// Task 56 follow-up: Tenkovi pause rules (main spec), as Curve's.
void main() {
  late Session s;
  late List<FakePeer> ps;
  var at = Duration.zero;

  void setUpSession(int n, {int rounds = 3}) {
    at = Duration.zero;
    s = Session(random: Random(1), clock: () => at);
    ps = [for (var i = 0; i < n; i++) join(s, 'P$i', token: 't$i')];
    ps[0].say(SetSettings(GameSettings(tenkoviMap: TenkoviMapPick.earth, tenkoviRounds: rounds)));
    ps[0].say(const StartGame(GameKind.tenkovi, null));
  }

  /// Time passes, in 16 ms frames, with nobody drawing anything.
  Future<void> advance(WidgetTester t, int ms) async {
    for (var i = 0; i < ms ~/ 16; i++) {
      at += const Duration(milliseconds: 16);
      await t.pump(const Duration(milliseconds: 16));
    }
  }

  void fireAll(int n) {
    for (var i = 0; i < n; i++) {
      ps[i].say(const TenkoviFire(80, 60, TenkoviShell.grenade));
    }
  }

  Future<void> back(WidgetTester t, int i) async {
    ps[i] = join(s, 'P$i', token: 't$i');
    await t.pump();
  }

  testWidgets('the volley flies with no view drawing: the match runs it itself', (t) async {
    setUpSession(3);
    fireAll(3);
    expect(s.tenkovi!.stage, TenkoviStageTv.fly);
    await advance(t, 8000);
    expect(s.tenkovi!.stage, isNot(TenkoviStageTv.fly), reason: 'the shells landed');
    expect(s.tenkovi!.round.volleys, 1);
    s.dispose();
  });

  testWidgets('nobody connected during the aim: paused for everyone, carries on when they return', (t) async {
    setUpSession(2);
    ps[0].close();
    await t.pump();
    ps[1].close();
    await t.pump();
    expect(s.paused, isTrue);
    expect(s.pauseText, Strings.waitingForPlayers);
    expect(s.pauseWaitingFor, isNull);
    expect(s.tenkovi!.paused, isTrue);
    // A Pucaj that arrives meanwhile (a stale phone) is not taken.
    await advance(t, 10000);
    expect(s.paused, isTrue);
    await back(t, 0);
    expect(s.paused, isTrue, reason: 'one is not enough for 2 players');
    expect(s.pauseWaitingFor!.name, 'P1');
    expect(s.pauseText, Strings.waitingForReturn('P1'));
    await back(t, 1);
    expect(s.paused, isFalse);
    expect(s.tenkovi!.paused, isFalse);
    expect(ps[0].last<TenkoviTurn>()!.stage, 'aim');
    ps[0].say(const TenkoviFire(80, 60, TenkoviShell.grenade));
    expect(s.tenkovi!.ready, isNotEmpty);
    s.dispose();
  });

  testWidgets('nobody returns for 30 s: the game ends and the scores stay as they were', (t) async {
    setUpSession(2);
    ps[0].close();
    await t.pump();
    ps[1].close();
    await t.pump();
    await advance(t, 29000);
    expect(s.phase, Phase.tenkovi);
    await advance(t, 2500);
    expect(s.phase, Phase.results);
    s.dispose();
  });

  testWidgets('nobody connected during a volley: it freezes in the air, then flies on once, no second volley', (t) async {
    setUpSession(2);
    fireAll(2);
    await advance(t, 400);
    final round = s.tenkovi!.round;
    expect(s.tenkovi!.stage, TenkoviStageTv.fly);
    ps[0].close();
    await t.pump();
    ps[1].close();
    await t.pump();
    expect(s.paused, isTrue);
    final where = [for (final p in round.projectiles) (p.x, p.y)];
    expect(where, isNotEmpty);
    await advance(t, 20000);
    expect([for (final p in round.projectiles) (p.x, p.y)], where, reason: 'frozen while paused');
    expect(s.paused, isTrue);
    await back(t, 0);
    await back(t, 1);
    expect(s.paused, isFalse);
    await advance(t, 8000);
    expect(s.tenkovi!.stage, isNot(TenkoviStageTv.fly));
    expect(s.tenkovi!.round.volleys, 1, reason: 'the volley did not fire twice');
    s.dispose();
  });

  testWidgets('2 players drop to 1: waits for the one who left, by name, and carries on when they are back', (t) async {
    setUpSession(2);
    ps[0].say(const TenkoviFire(80, 60, TenkoviShell.grenade));
    ps[1].close();
    await t.pump();
    expect(s.paused, isTrue);
    expect(s.pauseWaitingFor!.name, 'P1');
    expect(s.pauseText, Strings.waitingForReturn('P1'));
    expect(ps[0].sent.whereType<Waiting>().last.reason, Strings.waitingForReturn('P1'));
    await advance(t, 15000);
    expect(s.paused, isTrue);
    await back(t, 1);
    expect(s.paused, isFalse);
    expect(s.phase, Phase.tenkovi);
    expect(ps[0].last<TenkoviTurn>(), isNotNull);
    s.dispose();
  });

  testWidgets('2 players drop to 1 and the other does not come back: ends after 30 s with scores kept', (t) async {
    setUpSession(2);
    ps[1].close();
    await t.pump();
    await advance(t, 30500);
    expect(s.phase, Phase.results);
    s.dispose();
  });

  testWidgets('3 players lose one: no pause, the tank stays and does not fire, it rejoins next turn', (t) async {
    setUpSession(3);
    ps[2].close();
    await t.pump();
    expect(s.paused, isFalse);
    expect(s.tenkovi!.paused, isFalse);
    fireAll(2);
    expect(s.tenkovi!.stage, TenkoviStageTv.fly);
    expect(s.tenkovi!.round.projectiles.length, 2, reason: 'the dropped tank did not fire');
    await advance(t, 8000);
    await back(t, 2);
    expect(s.paused, isFalse);
    expect(ps[2].last<TenkoviTurn>()!.stage, anyOf('aim', 'end'));
    s.dispose();
  });

  testWidgets('a phone blip: every phone of 2 or 3 players drops one by one and returns: the round was not ended, nothing scored', (t) async {
    for (final n in [2, 3]) {
      setUpSession(n, rounds: 1);
      for (var i = 0; i < n; i++) {
        ps[i].close();
        await t.pump();
      }
      expect(s.paused, isTrue);
      await advance(t, 5000);
      for (var i = 0; i < n; i++) {
        await back(t, i);
      }
      expect(s.paused, isFalse);
      await advance(t, 60000);
      expect(s.phase, Phase.tenkovi, reason: ' players: the match is still on');
      expect(s.tenkovi!.match.played, 0);
      expect(s.tenkovi!.stage, TenkoviStageTv.aim);
      s.dispose();
    }
  });

  testWidgets('3 players lose two: paused for the last one to leave, as Curve does', (t) async {
    setUpSession(3);
    ps[1].close();
    await t.pump();
    expect(s.paused, isFalse);
    ps[2].close();
    await t.pump();
    expect(s.paused, isTrue);
    expect(s.pauseWaitingFor!.name, 'P2');
    await back(t, 1);
    expect(s.paused, isFalse);
    s.dispose();
  });
}
